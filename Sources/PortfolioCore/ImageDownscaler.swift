import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Downscales and JPEG-encodes images off the main actor, platform-neutrally
/// (ImageIO only — no UIKit/AppKit). Based on Jeroboam's `ImageDownscaler`
/// (the best of the portfolio's copies), rebuilt on the `CGImageSource`
/// thumbnail API so it also runs on macOS/watchOS and never decodes a 12 MP
/// photo at full size just to shrink it.
///
/// ```swift
/// // PhotosPicker / camera data → upload-ready JPEG (longest edge 2048 px)
/// let jpeg = await ImageDownscaler.jpegData(from: pickedData)
///
/// // UIKit: let jpeg = await ImageDownscaler.jpegData(from: uiImage.cgImage!, longestEdge: 1024)
/// ```
///
/// The data path applies the EXIF orientation and drops all metadata (GPS,
/// camera, timestamps) — usually what you want before an upload.
public enum ImageDownscaler {
    public static let defaultLongestEdge = 2048
    public static let defaultQuality = 0.7

    // MARK: Async (off the calling actor)

    /// Downscale encoded image `data` (JPEG/HEIC/PNG/…) so its longest edge is at
    /// most `longestEdge` pixels, then JPEG-encode — on a detached task.
    public static func jpegData(
        from data: Data,
        longestEdge: Int = defaultLongestEdge,
        quality: Double = defaultQuality
    ) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            downscaledJPEG(from: data, longestEdge: longestEdge, quality: quality)
        }.value
    }

    /// Same for an already-decoded `CGImage` (e.g. `UIImage.cgImage`). Note a
    /// `CGImage` carries no orientation — pass an upright image.
    public static func jpegData(
        from image: CGImage,
        longestEdge: Int = defaultLongestEdge,
        quality: Double = defaultQuality
    ) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            downscaledJPEG(from: image, longestEdge: longestEdge, quality: quality)
        }.value
    }

    // MARK: Synchronous building blocks

    /// Synchronous core of ``jpegData(from:longestEdge:quality:)-(Data,_,_)``.
    public static func downscaledJPEG(from data: Data, longestEdge: Int = defaultLongestEdge, quality: Double = defaultQuality) -> Data? {
        guard let image = downscaledImage(from: data, longestEdge: longestEdge) else { return nil }
        return encodeJPEG(image, quality: quality)
    }

    /// Synchronous core of ``jpegData(from:longestEdge:quality:)-(CGImage,_,_)``.
    public static func downscaledJPEG(from image: CGImage, longestEdge: Int = defaultLongestEdge, quality: Double = defaultQuality) -> Data? {
        guard let scaled = downscaledImage(image, longestEdge: longestEdge) else { return nil }
        return encodeJPEG(scaled, quality: quality)
    }

    /// Decode `data` at most `longestEdge` pixels on its longest side, upright.
    /// Never upscales.
    public static func downscaledImage(from data: Data, longestEdge: Int) -> CGImage? {
        guard longestEdge > 0,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
        else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: longestEdge,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Redraw `image` so its longest edge is at most `longestEdge`. Returns the
    /// original when it already fits.
    public static func downscaledImage(_ image: CGImage, longestEdge: Int) -> CGImage? {
        guard longestEdge > 0 else { return nil }
        let size = targetSize(width: image.width, height: image.height, longestEdge: longestEdge)
        guard size.width != image.width || size.height != image.height else { return image }
        let colorSpace = image.colorSpace.flatMap { $0.model == .rgb ? $0 : nil }
            ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil, width: size.width, height: size.height,
            bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        return context.makeImage()
    }

    /// JPEG-encode `image` at `quality` (0…1).
    public static func encodeJPEG(_ image: CGImage, quality: Double = defaultQuality) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        let options = [kCGImageDestinationLossyCompressionQuality: min(max(quality, 0), 1)] as CFDictionary
        CGImageDestinationAddImage(destination, image, options)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    /// The pixel size that fits `width × height` inside `longestEdge`,
    /// preserving aspect ratio (rounded, at least 1 px). Never upscales.
    public static func targetSize(width: Int, height: Int, longestEdge: Int) -> (width: Int, height: Int) {
        let maxEdge = max(width, height)
        guard maxEdge > longestEdge, maxEdge > 0 else { return (width, height) }
        let ratio = Double(longestEdge) / Double(maxEdge)
        return (max(1, Int((Double(width) * ratio).rounded())), max(1, Int((Double(height) * ratio).rounded())))
    }
}

/// An in-memory cache for loaded thumbnails (or any value) with **in-flight
/// de-duplication**: concurrent requests for the same key share one load.
/// Generalized from ThenCam Admin's `ThumbnailLoader`; the app supplies the
/// loader (Supabase Storage download, file read + ``ImageDownscaler``, …).
///
/// ```swift
/// let thumbnails = ThumbnailCache<String, Data>(countLimit: 300) { path in
///     guard let data = try? await storage.download(path: path) else { return nil }
///     return await ImageDownscaler.jpegData(from: data, longestEdge: 400)
/// }
/// let data = await thumbnails.value(for: photo.path)
/// ```
///
/// Backed by `NSCache`, so entries are evicted under memory pressure. Failed
/// loads (`nil`) are not cached.
public actor ThumbnailCache<Key: Hashable & Sendable, Value: Sendable> {
    private final class KeyBox: NSObject {
        let key: Key
        init(_ key: Key) { self.key = key }
        override var hash: Int { key.hashValue }
        override func isEqual(_ object: Any?) -> Bool { (object as? KeyBox)?.key == key }
    }

    private final class ValueBox {
        let value: Value
        init(_ value: Value) { self.value = value }
    }

    private let cache = NSCache<KeyBox, ValueBox>()
    private var inFlight: [Key: Task<Value?, Never>] = [:]
    private let loader: @Sendable (Key) async -> Value?
    private let cost: (@Sendable (Value) -> Int)?

    /// - Parameters:
    ///   - countLimit: max entries (0 = no limit).
    ///   - totalCostLimit: max total cost (0 = no limit); pair with `cost`.
    ///   - cost: per-value cost, e.g. `{ $0.count }` for `Data`.
    ///   - loader: produces the value for a key; `nil` means "not available".
    public init(
        countLimit: Int = 0,
        totalCostLimit: Int = 0,
        cost: (@Sendable (Value) -> Int)? = nil,
        loader: @escaping @Sendable (Key) async -> Value?
    ) {
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
        self.cost = cost
        self.loader = loader
    }

    /// The cached value, or the (shared) result of loading it.
    public func value(for key: Key) async -> Value? {
        if let cached = cache.object(forKey: KeyBox(key)) { return cached.value }
        if let task = inFlight[key] { return await task.value }

        let loader = self.loader
        let task = Task<Value?, Never> { await loader(key) }
        inFlight[key] = task
        let value = await task.value
        // Only clear/insert if this load is still current (not cancelled by
        // `remove`/`removeAll` while it ran).
        if inFlight[key] == task {
            inFlight[key] = nil
            if let value { insert(value, for: key) }
        }
        return value
    }

    /// The cached value without loading.
    public func cachedValue(for key: Key) -> Value? {
        cache.object(forKey: KeyBox(key))?.value
    }

    public func insert(_ value: Value, for key: Key) {
        cache.setObject(ValueBox(value), forKey: KeyBox(key), cost: cost?(value) ?? 0)
    }

    public func remove(_ key: Key) {
        inFlight[key] = nil
        cache.removeObject(forKey: KeyBox(key))
    }

    public func removeAll() {
        inFlight.removeAll()
        cache.removeAllObjects()
    }
}

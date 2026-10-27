import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Codable snapshots in an App Group container, shared between an app and its
/// widgets / extensions (encode → group container → `WidgetCenter` reload).
/// Replaces Sextant `SharedStore`, Celiador `WidgetShared`, Otta
/// `WidgetSnapshotWriter` and the copies in Lunker/Equinox/Jeroboam/Stokked.
///
/// ```swift
/// let store = AppGroupStore(groupID: "group.com.sextant.crawik")
/// try store.write(snapshot, as: "conditions.json")
/// store.reloadWidgets()                                   // or write(…, reloadWidgets: true)
///
/// // widget side
/// let snapshot = try? store.read(ConditionsSnapshot.self, from: "conditions.json")
/// ```
///
/// Files are written atomically. App Groups are **per device**: they are not
/// shared between iPhone and Apple Watch — use ``WatchLink`` for that hop.
public struct AppGroupStore: Sendable {
    public enum StoreError: Error, Equatable {
        /// The App Group container couldn't be resolved — the group is missing
        /// from the target's entitlements (or the ID is misspelt).
        case containerUnavailable(String)
    }

    /// The App Group identifier, or `nil` when created with a plain directory.
    public let groupID: String?
    /// The container (or custom) directory files are written into.
    public let directory: URL?

    /// A store backed by the App Group container for `groupID`.
    public init(groupID: String) {
        self.groupID = groupID
        self.directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
    }

    /// A store backed by an arbitrary directory (tests, previews, non-group use).
    public init(directory: URL) {
        self.groupID = nil
        self.directory = directory
    }

    /// The App Group's shared `UserDefaults` suite (for apps that keep small
    /// values there rather than in files). `nil` for directory-backed stores.
    public var defaults: UserDefaults? {
        groupID.flatMap(UserDefaults.init(suiteName:))
    }

    /// Where `filename` lives, or `nil` when the container is unavailable.
    public func url(for filename: String) -> URL? {
        directory?.appendingPathComponent(filename, isDirectory: false)
    }

    /// JSON-encode `value` into `filename` (atomically), optionally reloading
    /// every widget timeline afterwards.
    public func write<T: Encodable>(
        _ value: T,
        as filename: String,
        encoder: JSONEncoder = JSONEncoder(),
        reloadWidgets: Bool = false
    ) throws {
        guard let url = url(for: filename) else {
            throw StoreError.containerUnavailable(groupID ?? "<directory>")
        }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try encoder.encode(value).write(to: url, options: .atomic)
        if reloadWidgets { self.reloadWidgets() }
    }

    /// Decode `filename`. Returns `nil` when the file doesn't exist (or the
    /// container is unavailable); throws when it exists but doesn't decode.
    public func read<T: Decodable>(
        _ type: T.Type = T.self,
        from filename: String,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> T? {
        guard let url = url(for: filename), FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return try decoder.decode(T.self, from: Data(contentsOf: url))
    }

    /// Delete `filename` if present.
    public func remove(_ filename: String) throws {
        guard let url = url(for: filename), FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    /// Ask WidgetKit to reload timelines — all of them, or one `kind`.
    /// No-op where WidgetKit isn't available.
    public func reloadWidgets(kind: String? = nil) {
        Self.reloadWidgets(kind: kind)
    }

    /// Static form of ``reloadWidgets(kind:)``.
    public static func reloadWidgets(kind: String? = nil) {
        #if canImport(WidgetKit) && !os(visionOS)
        if let kind {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        } else {
            WidgetCenter.shared.reloadAllTimelines()
        }
        #elseif canImport(WidgetKit) && os(visionOS)
        if #available(visionOS 26, *) {
            if let kind {
                WidgetCenter.shared.reloadTimelines(ofKind: kind)
            } else {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        #endif
    }
}

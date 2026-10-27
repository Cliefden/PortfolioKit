import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import PortfolioCore

// MARK: - CSVWriter

@Suite struct CSVWriterTests {
    @Test func plainFieldsAreUnquoted() {
        #expect(CSVWriter.row(["a", "b c", "42"]) == "a,b c,42")
    }

    @Test func quotesWhenNeeded() {
        #expect(CSVWriter.field("a,b") == "\"a,b\"")
        #expect(CSVWriter.field("say \"hi\"") == "\"say \"\"hi\"\"\"")
        #expect(CSVWriter.field("line\nbreak") == "\"line\nbreak\"")
        #expect(CSVWriter.field("cr\rhere") == "\"cr\rhere\"")
        #expect(CSVWriter.field(" padded") == "\" padded\"")
        #expect(CSVWriter.field("trailing ") == "\"trailing \"")
        #expect(CSVWriter.field("") == "")
    }

    @Test func documentUsesCRLFAndHeader() {
        let csv = CSVWriter.document(header: ["Name", "Notes"], rows: [["Margaux", "Great, long"], ["Barolo", ""]])
        #expect(csv == "Name,Notes\r\nMargaux,\"Great, long\"\r\nBarolo,\r\n")
        #expect(CSVWriter.document(header: nil, rows: [], lineEnding: "\n") == "")
    }

    @Test func formulaGuardIsOptInAndReversible() {
        #expect(CSVWriter.field("=SUM(A1)") == "=SUM(A1)")
        #expect(CSVWriter.field("=SUM(A1)", formulaGuard: true) == "'=SUM(A1)")
        #expect(CSVWriter.field("-5", formulaGuard: true) == "'-5")
        #expect(CSVWriter.field("@x,y", formulaGuard: true) == "\"'@x,y\"")
        #expect(CSVWriter.removingFormulaGuard("'=SUM(A1)") == "=SUM(A1)")
        #expect(CSVWriter.removingFormulaGuard("'quoted") == "'quoted")
    }

    @Test func numbersAreLocaleIndependent() {
        #expect(CSVWriter.number(95.5) == "95.5")
        #expect(CSVWriter.number(12345) == "12345")
    }
}

// MARK: - PortfolioDateFormat

@Suite struct PortfolioDateFormatTests {
    let utc = TimeZone(identifier: "UTC")!
    let stockholm = TimeZone(identifier: "Europe/Stockholm")!
    let en = Locale(identifier: "en_US")
    // 2026-06-05 04:30:00 UTC
    let date = Date(timeIntervalSince1970: 1_780_633_800)

    @Test func timeHonoursZoneAndLocale() {
        #expect(PortfolioDateFormat.time(date, timeZone: utc, locale: Locale(identifier: "en_GB")) == "04:30")
        #expect(PortfolioDateFormat.time(date, timeZone: stockholm, locale: Locale(identifier: "sv_SE")) == "06:30")
        #expect(PortfolioDateFormat.time(nil) == "--:--")
    }

    @Test func shortDates() {
        #expect(PortfolioDateFormat.shortDate(date, timeZone: utc, locale: en) == "Jun 5")
        #expect(PortfolioDateFormat.shortDateWithYear(date, timeZone: utc, locale: en) == "Jun 5, 2026")
        #expect(PortfolioDateFormat.monthYear(date, timeZone: utc, locale: en) == "June 2026")
        #expect(PortfolioDateFormat.shortDate(date, timeZone: utc, locale: Locale(identifier: "sv_SE")) == "5 juni")
    }

    @Test func durationAlwaysShowsHoursAndMinutes() {
        #expect(PortfolioDateFormat.duration(14 * 3600 + 32 * 60 + 59, locale: en) == "14h 32m")
        #expect(PortfolioDateFormat.duration(5 * 60, locale: en) == "0h 5m")
        #expect(PortfolioDateFormat.duration(nil) == "--")
    }

    @Test func daysBetweenCountsCalendarDaysInZone() {
        let late = Date(timeIntervalSince1970: 1_780_696_800) // 2026-06-05 22:00 UTC = 06-06 00:00 Stockholm
        #expect(PortfolioDateFormat.daysBetween(from: date, to: late, timeZone: utc) == 0)
        #expect(PortfolioDateFormat.daysBetween(from: date, to: late, timeZone: stockholm) == 1)
        #expect(PortfolioDateFormat.daysBetween(from: late, to: date, timeZone: stockholm) == -1)
    }

    @Test func relativeShortBuckets() {
        let now = date
        func rel(_ seconds: TimeInterval) -> String {
            PortfolioDateFormat.relativeShort(now.addingTimeInterval(-seconds), now: now, timeZone: utc, locale: en)
        }
        #expect(rel(10) == "now")
        #expect(rel(-500) == "now")
        #expect(rel(4 * 60 + 5) == "4m")
        #expect(rel(3 * 3600 + 100) == "3h")
        #expect(rel(2 * 86_400 + 5) == "2d")
        #expect(rel(10 * 86_400) == "May 26")
    }

    @Test func relativeShortParsesISO() {
        let now = Date(timeIntervalSince1970: 1_780_633_800 + 120)
        #expect(PortfolioDateFormat.relativeShort(iso: "2026-06-05T04:30:00Z", now: now, locale: en) == "2m")
        #expect(PortfolioDateFormat.relativeShort(iso: "2026-06-05T04:29:59.500Z", now: now, locale: en) == "2m")
        #expect(PortfolioDateFormat.relativeShort(iso: "garbage", now: now) == "")
    }

    @Test func cachedFormattersAreThreadSafe() async {
        await withTaskGroup(of: String.self) { group in
            for i in 0..<200 {
                group.addTask { PortfolioDateFormat.shortDate(self.date.addingTimeInterval(Double(i)), timeZone: self.utc, locale: self.en) }
            }
            for await value in group { #expect(value == "Jun 5") }
        }
    }
}

// MARK: - AppGroupStore

@Suite struct AppGroupStoreTests {
    struct Snapshot: Codable, Equatable { var temperature: Double; var label: String }

    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("portfoliocore-appgroup-\(UUID().uuidString)", isDirectory: true)

    @Test func writeReadRemove() throws {
        let store = AppGroupStore(directory: directory)
        #expect(try store.read(Snapshot.self, from: "s.json") == nil)
        try store.write(Snapshot(temperature: 12.5, label: "Breezy"), as: "s.json")
        #expect(try store.read(Snapshot.self, from: "s.json") == Snapshot(temperature: 12.5, label: "Breezy"))
        try store.remove("s.json")
        #expect(try store.read(Snapshot.self, from: "s.json") == nil)
        try? FileManager.default.removeItem(at: directory)
    }

    @Test func corruptFileThrows() throws {
        let store = AppGroupStore(directory: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: store.url(for: "bad.json")!)
        #expect(throws: (any Error).self) { try store.read(Snapshot.self, from: "bad.json") }
        try? FileManager.default.removeItem(at: directory)
    }

    @Test func missingGroupContainerThrowsOnWrite() {
        // `swift test` has no App Group entitlement, so the container is nil
        // on iOS-style sandboxes; on an unsandboxed macOS host it may resolve.
        let store = AppGroupStore(groupID: "group.portfoliokit.tests.\(UUID().uuidString)")
        if store.directory == nil {
            #expect(throws: AppGroupStore.StoreError.self) { try store.write(1, as: "x.json") }
        }
        #expect(store.groupID != nil)
    }
}

// MARK: - LaunchFlags & AnyEncodable

@Suite struct LaunchFlagsTests {
    @Test func argumentsAndEnvironment() {
        let flags = LaunchFlags(arguments: ["app", "-premium", "-tab", "2", "SCREENSHOT_TAB_3"], environment: ["DEMO_SEED": "1", "OFF": "0"])
        #expect(flags.has("-premium"))
        #expect(flags.has("--demo-seed"))
        #expect(!flags.has("-off"))
        #expect(!flags.has("-missing"))
        #expect(flags.value(for: "-tab") == "2")
        #expect(flags.suffixNumber(afterPrefix: "SCREENSHOT_TAB_") == 3)
        #expect(!flags.isScreenshotMode)
    }

    @Test func screenshotModeSources() {
        #expect(LaunchFlags(arguments: ["SCREENSHOT_MODE"], environment: [:]).isScreenshotMode)
        #expect(LaunchFlags(arguments: ["-FASTLANE_SNAPSHOT", "YES"], environment: [:]).isScreenshotMode)
        #expect(LaunchFlags(arguments: [], environment: ["SCREENSHOT_MODE": "1"]).isScreenshotMode)
        #expect(!LaunchFlags(arguments: [], environment: ["SCREENSHOT_MODE": "false"]).isScreenshotMode)
    }

    @Test func environmentKeyDerivation() {
        #expect(LaunchFlags.environmentKey(for: "-premium") == "PREMIUM")
        #expect(LaunchFlags.environmentKey(for: "--demo-seed") == "DEMO_SEED")
    }

    @Test func anyEncodableEncodesWrappedValues() throws {
        let payload: [String: AnyEncodable] = ["name": AnyEncodable("Milk"), "count": AnyEncodable(2), "done": AnyEncodable(false)]
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let json = String(decoding: try encoder.encode(payload), as: UTF8.self)
        #expect(json == #"{"count":2,"done":false,"name":"Milk"}"#)
    }
}

// MARK: - ImageDownscaler & ThumbnailCache

private func makeImage(width: Int, height: Int) -> CGImage {
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(red: 0.2, green: 0.5, blue: 0.3, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()!
}

private func pixelSize(ofJPEG data: Data) -> [Int]? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let w = props[kCGImagePropertyPixelWidth] as? Int,
          let h = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
    return [w, h]
}

private func size(_ s: (width: Int, height: Int)) -> [Int] { [s.width, s.height] }

@Suite struct ImageDownscalerTests {
    @Test func targetSizeKeepsAspectAndNeverUpscales() {
        #expect(size(ImageDownscaler.targetSize(width: 4000, height: 3000, longestEdge: 2048)) == [2048, 1536])
        #expect(size(ImageDownscaler.targetSize(width: 3000, height: 4000, longestEdge: 1000)) == [750, 1000])
        #expect(size(ImageDownscaler.targetSize(width: 800, height: 600, longestEdge: 2048)) == [800, 600])
    }

    @Test func downscalesCGImage() async throws {
        let jpeg = try #require(await ImageDownscaler.jpegData(from: makeImage(width: 1200, height: 600), longestEdge: 300))
        let size = try #require(pixelSize(ofJPEG: jpeg))
        #expect(size == [300, 150])
    }

    @Test func downscalesEncodedData() async throws {
        let original = try #require(ImageDownscaler.encodeJPEG(makeImage(width: 1000, height: 2000), quality: 0.9))
        let jpeg = try #require(await ImageDownscaler.jpegData(from: original, longestEdge: 500))
        let size = try #require(pixelSize(ofJPEG: jpeg))
        #expect(size == [250, 500])
    }

    @Test func smallImagesAreNotUpscaled() throws {
        let original = try #require(ImageDownscaler.encodeJPEG(makeImage(width: 100, height: 80)))
        let jpeg = try #require(ImageDownscaler.downscaledJPEG(from: original, longestEdge: 2048))
        #expect(pixelSize(ofJPEG: jpeg) == [100, 80])
    }

    @Test func garbageDataReturnsNil() async {
        #expect(await ImageDownscaler.jpegData(from: Data("nope".utf8)) == nil)
    }
}

@Suite struct ThumbnailCacheTests {
    final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0
        func increment() { lock.withLock { value += 1 } }
        var count: Int { lock.withLock { value } }
    }

    @Test func dedupesConcurrentLoadsAndCaches() async {
        let counter = Counter()
        let cache = ThumbnailCache<String, String> { key in
            counter.increment()
            try? await Task.sleep(for: .milliseconds(50))
            return key.uppercased()
        }
        await withTaskGroup(of: String?.self) { group in
            for _ in 0..<20 { group.addTask { await cache.value(for: "a") } }
            for await value in group { #expect(value == "A") }
        }
        #expect(counter.count == 1)
        #expect(await cache.value(for: "a") == "A")
        #expect(counter.count == 1)
        #expect(await cache.cachedValue(for: "a") == "A")
    }

    @Test func failedLoadsAreNotCached() async {
        let counter = Counter()
        let cache = ThumbnailCache<Int, Int> { _ in counter.increment(); return nil }
        #expect(await cache.value(for: 1) == nil)
        #expect(await cache.value(for: 1) == nil)
        #expect(counter.count == 2)
    }

    @Test func removeEvicts() async {
        let counter = Counter()
        let cache = ThumbnailCache<Int, Int> { key in counter.increment(); return key * 2 }
        #expect(await cache.value(for: 2) == 4)
        await cache.remove(2)
        #expect(await cache.cachedValue(for: 2) == nil)
        #expect(await cache.value(for: 2) == 4)
        #expect(counter.count == 2)
    }
}

// MARK: - NetworkMonitor

@Suite struct NetworkMonitorTests {
    @Test func connectionTypeMapping() {
        typealias U = NetworkMonitor.PathUpdate
        #expect(U.connectionType(satisfied: false, wifi: true, cellular: false, wired: false) == .none)
        #expect(U.connectionType(satisfied: true, wifi: true, cellular: true, wired: false) == .wifi)
        #expect(U.connectionType(satisfied: true, wifi: false, cellular: true, wired: false) == .cellular)
        #expect(U.connectionType(satisfied: true, wifi: false, cellular: false, wired: true) == .wired)
        #expect(U.connectionType(satisfied: true, wifi: false, cellular: false, wired: false) == .other)
    }

    @MainActor
    @Test func simulateOfflineOverridesConnectivity() {
        let monitor = NetworkMonitor(assumeConnected: true)
        #expect(monitor.isConnected)
        monitor.simulateOffline = true
        #expect(!monitor.isConnected)
        monitor.simulateOffline = false
        #expect(monitor.isConnected)
    }
}

// MARK: - SwiftDataRecovery

#if canImport(SwiftData)
@Suite struct SwiftDataRecoveryTests {
    @Test func movesStoreAndSideFilesAside() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("portfoliocore-sd-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }
        let store = dir.appendingPathComponent("default.store")
        for name in ["default.store", "default.store-wal", "default.store-shm"] {
            try Data("x".utf8).write(to: dir.appendingPathComponent(name))
        }
        try fm.createDirectory(at: dir.appendingPathComponent(".default_SUPPORT"), withIntermediateDirectories: true)

        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let backup = try #require(SwiftDataRecovery.moveStoreAside(at: store, now: now))
        #expect(backup.lastPathComponent == "1800000000")
        #expect(backup.deletingLastPathComponent().lastPathComponent == "StoreRecovery")
        for name in ["default.store", "default.store-wal", "default.store-shm", ".default_SUPPORT"] {
            #expect(!fm.fileExists(atPath: dir.appendingPathComponent(name).path))
            #expect(fm.fileExists(atPath: backup.appendingPathComponent(name).path))
        }

        // A second recovery in the same second gets its own folder.
        try Data("y".utf8).write(to: store)
        let second = try #require(SwiftDataRecovery.moveStoreAside(at: store, now: now))
        #expect(second.lastPathComponent == "1800000000-1")
    }

    @Test func nothingToMoveReturnsNil() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("absent-\(UUID().uuidString).store")
        #expect(SwiftDataRecovery.moveStoreAside(at: url) == nil)
    }
}
#endif

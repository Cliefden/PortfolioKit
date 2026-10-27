#if canImport(SwiftData)
import Foundation
import SwiftData

/// Open a SwiftData container without crash-looping on an incompatible store
/// (failed migration, schema drift). From ThenCam's `ThenCamApp.makeContainer`.
///
/// On failure the store files are **moved aside, never deleted** — they may
/// hold the only copy of data that never synced — into
/// `<store dir>/StoreRecovery/<unix time>/`, and the container is created again
/// on a fresh store. If that also fails it can fall back to an in-memory store
/// so the app stays usable for this launch.
///
/// ```swift
/// let container = try SwiftDataRecovery.makeContainer(
///     for: VaultPhoto.self, Project.self,
///     configurations: ModelConfiguration(cloudKitDatabase: .none)
/// ) { error, backup in
///     AppLog.reportError("swiftdata.recovered", error)
/// }
/// ```
public enum SwiftDataRecovery {
    /// Called once when the store had to be moved aside: the opening error and
    /// the backup directory (if anything was moved).
    public typealias RecoveryHandler = (_ error: Error, _ backup: URL?) -> Void

    public static func makeContainer(
        for types: any PersistentModel.Type...,
        configurations: ModelConfiguration...,
        fallbackToInMemory: Bool = true,
        onRecovery: RecoveryHandler? = nil
    ) throws -> ModelContainer {
        try makeContainer(
            for: Schema(types),
            configurations: configurations,
            fallbackToInMemory: fallbackToInMemory,
            onRecovery: onRecovery
        )
    }

    public static func makeContainer(
        for schema: Schema,
        configurations: [ModelConfiguration],
        fallbackToInMemory: Bool = true,
        onRecovery: RecoveryHandler? = nil
    ) throws -> ModelContainer {
        let configurations = configurations.isEmpty ? [ModelConfiguration()] : configurations
        do {
            return try ModelContainer(for: schema, configurations: configurations)
        } catch {
            var backup: URL?
            for configuration in configurations where !configuration.isStoredInMemoryOnly {
                backup = moveStoreAside(at: configuration.url) ?? backup
            }
            onRecovery?(error, backup)
        }
        do {
            return try ModelContainer(for: schema, configurations: configurations)
        } catch {
            guard fallbackToInMemory else { throw error }
            return try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        }
    }

    /// Move a SQLite store, its `-wal`/`-shm` side files and SwiftData's
    /// external-storage directory (`.<name>_SUPPORT`) into
    /// `StoreRecovery/<timestamp>/` next to it. Returns the backup directory, or
    /// `nil` when none of the files existed.
    @discardableResult
    public static func moveStoreAside(
        at storeURL: URL,
        fileManager: FileManager = .default,
        now: Date = Date()
    ) -> URL? {
        let directory = storeURL.deletingLastPathComponent()
        let base = storeURL.deletingPathExtension().lastPathComponent
        let names = [
            storeURL.lastPathComponent,
            storeURL.lastPathComponent + "-wal",
            storeURL.lastPathComponent + "-shm",
            ".\(base)_SUPPORT",
        ]
        let existing = names.filter { fileManager.fileExists(atPath: directory.appendingPathComponent($0).path) }
        guard !existing.isEmpty else { return nil }

        var backup = directory
            .appendingPathComponent("StoreRecovery", isDirectory: true)
            .appendingPathComponent("\(Int(now.timeIntervalSince1970))", isDirectory: true)
        var suffix = 1
        while fileManager.fileExists(atPath: backup.path) {
            backup = backup.deletingLastPathComponent()
                .appendingPathComponent("\(Int(now.timeIntervalSince1970))-\(suffix)", isDirectory: true)
            suffix += 1
        }
        do {
            try fileManager.createDirectory(at: backup, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        for name in existing {
            try? fileManager.moveItem(
                at: directory.appendingPathComponent(name),
                to: backup.appendingPathComponent(name)
            )
        }
        return backup
    }
}
#endif

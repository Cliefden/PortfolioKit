import Foundation

/// Type-erased `Encodable`, for dynamic payloads such as Supabase/PostgREST
/// partial updates (`[String: AnyEncodable]`) without a struct per call site.
/// From Stokked `Utilities/AnyEncodable.swift` (copied twice there).
///
/// ```swift
/// var updates: [String: AnyEncodable] = [:]
/// updates["name"] = AnyEncodable(list.name)
/// updates["updated_at"] = AnyEncodable(Date())
/// try await client.from("lists").update(updates).eq("id", value: id).execute()
/// ```
public struct AnyEncodable: Encodable {
    private let encodeValue: (Encoder) throws -> Void

    public init<T: Encodable>(_ value: T) {
        encodeValue = { try value.encode(to: $0) }
    }

    public func encode(to encoder: Encoder) throws {
        try encodeValue(encoder)
    }
}

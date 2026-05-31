//
//  PersistentIdentifierEncoding.swift
//  ContactManager
//
//  `PersistentIdentifier` is `Codable` but not directly storable in
//  `@AppStorage` (which only takes a handful of property-list types).
//  These helpers round-trip a PID through a JSON string so a preference
//  can point at a SwiftData model without depending on a mutable display
//  name.
//

import Foundation
import SwiftData

extension PersistentIdentifier {
    /// JSON-encoded string suitable for `@AppStorage`. Returns `nil` only
    /// if encoding unexpectedly fails (shouldn't in practice).
    var storedString: String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Inverse of `storedString`. Returns `nil` for the empty string (the
    /// "no value" sentinel) or any string that isn't a valid encoded PID.
    static func decode(stored string: String) -> PersistentIdentifier? {
        guard !string.isEmpty,
              let data = string.data(using: .utf8),
              let id = try? JSONDecoder().decode(PersistentIdentifier.self, from: data)
        else { return nil }
        return id
    }
}

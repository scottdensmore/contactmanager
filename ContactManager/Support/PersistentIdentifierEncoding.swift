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
    ///
    /// Keys are sorted so the *same* identifier always encodes to the *same*
    /// string. Without this, `PersistentIdentifier`'s Codable output reorders
    /// keys between encodings (even within one process), and any code that
    /// compares two separately-encoded ids by string — Spotlight's
    /// `entities(for:)` lookup, incremental re-index matching — would miss.
    var storedString: String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(self) else { return nil }
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

//
//  DefaultGroupPreference.swift
//  ContactManager
//
//  Resolves the "new contacts join this group" preference (an encoded
//  `PersistentIdentifier` in @AppStorage) against the live groups. Pulled out
//  of the views so the matching — and the stale/renamed/deleted handling — is
//  unit-tested.
//

import Foundation
import SwiftData

enum DefaultGroupPreference {
    /// The group the stored preference points at, or `nil` when it's empty,
    /// undecodable, or its target was deleted.
    ///
    /// Matches on the *canonical encoded id* rather than `PersistentIdentifier`
    /// equality: a value decoded from a string doesn't compare equal to the
    /// live persisted id, so `==` would never match a saved group. Decoding
    /// first also lets an older, non-canonically-encoded stored value still
    /// resolve (decode is key-order independent; re-encoding canonicalizes it).
    static func group(stored: String, in groups: [ContactGroup]) -> ContactGroup? {
        guard let canonical = PersistentIdentifier.decode(stored: stored)?.storedString else {
            return nil
        }
        return groups.first { $0.persistentModelID.storedString == canonical }
    }

    /// The value the preference should hold: the matched group's canonical id,
    /// or `""` when it points at nothing — so a blank, stale, deleted, or
    /// old-format value self-heals to a consistent state.
    static func normalized(stored: String, in groups: [ContactGroup]) -> String {
        group(stored: stored, in: groups)?.persistentModelID.storedString ?? ""
    }
}

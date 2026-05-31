//
//  ContactEntityQuery.swift
//  ContactManager
//
//  Lookup paths for `ContactEntity`: by id (Shortcuts handoff + Spotlight
//  open), by free-text string (Find Contact intent), and "all" (Spotlight
//  re-index and the Shortcuts picker).
//

import AppIntents
import Foundation
import SwiftData

struct ContactEntityQuery: EntityQuery, EnumerableEntityQuery, EntityStringQuery {
    func entities(for identifiers: [ContactEntity.ID]) async throws -> [ContactEntity] {
        guard let container = EntityModelContainer.shared else { return [] }
        let wanted = Set(identifiers)
        return try await Self.snapshot(container: container) { contacts in
            contacts.filter { wanted.contains($0.persistentModelID.storedString ?? "") }
        }
    }

    func entities(matching string: String) async throws -> [ContactEntity] {
        guard let container = EntityModelContainer.shared else { return [] }
        let needle = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }
        return try await Self.snapshot(container: container) { contacts in
            // Reuse the same matcher the contact list uses so Shortcuts and
            // in-app search behave the same.
            ContactQuery.filtered(contacts, matching: needle)
        }
    }

    func suggestedEntities() async throws -> [ContactEntity] {
        try await allEntities()
    }

    func allEntities() async throws -> [ContactEntity] {
        guard let container = EntityModelContainer.shared else { return [] }
        return try await Self.snapshot(container: container) { $0 }
    }

    /// Fetches every contact on a fresh background context, applies the
    /// caller's filter, and maps to entity values. The fetch and the
    /// mapping both happen on the same actor as the context (none here),
    /// so the resulting `[ContactEntity]` is safe to send to App Intents
    /// callers on any actor.
    private static func snapshot(
        container: ModelContainer,
        filter: (_ contacts: [Contact]) -> [Contact]
    ) async throws -> [ContactEntity] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Contact>(
            sortBy: [SortDescriptor(\.lastName), SortDescriptor(\.firstName)]
        )
        let contacts = try context.fetch(descriptor)
        return filter(contacts).map(ContactEntity.init(contact:))
    }
}

//
//  SpotlightIndexer.swift
//  ContactManager
//
//  Pushes contacts into Spotlight's index. The first launch indexes the
//  full set; subsequent calls do the same — the contact corpus stays
//  modest enough that a full reindex on every mutation is cheaper than
//  tracking per-row deltas.
//

import CoreSpotlight
import Foundation

enum SpotlightIndexer {
    /// Identifier scope so we can clear *our* items without touching
    /// anything else Spotlight has indexed for this app.
    static let domainIdentifier = "com.scottdensmore.ContactManager.contacts"

    /// Replaces our entire indexed set with the supplied entities. Errors
    /// are logged but not surfaced — Spotlight indexing failure is a
    /// quality-of-life regression, not a user-visible error worth alerting.
    static func reindex(_ entities: [ContactEntity]) async {
        let index = CSSearchableIndex.default()
        let items = entities.map { entity in
            CSSearchableItem(
                uniqueIdentifier: entity.id,
                domainIdentifier: domainIdentifier,
                attributeSet: entity.attributeSet
            )
        }
        do {
            try await index.deleteSearchableItems(withDomainIdentifiers: [domainIdentifier])
            if !items.isEmpty {
                try await index.indexSearchableItems(items)
            }
        } catch {
            print("Spotlight reindex failed: \(error)")
        }
    }
}

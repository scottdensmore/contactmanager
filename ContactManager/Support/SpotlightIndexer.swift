//
//  SpotlightIndexer.swift
//  ContactManager
//
//  Pushes contacts into Spotlight's index. An actor so back-to-back calls
//  during a burst of mutations serialize cleanly — a delete-then-index
//  pair must not interleave with another pair or Spotlight ends up
//  reflecting an older snapshot (or empty).
//
//  Each call fetches a fresh snapshot via `ContactEntityQuery` instead of
//  trusting a caller-supplied list, because `@Query`'s post-save refresh
//  is asynchronous and can lag a `ContactStore.mutate` notification.
//

import CoreSpotlight
import Foundation

actor SpotlightIndexer {
    static let shared = SpotlightIndexer()

    /// Identifier scope so we can clear *our* items without touching
    /// anything else Spotlight has indexed for this app.
    static let domainIdentifier = "com.scottdensmore.ContactManager.contacts"

    /// Replaces our entire indexed set with a freshly-fetched snapshot.
    /// Used at launch and as a fallback; per-mutation refreshes should go
    /// through `apply(_:)` so they don't rebuild the whole index.
    /// Errors are logged but not surfaced — a Spotlight indexing failure
    /// is a quality-of-life regression, not a user-visible error.
    func reindex() async {
        let entities = await (try? ContactEntityQuery().allEntities()) ?? []
        let index = CSSearchableIndex.default()
        let items = entities.map(Self.makeItem)
        do {
            try await index.deleteSearchableItems(withDomainIdentifiers: [Self.domainIdentifier])
            if !items.isEmpty {
                try await index.indexSearchableItems(items)
            }
        } catch {
            print("Spotlight reindex failed: \(error)")
        }
    }

    /// Applies a single mutation's delta: re-indexes the updated contacts
    /// (fetched fresh by id) and removes the deleted ones. O(changed) instead
    /// of `reindex()`'s O(all contacts), so a one-contact edit no longer
    /// rebuilds the entire index. Like `reindex()`, errors are logged only.
    func apply(_ change: ContactChange) async {
        guard !change.isEmpty else { return }
        let index = CSSearchableIndex.default()
        do {
            if !change.deletedIDs.isEmpty {
                try await index.deleteSearchableItems(withIdentifiers: Array(change.deletedIDs))
            }
            if !change.updatedIDs.isEmpty {
                // Fetch only the touched contacts. An id with no match (created
                // and removed before we got here) simply yields no item.
                let entities = await (try? ContactEntityQuery().entities(for: Array(change.updatedIDs))) ?? []
                let items = entities.map(Self.makeItem)
                if !items.isEmpty {
                    try await index.indexSearchableItems(items)
                }
            }
        } catch {
            print("Spotlight incremental update failed: \(error)")
        }
    }

    private static func makeItem(for entity: ContactEntity) -> CSSearchableItem {
        CSSearchableItem(
            uniqueIdentifier: entity.id,
            domainIdentifier: domainIdentifier,
            attributeSet: entity.attributeSet
        )
    }
}

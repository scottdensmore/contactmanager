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
    /// Errors are logged but not surfaced — a Spotlight indexing failure
    /// is a quality-of-life regression, not a user-visible error.
    func reindex() async {
        let entities = await (try? ContactEntityQuery().allEntities()) ?? []
        let index = CSSearchableIndex.default()
        let items = entities.map { entity in
            CSSearchableItem(
                uniqueIdentifier: entity.id,
                domainIdentifier: Self.domainIdentifier,
                attributeSet: entity.attributeSet
            )
        }
        do {
            try await index.deleteSearchableItems(withDomainIdentifiers: [Self.domainIdentifier])
            if !items.isEmpty {
                try await index.indexSearchableItems(items)
            }
        } catch {
            print("Spotlight reindex failed: \(error)")
        }
    }
}

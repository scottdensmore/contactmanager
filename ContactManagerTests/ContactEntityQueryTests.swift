//
//  ContactEntityQueryTests.swift
//  ContactManagerTests
//
//  Integration coverage for the App Intents entity query — the lookup paths
//  (by free-text, by id, and "all") that live behind the process-wide model
//  container — plus the Find Contact intent that drives the free-text path.
//  ContactEntityTests covers the pure Contact → ContactEntity mapping and
//  explicitly left these container-backed paths "for a future pass"; this is it.
//

@testable import ContactManager
import Foundation
import SwiftData
import Testing

@MainActor
@Suite(.serialized)
final class ContactEntityQueryTests {
    let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: Contact.self, ContactField.self, ContactGroup.self, ContactInteraction.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        // The query reads contacts from this process-wide handle.
        EntityModelContainer.shared = container
    }

    /// Swift Testing builds a fresh instance per test; clear the global handle
    /// afterward so no other suite/test ever sees a freed container. Setting the
    /// lock-guarded static is safe from deinit's nonisolated context.
    deinit { EntityModelContainer.shared = nil }

    @discardableResult
    private func seed(_ contacts: Contact...) throws -> [Contact] {
        for contact in contacts {
            container.mainContext.insert(contact)
        }
        try container.mainContext.save()
        return contacts
    }

    private func contact(_ first: String, _ last: String, company: String = "") -> Contact {
        Contact(firstName: first, lastName: last, company: company)
    }

    // MARK: - entities(matching:)

    @Test func matchingFiltersByName() async throws {
        try seed(
            contact("Ada", "Lovelace", company: "Analytical Engine"),
            contact("Grace", "Hopper", company: "US Navy")
        )
        let results = try await ContactEntityQuery().entities(matching: "lovelace")
        #expect(results.map(\.displayName) == ["Ada Lovelace"])
    }

    @Test func matchingFiltersByCompany() async throws {
        try seed(
            contact("Ada", "Lovelace", company: "Analytical Engine"),
            contact("Grace", "Hopper", company: "US Navy")
        )
        let results = try await ContactEntityQuery().entities(matching: "navy")
        #expect(results.map(\.displayName) == ["Grace Hopper"])
    }

    @Test func emptyQueryReturnsNothing() async throws {
        try seed(contact("Ada", "Lovelace"))
        let empty = try await ContactEntityQuery().entities(matching: "")
        let blank = try await ContactEntityQuery().entities(matching: "   \n ")
        #expect(empty.isEmpty)
        #expect(blank.isEmpty)
    }

    @Test func matchingReturnsEmptyWhenNoContainer() async throws {
        EntityModelContainer.shared = nil
        let results = try await ContactEntityQuery().entities(matching: "anything")
        #expect(results.isEmpty)
    }

    // MARK: - entities(for:)

    @Test func entitiesForIdLooksUpByEncodedIdentifier() async throws {
        let seeded = try seed(contact("Ada", "Lovelace"), contact("Grace", "Hopper"))
        let id = try #require(seeded[0].persistentModelID.storedString)
        let results = try await ContactEntityQuery().entities(for: [id])
        #expect(results.map(\.displayName) == ["Ada Lovelace"])
    }

    @Test func entitiesForUnknownIdReturnsNothing() async throws {
        try seed(contact("Ada", "Lovelace"))
        let results = try await ContactEntityQuery().entities(for: ["not-a-real-id"])
        #expect(results.isEmpty)
    }

    // MARK: - allEntities / suggestedEntities

    @Test func allEntitiesReturnsEverythingSortedByName() async throws {
        try seed(contact("Ada", "Lovelace"), contact("Grace", "Hopper"))
        // snapshot() sorts by lastName then firstName: Hopper < Lovelace.
        let all = try await ContactEntityQuery().allEntities()
        #expect(all.map(\.displayName) == ["Grace Hopper", "Ada Lovelace"])
    }

    @Test func suggestedEntitiesMatchesAll() async throws {
        try seed(contact("Ada", "Lovelace"), contact("Grace", "Hopper"))
        let suggested = try await ContactEntityQuery().suggestedEntities()
        #expect(suggested.count == 2)
    }

    // MARK: - FindContactIntent

    @Test func findContactIntentReturnsMatches() async throws {
        try seed(contact("Ada", "Lovelace"), contact("Grace", "Hopper"))
        let intent = FindContactIntent()
        intent.query = "hopper"
        let result = try await intent.perform()
        #expect(result.value?.map(\.displayName) == ["Grace Hopper"])
    }
}

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
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: Contact.self, ContactField.self, ContactGroup.self, ContactInteraction.self,
            ContactSavedSmartList.self,
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

    @Test func quickCaptureContactIntentCreatesParsedContact() async throws {
        let intent = QuickCaptureContactIntent()
        intent.text = "Ada Lovelace, ada@example.com, mobile 555-0100, notes Met at WWDC"

        let result = try await intent.perform()

        let contacts = try context.fetch(FetchDescriptor<Contact>())
        let contact = try #require(contacts.first)
        #expect(result.value?.displayName == "Ada Lovelace")
        #expect(contact.fullName == "Ada Lovelace")
        #expect(contact.primaryEmail == "ada@example.com")
        #expect(contact.primaryPhone == "555-0100")
        #expect(contact.notes == "Met at WWDC")
    }

    @Test func createContactIntentCreatesStructuredContact() async throws {
        let intent = CreateContactIntent()
        intent.firstName = "  Grace  "
        intent.lastName = "  Hopper  "
        intent.company = "  US Navy  "
        intent.jobTitle = "  Rear Admiral  "
        intent.email = " grace@example.com "
        intent.phone = " 555-0101 "
        intent.notes = "  COBOL pioneer.  "

        let result = try await intent.perform()

        let contacts = try context.fetch(FetchDescriptor<Contact>())
        let contact = try #require(contacts.first)
        #expect(result.value?.displayName == "Grace Hopper")
        #expect(contact.fullName == "Grace Hopper")
        #expect(contact.company == "US Navy")
        #expect(contact.jobTitle == "Rear Admiral")
        #expect(contact.primaryEmail == "grace@example.com")
        #expect(contact.primaryPhone == "555-0101")
        #expect(contact.notes == "COBOL pioneer.")
    }

    @Test func addContactHistoryNoteIntentPersistsInteraction() async throws {
        let contactedAt = try #require(Birthday.calendar.date(from: DateComponents(
            year: 2026, month: 6, day: 7, hour: 12
        )))
        let contact = try #require(try seed(contact("Ada", "Lovelace")).first)
        let intent = AddContactHistoryNoteIntent()
        intent.contact = ContactEntity(contact: contact)
        intent.kind = .call
        intent.summary = "  Called about conference follow-up.  "
        intent.date = contactedAt

        let result = try await intent.perform()

        #expect(result.value?.displayName == "Ada Lovelace")
        #expect(contact.sortedInteractions.map(\.kind) == [.call])
        #expect(contact.sortedInteractions.map(\.summary) == ["Called about conference follow-up."])
        #expect(contact.lastContactedAt == contactedAt)
    }
}

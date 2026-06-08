//
//  ContactHistoryTests.swift
//  ContactManagerTests
//
//  Relationship-history ContactStore behavior.
//

@testable import ContactManager
import Foundation
import SwiftData
import Testing

@MainActor
@Suite(.serialized)
struct ContactHistoryTests {
    let container: ModelContainer
    let store: ContactStore
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: Contact.self, ContactField.self, ContactGroup.self, ContactInteraction.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = ContactStore(container.mainContext)
    }

    private func count<T: PersistentModel>(_: T.Type) throws -> Int {
        try context.fetchCount(FetchDescriptor<T>())
    }

    @Test func addInteractionPersistsHistoryAndMarksContacted() throws {
        let contactedAt = try #require(Birthday.calendar.date(from: DateComponents(
            year: 2026, month: 6, day: 7, hour: 12
        )))
        let contact = try store.createContact()

        let interaction = try store.addInteraction(
            to: contact,
            kind: .call,
            summary: "Called about conference follow-up.",
            at: contactedAt
        )

        #expect(interaction.contact?.persistentModelID == contact.persistentModelID)
        #expect(interaction.kind == .call)
        #expect(interaction.summary == "Called about conference follow-up.")
        #expect(contact.lastContactedAt == contactedAt)
        #expect(contact.interactions.map(\.summary) == ["Called about conference follow-up."])
        #expect(try count(ContactInteraction.self) == 1)
    }

    @Test func interactionsAreSortedNewestFirst() throws {
        let olderDate = try #require(Birthday.calendar.date(from: DateComponents(
            year: 2026, month: 6, day: 1, hour: 12
        )))
        let newerDate = try #require(Birthday.calendar.date(from: DateComponents(
            year: 2026, month: 6, day: 7, hour: 12
        )))
        let contact = try store.createContact()
        _ = try store.addInteraction(to: contact, kind: .meeting, summary: "Planning meeting.", at: olderDate)
        _ = try store.addInteraction(to: contact, kind: .email, summary: "Sent recap.", at: newerDate)

        #expect(contact.sortedInteractions.map(\.summary) == ["Sent recap.", "Planning meeting."])
    }

    @Test func backfilledInteractionDoesNotRegressLastContactedDate() throws {
        let olderDate = try #require(Birthday.calendar.date(from: DateComponents(
            year: 2026, month: 6, day: 1, hour: 12
        )))
        let newerDate = try #require(Birthday.calendar.date(from: DateComponents(
            year: 2026, month: 6, day: 7, hour: 12
        )))
        let contact = try store.createContact()
        try store.markContacted(contact, at: newerDate)

        _ = try store.addInteraction(to: contact, kind: .note, summary: "Backfilled note.", at: olderDate)

        #expect(contact.lastContactedAt == newerDate)
    }

    @Test func deletingContactCascadesToInteractions() throws {
        let contact = try store.createContact()
        _ = try store.addInteraction(to: contact, kind: .note, summary: "Initial note.")
        #expect(try count(ContactInteraction.self) == 1)

        try store.delete(contact)

        #expect(try count(Contact.self) == 0)
        #expect(try count(ContactInteraction.self) == 0)
    }

    @Test func mergePreservesHistoryFromMergedContacts() throws {
        let primary = try store.createContact()
        primary.firstName = "Ada"
        let duplicate = try store.createContact()
        duplicate.firstName = "Ada"
        _ = try store.addInteraction(to: duplicate, kind: .meeting, summary: "Met at WWDC.")

        let merged = try store.merge([primary, duplicate])

        #expect(try count(Contact.self) == 1)
        #expect(try count(ContactInteraction.self) == 1)
        #expect(merged.sortedInteractions.map(\.summary) == ["Met at WWDC."])
        #expect(merged.sortedInteractions.first?.contact?.persistentModelID == primary.persistentModelID)
    }
}

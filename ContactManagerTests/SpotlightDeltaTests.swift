//
//  SpotlightDeltaTests.swift
//  ContactManagerTests
//
//  Verifies the `ContactChange` delta that `ContactStore` broadcasts in the
//  `.contactsDidChange` notification. `SpotlightIndexer` consumes this delta
//  to update the index incrementally, so getting the affected-contact set
//  right is what keeps a single edit from rebuilding the entire index.
//

@testable import ContactManager
import Foundation
import SwiftData
import Testing

@MainActor
@Suite(.serialized)
struct SpotlightDeltaTests {
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

    /// Captures the `ContactChange` posted by the mutation `body` runs.
    /// `.contactsDidChange` is posted synchronously on the main actor, so the
    /// observer fires before `body` returns.
    private func change(during body: () throws -> Void) rethrows -> ContactChange? {
        var captured: ContactChange?
        let token = NotificationCenter.default.addObserver(
            forName: .contactsDidChange, object: nil, queue: nil
        ) { note in
            captured = note.userInfo?[ContactChange.userInfoKey] as? ContactChange
        }
        defer { NotificationCenter.default.removeObserver(token) }
        try body()
        return captured
    }

    @Test func createEmitsUpdateForTheNewContact() throws {
        var contact: Contact?
        let change = try #require(try change { contact = try store.createContact() })
        let id = try #require(contact?.persistentModelID.storedString)
        #expect(change.updatedIDs == [id])
        #expect(change.deletedIDs.isEmpty)
    }

    @Test func deleteEmitsRemovalAndNoUpdate() throws {
        let contact = try store.createContact()
        let id = try #require(contact.persistentModelID.storedString)

        let change = try #require(try change { try store.delete(contact) })
        #expect(change.deletedIDs == [id])
        #expect(change.updatedIDs.isEmpty)
    }

    @Test func addFieldEmitsUpdateForOwningContact() throws {
        let contact = try store.createContact()
        let id = try #require(contact.persistentModelID.storedString)

        let change = try #require(try change { try store.addField(.email, to: contact) })
        #expect(change.updatedIDs.contains(id))
        #expect(change.deletedIDs.isEmpty)
    }

    @Test func deleteFieldEmitsUpdateForSurvivingOwner() throws {
        let contact = try store.createContact()
        let field = try store.addField(.phone, value: "555", to: contact)
        let id = try #require(contact.persistentModelID.storedString)

        let change = try #require(try change { try store.delete([field]) })
        #expect(change.updatedIDs == [id]) // owner refreshed, not deleted
        #expect(change.deletedIDs.isEmpty)
    }

    @Test func renamingGroupTouchesNoContact() throws {
        let group = try store.createGroup(named: "Work")

        let change = try #require(try change { try store.rename(group, to: "Clients") })
        #expect(change.isEmpty)
    }

    @Test func mergeUpdatesPrimaryAndDeletesTheRest() throws {
        let primary = try store.createContact()
        primary.firstName = "Ada"
        let duplicate = try store.createContact()
        duplicate.firstName = "Ada"
        // Give the duplicate an email so the merge reassigns it to the primary
        // — that reassignment is what marks the primary as touched.
        try store.addField(.email, value: "ada@home.test", to: duplicate)
        try context.save()

        let primaryID = try #require(primary.persistentModelID.storedString)
        let duplicateID = try #require(duplicate.persistentModelID.storedString)

        let change = try #require(try change { _ = try store.merge([primary, duplicate]) })
        #expect(change.updatedIDs == [primaryID]) // surviving contact re-indexed
        #expect(change.deletedIDs == [duplicateID]) // duplicate removed
    }
}

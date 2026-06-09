//
//  ContactStorePendingEditTests.swift
//  ContactManagerTests
//
//  Covers direct SwiftData form edits saved through ContactStore.
//

@testable import ContactManager
import SwiftData
import Testing

@MainActor
@Suite(.serialized)
struct ContactStorePendingEditTests {
    let container: ModelContainer
    let store: ContactStore
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: Contact.self, ContactField.self, ContactGroup.self, ContactInteraction.self,
            ContactTag.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = ContactStore(container.mainContext)
    }

    private func allContacts() throws -> [Contact] {
        try context.fetch(FetchDescriptor<Contact>())
    }

    @Test func scalarEditsPersistAndEmitTheContact() throws {
        let contact = try store.createContact()
        contact.firstName = "Ada"
        contact.lastName = "Lovelace"

        let change = try store.savePendingEdits(actionName: "Edit Contact")

        let restored = try #require(try allContacts().first)
        let id = try #require(restored.persistentModelID.storedString)
        #expect(restored.fullName == "Ada Lovelace")
        #expect(restored.initials == "AL")
        #expect(change.updatedIDs == [id])
        #expect(change.deletedIDs.isEmpty)
    }

    @Test func fieldEditsPersistAndEmitTheOwner() throws {
        let contact = try store.createContact()
        let email = try store.addField(.email, to: contact)
        email.label = .work
        email.value = "ada@analytical.engine"

        let change = try store.savePendingEdits(actionName: "Edit Contact")

        let id = try #require(contact.persistentModelID.storedString)
        #expect(change.updatedIDs == [id])
        #expect(contact.emails.first?.label == .work)
        #expect(contact.primaryEmail == "ada@analytical.engine")
    }

    @Test func savePendingEditsIsANoOpWithoutChanges() throws {
        _ = try store.createContact()
        let change = try store.savePendingEdits(actionName: "Edit Contact")

        #expect(change.isEmpty)
    }
}

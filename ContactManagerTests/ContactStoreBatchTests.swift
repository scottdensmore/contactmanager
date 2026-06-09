//
//  ContactStoreBatchTests.swift
//  ContactManagerTests
//
//  Covers multi-contact operations behind the batch action UI.
//

@testable import ContactManager
import SwiftData
import Testing

@MainActor
@Suite(.serialized)
struct ContactStoreBatchTests {
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

    @Test func batchDeleteRemovesAllSelectedContacts() throws {
        let ada = try store.createContact()
        let alan = try store.createContact()
        _ = try store.createContact()

        let deleted = try store.delete([ada, alan])

        let contacts = try context.fetch(FetchDescriptor<Contact>())
        #expect(deleted == 2)
        #expect(contacts.count == 1)
        #expect(!contacts.contains { $0.persistentModelID == ada.persistentModelID })
        #expect(!contacts.contains { $0.persistentModelID == alan.persistentModelID })
    }

    @Test func batchDeleteIsANoOpForEmptySelection() throws {
        _ = try store.createContact()

        let deleted = try store.delete([Contact]())

        #expect(deleted == 0)
        #expect(try context.fetch(FetchDescriptor<Contact>()).count == 1)
    }

    @Test func batchAssignAddsSelectedContactsToGroup() throws {
        let group = try store.createGroup(named: "Work")
        let ada = try store.createContact()
        let alan = try store.createContact(in: group)
        let grace = try store.createContact()

        let added = try store.addContacts([ada, alan, grace], to: group)

        #expect(added == 2)
        #expect(Set(group.contacts.map(\.persistentModelID)) == [
            ada.persistentModelID,
            alan.persistentModelID,
            grace.persistentModelID,
        ])
    }

    @Test func batchAssignAddsSelectedContactsToTag() throws {
        let tag = try store.createTag(named: "VIP")
        let ada = try store.createContact()
        let alan = try store.createContact()
        let grace = try store.createContact()
        try store.setMembership(of: alan, in: tag, isMember: true)

        let added = try store.addContacts([ada, alan, grace], to: tag)

        #expect(added == 2)
        #expect(Set(tag.contacts.map(\.persistentModelID)) == [
            ada.persistentModelID,
            alan.persistentModelID,
            grace.persistentModelID,
        ])
    }
}

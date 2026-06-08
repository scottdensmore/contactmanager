//
//  GroupDropTests.swift
//  ContactManagerTests
//
//  Covers `ContactStore.addContacts(withEncodedIDs:to:)` — the data path
//  behind dragging contacts from the list onto a sidebar group.
//

@testable import ContactManager
import Foundation
import SwiftData
import Testing

@MainActor
@Suite(.serialized)
struct GroupDropTests {
    let container: ModelContainer
    let store: ContactStore

    init() throws {
        container = try ModelContainer(
            for: Contact.self, ContactField.self, ContactGroup.self, ContactInteraction.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = ContactStore(container.mainContext)
    }

    @Test func addsDroppedContactsToTheGroup() throws {
        let group = try store.createGroup(named: "Work")
        let ada = try store.createContact()
        let alan = try store.createContact()
        let ids = try [ada, alan].map { try #require($0.persistentModelID.storedString) }

        let added = try store.addContacts(withEncodedIDs: ids, to: group)
        #expect(added == 2)
        #expect(Set(group.contacts.map(\.persistentModelID)) == [ada.persistentModelID, alan.persistentModelID])
    }

    @Test func skipsExistingMembersAndUnknownIDs() throws {
        let group = try store.createGroup(named: "Work")
        let ada = try store.createContact(in: group) // already a member
        let alan = try store.createContact()
        let adaID = try #require(ada.persistentModelID.storedString)
        let alanID = try #require(alan.persistentModelID.storedString)

        // Ada is already in the group; "garbage" resolves to no contact.
        let added = try store.addContacts(withEncodedIDs: [adaID, alanID, "garbage"], to: group)
        #expect(added == 1)
        #expect(group.contacts.count == 2)
    }

    @Test func isANoOpForEmptyInput() throws {
        let group = try store.createGroup(named: "Work")
        #expect(try store.addContacts(withEncodedIDs: [], to: group) == 0)
    }
}

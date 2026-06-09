//
//  ContactTagTests.swift
//  ContactManagerTests
//
//  Covers tag lifecycle mutations.
//

@testable import ContactManager
import SwiftData
import Testing

@MainActor
@Suite(.serialized)
struct ContactTagTests {
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

    private func count<T: PersistentModel>(_: T.Type) throws -> Int {
        try context.fetchCount(FetchDescriptor<T>())
    }

    @Test func tagMembershipScopesContactsAndDeleteClearsIt() throws {
        let tag = try store.createTag(named: "  VIP  ")
        let ada = try store.createContact()
        let alan = try store.createContact()

        #expect(tag.displayName == "VIP")
        try store.setMembership(of: ada, in: tag, isMember: true)
        #expect(tag.contacts.map(\.persistentModelID) == [ada.persistentModelID])

        // Toggling membership on again is a no-op (no duplicates).
        try store.setMembership(of: ada, in: tag, isMember: true)
        #expect(tag.contacts.count == 1)

        try store.rename(tag, to: "  Priority  ")
        #expect(tag.displayName == "Priority")

        try store.delete(tag)
        #expect(try count(ContactTag.self) == 0)
        #expect(try count(Contact.self) == 2)
        #expect(ada.tags.isEmpty)
        #expect(alan.tags.isEmpty)
    }

    @Test func blankTagRenameIsIgnored() throws {
        let tag = try store.createTag(named: "VIP")
        try store.rename(tag, to: "   ")
        #expect(tag.name == "VIP")
    }
}

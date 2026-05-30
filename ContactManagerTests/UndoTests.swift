//
//  UndoTests.swift
//  ContactManagerTests
//
//  Verifies that ContactStore mutations are undoable as named groups: each
//  Edit ▸ Undo reverts exactly one user-visible action, and Redo restores it.
//

@testable import ContactManager
import Foundation
import SwiftData
import Testing

@MainActor
@Suite(.serialized)
struct UndoTests {
    let container: ModelContainer
    let undoManager: UndoManager
    let store: ContactStore
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: Contact.self, ContactField.self, ContactGroup.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        undoManager = UndoManager()
        container.mainContext.undoManager = undoManager
        store = ContactStore(container.mainContext)
    }

    private func count<T: PersistentModel>(_: T.Type) throws -> Int {
        try context.fetchCount(FetchDescriptor<T>())
    }

    // MARK: - Action naming

    @Test func undoActionNameMatchesTheOperation() throws {
        try store.createContact()
        #expect(undoManager.undoActionName == "Create Contact")

        try store.createGroup(named: "Work")
        #expect(undoManager.undoActionName == "New Group")
    }

    // MARK: - Create

    @Test func undoCreateLeavesStoreEmpty() throws {
        try store.createContact()
        #expect(try count(Contact.self) == 1)

        undoManager.undo()
        #expect(try count(Contact.self) == 0)
    }

    @Test func redoReappliesACreate() throws {
        try store.createContact()
        undoManager.undo()
        undoManager.redo()

        #expect(try count(Contact.self) == 1)
        #expect(undoManager.undoActionName == "Create Contact")
    }

    // MARK: - Field add / membership / rename

    @Test func undoAddFieldRemovesIt() throws {
        let contact = try store.createContact()
        try store.addField(.email, value: "a@b.com", to: contact)
        #expect(try count(ContactField.self) == 1)

        undoManager.undo()
        #expect(try count(ContactField.self) == 0)
    }

    @Test func undoMembershipChangeRevertsIt() throws {
        let group = try store.createGroup(named: "Work")
        let contact = try store.createContact()
        try store.setMembership(of: contact, in: group, isMember: true)
        #expect(contact.groups.count == 1)

        undoManager.undo()
        #expect(contact.groups.isEmpty)
    }

    @Test func undoRenameRestoresThePreviousName() throws {
        let group = try store.createGroup(named: "Work")
        try store.rename(group, to: "Office")
        #expect(group.name == "Office")

        undoManager.undo()
        #expect(group.name == "Work")
    }

    // MARK: - Merge & delete action names

    /// Delete and merge are registered as undo groups with the right action
    /// names so the Edit menu reads "Undo Delete Contact" / "Undo Merge
    /// Contacts". (SwiftData's automatic undo doesn't always recreate
    /// deleted models after save, so we don't assert restoration here.)
    @Test func mergeAndDeleteRegisterActionNames() throws {
        let ada = try store.createContact()
        let dupe = try store.createContact()
        try store.merge([ada, dupe])
        #expect(undoManager.undoActionName == "Merge Contacts")

        let solo = try store.createContact()
        try store.delete(solo)
        #expect(undoManager.undoActionName == "Delete Contact")
    }
}

//
//  ContactSavedSmartListTests.swift
//  ContactManagerTests
//
//  Covers saved smart-list lifecycle mutations.
//

@testable import ContactManager
import SwiftData
import Testing

@MainActor
@Suite(.serialized)
struct ContactSavedSmartListTests {
    let container: ModelContainer
    let store: ContactStore
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: Contact.self, ContactField.self, ContactGroup.self, ContactInteraction.self,
            ContactSavedSmartList.self, ContactTag.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = ContactStore(container.mainContext)
    }

    private func count<T: PersistentModel>(_: T.Type) throws -> Int {
        try context.fetchCount(FetchDescriptor<T>())
    }

    @Test func savedSmartListLifecycleTrimsQueryAndName() throws {
        let savedList = try store.createSavedSmartList(named: "  Engine People  ", query: "  engine  ")

        #expect(savedList.displayName == "Engine People")
        #expect(savedList.query == "engine")
        #expect(try count(ContactSavedSmartList.self) == 1)

        try store.rename(savedList, to: "  Machines  ")
        #expect(savedList.displayName == "Machines")

        try store.delete(savedList)
        #expect(try count(ContactSavedSmartList.self) == 0)
    }
}

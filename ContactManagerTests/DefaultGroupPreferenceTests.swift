//
//  DefaultGroupPreferenceTests.swift
//  ContactManagerTests
//
//  Covers resolving the "new contacts join this group" preference against the
//  live groups — including the stale/deleted/blank cases SettingsView prunes.
//

@testable import ContactManager
import Foundation
import SwiftData
import Testing

@MainActor
@Suite(.serialized)
struct DefaultGroupPreferenceTests {
    let container: ModelContainer
    let store: ContactStore
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: Contact.self, ContactField.self, ContactGroup.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = ContactStore(container.mainContext)
    }

    private func groups() throws -> [ContactGroup] {
        try context.fetch(FetchDescriptor<ContactGroup>())
    }

    @Test func resolvesAStoredGroupToTheLiveModel() throws {
        let group = try store.createGroup(named: "Work")
        let stored = try #require(group.persistentModelID.storedString)

        // Matching a persisted id must work — `PersistentIdentifier ==` on a
        // decoded id wouldn't, which is the whole point of the helper.
        let resolved = try #require(DefaultGroupPreference.group(stored: stored, in: groups()))
        #expect(resolved.persistentModelID == group.persistentModelID)
        #expect(try DefaultGroupPreference.normalized(stored: stored, in: groups()) == stored)
    }

    @Test func emptyStoredValueResolvesToNothing() throws {
        #expect(try DefaultGroupPreference.group(stored: "", in: groups()) == nil)
        #expect(try DefaultGroupPreference.normalized(stored: "", in: groups()).isEmpty)
    }

    @Test func undecodableStoredValueResolvesToNothing() throws {
        _ = try store.createGroup(named: "Work")
        #expect(try DefaultGroupPreference.group(stored: "garbage", in: groups()) == nil)
        #expect(try DefaultGroupPreference.normalized(stored: "garbage", in: groups()).isEmpty)
    }

    @Test func deletedGroupNormalizesToEmpty() throws {
        let group = try store.createGroup(named: "Temp")
        let stored = try #require(group.persistentModelID.storedString)
        try store.delete(group)

        #expect(try DefaultGroupPreference.group(stored: stored, in: groups()) == nil)
        #expect(try DefaultGroupPreference.normalized(stored: stored, in: groups()).isEmpty)
    }
}

//
//  ContactModelTests.swift
//  ContactManagerTests
//
//  Swift Testing suite backed by an in-memory SwiftData store, mirroring the
//  original in-memory Core Data integration tests.
//

import Testing
import SwiftData
@testable import ContactManager

@MainActor
@Suite(.serialized)
struct ContactModelTests {

    // A fresh in-memory container per test instance. Holding it as a stored
    // property keeps it alive for the lifetime of the test.
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: Contact.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    // MARK: - Persistence

    @Test func insertingContactPersistsIt() throws {
        context.insert(Contact(firstName: "Ada", lastName: "Lovelace"))
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Contact>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.firstName == "Ada")
    }

    @Test func deletingContactRemovesIt() throws {
        let contact = Contact(firstName: "Grace", lastName: "Hopper")
        context.insert(contact)
        try context.save()

        context.delete(contact)
        try context.save()

        let count = try context.fetchCount(FetchDescriptor<Contact>())
        #expect(count == 0)
    }

    @Test func seedingPopulatesAnEmptyStoreOnce() throws {
        SampleData.seedIfNeeded(context)
        #expect(try context.fetchCount(FetchDescriptor<Contact>()) == SampleData.count)

        // Seeding again should be a no-op on a non-empty store.
        SampleData.seedIfNeeded(context)
        #expect(try context.fetchCount(FetchDescriptor<Contact>()) == SampleData.count)
    }

    // MARK: - Derived values

    @Test func fullNameJoinsAvailableParts() {
        #expect(Contact(firstName: "Ada", lastName: "Lovelace").fullName == "Ada Lovelace")
        #expect(Contact(firstName: "Ada").fullName == "Ada")
        #expect(Contact().fullName == "New Contact")
    }

    @Test func initialsUseFirstAndLastInitial() {
        #expect(Contact(firstName: "Ada", lastName: "Lovelace").initials == "AL")
        #expect(Contact(firstName: "grace").initials == "G")
        #expect(Contact().initials == "#")
    }

    // MARK: - Query helpers

    @Test func sortingOrdersByLastNameThenFirstName() {
        let contacts = [
            Contact(firstName: "Grace", lastName: "Hopper"),
            Contact(firstName: "Ada", lastName: "Lovelace"),
            Contact(firstName: "Alan", lastName: "Turing"),
        ]
        let sorted = ContactQuery.sorted(contacts)
        #expect(sorted.map(\.lastName) == ["Hopper", "Lovelace", "Turing"])
    }

    @Test func filteringMatchesNameEmailAndPhone() {
        let contacts = [
            Contact(firstName: "Ada", lastName: "Lovelace", emailAddress: "ada@analytical.engine"),
            Contact(firstName: "Alan", lastName: "Turing", phoneNumber: "+44 20 7555 0142"),
        ]
        #expect(ContactQuery.filtered(contacts, matching: "love").count == 1)
        #expect(ContactQuery.filtered(contacts, matching: "analytical").first?.firstName == "Ada")
        #expect(ContactQuery.filtered(contacts, matching: "7555").first?.firstName == "Alan")
        #expect(ContactQuery.filtered(contacts, matching: "").count == 2)
        #expect(ContactQuery.filtered(contacts, matching: "nobody").isEmpty)
    }
}

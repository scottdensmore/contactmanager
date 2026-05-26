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
            for: Contact.self, ContactField.self,
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

        #expect(try context.fetchCount(FetchDescriptor<Contact>()) == 0)
    }

    @Test func deletingContactCascadesToItsFields() throws {
        let contact = Contact(firstName: "Ada", lastName: "Lovelace")
        contact.fields = [
            ContactField(kind: .email, value: "ada@analytical.engine"),
            ContactField(kind: .phone, value: "+1 (555) 0100"),
        ]
        context.insert(contact)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<ContactField>()) == 2)

        context.delete(contact)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<ContactField>()) == 0)
    }

    @Test func seedingPopulatesAnEmptyStoreOnce() throws {
        SampleData.seedIfNeeded(context)
        #expect(try context.fetchCount(FetchDescriptor<Contact>()) == SampleData.count)
        #expect(try context.fetchCount(FetchDescriptor<ContactField>()) > 0)

        // Seeding again should be a no-op on a non-empty store.
        SampleData.seedIfNeeded(context)
        #expect(try context.fetchCount(FetchDescriptor<Contact>()) == SampleData.count)
    }

    // MARK: - Derived values

    @Test func fullNameJoinsAvailablePartsThenFallsBackToCompany() {
        #expect(Contact(firstName: "Ada", lastName: "Lovelace").fullName == "Ada Lovelace")
        #expect(Contact(firstName: "Ada").fullName == "Ada")
        #expect(Contact(company: "Acme").fullName == "Acme")
        #expect(Contact().fullName == "New Contact")
    }

    @Test func initialsUseFirstAndLastInitial() {
        #expect(Contact(firstName: "Ada", lastName: "Lovelace").initials == "AL")
        #expect(Contact(firstName: "grace").initials == "G")
        #expect(Contact(company: "acme").initials == "A")
        #expect(Contact().initials == "#")
    }

    @Test func primaryValuesAndSubtitlePreferEmail() {
        let contact = Contact(firstName: "Ada", company: "Analytical")
        contact.fields = [
            ContactField(kind: .phone, value: "+1 (555) 0100", sortIndex: 0),
            ContactField(kind: .email, value: "ada@analytical.engine", sortIndex: 0),
        ]
        #expect(contact.primaryEmail == "ada@analytical.engine")
        #expect(contact.primaryPhone == "+1 (555) 0100")
        #expect(contact.subtitle == "ada@analytical.engine")

        let companyOnly = Contact(firstName: "Bob", company: "Globex")
        #expect(companyOnly.subtitle == "Globex")
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

    @Test func filteringMatchesName_Company_Notes_AndFieldValues() throws {
        let ada = Contact(firstName: "Ada", lastName: "Lovelace", company: "Analytical Engine")
        ada.fields = [ContactField(kind: .email, value: "ada@analytical.engine")]
        let alan = Contact(firstName: "Alan", lastName: "Turing", notes: "Enigma")
        alan.fields = [ContactField(kind: .phone, value: "+44 20 7555 0142")]
        context.insert(ada)
        context.insert(alan)
        try context.save()

        let all = try context.fetch(FetchDescriptor<Contact>())
        #expect(ContactQuery.filtered(all, matching: "love").count == 1)        // name
        #expect(ContactQuery.filtered(all, matching: "analytical").count == 1)  // company + email
        #expect(ContactQuery.filtered(all, matching: "enigma").first?.firstName == "Alan") // notes
        #expect(ContactQuery.filtered(all, matching: "7555").first?.firstName == "Alan")   // phone field
        #expect(ContactQuery.filtered(all, matching: "").count == 2)
        #expect(ContactQuery.filtered(all, matching: "nobody").isEmpty)
    }
}

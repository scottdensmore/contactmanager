//
//  ContactModelTests.swift
//  ContactManagerTests
//
//  Swift Testing suite backed by an in-memory SwiftData store, mirroring the
//  original in-memory Core Data integration tests.
//

@testable import ContactManager
import Foundation
import SwiftData
import Testing

@MainActor
@Suite(.serialized)
struct ContactModelTests {
    // A fresh in-memory container per test instance. Holding it as a stored
    // property keeps it alive for the lifetime of the test.
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: Contact.self, ContactField.self, ContactGroup.self, ContactInteraction.self,
            ContactSavedSmartList.self, ContactTag.self,
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

    @Test func contactGroupMembershipIsTracked() throws {
        let group = ContactGroup(name: "Work")
        let contact = Contact(firstName: "Ada", lastName: "Lovelace")
        contact.groups = [group]
        context.insert(group)
        context.insert(contact)
        try context.save()

        #expect(group.contacts.count == 1)
        #expect(contact.groups.first?.name == "Work")
    }

    @Test func deletingGroupKeepsContactsButClearsMembership() throws {
        let group = ContactGroup(name: "Work")
        let contact = Contact(firstName: "Ada", lastName: "Lovelace")
        contact.groups = [group]
        context.insert(group)
        context.insert(contact)
        try context.save()

        context.delete(group)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Contact>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<ContactGroup>()) == 0)
        #expect(contact.groups.isEmpty)
    }

    @Test func contactTagMembershipIsTracked() throws {
        let tag = ContactTag(name: "VIP")
        let contact = Contact(firstName: "Ada", lastName: "Lovelace")
        contact.tags = [tag]
        context.insert(tag)
        context.insert(contact)
        try context.save()

        #expect(tag.contacts.count == 1)
        #expect(contact.tags.first?.name == "VIP")
    }

    @Test func deletingTagKeepsContactsButClearsMembership() throws {
        let tag = ContactTag(name: "VIP")
        let contact = Contact(firstName: "Ada", lastName: "Lovelace")
        contact.tags = [tag]
        context.insert(tag)
        context.insert(contact)
        try context.save()

        context.delete(tag)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Contact>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<ContactTag>()) == 0)
        #expect(contact.tags.isEmpty)
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
        try SampleData.seedIfNeeded(context)
        #expect(try context.fetchCount(FetchDescriptor<Contact>()) == SampleData.count)
        #expect(try context.fetchCount(FetchDescriptor<ContactField>()) > 0)

        // Seeding again should be a no-op on a non-empty store.
        try SampleData.seedIfNeeded(context)
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

    @Test func roleLineJoinsTitleAndCompanyAndDropsBlanks() {
        #expect(Contact(company: "Acme", jobTitle: "CEO").roleLine == "CEO · Acme")
        #expect(Contact(jobTitle: "CEO").roleLine == "CEO")
        #expect(Contact(company: "Acme").roleLine == "Acme")
        #expect(Contact().roleLine == nil)
        // A whitespace-only field is dropped rather than leaving a stray separator.
        #expect(Contact(company: "  ", jobTitle: "CTO").roleLine == "CTO")
    }

    @Test func addressLinesDropEmptyComponents() {
        let full = Contact(
            street: "1 Infinite Loop", city: "Cupertino",
            state: "CA", postalCode: "95014", country: "USA"
        )
        #expect(full.addressLines == ["1 Infinite Loop", "Cupertino CA 95014", "USA"])

        // City/state/postal collapse to one line; missing pieces are skipped.
        let partial = Contact(city: "Portland", state: "OR")
        #expect(partial.addressLines == ["Portland OR"])

        #expect(Contact().addressLines.isEmpty)
        #expect(Contact(street: "  ", city: "Reno").addressLines == ["Reno"])
    }

    @Test func avatarPaletteIndexStaysInRangeForAnySeed() {
        let count = 8
        // Negative seeds (a real colorSeed can be negative) and Int.min must
        // not produce a negative index or trap.
        for seed in [0, 1, 7, 8, 9, -1, -8, -9, Int.min, Int.max] {
            #expect((0 ..< count).contains(Contact.avatarPaletteIndex(seed: seed, count: count)))
        }
    }

    @Test func avatarPaletteIndexWrapsDeterministically() {
        #expect(Contact.avatarPaletteIndex(seed: 10, count: 8) == 2)
        #expect(Contact.avatarPaletteIndex(seed: -1, count: 8) == 7)
        #expect(Contact.avatarPaletteIndex(seed: Int.min, count: 8) == 0)
    }

    @Test func avatarPaletteIndexHandlesNonPositiveCount() {
        #expect(Contact.avatarPaletteIndex(seed: 5, count: 0) == 0)
        #expect(Contact.avatarPaletteIndex(seed: 5, count: -3) == 0)
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

    @Test func sectionsGroupByInitialWithSymbolsLast() {
        let contacts = [
            Contact(firstName: "Ada", lastName: "Lovelace"),
            Contact(firstName: "Alan", lastName: "Turing"),
            Contact(firstName: "Grace", lastName: "Hopper"),
            Contact(company: "1Password"), // no person name → "#"
        ]
        let sections = ContactQuery.sections(contacts, by: .lastName)
        #expect(sections.map(\.title) == ["H", "L", "T", "#"])
        #expect(sections.first?.contacts.first?.lastName == "Hopper")
    }

    @Test func companyOnlyContactGroupsUnderCompanyInitial() {
        let acme = Contact(company: "Acme") // letter → "A"
        let numeric = Contact(company: "1Password") // non-letter → "#"
        let sections = ContactQuery.sections([acme, numeric], by: .lastName)
        #expect(sections.map(\.title) == ["A", "#"])
    }

    @Test func sortingAndSectioningByFirstNameUsesFirstNameInitial() {
        let contacts = [
            Contact(firstName: "Ada", lastName: "Lovelace"),
            Contact(firstName: "Alan", lastName: "Turing"),
            Contact(firstName: "Grace", lastName: "Hopper"),
        ]
        let sections = ContactQuery.sections(contacts, by: .firstName)
        #expect(sections.map(\.title) == ["A", "G"])
        // Within "A": Ada (Lovelace) before Alan (Turing).
        #expect(sections.first?.contacts.map(\.firstName) == ["Ada", "Alan"])
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
        #expect(ContactQuery.filtered(all, matching: "love").count == 1) // name
        #expect(ContactQuery.filtered(all, matching: "analytical").count == 1) // company + email
        #expect(ContactQuery.filtered(all, matching: "enigma").first?.firstName == "Alan") // notes
        #expect(ContactQuery.filtered(all, matching: "7555").first?.firstName == "Alan") // phone field
        #expect(ContactQuery.filtered(all, matching: "").count == 2)
        #expect(ContactQuery.filtered(all, matching: "nobody").isEmpty)
    }

    @Test func smartListsFilterRelationshipSignals() throws {
        let reference = try #require(Birthday.calendar.date(from: DateComponents(
            year: 2026, month: 6, day: 7
        )))
        let recent = Contact(firstName: "Recent")
        recent.lastContactedAt = reference.addingTimeInterval(-7 * 24 * 60 * 60)
        recent.fields = [ContactField(kind: .email, value: "recent@example.com")]
        let old = Contact(firstName: "Old")
        old.lastContactedAt = reference.addingTimeInterval(-45 * 24 * 60 * 60)
        old.fields = [ContactField(kind: .email, value: "old@example.com")]
        let missingEmail = Contact(firstName: "No Email")

        let contacts = [recent, old, missingEmail]

        let recentNames = ContactQuery.filtered(contacts, by: .recentlyContacted, now: reference).map(\.firstName)
        let followUpNames = ContactQuery.filtered(contacts, by: .needsFollowUp, now: reference).map(\.firstName)
        let noEmailNames = ContactQuery.filtered(contacts, by: .noEmail, now: reference).map(\.firstName)

        #expect(recentNames == ["Recent"])
        #expect(followUpNames == ["Old", "No Email"])
        #expect(noEmailNames == ["No Email"])
    }

    @Test func savedSmartListsFilterBySavedQuery() {
        let savedList = ContactSavedSmartList(name: "Engine People", query: "engine")
        let ada = Contact(firstName: "Ada", lastName: "Lovelace", company: "Analytical Engine")
        let alan = Contact(firstName: "Alan", lastName: "Turing", notes: "Enigma")
        let contacts = [ada, alan]

        let matches = ContactQuery.filtered(contacts, by: savedList)

        #expect(matches.map(\.firstName) == ["Ada"])
    }

    @Test func birthdaysSoonIgnoresStoredYearAndWrapsAcrossYearEnd() throws {
        let reference = try #require(Birthday.calendar.date(from: DateComponents(
            year: 2026, month: 12, day: 20
        )))
        let soon = Contact(firstName: "Soon", birthday: Birthday.date(year: 1980, month: 1, day: 5))
        let later = Contact(firstName: "Later", birthday: Birthday.date(year: 1980, month: 2, day: 15))
        let none = Contact(firstName: "None")

        let birthdays = ContactQuery.filtered([soon, later, none], by: .birthdaysSoon, now: reference)

        #expect(birthdays.map(\.firstName) == ["Soon"])
    }

    @Test func pastLeapDayBirthdayIsNotSoonInANonLeapYear() throws {
        let reference = try #require(Birthday.calendar.date(from: DateComponents(
            year: 2026, month: 3, day: 1
        )))
        let leapDay = Contact(firstName: "Leap", birthday: Birthday.date(year: 1980, month: 2, day: 29))

        let birthdays = ContactQuery.filtered([leapDay], by: .birthdaysSoon, now: reference)

        #expect(birthdays.isEmpty)
    }
}

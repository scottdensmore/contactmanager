//
//  DuplicateFinderTests.swift
//  ContactManagerTests
//
//  Pure tests for duplicate detection: matching by email/phone/name, transitive
//  grouping, and avoiding false positives.
//

@testable import ContactManager
import Testing

@MainActor
struct DuplicateFinderTests {
    private func contact(
        first: String = "",
        last: String = "",
        emails: [String] = [],
        phones: [String] = []
    ) -> Contact {
        let contact = Contact(firstName: first, lastName: last)
        contact.fields =
            emails.enumerated().map { ContactField(kind: .email, value: $1, sortIndex: $0) }
                + phones.enumerated().map { ContactField(kind: .phone, value: $1, sortIndex: $0) }
        return contact
    }

    @Test func matchesByEmailCaseInsensitively() {
        let ada = contact(first: "Ada", emails: ["ada@x.com"])
        let dupe = contact(first: "A.", emails: ["ADA@X.COM"])
        let other = contact(first: "Bob", emails: ["bob@x.com"])

        let groups = DuplicateFinder.duplicateGroups(in: [ada, dupe, other])
        #expect(groups.count == 1)
        #expect(groups.first?.count == 2)
    }

    @Test func matchesByPhoneIgnoringFormatting() {
        let ada = contact(first: "Ada", phones: ["+1 (555) 123-4567"])
        let dupe = contact(first: "A", phones: ["15551234567"])

        #expect(DuplicateFinder.duplicateGroups(in: [ada, dupe]).count == 1)
    }

    @Test func matchesByFullNameCaseInsensitively() {
        let ada = contact(first: "Ada", last: "Lovelace")
        let dupe = contact(first: "ada", last: "lovelace")

        #expect(DuplicateFinder.duplicateGroups(in: [ada, dupe]).count == 1)
    }

    @Test func groupsTransitiveMatchesIntoOne() {
        // ada ~ middle by email; middle ~ tail by phone → all three in one group.
        let ada = contact(first: "Ada", emails: ["shared@x.com"])
        let middle = contact(first: "Middle", emails: ["shared@x.com"], phones: ["5551112222"])
        let tail = contact(first: "Tail", phones: ["555 111 2222"])

        let groups = DuplicateFinder.duplicateGroups(in: [ada, middle, tail])
        #expect(groups.count == 1)
        #expect(groups.first?.count == 3)
    }

    @Test func distinctContactsAreNotGrouped() {
        let ada = contact(first: "Ada", last: "Lovelace", emails: ["ada@x.com"])
        let alan = contact(first: "Alan", last: "Turing", emails: ["alan@y.com"])

        #expect(DuplicateFinder.duplicateGroups(in: [ada, alan]).isEmpty)
    }

    @Test func shortPhoneFragmentsDoNotMatch() {
        let ada = contact(first: "Ada", phones: ["123"])
        let bob = contact(first: "Bob", phones: ["123"])

        #expect(DuplicateFinder.duplicateGroups(in: [ada, bob]).isEmpty)
    }

    @Test func emptyOrSingleInputYieldsNoGroups() {
        #expect(DuplicateFinder.duplicateGroups(in: []).isEmpty)
        #expect(DuplicateFinder.duplicateGroups(in: [contact(first: "Solo")]).isEmpty)
    }
}

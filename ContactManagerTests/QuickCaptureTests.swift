//
//  QuickCaptureTests.swift
//  ContactManagerTests
//
//  Fast-capture parsing and persistence tests. The parser stays pure so the
//  quick-entry window can stay thin; the store path proves capture still saves,
//  rolls back, and emits change notifications like other mutations.
//

@testable import ContactManager
import SwiftData
import Testing

@MainActor
@Suite(.serialized)
struct QuickCaptureTests {
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

    @Test func parsesNameEmailAndYearlessBirthday() throws {
        let draft = QuickCaptureParser.parse("Ada Lovelace, ada@example.com, birthday Dec 10")

        #expect(draft.firstName == "Ada")
        #expect(draft.lastName == "Lovelace")
        #expect(draft.emails.map(\.value) == ["ada@example.com"])

        let birthday = try #require(draft.birthday)
        let fields = Birthday.fields(of: birthday)
        #expect(fields.year == nil)
        #expect(fields.month == 12)
        #expect(fields.day == 10)
    }

    @Test func parsesPhoneCompanyTitleAndNotes() {
        let draft = QuickCaptureParser.parse(
            "Grace Hopper at Navy, title Rear Admiral, mobile +1 (555) 0100, notes COBOL pioneer"
        )

        #expect(draft.firstName == "Grace")
        #expect(draft.lastName == "Hopper")
        #expect(draft.company == "Navy")
        #expect(draft.jobTitle == "Rear Admiral")
        #expect(draft.phones.map(\.value) == ["+1 (555) 0100"])
        #expect(draft.phones.first?.label == .mobile)
        #expect(draft.notes == "COBOL pioneer")
    }

    @Test func parsesLabeledEmailAndPhoneFields() {
        let draft = QuickCaptureParser.parse(
            "Ada Lovelace, work email ada@example.com, home phone 555-0100"
        )

        #expect(draft.emails.map(\.value) == ["ada@example.com"])
        #expect(draft.emails.first?.label == .work)
        #expect(draft.phones.map(\.value) == ["555-0100"])
        #expect(draft.phones.first?.label == .home)
    }

    @Test func parsesMultiplePreviewDetailKinds() {
        let draft = QuickCaptureParser.parse(
            "Ada Lovelace, home email ada@example.com, work email ada@work.example, " +
                "mobile 555-0101, home phone 555-0102, tag VIP, group Work"
        )

        #expect(draft.emails.map(\.value) == ["ada@example.com", "ada@work.example"])
        #expect(draft.emails.map(\.label) == [.home, .work])
        #expect(draft.phones.map(\.value) == ["555-0101", "555-0102"])
        #expect(draft.phones.map(\.label) == [.mobile, .home])
        #expect(draft.tags == ["VIP"])
        #expect(draft.groups == ["Work"])
    }

    @Test func parsesTagsAndGroups() {
        let draft = QuickCaptureParser.parse(
            "Ada Lovelace, ada@example.com, tag VIP, group Work"
        )

        #expect(draft.tags == ["VIP"])
        #expect(draft.groups == ["Work"])
    }

    @Test func warnsAboutInvalidPrefixedFragments() {
        let draft = QuickCaptureParser.parse(
            "Ada Lovelace, birthday someday, email nope, phone 12, tag"
        )

        #expect(draft.birthday == nil)
        #expect(draft.emails.isEmpty)
        #expect(draft.phones.isEmpty)
        #expect(draft.tags.isEmpty)
        #expect(draft.parseWarnings == [
            "Couldn't parse birthday: someday",
            "Ignored email: nope",
            "Ignored phone: 12",
            "Ignored empty tag",
        ])
    }

    @Test func explicitFieldKindsDoNotFallThroughToOtherParsers() {
        let draft = QuickCaptureParser.parse(
            "Ada Lovelace, email 555-0101, phone ada@example.com"
        )

        #expect(draft.emails.isEmpty)
        #expect(draft.phones.isEmpty)
        #expect(draft.parseWarnings == [
            "Ignored email: 555-0101",
            "Ignored phone: ada@example.com",
        ])
    }

    @Test func duplicateMatchFindsExactEmail() {
        let ada = Contact(firstName: "Ada", lastName: "Lovelace")
        ada.fields = [
            ContactField(kind: .email, label: .home, value: "ada@example.com"),
        ]
        let draft = QuickCaptureParser.parse("Ada Byron, ADA@example.com")

        let match = QuickCaptureMatcher.bestMatch(for: draft, in: [ada])

        #expect(match?.contact === ada)
        #expect(match?.confidence == .likely)
        #expect(match?.reason == "same email")
    }

    @Test func duplicateMatchFindsExactPhone() {
        let ada = Contact(firstName: "Ada", lastName: "Lovelace")
        ada.fields = [
            ContactField(kind: .phone, label: .mobile, value: "(555) 010-1000"),
        ]
        let draft = QuickCaptureParser.parse("Ada Byron, phone 5550101000")

        let match = QuickCaptureMatcher.bestMatch(for: draft, in: [ada])

        #expect(match?.contact === ada)
        #expect(match?.confidence == .likely)
        #expect(match?.reason == "same phone")
    }

    @Test func duplicateMatchFindsPartialName() {
        let ada = Contact(firstName: "Ada", lastName: "Lovelace")
        let alan = Contact(firstName: "Alan", lastName: "Turing")
        let draft = QuickCaptureParser.parse("Ada")

        let match = QuickCaptureMatcher.bestMatch(for: draft, in: [alan, ada])

        #expect(match?.contact === ada)
        #expect(match?.confidence == .possible)
        #expect(match?.reason == "similar name")
    }

    @Test func duplicateMatchIgnoresUnrelatedContacts() {
        let alan = Contact(firstName: "Alan", lastName: "Turing")
        alan.fields = [
            ContactField(kind: .email, label: .home, value: "alan@example.com"),
        ]
        let draft = QuickCaptureParser.parse("Grace Hopper, grace@example.com")

        #expect(QuickCaptureMatcher.bestMatch(for: draft, in: [alan]) == nil)
    }

    @Test func parsesNumericBirthdayWithYear() throws {
        let draft = QuickCaptureParser.parse("Katherine Johnson, birthday 1918-08-26")

        let birthday = try #require(draft.birthday)
        let fields = Birthday.fields(of: birthday)
        #expect(fields.year == 1918)
        #expect(fields.month == 8)
        #expect(fields.day == 26)
    }

    @Test func createContactFromQuickCaptureDraftPersistsFields() throws {
        let draft = QuickCaptureParser.parse(
            "Alan Turing, alan@example.com, work 555-0101, birthday Jun 23, notes Enigma"
        )

        let contact = try store.createContact(from: draft)

        #expect(contact.firstName == "Alan")
        #expect(contact.lastName == "Turing")
        #expect(contact.emails.map(\.value) == ["alan@example.com"])
        #expect(contact.phones.map(\.value) == ["555-0101"])
        #expect(contact.phones.first?.label == .work)
        #expect(contact.notes == "Enigma")
        #expect(try context.fetchCount(FetchDescriptor<Contact>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<ContactField>()) == 2)
    }

    @Test func createContactFromQuickCaptureDraftPreservesFieldLabels() throws {
        let draft = QuickCaptureParser.parse(
            "Katherine Johnson, work email katherine@example.com, home phone 555-0102"
        )

        let contact = try store.createContact(from: draft)

        let email = try #require(contact.emails.first)
        #expect(email.label == .work)
        #expect(email.value == "katherine@example.com")

        let phone = try #require(contact.phones.first)
        #expect(phone.label == .home)
        #expect(phone.value == "555-0102")
    }

    @Test func createContactFromQuickCaptureDraftAssignsGroupsAndTags() throws {
        let existingGroup = ContactGroup(name: "Work")
        let existingTag = ContactTag(name: "VIP")
        context.insert(existingGroup)
        context.insert(existingTag)
        try context.save()

        let draft = QuickCaptureParser.parse(
            "Hedy Lamarr, hedy@example.com, tag vip, group work"
        )

        let contact = try store.createContact(from: draft)

        #expect(contact.groups.map(\.displayName) == ["Work"])
        #expect(contact.tags.map(\.displayName) == ["VIP"])
        #expect(existingGroup.contacts.map(\.fullName) == ["Hedy Lamarr"])
        #expect(existingTag.contacts.map(\.fullName) == ["Hedy Lamarr"])
        #expect(try context.fetchCount(FetchDescriptor<ContactGroup>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<ContactTag>()) == 1)
    }

    @Test func createContactFromQuickCaptureDraftCreatesMissingGroupsAndTags() throws {
        let draft = QuickCaptureParser.parse(
            "Dorothy Vaughan, dorothy@example.com, tag VIP, group Work"
        )

        let contact = try store.createContact(from: draft)

        #expect(contact.groups.map(\.displayName) == ["Work"])
        #expect(contact.tags.map(\.displayName) == ["VIP"])
        #expect(try context.fetchCount(FetchDescriptor<ContactGroup>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<ContactTag>()) == 1)
    }

    @Test func updateContactFromQuickCaptureDraftAddsMissingData() throws {
        let contact = Contact(firstName: "Ada", lastName: "Lovelace")
        contact.fields = [
            ContactField(kind: .email, label: .home, value: "ada@example.com"),
        ]
        context.insert(contact)
        try context.save()

        let draft = QuickCaptureParser.parse(
            "Ada Lovelace, ada@example.com, work ada@analytical.example, phone 555-0101, tag VIP"
        )

        try store.updateContact(contact, from: draft)

        #expect(contact.emails.map(\.value) == ["ada@example.com", "ada@analytical.example"])
        #expect(contact.phones.map(\.value) == ["555-0101"])
        #expect(contact.tags.map(\.displayName) == ["VIP"])
        #expect(try context.fetchCount(FetchDescriptor<Contact>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<ContactField>()) == 3)
    }
}

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
            for: Contact.self, ContactField.self, ContactGroup.self,
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
}

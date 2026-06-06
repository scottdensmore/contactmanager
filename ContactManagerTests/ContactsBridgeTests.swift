//
//  ContactsBridgeTests.swift
//  ContactManagerTests
//
//  Tests for the pure `CNContact` → `ParsedContact` mapping. The fetch
//  itself isn't tested here — it needs a real address book + user
//  permission, neither of which we have in CI.
//

@testable import ContactManager
import Contacts
import Foundation
import Testing

struct ContactsBridgeTests {
    @Test func mapsTopLevelFields() {
        let cnContact = CNMutableContact()
        cnContact.givenName = "Ada"
        cnContact.familyName = "Lovelace"
        cnContact.organizationName = "Analytical Engine Co."
        cnContact.jobTitle = "Mathematician"

        let parsed = ContactsBridge.parsed(from: cnContact)
        #expect(parsed.firstName == "Ada")
        #expect(parsed.lastName == "Lovelace")
        #expect(parsed.company == "Analytical Engine Co.")
        #expect(parsed.jobTitle == "Mathematician")
    }

    @Test func mapsEmailsWithLabels() {
        let cnContact = CNMutableContact()
        cnContact.emailAddresses = [
            CNLabeledValue(label: CNLabelHome, value: "ada@home.test" as NSString),
            CNLabeledValue(label: CNLabelWork, value: "ada@work.test" as NSString),
            CNLabeledValue(label: "iCloud", value: "ada@icloud.test" as NSString),
        ]

        let parsed = ContactsBridge.parsed(from: cnContact)
        #expect(parsed.emails.count == 3)
        #expect(parsed.emails[0].label == .home)
        #expect(parsed.emails[0].value == "ada@home.test")
        #expect(parsed.emails[1].label == .work)
        // Unknown label falls back to .other rather than dropping the value.
        #expect(parsed.emails[2].label == .other)
        #expect(parsed.emails[2].value == "ada@icloud.test")
    }

    @Test func mapsPhonesWithSpecializedLabels() {
        let cnContact = CNMutableContact()
        cnContact.phoneNumbers = [
            CNLabeledValue(
                label: CNLabelPhoneNumberMobile,
                value: CNPhoneNumber(stringValue: "+1 555 0100")
            ),
            CNLabeledValue(
                label: CNLabelPhoneNumberiPhone,
                value: CNPhoneNumber(stringValue: "+1 555 0101")
            ),
            CNLabeledValue(
                label: CNLabelPhoneNumberMain,
                value: CNPhoneNumber(stringValue: "+1 555 0102")
            ),
        ]

        let parsed = ContactsBridge.parsed(from: cnContact)
        #expect(parsed.phones.map(\.label) == [.mobile, .mobile, .main])
        #expect(parsed.phones.map(\.value) == ["+1 555 0100", "+1 555 0101", "+1 555 0102"])
    }

    @Test func mapsFirstPostalAddress() {
        let cnContact = CNMutableContact()
        let address = CNMutablePostalAddress()
        address.street = "1 Infinite Loop"
        address.city = "Cupertino"
        address.state = "CA"
        address.postalCode = "95014"
        address.country = "United States"
        cnContact.postalAddresses = [CNLabeledValue(label: CNLabelWork, value: address)]

        let parsed = ContactsBridge.parsed(from: cnContact)
        #expect(parsed.street == "1 Infinite Loop")
        #expect(parsed.city == "Cupertino")
        #expect(parsed.state == "CA")
        #expect(parsed.postalCode == "95014")
        #expect(parsed.country == "United States")
    }

    @Test func mapsBirthdayToGregorianDate() throws {
        let cnContact = CNMutableContact()
        cnContact.birthday = DateComponents(year: 1815, month: 12, day: 10)
        let parsed = ContactsBridge.parsed(from: cnContact)
        let birthday = try #require(parsed.birthday)
        // Read back through the same UTC-anchored calendar the mapping used,
        // so the assertion doesn't depend on the test machine's time zone.
        let fields = Birthday.fields(of: birthday)
        #expect(fields.year == 1815)
        #expect(fields.month == 12)
        #expect(fields.day == 10)
    }

    @Test func mapsYearlessBirthday() throws {
        // A Contacts card with no birth year (year omitted) must keep its
        // month/day and report no year, not collapse to a wrong date.
        let cnContact = CNMutableContact()
        cnContact.birthday = DateComponents(month: 4, day: 15)
        let parsed = ContactsBridge.parsed(from: cnContact)
        let birthday = try #require(parsed.birthday)
        let fields = Birthday.fields(of: birthday)
        #expect(fields.year == nil)
        #expect(fields.month == 4)
        #expect(fields.day == 15)
    }

    @Test func passesThroughPhotoData() {
        let cnContact = CNMutableContact()
        let payload = Data([0x89, 0x50, 0x4E, 0x47])
        cnContact.imageData = payload
        let parsed = ContactsBridge.parsed(from: cnContact)
        #expect(parsed.photoData == payload)
    }

    @Test func handlesEmptyContact() {
        let parsed = ContactsBridge.parsed(from: CNMutableContact())
        #expect(parsed.firstName.isEmpty)
        #expect(parsed.emails.isEmpty)
        #expect(parsed.phones.isEmpty)
        #expect(parsed.birthday == nil)
        #expect(parsed.photoData == nil)
    }
}

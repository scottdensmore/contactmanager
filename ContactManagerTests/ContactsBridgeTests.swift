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
        let cn = CNMutableContact()
        cn.givenName = "Ada"
        cn.familyName = "Lovelace"
        cn.organizationName = "Analytical Engine Co."
        cn.jobTitle = "Mathematician"

        let parsed = ContactsBridge.parsed(from: cn)
        #expect(parsed.firstName == "Ada")
        #expect(parsed.lastName == "Lovelace")
        #expect(parsed.company == "Analytical Engine Co.")
        #expect(parsed.jobTitle == "Mathematician")
    }

    @Test func mapsEmailsWithLabels() {
        let cn = CNMutableContact()
        cn.emailAddresses = [
            CNLabeledValue(label: CNLabelHome, value: "ada@home.test" as NSString),
            CNLabeledValue(label: CNLabelWork, value: "ada@work.test" as NSString),
            CNLabeledValue(label: "iCloud", value: "ada@icloud.test" as NSString),
        ]

        let parsed = ContactsBridge.parsed(from: cn)
        #expect(parsed.emails.count == 3)
        #expect(parsed.emails[0].label == .home)
        #expect(parsed.emails[0].value == "ada@home.test")
        #expect(parsed.emails[1].label == .work)
        // Unknown label falls back to .other rather than dropping the value.
        #expect(parsed.emails[2].label == .other)
        #expect(parsed.emails[2].value == "ada@icloud.test")
    }

    @Test func mapsPhonesWithSpecializedLabels() {
        let cn = CNMutableContact()
        cn.phoneNumbers = [
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

        let parsed = ContactsBridge.parsed(from: cn)
        #expect(parsed.phones.map(\.label) == [.mobile, .mobile, .main])
        #expect(parsed.phones.map(\.value) == ["+1 555 0100", "+1 555 0101", "+1 555 0102"])
    }

    @Test func mapsFirstPostalAddress() {
        let cn = CNMutableContact()
        let address = CNMutablePostalAddress()
        address.street = "12 Mayfair"
        address.city = "London"
        address.state = ""
        address.postalCode = "W1"
        address.country = "United Kingdom"
        cn.postalAddresses = [CNLabeledValue(label: CNLabelHome, value: address)]

        let parsed = ContactsBridge.parsed(from: cn)
        #expect(parsed.street == "12 Mayfair")
        #expect(parsed.city == "London")
        #expect(parsed.postalCode == "W1")
        #expect(parsed.country == "United Kingdom")
    }

    @Test func mapsBirthdayToGregorianDate() throws {
        let cn = CNMutableContact()
        cn.birthday = DateComponents(year: 1815, month: 12, day: 10)
        let parsed = ContactsBridge.parsed(from: cn)
        let birthday = try #require(parsed.birthday)
        let parts = Calendar(identifier: .gregorian)
            .dateComponents([.year, .month, .day], from: birthday)
        #expect(parts.year == 1815)
        #expect(parts.month == 12)
        #expect(parts.day == 10)
    }

    @Test func passesThroughPhotoData() {
        let cn = CNMutableContact()
        let payload = Data([0x89, 0x50, 0x4E, 0x47])
        cn.imageData = payload
        let parsed = ContactsBridge.parsed(from: cn)
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

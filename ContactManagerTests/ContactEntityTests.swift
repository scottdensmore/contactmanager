//
//  ContactEntityTests.swift
//  ContactManagerTests
//
//  Coverage of the pure `Contact` → `ContactEntity` mapping and the
//  derived Spotlight attribute set. The query and `SpotlightIndexer`
//  live behind a process-wide model container that's set up at app
//  launch; integration coverage for those would need a parallel
//  container fixture and is left for a future pass.
//

@testable import ContactManager
import CoreSpotlight
import Foundation
import SwiftData
import Testing

@MainActor
struct ContactEntityTests {
    private func sampleContact() -> Contact {
        let contact = Contact(
            firstName: "Ada", lastName: "Lovelace",
            company: "Analytical Engine Co.", jobTitle: "Mathematician"
        )
        contact.fields = [
            ContactField(kind: .email, label: .work, value: "ada@analytical.engine", sortIndex: 0),
            ContactField(kind: .email, label: .home, value: "ada@home.test", sortIndex: 1),
            ContactField(kind: .phone, label: .mobile, value: "+1 555 0100", sortIndex: 0),
        ]
        return contact
    }

    @Test func snapshotsScalarFields() {
        let entity = ContactEntity(contact: sampleContact())
        #expect(entity.displayName == "Ada Lovelace")
        #expect(entity.company == "Analytical Engine Co.")
        #expect(entity.jobTitle == "Mathematician")
    }

    @Test func snapshotsContactEmailsAndPhones() {
        let entity = ContactEntity(contact: sampleContact())
        #expect(entity.emails == ["ada@analytical.engine", "ada@home.test"])
        #expect(entity.phones == ["+1 555 0100"])
    }

    @Test func skipsBlankFieldValues() {
        let contact = Contact(firstName: "Blank", lastName: "Fields")
        contact.fields = [
            ContactField(kind: .email, label: .home, value: "", sortIndex: 0),
            ContactField(kind: .email, label: .work, value: "real@example.com", sortIndex: 1),
        ]
        let entity = ContactEntity(contact: contact)
        #expect(entity.emails == ["real@example.com"])
    }

    @Test func attributeSetReflectsAllPopulatedFields() {
        let attrs = ContactEntity(contact: sampleContact()).attributeSet
        #expect(attrs.displayName == "Ada Lovelace")
        #expect(attrs.contentDescription == "ada@analytical.engine")
        #expect(attrs.emailAddresses == ["ada@analytical.engine", "ada@home.test"])
        #expect(attrs.phoneNumbers == ["+1 555 0100"])
        #expect(attrs.organizations == ["Analytical Engine Co."])
        #expect(attrs.title == "Mathematician")
    }

    @Test func attributeSetOmitsEmptyFields() {
        let contact = Contact(firstName: "Solo", lastName: "Name")
        let attrs = ContactEntity(contact: contact).attributeSet
        #expect(attrs.displayName == "Solo Name")
        #expect(attrs.contentDescription == nil)
        #expect(attrs.emailAddresses == nil)
        #expect(attrs.phoneNumbers == nil)
        #expect(attrs.organizations == nil)
        #expect(attrs.title == nil)
    }

    @Test func subtitleFallsBackToCompanyWhenNoEmailOrPhone() {
        let contact = Contact(firstName: "Solo", lastName: "Worker", company: "Acme")
        let attrs = ContactEntity(contact: contact).attributeSet
        #expect(attrs.contentDescription == "Acme")
    }

    @Test func entityIdMatchesEncodedPersistentIdentifier() throws {
        // The id is reused by `selectContact(byEncodedID:)` and the
        // default-group preference — they must agree on the encoding.
        let contact = sampleContact()
        let entity = ContactEntity(contact: contact)
        let decoded = try #require(PersistentIdentifier.decode(stored: entity.id))
        #expect(decoded == contact.persistentModelID)
    }

    @Test func encodedIdIsStableAcrossEncodings() throws {
        // Spotlight's incremental re-index and `entities(for:)` lookup match
        // contacts by comparing two separately-encoded ids as strings, so the
        // same identifier must always encode to the same string. Unwrap both
        // so a `nil` encoding fails the test instead of trivially matching.
        let id = sampleContact().persistentModelID
        let first = try #require(id.storedString)
        let second = try #require(id.storedString)
        #expect(first == second)
    }
}

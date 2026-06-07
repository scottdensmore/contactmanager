//
//  ContactPDFTests.swift
//  ContactManagerTests
//
//  Verifies the contact-card PDF renderer produces real PDF bytes and a
//  sensible filename.
//

@testable import ContactManager
import Foundation
import Testing

@MainActor
struct ContactPDFTests {
    @Test func rendersNonEmptyPDFData() throws {
        let contact = Contact(firstName: "Ada", lastName: "Lovelace", company: "Analytical")
        contact.fields = [
            ContactField(kind: .email, label: .work, value: "ada@analytical.engine", sortIndex: 0),
            ContactField(kind: .phone, label: .mobile, value: "+1 555 0100", sortIndex: 0),
        ]
        let data = try #require(ContactPDF.data(for: contact))
        #expect(!data.isEmpty)
        // Every PDF starts with the "%PDF" magic header.
        #expect(data.prefix(4).elementsEqual(Data("%PDF".utf8)))
    }

    @Test func rendersAMinimalContact() throws {
        // No fields/photo/notes — should still produce a valid one-page PDF.
        let data = try #require(ContactPDF.data(for: Contact(firstName: "Solo", lastName: "Name")))
        #expect(data.prefix(4).elementsEqual(Data("%PDF".utf8)))
    }

    @Test func filenameFollowsContactName() {
        let contact = Contact(firstName: "Ada", lastName: "Lovelace")
        #expect(ContactPDF.filename(for: contact) == "Ada Lovelace")
    }
}

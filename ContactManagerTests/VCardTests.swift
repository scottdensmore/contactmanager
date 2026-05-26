//
//  VCardTests.swift
//  ContactManagerTests
//
//  Verifies vCard writing and parsing, including a full round-trip.
//

import Testing
import Foundation
@testable import ContactManager

@MainActor
struct VCardTests {

    private func sampleContact() -> Contact {
        let contact = Contact(
            firstName: "Ada", lastName: "Lovelace",
            company: "Analytical Engine Co.", jobTitle: "Mathematician",
            street: "12 Mayfair", city: "London", state: "",
            postalCode: "W1", country: "United Kingdom",
            birthday: DateComponents(calendar: .current, year: 1815, month: 12, day: 10).date,
            notes: "First programmer; loves semicolons, commas."
        )
        contact.fields = [
            ContactField(kind: .email, label: .work, value: "ada@analytical.engine", sortIndex: 0),
            ContactField(kind: .phone, label: .mobile, value: "+1 (555) 0100", sortIndex: 0),
        ]
        return contact
    }

    @Test func writesBeginAndEndWithEscaping() {
        let card = VCard.card(for: sampleContact())
        #expect(card.hasPrefix("BEGIN:VCARD"))
        #expect(card.contains("END:VCARD"))
        #expect(card.contains("FN:Ada Lovelace"))
        #expect(card.contains("EMAIL;TYPE=WORK:ada@analytical.engine"))
        #expect(card.contains("TEL;TYPE=CELL:+1 (555) 0100"))
        // Commas/semicolons in NOTE are escaped.
        #expect(card.contains("NOTE:First programmer; loves semicolons, commas.".replacingOccurrences(of: ";", with: "\\;").replacingOccurrences(of: ",", with: "\\,")))
    }

    @Test func roundTripsCoreFields() {
        let original = sampleContact()
        let document = VCard.makeDocument(from: [original])
        let parsed = VCard.parse(document)

        #expect(parsed.count == 1)
        let card = try? #require(parsed.first)
        #expect(card?.firstName == "Ada")
        #expect(card?.lastName == "Lovelace")
        #expect(card?.company == "Analytical Engine Co.")
        #expect(card?.jobTitle == "Mathematician")
        #expect(card?.notes == "First programmer; loves semicolons, commas.")
        #expect(card?.city == "London")
        #expect(card?.country == "United Kingdom")
        #expect(card?.emails.first?.value == "ada@analytical.engine")
        #expect(card?.emails.first?.label == .work)
        #expect(card?.phones.first?.value == "+1 (555) 0100")
        #expect(card?.phones.first?.label == .mobile)
    }

    @Test func parsesMultipleCardsAndFoldedLines() {
        let text = """
        BEGIN:VCARD
        VERSION:3.0
        FN:Grace Hopper
        N:Hopper;Grace;;;
        NOTE:A very long note that has been folded across
          multiple physical lines per the vCard spec.
        END:VCARD
        BEGIN:VCARD
        VERSION:3.0
        FN:Alan Turing
        N:Turing;Alan;;;
        END:VCARD
        """
        let parsed = VCard.parse(text)
        #expect(parsed.count == 2)
        #expect(parsed.first?.lastName == "Hopper")
        #expect(parsed.first?.notes.contains("folded across multiple physical lines") == true)
        #expect(parsed.last?.firstName == "Alan")
    }

    @Test func foldsLongLinesOnWriteAndRoundTrips() {
        let longNote = String(repeating: "All models are wrong but some are useful. ", count: 5)
        let contact = Contact(firstName: "Box", lastName: "George", notes: longNote)
        let document = VCard.card(for: contact)

        // A continuation line (folded) begins with a single space.
        let hasFoldedLine = document
            .components(separatedBy: "\r\n")
            .contains { $0.hasPrefix(" ") }
        #expect(hasFoldedLine)

        // Folding is reversible: parsing recovers the original note.
        #expect(VCard.parse(document).first?.notes == longNote)
    }

    @Test func ignoresEmptyDocuments() {
        #expect(VCard.parse("").isEmpty)
        #expect(VCard.parse("not a vcard at all").isEmpty)
    }
}

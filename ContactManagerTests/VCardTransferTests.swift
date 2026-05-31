//
//  VCardTransferTests.swift
//  ContactManagerTests
//
//  Filename sanitization for the drag-to-Finder export.
//

@testable import ContactManager
import Testing

struct VCardTransferTests {
    @Test func usesContactNameWhenPresent() {
        #expect(VCardTransfer.suggestedFilename(for: "Ada Lovelace") == "Ada Lovelace")
    }

    @Test func fallsBackToContactForEmptyName() {
        #expect(VCardTransfer.suggestedFilename(for: "") == "Contact")
        #expect(VCardTransfer.suggestedFilename(for: "   ") == "Contact")
    }

    @Test func replacesPathIllegalCharacters() {
        // `/` and `:` are illegal in HFS+/APFS filenames; both should be
        // rewritten rather than dropped so two distinct names don't collide.
        #expect(VCardTransfer.suggestedFilename(for: "AC/DC") == "AC-DC")
        #expect(VCardTransfer.suggestedFilename(for: "9:30 Club") == "9-30 Club")
        #expect(VCardTransfer.suggestedFilename(for: "/:/") == "---")
    }

    @Test func keepsInternationalCharacters() {
        #expect(VCardTransfer.suggestedFilename(for: "Søren Kierkegaard") == "Søren Kierkegaard")
    }
}

//
//  ContactLinkTests.swift
//  ContactManagerTests
//
//  Covers the `mailto:` / `tel:` URL construction behind the detail view's
//  click-to-mail and click-to-call actions — the value normalization is the
//  part with edge cases (formatting characters, blanks, country codes).
//

@testable import ContactManager
import Foundation
import Testing

struct ContactLinkTests {
    // MARK: - mailto

    @Test func mailtoWrapsAPlainAddress() throws {
        let url = try #require(ContactLink.mailto("ada@example.com"))
        #expect(url.absoluteString == "mailto:ada@example.com")
    }

    @Test func mailtoTrimsSurroundingWhitespace() throws {
        let url = try #require(ContactLink.mailto("  ada@example.com \n"))
        #expect(url.absoluteString == "mailto:ada@example.com")
    }

    @Test func mailtoKeepsPlusAddressing() throws {
        let url = try #require(ContactLink.mailto("ada+news@example.com"))
        #expect(url.absoluteString == "mailto:ada+news@example.com")
    }

    @Test func mailtoPercentEncodesSpaces() throws {
        let url = try #require(ContactLink.mailto("ada lovelace@example.com"))
        #expect(url.absoluteString == "mailto:ada%20lovelace@example.com")
    }

    @Test func mailtoEncodesReservedDelimitersInsteadOfInjectingHeaders() throws {
        // A value carrying `?`/`#` must fold into the address, not turn into
        // mailto query headers or a fragment.
        let url = try #require(ContactLink.mailto("ada@example.com?subject=hi#x"))
        #expect(url.query == nil)
        #expect(url.fragment == nil)
        #expect(url.absoluteString.hasPrefix("mailto:ada@example.com"))
    }

    @Test func mailtoIsNilForBlank() {
        #expect(ContactLink.mailto("") == nil)
        #expect(ContactLink.mailto("   ") == nil)
    }

    // MARK: - tel

    @Test func telStripsFormattingCharacters() throws {
        let url = try #require(ContactLink.tel("(555) 010-0199"))
        #expect(url.absoluteString == "tel:5550100199")
    }

    @Test func telKeepsLeadingCountryCodePlus() throws {
        let url = try #require(ContactLink.tel("+1 (555) 010-0199"))
        #expect(url.absoluteString == "tel:+15550100199")
    }

    @Test func telDropsAPlusThatIsNotLeading() throws {
        // A stray "+" mid-string isn't a country-code marker; only a leading
        // one is kept.
        let url = try #require(ContactLink.tel("555+0100"))
        #expect(url.absoluteString == "tel:5550100")
    }

    @Test func telIsNilWhenNoDigits() {
        #expect(ContactLink.tel("") == nil)
        #expect(ContactLink.tel("call me") == nil)
        #expect(ContactLink.tel("+") == nil)
    }
}

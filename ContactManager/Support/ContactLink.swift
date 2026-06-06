//
//  ContactLink.swift
//  ContactManager
//
//  Builds the `mailto:` / `tel:` URLs behind the contact detail's
//  click-to-mail and click-to-call actions. Kept here (not in the view) so
//  the value normalization — which is the part that actually has edge cases
//  — is unit-tested directly.
//

import Foundation

enum ContactLink {
    /// A `mailto:` URL for an email address, or `nil` if it's blank.
    /// Built through `URLComponents` so reserved delimiters (`?`, `#`) in an
    /// odd value are percent-encoded into the address rather than becoming
    /// mailto headers or a fragment; `@` and `+` are legal in the path and
    /// pass through untouched.
    static func mailto(_ email: String) -> URL? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = trimmed
        return components.url
    }

    /// A `tel:` URL for a phone number, or `nil` if it carries no digits.
    /// Keeps only the dialable digits plus a leading `+` (country code),
    /// dropping the spaces, parentheses, and dashes people type for
    /// readability. (`ContactStore`'s phone normalization strips the `+`
    /// too; here it's kept because a country code is dialable.)
    static func tel(_ phone: String) -> URL? {
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = String(trimmed.filter(\.isNumber))
        guard !digits.isEmpty else { return nil }
        let prefix = trimmed.hasPrefix("+") ? "+" : ""
        return URL(string: "tel:\(prefix)\(digits)")
    }
}

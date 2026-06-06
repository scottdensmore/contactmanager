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
    /// The address is percent-encoded so an odd value can't produce a
    /// malformed URL (`@` and `+` are left intact — both are legal here).
    static func mailto(_ email: String) -> URL? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return nil }
        return URL(string: "mailto:\(encoded)")
    }

    /// A `tel:` URL for a phone number, or `nil` if it carries no digits.
    /// Keeps only the dialable digits plus a leading `+` (country code),
    /// dropping the spaces, parentheses, and dashes people type for
    /// readability — matching how `ContactStore` normalizes phone values.
    static func tel(_ phone: String) -> URL? {
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = String(trimmed.filter(\.isNumber))
        guard !digits.isEmpty else { return nil }
        let prefix = trimmed.hasPrefix("+") ? "+" : ""
        return URL(string: "tel:\(prefix)\(digits)")
    }
}

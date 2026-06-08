//
//  Contact.swift
//  ContactManager
//
//  The SwiftData model backing a single contact.
//

import Foundation
import SwiftData

@Model
final class Contact {
    // Identity
    var firstName: String = ""
    var lastName: String = ""

    // Work
    var company: String = ""
    var jobTitle: String = ""

    // Postal address
    var street: String = ""
    var city: String = ""
    var state: String = ""
    var postalCode: String = ""
    var country: String = ""

    // Misc
    var birthday: Date?
    var lastContactedAt: Date?
    var notes: String = ""
    var createdAt: Date = Date.now

    /// Downscaled avatar image (JPEG). `.externalStorage` lets SwiftData keep
    /// large blobs outside the SQLite file when appropriate.
    @Attribute(.externalStorage) var photoData: Data?

    /// Labeled emails and phone numbers.
    @Relationship(deleteRule: .cascade, inverse: \ContactField.contact)
    var fields: [ContactField] = []

    /// Groups this contact belongs to (many-to-many; inverse on ContactGroup).
    var groups: [ContactGroup] = []

    init(
        firstName: String = "",
        lastName: String = "",
        company: String = "",
        jobTitle: String = "",
        street: String = "",
        city: String = "",
        state: String = "",
        postalCode: String = "",
        country: String = "",
        birthday: Date? = nil,
        lastContactedAt: Date? = nil,
        notes: String = "",
        createdAt: Date = .now
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.company = company
        self.jobTitle = jobTitle
        self.street = street
        self.city = city
        self.state = state
        self.postalCode = postalCode
        self.country = country
        self.birthday = birthday
        self.lastContactedAt = lastContactedAt
        self.notes = notes
        self.createdAt = createdAt
        fields = []
    }
}

extension Contact {
    /// Human-readable name, falling back to company, then a placeholder.
    var fullName: String {
        let name = [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if !name.isEmpty { return name }
        let trimmedCompany = company.trimmingCharacters(in: .whitespaces)
        return trimmedCompany.isEmpty ? "New Contact" : trimmedCompany
    }

    /// One or two uppercase letters used for the avatar placeholder.
    var initials: String {
        let first = firstName.trimmingCharacters(in: .whitespaces).first.map(String.init) ?? ""
        let last = lastName.trimmingCharacters(in: .whitespaces).first.map(String.init) ?? ""
        var combined = (first + last).uppercased()
        if combined.isEmpty {
            combined = company.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? ""
        }
        return combined.isEmpty ? "#" : combined
    }

    /// Lowercased key used to sort contacts: last name, then first name, then
    /// company. Falling back to company keeps sorting/sectioning aligned with
    /// the displayed `fullName` for company-only contacts.
    var sortKey: String {
        for candidate in [lastName, firstName, company] {
            let trimmed = candidate.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { return trimmed.lowercased() }
        }
        return ""
    }

    /// Lowercased first name, trimmed — used as the secondary sort key so it
    /// stays consistent with `sortKey`.
    var firstNameSortKey: String {
        firstName.trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// Deterministic, launch-stable seed for the avatar tint. Derived from the
    /// persisted creation date so the color survives relaunches (unlike
    /// `hashValue`, which is per-process) and doesn't shift when the name is
    /// edited.
    var colorSeed: Int {
        Int(truncatingIfNeeded: createdAt.timeIntervalSinceReferenceDate.bitPattern)
    }

    /// Index into an avatar palette of `count` colors for a stable `seed`.
    /// Normalizes into range without `abs` (which traps on `Int.min`), so any
    /// seed — including a negative `colorSeed` — yields a valid index. Returns
    /// 0 for a non-positive `count`. Shared by `AvatarView` and the printable
    /// card so both pick the same color.
    static func avatarPaletteIndex(seed: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return ((seed % count) + count) % count
    }

    /// Avatar palette index for this contact's `colorSeed`.
    func avatarPaletteIndex(count: Int) -> Int {
        Self.avatarPaletteIndex(seed: colorSeed, count: count)
    }

    /// Primary/secondary keys for a given sort order. The primary key also
    /// drives alphabetical section grouping.
    func sortKeys(for order: ContactSortOrder) -> (primary: String, secondary: String) {
        switch order {
        case .lastName:
            return (sortKey, firstNameSortKey)
        case .firstName:
            let first = firstNameSortKey
            return (first.isEmpty ? sortKey : first, sortKey)
        }
    }

    // MARK: - Field helpers

    var emails: [ContactField] { fields(of: .email) }
    var phones: [ContactField] { fields(of: .phone) }

    func fields(of kind: FieldKind) -> [ContactField] {
        fields
            .filter { $0.kind == kind }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    /// The first non-empty email, used as the list subtitle.
    var primaryEmail: String? {
        emails.first { !$0.value.trimmingCharacters(in: .whitespaces).isEmpty }?.value
    }

    /// The first non-empty phone number.
    var primaryPhone: String? {
        phones.first { !$0.value.trimmingCharacters(in: .whitespaces).isEmpty }?.value
    }

    /// Best available secondary line for list rows: email, then phone, then company.
    var subtitle: String? {
        if let email = primaryEmail { return email }
        if let phone = primaryPhone { return phone }
        let trimmedCompany = company.trimmingCharacters(in: .whitespaces)
        return trimmedCompany.isEmpty ? nil : trimmedCompany
    }

    /// "Job Title · Company" header line, or `nil` when both are blank. Trims
    /// like the other derived strings so a whitespace-only field is dropped
    /// rather than producing a stray separator. Shown under the name in the
    /// detail view and the printable card.
    var roleLine: String? {
        let line = [jobTitle, company]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        return line.isEmpty ? nil : line
    }

    /// The postal address as display lines — street, then "city state postal",
    /// then country — dropping any blank component. Empty when no address is
    /// set. Backs the printable card's address block.
    var addressLines: [String] {
        let cityStatePostal = [city, state, postalCode]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return [
            street.trimmingCharacters(in: .whitespaces),
            cityStatePostal,
            country.trimmingCharacters(in: .whitespaces),
        ].filter { !$0.isEmpty }
    }
}

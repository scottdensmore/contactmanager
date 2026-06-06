//
//  ContactsBridge.swift
//  ContactManager
//
//  Reads contacts from the user's macOS Contacts (Address Book) store via
//  the `Contacts` framework and maps them to our own `ParsedContact`
//  values so import flows through the same path as vCard import.
//
//  The fetch + mapping pipeline is pure (no SwiftData), so it's testable
//  with `CNMutableContact` fixtures.
//

import Contacts
import Foundation

enum ContactsBridge {
    /// Errors surfaced to the user. Anything else (e.g. an unexpected
    /// `CNError`) is rethrown so the caller can show its message.
    enum AccessError: LocalizedError {
        case denied
        case restricted

        var errorDescription: String? {
            switch self {
            case .denied:
                "ContactManager doesn't have permission to read your Contacts. " +
                    "Enable it in System Settings ▸ Privacy & Security ▸ Contacts."
            case .restricted:
                "Access to Contacts is restricted on this Mac."
            }
        }
    }

    /// Keys we need from each unified contact. Listed once so a future
    /// addition (e.g. notes) is a one-line change.
    private static let keysToFetch: [CNKeyDescriptor] = [
        CNContactGivenNameKey, CNContactFamilyNameKey,
        CNContactOrganizationNameKey, CNContactJobTitleKey,
        CNContactEmailAddressesKey, CNContactPhoneNumbersKey,
        CNContactPostalAddressesKey, CNContactBirthdayKey,
        CNContactImageDataKey,
    ].map { $0 as CNKeyDescriptor }

    /// Requests permission if needed and returns the unified contact list
    /// mapped to `ParsedContact`. Safe to call off the main actor.
    static func fetchAllParsed() async throws -> [ParsedContact] {
        let store = CNContactStore()
        try await ensureAccess(store: store)

        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        var parsed: [ParsedContact] = []
        try store.enumerateContacts(with: request) { cnContact, _ in
            parsed.append(self.parsed(from: cnContact))
        }
        return parsed
    }

    private static func ensureAccess(store: CNContactStore) async throws {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        // `.limited` (macOS 15+) means the user granted access to a subset
        // of contacts via the system picker; `enumerateContacts` will
        // return only that subset, which is exactly the behavior we want.
        case .authorized, .limited: return
        case .denied: throw AccessError.denied
        case .restricted: throw AccessError.restricted
        case .notDetermined:
            let granted = try await store.requestAccess(for: .contacts)
            if !granted { throw AccessError.denied }
        @unknown default:
            throw AccessError.denied
        }
    }

    // MARK: - Mapping (pure)

    /// Translates a `CNContact` to our `ParsedContact`. Visible for tests.
    static func parsed(from cnContact: CNContact) -> ParsedContact {
        var parsed = ParsedContact(
            firstName: cnContact.givenName,
            lastName: cnContact.familyName,
            company: cnContact.organizationName,
            jobTitle: cnContact.jobTitle
        )
        // CNContact.birthday is date-only DateComponents; its year is absent
        // for "no year" birthdays. Anchor to UTC (and keep the no-year case)
        // so the stored day doesn't shift with the device's time zone.
        if let birthday = cnContact.birthday, let month = birthday.month, let day = birthday.day {
            parsed.birthday = Birthday.date(year: birthday.year, month: month, day: day)
        }
        if let primary = cnContact.postalAddresses.first?.value {
            parsed.street = primary.street
            parsed.city = primary.city
            parsed.state = primary.state
            parsed.postalCode = primary.postalCode
            parsed.country = primary.country
        }
        parsed.emails = cnContact.emailAddresses.map { entry in
            (label: emailLabel(from: entry.label), value: entry.value as String)
        }
        parsed.phones = cnContact.phoneNumbers.map { entry in
            (label: phoneLabel(from: entry.label), value: entry.value.stringValue)
        }
        parsed.photoData = cnContact.imageData
        return parsed
    }

    private static func emailLabel(from raw: String?) -> FieldLabel {
        switch raw {
        case CNLabelHome: .home
        case CNLabelWork: .work
        case CNLabelOther: .other
        default: .other
        }
    }

    private static func phoneLabel(from raw: String?) -> FieldLabel {
        switch raw {
        case CNLabelPhoneNumberMobile, CNLabelPhoneNumberiPhone: .mobile
        case CNLabelPhoneNumberMain: .main
        case CNLabelHome: .home
        case CNLabelWork: .work
        case CNLabelPhoneNumberOtherFax, CNLabelOther: .other
        default: .other
        }
    }
}

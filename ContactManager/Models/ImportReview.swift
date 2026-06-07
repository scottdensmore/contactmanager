//
//  ImportReview.swift
//  ContactManager
//
//  Preflight model for contact imports. It compares parsed contacts with the
//  current store and picks a conservative default decision for each row before
//  anything is written.
//

import Foundation

enum ImportDecision: String, CaseIterable, Identifiable {
    case add
    case merge
    case updateExisting
    case skip

    var id: String { rawValue }

    var title: String {
        switch self {
        case .add: "Add"
        case .merge: "Merge"
        case .updateExisting: "Update Existing"
        case .skip: "Skip"
        }
    }
}

struct ImportReviewItem: Identifiable {
    let id = UUID()
    var parsed: ParsedContact
    var matchedContact: Contact?
    var decision: ImportDecision

    var displayName: String {
        let name = [parsed.firstName, parsed.lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if !name.isEmpty { return name }
        let company = parsed.company.trimmingCharacters(in: .whitespacesAndNewlines)
        return company.isEmpty ? "Unnamed Contact" : company
    }

    var subtitle: String? {
        if let email = parsed.emails.map(\.value).first(where: { !$0.isBlank }) { return email }
        if let phone = parsed.phones.map(\.value).first(where: { !$0.isBlank }) { return phone }
        return parsed.company.isBlank ? nil : parsed.company
    }

    var availableDecisions: [ImportDecision] {
        matchedContact == nil ? [.add, .skip] : ImportDecision.allCases
    }
}

enum ImportReview {
    static func makeItems(for parsed: [ParsedContact], existing contacts: [Contact]) -> [ImportReviewItem] {
        parsed.map { parsedContact in
            guard let match = bestMatch(for: parsedContact, in: contacts) else {
                return ImportReviewItem(parsed: parsedContact, matchedContact: nil, decision: .add)
            }
            return ImportReviewItem(
                parsed: parsedContact,
                matchedContact: match,
                decision: defaultDecision(for: parsedContact, matchedContact: match)
            )
        }
    }

    private static func bestMatch(for parsed: ParsedContact, in contacts: [Contact]) -> Contact? {
        let keys = ContactMatchKey.keys(for: parsed)
        guard !keys.isEmpty else { return nil }
        return ContactQuery.sorted(contacts).first { contact in
            !DuplicateFinder.matchKeys(for: contact).isDisjoint(with: keys)
        }
    }

    private static func defaultDecision(
        for parsed: ParsedContact,
        matchedContact contact: Contact
    ) -> ImportDecision {
        if parsed.hasNoNewData(comparedWith: contact) { return .skip }
        if parsed.canFill(contact) { return .updateExisting }
        return .merge
    }
}

extension ContactMatchKey {
    static func keys(for parsed: ParsedContact) -> Set<ContactMatchKey> {
        keys(
            firstName: parsed.firstName,
            lastName: parsed.lastName,
            emails: parsed.emails.map(\.value),
            phones: parsed.phones.map(\.value)
        )
    }
}

private extension ParsedContact {
    func hasNoNewData(comparedWith contact: Contact) -> Bool {
        canFill(contact)
            && emailValues.allSatisfy { existingEmailValues(in: contact).contains($0) }
            && phoneValues.allSatisfy { existingPhoneValues(in: contact).contains($0) }
    }

    func canFill(_ contact: Contact) -> Bool {
        scalarsAreSameOrFillBlank(comparedWith: contact)
            && birthdayCanFill(contact)
            && photoCanFill(contact)
    }

    private func scalarsAreSameOrFillBlank(comparedWith contact: Contact) -> Bool {
        scalarPairs(comparedWith: contact).allSatisfy { incoming, existing in
            incoming.isBlank || existing.isBlank || incoming.normalizedText == existing.normalizedText
        }
    }

    private func scalarPairs(comparedWith contact: Contact) -> [(String, String)] {
        [
            (firstName, contact.firstName),
            (lastName, contact.lastName),
            (company, contact.company),
            (jobTitle, contact.jobTitle),
            (street, contact.street),
            (city, contact.city),
            (state, contact.state),
            (postalCode, contact.postalCode),
            (country, contact.country),
            (notes, contact.notes),
        ]
    }

    private func birthdayCanFill(_ contact: Contact) -> Bool {
        birthday == nil || contact.birthday == nil || birthday == contact.birthday
    }

    private func photoCanFill(_ contact: Contact) -> Bool {
        photoData == nil || contact.photoData == nil || photoData == contact.photoData
    }

    private var emailValues: Set<String> {
        Set(emails.map(\.value).map(\.normalizedEmail).filter { !$0.isEmpty })
    }

    private var phoneValues: Set<String> {
        Set(phones.map(\.value).map(\.normalizedPhone).filter { $0.count >= 7 })
    }

    private func existingEmailValues(in contact: Contact) -> Set<String> {
        Set(contact.emails.map(\.value).map(\.normalizedEmail).filter { !$0.isEmpty })
    }

    private func existingPhoneValues(in contact: Contact) -> Set<String> {
        Set(contact.phones.map(\.value).map(\.normalizedPhone).filter { $0.count >= 7 })
    }
}

extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var normalizedText: String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var normalizedEmail: String {
        normalizedText
    }

    var normalizedPhone: String {
        String(filter(\.isNumber))
    }
}

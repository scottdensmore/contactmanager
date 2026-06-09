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

enum ImportMatchConfidence: String {
    case exact
    case likely
    case possible

    var title: String {
        switch self {
        case .exact: "Exact match"
        case .likely: "Likely match"
        case .possible: "Possible match"
        }
    }
}

struct ImportReviewItem: Identifiable {
    let id = UUID()
    var parsed: ParsedContact
    var matchedContact: Contact?
    var decision: ImportDecision
    var confidence: ImportMatchConfidence?
    var matchReason: String?

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
                return ImportReviewItem(
                    parsed: parsedContact,
                    matchedContact: nil,
                    decision: .add,
                    confidence: nil,
                    matchReason: nil
                )
            }
            let decision = defaultDecision(for: parsedContact, matchedContact: match.contact)
            return ImportReviewItem(
                parsed: parsedContact,
                matchedContact: match.contact,
                decision: decision,
                confidence: confidence(for: decision, sharedKeys: match.sharedKeys),
                matchReason: reason(for: match.sharedKeys)
            )
        }
    }

    private static func bestMatch(
        for parsed: ParsedContact,
        in contacts: [Contact]
    ) -> (contact: Contact, sharedKeys: Set<ContactMatchKey>)? {
        let keys = ContactMatchKey.keys(for: parsed)
        guard !keys.isEmpty else { return nil }
        for contact in ContactQuery.sorted(contacts) {
            let shared = DuplicateFinder.matchKeys(for: contact).intersection(keys)
            if !shared.isEmpty { return (contact, shared) }
        }
        return nil
    }

    private static func defaultDecision(
        for parsed: ParsedContact,
        matchedContact contact: Contact
    ) -> ImportDecision {
        if parsed.hasNoNewData(comparedWith: contact) { return .skip }
        if parsed.canFill(contact) { return .updateExisting }
        return .merge
    }

    private static func confidence(
        for decision: ImportDecision,
        sharedKeys: Set<ContactMatchKey>
    ) -> ImportMatchConfidence {
        if decision == .skip { return .exact }
        if sharedKeys.contains(where: \.isStrongMatch) { return .likely }
        return .possible
    }

    private static func reason(for sharedKeys: Set<ContactMatchKey>) -> String? {
        if sharedKeys.contains(where: \.isEmail) { return "same email" }
        if sharedKeys.contains(where: \.isPhone) { return "same phone" }
        if sharedKeys.contains(where: \.isName) { return "same full name" }
        return nil
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

extension ContactMatchKey {
    var isStrongMatch: Bool {
        isEmail || isPhone
    }

    var isEmail: Bool {
        if case .email = self { return true }
        return false
    }

    var isPhone: Bool {
        if case .phone = self { return true }
        return false
    }

    var isName: Bool {
        if case .name = self { return true }
        return false
    }
}

private extension ParsedContact {
    func hasNoNewData(comparedWith contact: Contact) -> Bool {
        scalarsAlreadyPresent(comparedWith: contact)
            && birthdayAlreadyPresent(in: contact)
            && photoAlreadyPresent(in: contact)
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

    private func scalarsAlreadyPresent(comparedWith contact: Contact) -> Bool {
        scalarPairs(comparedWith: contact).allSatisfy { incoming, existing in
            incoming.isBlank || incoming.normalizedText == existing.normalizedText
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

    private func birthdayAlreadyPresent(in contact: Contact) -> Bool {
        birthday == nil || birthday == contact.birthday
    }

    private func photoAlreadyPresent(in contact: Contact) -> Bool {
        photoData == nil || photoData == contact.photoData
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

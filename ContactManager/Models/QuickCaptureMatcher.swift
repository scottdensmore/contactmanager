//
//  QuickCaptureMatcher.swift
//  ContactManager
//
//  Duplicate awareness for Quick Capture. It shares normalized identity keys
//  with import review and duplicate finding so those flows agree on matches.
//

import Foundation

struct QuickCaptureMatch {
    var contact: Contact
    var confidence: ImportMatchConfidence
    var reason: String
}

enum QuickCaptureMatcher {
    static func bestMatch(for draft: QuickCaptureDraft, in contacts: [Contact]) -> QuickCaptureMatch? {
        guard !draft.isEmpty else { return nil }

        let draftKeys = ContactMatchKey.keys(for: draft)
        if let match = strongMatch(for: draftKeys, in: contacts) {
            return match
        }

        return nameMatch(for: draft, in: contacts)
    }

    private static func strongMatch(
        for draftKeys: Set<ContactMatchKey>,
        in contacts: [Contact]
    ) -> QuickCaptureMatch? {
        guard !draftKeys.isEmpty else { return nil }

        for contact in ContactQuery.sorted(contacts) {
            let sharedKeys = DuplicateFinder.matchKeys(for: contact).intersection(draftKeys)
            if sharedKeys.contains(where: \.isEmail) {
                return QuickCaptureMatch(contact: contact, confidence: .likely, reason: "same email")
            }
            if sharedKeys.contains(where: \.isPhone) {
                return QuickCaptureMatch(contact: contact, confidence: .likely, reason: "same phone")
            }
        }

        return nil
    }

    private static func nameMatch(for draft: QuickCaptureDraft, in contacts: [Contact]) -> QuickCaptureMatch? {
        let draftTokens = nameTokens(firstName: draft.firstName, lastName: draft.lastName)
        guard !draftTokens.isEmpty else { return nil }

        for contact in ContactQuery.sorted(contacts) {
            let contactTokens = nameTokens(firstName: contact.firstName, lastName: contact.lastName)
            if !contactTokens.isEmpty, draftTokens.isSubset(of: contactTokens) {
                return QuickCaptureMatch(contact: contact, confidence: .possible, reason: "similar name")
            }
        }

        return nil
    }

    private static func nameTokens(firstName: String, lastName: String) -> Set<String> {
        let rawName = [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return Set(
            rawName
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count >= 3 }
        )
    }
}

extension ContactMatchKey {
    static func keys(for draft: QuickCaptureDraft) -> Set<ContactMatchKey> {
        keys(
            firstName: draft.firstName,
            lastName: draft.lastName,
            emails: draft.emails.map(\.value),
            phones: draft.phones.map(\.value)
        )
    }
}

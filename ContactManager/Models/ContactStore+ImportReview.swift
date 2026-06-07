//
//  ContactStore+ImportReview.swift
//  ContactManager
//
//  Applies reviewed import decisions through ContactStore's save, undo, and
//  Spotlight-notification pipeline.
//

import Foundation

extension ContactStore {
    @discardableResult
    func applyImportReview(_ items: [ImportReviewItem]) throws -> ImportReviewResult {
        try mutate("Import Contacts") {
            var result = ImportReviewResult()
            for item in items {
                apply(item, result: &result)
            }
            return result
        }
    }

    private func apply(_ item: ImportReviewItem, result: inout ImportReviewResult) {
        switch item.decision {
        case .add:
            context.insert(Self.makeContact(from: item.parsed))
            result.added += 1
        case .skip:
            result.skipped += 1
        case .updateExisting:
            applyUpdate(item, result: &result)
        case .merge:
            applyMerge(item, result: &result)
        }
    }

    private func applyUpdate(_ item: ImportReviewItem, result: inout ImportReviewResult) {
        if let existing = item.matchedContact {
            update(existing, with: item.parsed)
            result.updated += 1
        } else {
            context.insert(Self.makeContact(from: item.parsed))
            result.added += 1
        }
    }

    private func applyMerge(_ item: ImportReviewItem, result: inout ImportReviewResult) {
        if let existing = item.matchedContact {
            merge(item.parsed, into: existing)
            result.merged += 1
        } else {
            context.insert(Self.makeContact(from: item.parsed))
            result.added += 1
        }
    }

    private func update(_ contact: Contact, with parsed: ParsedContact) {
        fillBlankScalars(of: contact, from: parsed)
        appendNewFields(from: parsed, to: contact)
        if contact.birthday == nil { contact.birthday = parsed.birthday }
        if contact.photoData == nil, let raw = parsed.photoData {
            contact.photoData = ImageProcessing.avatarData(from: raw)
        }
    }

    private func merge(_ parsed: ParsedContact, into existing: Contact) {
        let imported = Self.makeContact(from: parsed)
        context.insert(imported)
        fillEmptyFields(of: existing, from: imported)
        mergeFields(into: existing, from: [imported])
        context.delete(imported)
    }

    private func fillBlankScalars(of contact: Contact, from parsed: ParsedContact) {
        if contact.firstName.isBlank { contact.firstName = parsed.firstName }
        if contact.lastName.isBlank { contact.lastName = parsed.lastName }
        if contact.company.isBlank { contact.company = parsed.company }
        if contact.jobTitle.isBlank { contact.jobTitle = parsed.jobTitle }
        if contact.street.isBlank { contact.street = parsed.street }
        if contact.city.isBlank { contact.city = parsed.city }
        if contact.state.isBlank { contact.state = parsed.state }
        if contact.postalCode.isBlank { contact.postalCode = parsed.postalCode }
        if contact.country.isBlank { contact.country = parsed.country }
        if contact.notes.isBlank { contact.notes = parsed.notes }
    }

    private func appendNewFields(from parsed: ParsedContact, to contact: Contact) {
        appendNewFields(
            parsed.emails, kind: .email,
            existingValues: Set(contact.emails.map(\.value).map(\.normalizedEmail)),
            to: contact
        )
        appendNewFields(
            parsed.phones, kind: .phone,
            existingValues: Set(contact.phones.map(\.value).map(\.normalizedPhone)),
            to: contact
        )
    }

    private func appendNewFields(
        _ fields: [(label: FieldLabel, value: String)],
        kind: FieldKind,
        existingValues: Set<String>,
        to contact: Contact
    ) {
        var seen = existingValues
        var nextIndex = (contact.fields(of: kind).map(\.sortIndex).max() ?? -1) + 1
        for parsedField in fields {
            let normalized = kind == .email
                ? parsedField.value.normalizedEmail
                : parsedField.value.normalizedPhone
            guard !normalized.isEmpty, !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            insertField(parsedField, kind: kind, sortIndex: nextIndex, into: contact)
            nextIndex += 1
        }
    }

    private func insertField(
        _ parsedField: (label: FieldLabel, value: String),
        kind: FieldKind,
        sortIndex: Int,
        into contact: Contact
    ) {
        let field = ContactField(
            kind: kind,
            label: parsedField.label,
            value: parsedField.value,
            sortIndex: sortIndex
        )
        field.contact = contact
        context.insert(field)
    }
}

struct ImportReviewResult {
    var added = 0
    var updated = 0
    var merged = 0
    var skipped = 0

    var totalWritten: Int { added + updated + merged }
}

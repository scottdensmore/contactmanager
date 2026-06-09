//
//  ContactStore+QuickCapture.swift
//  ContactManager
//
//  Writes quick-entry drafts through the same save, undo, rollback, and
//  Spotlight-notification pipeline as the rest of ContactStore.
//

import Foundation
import SwiftData

extension ContactStore {
    @discardableResult
    func createContact(from draft: QuickCaptureDraft) throws -> Contact {
        try mutate("Quick Capture") {
            let groups = try groups(named: draft.groups)
            let tags = try tags(named: draft.tags)
            let contact = Contact(
                firstName: draft.firstName,
                lastName: draft.lastName,
                company: draft.company,
                jobTitle: draft.jobTitle,
                birthday: draft.birthday,
                notes: draft.notes
            )
            contact.groups = groups
            contact.tags = tags
            context.insert(contact)
            insert(draft.emails, kind: .email, into: contact)
            insert(draft.phones, kind: .phone, into: contact)
            return contact
        }
    }

    func updateContact(_ contact: Contact, from draft: QuickCaptureDraft) throws {
        try mutate("Quick Capture Update") {
            fillEmptyScalars(of: contact, from: draft)
            try adoptGroups(named: draft.groups, into: contact)
            try adoptTags(named: draft.tags, into: contact)
            insertMissing(draft.emails, kind: .email, into: contact)
            insertMissing(draft.phones, kind: .phone, into: contact)
        }
    }

    private func fillEmptyScalars(of contact: Contact, from draft: QuickCaptureDraft) {
        if contact.firstName.isBlank { contact.firstName = draft.firstName }
        if contact.lastName.isBlank { contact.lastName = draft.lastName }
        if contact.company.isBlank { contact.company = draft.company }
        if contact.jobTitle.isBlank { contact.jobTitle = draft.jobTitle }
        if contact.notes.isBlank { contact.notes = draft.notes }
        if contact.birthday == nil { contact.birthday = draft.birthday }
    }

    private func insert(
        _ fields: [(label: FieldLabel, value: String)],
        kind: FieldKind,
        into contact: Contact
    ) {
        for (index, field) in fields.enumerated() where !field.value.isBlank {
            let model = ContactField(
                kind: kind,
                label: field.label,
                value: field.value,
                sortIndex: index
            )
            model.contact = contact
            context.insert(model)
        }
    }

    private func insertMissing(
        _ fields: [(label: FieldLabel, value: String)],
        kind: FieldKind,
        into contact: Contact
    ) {
        var existing = Set(contact.fields(of: kind).map { normalized($0.value, kind: kind) })
        var nextIndex = (contact.fields(of: kind).map(\.sortIndex).max() ?? -1) + 1

        for field in fields where !field.value.isBlank {
            let normalizedValue = normalized(field.value, kind: kind)
            guard !normalizedValue.isEmpty, existing.insert(normalizedValue).inserted else { continue }

            let model = ContactField(
                kind: kind,
                label: field.label,
                value: field.value,
                sortIndex: nextIndex
            )
            nextIndex += 1
            model.contact = contact
            context.insert(model)
        }
    }

    private func adoptGroups(named names: [String], into contact: Contact) throws {
        var existingIDs = Set(contact.groups.map(\.persistentModelID))
        for group in try groups(named: names) where existingIDs.insert(group.persistentModelID).inserted {
            contact.groups.append(group)
        }
    }

    private func adoptTags(named names: [String], into contact: Contact) throws {
        var existingIDs = Set(contact.tags.map(\.persistentModelID))
        for tag in try tags(named: names) where existingIDs.insert(tag.persistentModelID).inserted {
            contact.tags.append(tag)
        }
    }

    private func normalized(_ value: String, kind: FieldKind) -> String {
        switch kind {
        case .email:
            value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        case .phone:
            String(value.filter(\.isNumber))
        }
    }

    private func groups(named names: [String]) throws -> [ContactGroup] {
        var existing = try context.fetch(FetchDescriptor<ContactGroup>())
        return uniqueNames(names).compactMap { name in
            namedModel(
                name,
                existing: &existing,
                displayName: \.displayName
            ) { ContactGroup(name: $0) }
        }
    }

    private func tags(named names: [String]) throws -> [ContactTag] {
        var existing = try context.fetch(FetchDescriptor<ContactTag>())
        return uniqueNames(names).compactMap { name in
            namedModel(
                name,
                existing: &existing,
                displayName: \.displayName
            ) { ContactTag(name: $0) }
        }
    }

    private func uniqueNames(_ names: [String]) -> [String] {
        var seen: Set<String> = []
        return names.compactMap { name in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let normalized = trimmed.lowercased()
            guard seen.insert(normalized).inserted else { return nil }
            return trimmed
        }
    }

    private func namedModel<Model: PersistentModel>(
        _ name: String,
        existing: inout [Model],
        displayName: KeyPath<Model, String>,
        create: (String) -> Model
    ) -> Model? {
        let normalized = name.lowercased()
        if let match = existing.first(where: { $0[keyPath: displayName].lowercased() == normalized }) {
            return match
        }
        let model = create(name)
        existing.append(model)
        context.insert(model)
        return model
    }
}

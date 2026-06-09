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

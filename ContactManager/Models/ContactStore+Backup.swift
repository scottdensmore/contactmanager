//
//  ContactStore+Backup.swift
//  ContactManager
//
//  Additive restore support for ContactManager backup snapshots.
//

import Foundation

extension ContactStore {
    @discardableResult
    func restoreBackup(_ backup: ContactBackup) throws -> BackupRestoreResult {
        try mutate("Restore Backup") {
            var result = BackupRestoreResult()
            var restoredGroups: [String: ContactGroup] = [:]
            var restoredTags: [String: ContactTag] = [:]

            for record in backup.groups {
                let group = ContactGroup(name: record.name, createdAt: record.createdAt)
                context.insert(group)
                restoredGroups[record.id] = group
                result.groupsRestored += 1
            }

            for record in backup.tags {
                let tag = ContactTag(name: record.name, createdAt: record.createdAt)
                context.insert(tag)
                restoredTags[record.id] = tag
                result.tagsRestored += 1
            }

            for record in backup.savedSmartLists {
                let savedList = ContactSavedSmartList(
                    name: record.name,
                    query: record.query,
                    createdAt: record.createdAt
                )
                context.insert(savedList)
                result.savedSmartListsRestored += 1
            }

            for record in backup.contacts {
                let contact = Contact(record)
                contact.photoData = record.photoData
                contact.groups = record.groupIDs.compactMap { restoredGroups[$0] }
                contact.tags = record.tagIDs.compactMap { restoredTags[$0] }
                context.insert(contact)
                restoreFields(record.fields, to: contact)
                restoreInteractions(record.interactions, to: contact)
                result.contactsRestored += 1
                result.interactionsRestored += record.interactions.count
            }

            return result
        }
    }

    private func restoreFields(_ records: [ContactBackup.FieldRecord], to contact: Contact) {
        for record in records {
            let field = ContactField(
                kind: record.kind,
                label: record.label,
                value: record.value,
                sortIndex: record.sortIndex
            )
            field.contact = contact
            context.insert(field)
        }
    }

    private func restoreInteractions(_ records: [ContactBackup.InteractionRecord], to contact: Contact) {
        for record in records {
            let interaction = ContactInteraction(kind: record.kind, summary: record.summary, date: record.date)
            interaction.contact = contact
            context.insert(interaction)
        }
    }
}

private extension Contact {
    convenience init(_ record: ContactBackup.ContactRecord) {
        self.init(
            firstName: record.firstName,
            lastName: record.lastName,
            company: record.company,
            jobTitle: record.jobTitle,
            street: record.street,
            city: record.city,
            state: record.state,
            postalCode: record.postalCode,
            country: record.country,
            birthday: record.birthday,
            lastContactedAt: record.lastContactedAt,
            notes: record.notes,
            createdAt: record.createdAt
        )
    }
}

struct BackupRestoreResult {
    var contactsRestored = 0
    var groupsRestored = 0
    var tagsRestored = 0
    var savedSmartListsRestored = 0
    var interactionsRestored = 0

    var title: String {
        if contactsRestored == 1 { return "Restored 1 Contact" }
        return "Restored \(contactsRestored) Contacts"
    }

    var message: String {
        let parts = [
            count(contactsRestored, label: "contacts"),
            count(groupsRestored, label: "groups"),
            count(tagsRestored, label: "tags"),
            count(savedSmartListsRestored, label: "smart lists"),
            count(interactionsRestored, label: "history notes"),
        ].compactMap(\.self)
        if parts.isEmpty {
            return "No contacts, groups, tags, smart lists, or history notes restored."
        }
        return parts.joined(separator: ", ").capitalizedIfFirst + "."
    }

    private func count(_ value: Int, label: String) -> String? {
        value == 0 ? nil : "\(value) \(label)"
    }
}

private extension String {
    var capitalizedIfFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}

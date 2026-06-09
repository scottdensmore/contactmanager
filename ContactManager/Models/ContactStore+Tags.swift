//
//  ContactStore+Tags.swift
//  ContactManager
//
//  Durable mutations for contact tags and tag membership.
//

import Foundation
import SwiftData

extension ContactStore {
    @discardableResult
    func createTag(named name: String = "New Tag") throws -> ContactTag {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return try mutate("New Tag") {
            let tag = ContactTag(name: trimmed.isEmpty ? "New Tag" : trimmed)
            context.insert(tag)
            return tag
        }
    }

    func rename(_ tag: ContactTag, to name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try mutate("Rename Tag") {
            tag.name = trimmed
        }
    }

    func delete(_ tag: ContactTag) throws {
        try mutate("Delete Tag") {
            context.delete(tag)
        }
    }

    func setMembership(of contact: Contact, in tag: ContactTag, isMember: Bool) throws {
        let alreadyMember = contact.tags.contains { $0.persistentModelID == tag.persistentModelID }
        guard isMember != alreadyMember else { return }

        try mutate("Change Tag Membership") {
            if isMember {
                contact.tags.append(tag)
            } else {
                contact.tags.removeAll { $0.persistentModelID == tag.persistentModelID }
            }
        }
    }

    @discardableResult
    func addContacts(_ contacts: [Contact], to tag: ContactTag) throws -> Int {
        let tagID = tag.persistentModelID
        let toAdd = contacts.filter { contact in
            !contact.tags.contains { $0.persistentModelID == tagID }
        }
        guard !toAdd.isEmpty else { return 0 }
        return try mutate("Add to Tag") {
            toAdd.forEach { $0.tags.append(tag) }
            return toAdd.count
        }
    }

    func adoptTags(into primary: Contact, from other: Contact) {
        let existing = Set(primary.tags.map(\.persistentModelID))
        for tag in other.tags where !existing.contains(tag.persistentModelID) {
            primary.tags.append(tag)
        }
    }

    /// Adds the contacts named by their encoded `PersistentIdentifier`s to
    /// `tag` — the data path behind dragging contacts onto a sidebar tag.
    /// Invalid ids and contacts already carrying the tag are skipped.
    @discardableResult
    func addContacts(withEncodedIDs ids: [String], to tag: ContactTag) throws -> Int {
        let wanted = Set(ids.filter { PersistentIdentifier.decode(stored: $0) != nil })
        guard !wanted.isEmpty else { return 0 }
        let tagID = tag.persistentModelID
        let toAdd = try context.fetch(FetchDescriptor<Contact>()).filter { contact in
            guard let encoded = contact.persistentModelID.storedString else { return false }
            return wanted.contains(encoded)
                && !contact.tags.contains { $0.persistentModelID == tagID }
        }
        guard !toAdd.isEmpty else { return 0 }
        return try mutate("Add to Tag") {
            toAdd.forEach { $0.tags.append(tag) }
            return toAdd.count
        }
    }
}

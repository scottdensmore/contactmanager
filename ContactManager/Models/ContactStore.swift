//
//  ContactStore.swift
//  ContactManager
//
//  The data layer for the contact manager: every create/edit/delete,
//  group, and vCard operation goes through here so the views stay thin and
//  the logic is unit-testable against an in-memory ModelContext.
//
//  Each mutating operation saves and, on failure, rolls back so the context
//  is left consistent and the caller can surface the thrown error.
//

import Foundation
import SwiftData

@MainActor
struct ContactStore {
    let context: ModelContext

    init(_ context: ModelContext) {
        self.context = context
    }

    // MARK: - Contacts

    /// Creates an empty contact, optionally adding it to a group.
    @discardableResult
    func createContact(in group: ContactGroup? = nil) throws -> Contact {
        let contact = Contact()
        if let group {
            contact.groups = [group]
        }
        context.insert(contact)
        try saveOrRollback()
        return contact
    }

    func delete(_ contact: Contact) throws {
        context.delete(contact)
        try saveOrRollback()
    }

    func setPhotoData(_ data: Data?, on contact: Contact) throws {
        contact.photoData = data
        try saveOrRollback()
    }

    // MARK: - Fields (emails / phones)

    /// Adds a labeled field, keeping `sortIndex` strictly increasing so order
    /// is stable even after deletions.
    @discardableResult
    func addField(_ kind: FieldKind, value: String = "", to contact: Contact) throws -> ContactField {
        let nextIndex = (contact.fields(of: kind).map(\.sortIndex).max() ?? -1) + 1
        let field = ContactField(kind: kind, label: kind.defaultLabel, value: value, sortIndex: nextIndex)
        field.contact = contact
        context.insert(field)
        try saveOrRollback()
        return field
    }

    func delete(_ fields: [ContactField]) throws {
        fields.forEach(context.delete)
        try saveOrRollback()
    }

    // MARK: - Groups

    @discardableResult
    func createGroup(named name: String = "New Group") throws -> ContactGroup {
        let group = ContactGroup(name: name)
        context.insert(group)
        try saveOrRollback()
        return group
    }

    /// Renames a group, ignoring blank names.
    func rename(_ group: ContactGroup, to name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        group.name = trimmed
        try saveOrRollback()
    }

    func delete(_ group: ContactGroup) throws {
        context.delete(group)
        try saveOrRollback()
    }

    func setMembership(of contact: Contact, in group: ContactGroup, isMember: Bool) throws {
        let alreadyMember = contact.groups.contains { $0.persistentModelID == group.persistentModelID }
        if isMember, !alreadyMember {
            contact.groups.append(group)
        } else if !isMember {
            contact.groups.removeAll { $0.persistentModelID == group.persistentModelID }
        }
        try saveOrRollback()
    }

    // MARK: - vCard import / export

    /// Parses a vCard document and inserts the contacts it describes.
    @discardableResult
    func importVCards(from text: String) throws -> [Contact] {
        try importContacts(VCard.parse(text))
    }

    /// Inserts contacts built from already-parsed vCards. (Parsing can be done
    /// off the main actor by the caller; insertion happens here.)
    @discardableResult
    func importContacts(_ parsed: [ParsedContact]) throws -> [Contact] {
        let contacts = parsed.map(Self.makeContact(from:))
        contacts.forEach(context.insert)
        try saveOrRollback()
        return contacts
    }

    /// Serializes contacts to a vCard document, sorted for stable output.
    func exportVCards(_ contacts: [Contact]) -> String {
        VCard.makeDocument(from: ContactQuery.sorted(contacts))
    }

    /// Maps a parsed vCard into a new (uninserted) `Contact` with its fields.
    static func makeContact(from parsed: ParsedContact) -> Contact {
        let contact = Contact(
            firstName: parsed.firstName, lastName: parsed.lastName,
            company: parsed.company, jobTitle: parsed.jobTitle,
            street: parsed.street, city: parsed.city, state: parsed.state,
            postalCode: parsed.postalCode, country: parsed.country,
            birthday: parsed.birthday, notes: parsed.notes
        )
        let emails = parsed.emails.enumerated().map { index, email in
            ContactField(kind: .email, label: email.label, value: email.value, sortIndex: index)
        }
        let phones = parsed.phones.enumerated().map { index, phone in
            ContactField(kind: .phone, label: phone.label, value: phone.value, sortIndex: index)
        }
        contact.fields = emails + phones
        return contact
    }

    // MARK: - Saving

    private func saveOrRollback() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}

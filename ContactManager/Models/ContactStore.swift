//
//  ContactStore.swift
//  ContactManager
//
//  The data layer for the contact manager: every create/edit/delete,
//  group, and vCard operation goes through here so the views stay thin and
//  the logic is unit-testable against an in-memory ModelContext.
//
//  Each mutating operation runs inside an explicit undo group, saves, and
//  rolls back on failure. The group's action name shows up in the Edit menu
//  (e.g. "Undo Create Contact") when the context has an UndoManager attached.
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
        try mutate("Create Contact") {
            let contact = Contact()
            if let group { contact.groups = [group] }
            context.insert(contact)
            return contact
        }
    }

    func delete(_ contact: Contact) throws {
        try mutate("Delete Contact") {
            context.delete(contact)
        }
    }

    func setPhotoData(_ data: Data?, on contact: Contact) throws {
        try mutate("Change Photo") {
            contact.photoData = data
        }
    }

    func markContacted(_ contact: Contact, at date: Date = .now) throws {
        try mutate("Mark Contacted") {
            contact.lastContactedAt = date
        }
    }

    // MARK: - Fields (emails / phones)

    /// Adds a labeled field, keeping `sortIndex` strictly increasing so order
    /// is stable even after deletions.
    @discardableResult
    func addField(_ kind: FieldKind, value: String = "", to contact: Contact) throws -> ContactField {
        try mutate(kind == .email ? "Add Email" : "Add Phone") {
            let nextIndex = (contact.fields(of: kind).map(\.sortIndex).max() ?? -1) + 1
            let field = ContactField(kind: kind, label: kind.defaultLabel, value: value, sortIndex: nextIndex)
            field.contact = contact
            context.insert(field)
            return field
        }
    }

    func delete(_ fields: [ContactField]) throws {
        try mutate("Delete Field") {
            fields.forEach(context.delete)
        }
    }

    // MARK: - Groups

    @discardableResult
    func createGroup(named name: String = "New Group") throws -> ContactGroup {
        try mutate("New Group") {
            let group = ContactGroup(name: name)
            context.insert(group)
            return group
        }
    }

    /// Renames a group, ignoring blank names.
    func rename(_ group: ContactGroup, to name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        try mutate("Rename Group") {
            group.name = trimmed
        }
    }

    func delete(_ group: ContactGroup) throws {
        try mutate("Delete Group") {
            context.delete(group)
        }
    }

    func setMembership(of contact: Contact, in group: ContactGroup, isMember: Bool) throws {
        let alreadyMember = contact.groups.contains { $0.persistentModelID == group.persistentModelID }
        guard isMember != alreadyMember else { return } // no-op; avoid an unnecessary save

        try mutate("Change Group Membership") {
            if isMember {
                contact.groups.append(group)
            } else {
                contact.groups.removeAll { $0.persistentModelID == group.persistentModelID }
            }
        }
    }

    /// Adds the contacts named by their encoded `PersistentIdentifier`s to
    /// `group` — the data path behind dragging contacts onto a sidebar group.
    /// Ids that don't resolve and contacts already in the group are skipped;
    /// returns how many were actually added (0 means no save/undo step).
    @discardableResult
    func addContacts(withEncodedIDs ids: [String], to group: ContactGroup) throws -> Int {
        // Keep only well-formed encoded ids; unrelated text (an empty string, a
        // stray drop) decodes to nothing and short-circuits the fetch. We match
        // on the canonical encoded string rather than `PersistentIdentifier`
        // equality, which doesn't hold for a decoded-vs-live persisted id.
        let wanted = Set(ids.filter { PersistentIdentifier.decode(stored: $0) != nil })
        guard !wanted.isEmpty else { return 0 }
        let groupID = group.persistentModelID
        let toAdd = try context.fetch(FetchDescriptor<Contact>()).filter { contact in
            guard let encoded = contact.persistentModelID.storedString else { return false }
            return wanted.contains(encoded)
                && !contact.groups.contains { $0.persistentModelID == groupID }
        }
        guard !toAdd.isEmpty else { return 0 }
        return try mutate("Add to Group") {
            toAdd.forEach { $0.groups.append(group) }
            return toAdd.count
        }
    }

    // MARK: - Merge duplicates

    /// Merges several contacts into one canonical contact (the earliest
    /// created), then deletes the rest. Empty fields on the canonical contact
    /// are filled from the others, emails/phones are unioned and de-duplicated,
    /// group memberships are unioned, and a missing photo is adopted.
    @discardableResult
    func merge(_ contacts: [Contact]) throws -> Contact {
        // Earliest created wins, with a stable tiebreaker so the choice is
        // deterministic even when timestamps are identical.
        let ordered = contacts.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return String(describing: lhs.persistentModelID) < String(describing: rhs.persistentModelID)
        }
        guard let primary = ordered.first else {
            throw ContactStoreError.nothingToMerge
        }
        let others = ordered.dropFirst()
        guard !others.isEmpty else { return primary }

        return try mutate("Merge Contacts") {
            for other in others {
                fillEmptyFields(of: primary, from: other)
                adoptGroups(into: primary, from: other)
            }
            mergeFields(into: primary, from: Array(others))
            others.forEach(context.delete)
            return primary
        }
    }

    func fillEmptyFields(of primary: Contact, from other: Contact) {
        /// Treat whitespace-only values as empty, consistent with the rest of
        /// the codebase (Contact.fullName, primaryEmail, etc.).
        func isBlank(_ value: String) -> Bool {
            value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if isBlank(primary.firstName) { primary.firstName = other.firstName }
        if isBlank(primary.lastName) { primary.lastName = other.lastName }
        if isBlank(primary.company) { primary.company = other.company }
        if isBlank(primary.jobTitle) { primary.jobTitle = other.jobTitle }
        if isBlank(primary.street) { primary.street = other.street }
        if isBlank(primary.city) { primary.city = other.city }
        if isBlank(primary.state) { primary.state = other.state }
        if isBlank(primary.postalCode) { primary.postalCode = other.postalCode }
        if isBlank(primary.country) { primary.country = other.country }
        if isBlank(primary.notes) { primary.notes = other.notes }
        if primary.birthday == nil { primary.birthday = other.birthday }
        if primary.photoData == nil { primary.photoData = other.photoData }
    }

    private func adoptGroups(into primary: Contact, from other: Contact) {
        let existing = Set(primary.groups.map(\.persistentModelID))
        for group in other.groups where !existing.contains(group.persistentModelID) {
            primary.groups.append(group)
        }
    }

    /// Reassigns every contact's email/phone fields to `primary`, dropping
    /// blanks and value-duplicates and reindexing for a stable order.
    func mergeFields(into primary: Contact, from others: [Contact]) {
        for kind in FieldKind.allCases {
            let candidates = primary.fields(of: kind) + others.flatMap { $0.fields(of: kind) }
            var seenValues: Set<String> = []
            var keptIndex = 0
            for field in candidates {
                let normalized = normalizedValue(of: field)
                if normalized.isEmpty || seenValues.contains(normalized) {
                    context.delete(field)
                    continue
                }
                seenValues.insert(normalized)
                field.contact = primary
                field.sortIndex = keptIndex
                keptIndex += 1
            }
        }
    }

    private func normalizedValue(of field: ContactField) -> String {
        switch field.kind {
        case .email:
            field.value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        case .phone:
            String(field.value.filter(\.isNumber))
        }
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
        try mutate("Import Contacts") {
            let contacts = parsed.map(Self.makeContact(from:))
            contacts.forEach(context.insert)
            return contacts
        }
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
        // Normalize an imported photo through the avatar pipeline so storage
        // stays consistent (downscaled JPEG); an undecodable photo is dropped.
        if let raw = parsed.photoData {
            contact.photoData = ImageProcessing.avatarData(from: raw)
        }
        let emails = parsed.emails.enumerated().map { index, email in
            ContactField(kind: .email, label: email.label, value: email.value, sortIndex: index)
        }
        let phones = parsed.phones.enumerated().map { index, phone in
            ContactField(kind: .phone, label: phone.label, value: phone.value, sortIndex: index)
        }
        contact.fields = emails + phones
        return contact
    }

    // MARK: - Saving + undo

    /// Wraps `body` in an explicit undo group, saves the context, and rolls
    /// back on failure. The group is given `actionName` so the Edit menu shows
    /// e.g. "Undo Create Contact".
    @discardableResult
    func mutate<Result>(_ actionName: String, _ body: () throws -> Result) throws -> Result {
        let undoManager = context.undoManager
        undoManager?.beginUndoGrouping()
        do {
            let result = try body()
            let pending = pendingContactChange()

            try context.save()
            undoManager?.endUndoGrouping()
            undoManager?.setActionName(actionName)
            post(pending.contactChange())
            return result
        } catch {
            context.rollback()
            undoManager?.endUndoGrouping()
            throw error
        }
    }

    /// Maps a touched model to the contact whose Spotlight entry it affects: a
    /// `Contact` directly, or a `ContactField` via its owner. Other models
    /// (e.g. `ContactGroup`) don't appear in the index and map to `nil`.
    static func affectedContactID(of model: any PersistentModel) -> String? {
        switch model {
        case let contact as Contact:
            contact.persistentModelID.storedString
        case let field as ContactField:
            field.contact?.persistentModelID.storedString
        default:
            nil
        }
    }

    func pendingContactChange() -> PendingContactChange {
        // Snapshot the context's pending changes *before* the save clears
        // them, so the notification can carry a precise delta and the
        // Spotlight index updates incrementally rather than rebuilding the
        // whole thing on every edit.
        let touched = context.insertedModelsArray + context.changedModelsArray
        let deletedModels = context.deletedModelsArray
        // Deleted contacts already hold permanent ids (they were saved
        // before), so read them now — after the save the objects are gone.
        let deletedIDs = Set(
            deletedModels.compactMap { ($0 as? Contact)?.persistentModelID.storedString }
        )
        // A field can be deleted while its owning contact survives (Delete
        // Field, or merge folding duplicates). Capture those owners now,
        // while the inverse relationship is still intact, so the contact's
        // emails/phones get refreshed.
        let survivingFieldOwnerIDs = Set(
            deletedModels.compactMap { ($0 as? ContactField)?.contact?.persistentModelID.storedString }
        )

        return PendingContactChange(
            touched: touched,
            survivingFieldOwnerIDs: survivingFieldOwnerIDs,
            deletedIDs: deletedIDs
        )
    }

    func post(_ change: ContactChange) {
        // Observed by ContentView to refresh the Spotlight index. Fired
        // after the save commits so observers see the post-mutation state,
        // and carries the delta so the refresh stays incremental.
        NotificationCenter.default.post(
            name: .contactsDidChange,
            object: nil,
            userInfo: [ContactChange.userInfoKey: change]
        )
    }
}

/// The set of contacts a `ContactStore` mutation touched, delivered in the
/// `.contactsDidChange` notification so observers (the Spotlight indexer) can
/// update incrementally. Ids are encoded `PersistentIdentifier`s — the same
/// scheme `ContactEntity.id` uses, so they round-trip through a fetch-by-id.
struct ContactChange {
    /// Contacts created or edited — their Spotlight entry needs refreshing.
    var updatedIDs: Set<String>
    /// Contacts deleted — their Spotlight entry must be removed.
    var deletedIDs: Set<String>

    /// True when the mutation touched no indexable contact (e.g. renaming a
    /// group), letting observers skip work entirely.
    var isEmpty: Bool { updatedIDs.isEmpty && deletedIDs.isEmpty }

    /// `userInfo` key the change rides under in `.contactsDidChange`.
    static let userInfoKey = "ContactManager.contactChange"
}

@MainActor
struct PendingContactChange {
    var touched: [any PersistentModel]
    var survivingFieldOwnerIDs: Set<String>
    var deletedIDs: Set<String>

    func contactChange() -> ContactChange {
        // Read updated ids *after* the save: a freshly inserted contact's
        // pre-save id is temporary and wouldn't match a later fetch-by-id;
        // the save promotes it to the permanent identifier in place.
        var updatedIDs = Set(touched.compactMap { ContactStore.affectedContactID(of: $0) })
        updatedIDs.formUnion(survivingFieldOwnerIDs)
        updatedIDs.subtract(deletedIDs) // never re-index a contact we just deleted
        return ContactChange(updatedIDs: updatedIDs, deletedIDs: deletedIDs)
    }
}

enum ContactStoreError: LocalizedError {
    case nothingToMerge

    var errorDescription: String? {
        switch self {
        case .nothingToMerge: "There were no contacts to merge."
        }
    }
}

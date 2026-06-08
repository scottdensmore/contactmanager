//
//  ContactStore+QuickCapture.swift
//  ContactManager
//
//  Writes quick-entry drafts through the same save, undo, rollback, and
//  Spotlight-notification pipeline as the rest of ContactStore.
//

extension ContactStore {
    @discardableResult
    func createContact(from draft: QuickCaptureDraft) throws -> Contact {
        try mutate("Quick Capture") {
            let contact = Contact(
                firstName: draft.firstName,
                lastName: draft.lastName,
                company: draft.company,
                jobTitle: draft.jobTitle,
                birthday: draft.birthday,
                notes: draft.notes
            )
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
}

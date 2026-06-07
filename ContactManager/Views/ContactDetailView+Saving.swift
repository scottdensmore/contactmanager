//
//  ContactDetailView+Saving.swift
//  ContactManager
//
//  Debounced save support for direct SwiftData form bindings.
//

import Foundation

enum ContactEditFingerprint {
    static func make(for contact: Contact) -> String {
        let fields = contact.fields
            .sorted { lhs, rhs in
                if lhs.kind != rhs.kind { return lhs.kind.rawValue < rhs.kind.rawValue }
                return lhs.sortIndex < rhs.sortIndex
            }
            .map { field in
                [
                    field.kind.rawValue,
                    field.label.rawValue,
                    field.value,
                    String(field.sortIndex),
                ].joined(separator: "\u{1F}")
            }
            .joined(separator: "\u{1E}")
        let birthday = contact.birthday.map { String($0.timeIntervalSinceReferenceDate) } ?? ""
        return [
            contact.firstName,
            contact.lastName,
            contact.company,
            contact.jobTitle,
            contact.street,
            contact.city,
            contact.state,
            contact.postalCode,
            contact.country,
            birthday,
            contact.notes,
            fields,
        ].joined(separator: "\u{1D}")
    }
}

extension ContactDetailView {
    func flushPendingEdits() {
        guard editFingerprint != lastSavedFingerprint else { return }
        do {
            try store.savePendingEdits(actionName: "Edit Contact")
            lastSavedFingerprint = editFingerprint
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

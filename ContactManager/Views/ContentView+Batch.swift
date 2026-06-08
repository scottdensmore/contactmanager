//
//  ContentView+Batch.swift
//  ContactManager
//
//  Batch contact actions split out of ContentView's main body.
//

import SwiftUI

extension ContentView {
    func requestDeleteSelectedContacts() {
        let selected = selectedContacts
        guard !selected.isEmpty else { return }
        if selected.count == 1, let contact = selected.first {
            deleteContact(contact)
        } else {
            isConfirmingBatchDelete = true
        }
    }

    func confirmDeleteSelectedContacts() {
        let selected = selectedContacts
        guard !selected.isEmpty else { return }
        do {
            try store.delete(selected)
            selectedContactIDs.subtract(selected.map(\.persistentModelID))
            if shouldClearDetail(afterDeleting: selected) {
                selectedContact = nil
            }
            isConfirmingBatchDelete = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addSelectedContacts(to group: ContactGroup) {
        do {
            _ = try store.addContacts(selectedContacts, to: group)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func shouldClearDetail(afterDeleting deleted: [Contact]) -> Bool {
        guard let selectedContact else { return false }
        return deleted.contains { contact in
            contact.persistentModelID == selectedContact.persistentModelID
        }
    }
}

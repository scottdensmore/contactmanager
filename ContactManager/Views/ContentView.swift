//
//  ContentView.swift
//  ContactManager
//
//  Three-column NavigationSplitView shell: sidebar (groups) / contact list /
//  detail. Owns selection and the create/delete actions.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Contact.lastName), SortDescriptor(\Contact.firstName)])
    private var contacts: [Contact]

    @State private var sidebarSelection: SidebarItem? = .allContacts
    @State private var selectedContact: Contact?
    @State private var errorMessage: String?

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $sidebarSelection, contactCount: contacts.count)
        } content: {
            ContactListView(
                contacts: contacts,
                selection: $selectedContact,
                addContact: addContact,
                deleteContact: deleteContact
            )
        } detail: {
            if let selectedContact {
                ContactDetailView(contact: selectedContact)
                    .id(selectedContact.persistentModelID)
            } else {
                ContactPlaceholderView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newContactRequested)) { _ in
            addContact()
        }
        .alert(
            "Couldn't Save Changes",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }),
            presenting: errorMessage
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    // MARK: - Actions

    private func addContact() {
        let contact = Contact()
        context.insert(contact)
        do {
            try context.save()
            selectedContact = contact
        } catch {
            // Roll back the insert so the UI doesn't show a contact that
            // wasn't actually persisted.
            context.delete(contact)
            errorMessage = error.localizedDescription
        }
    }

    private func deleteContact(_ contact: Contact) {
        let wasSelected = selectedContact?.persistentModelID == contact.persistentModelID
        context.delete(contact)
        do {
            try context.save()
            if wasSelected { selectedContact = nil }
        } catch {
            // Keep the contact (and selection) if the delete didn't persist.
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Contact.self, inMemory: true)
}

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
    }

    // MARK: - Actions

    private func addContact() {
        let contact = Contact()
        context.insert(contact)
        try? context.save()
        selectedContact = contact
    }

    private func deleteContact(_ contact: Contact) {
        if selectedContact?.persistentModelID == contact.persistentModelID {
            selectedContact = nil
        }
        context.delete(contact)
        try? context.save()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Contact.self, inMemory: true)
}

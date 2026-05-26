//
//  ContactListView.swift
//  ContactManager
//
//  Middle column: the selectable list of contacts plus the add/delete
//  toolbar affordances.
//

import SwiftUI

struct ContactListView: View {
    let contacts: [Contact]
    @Binding var selection: Contact?
    var addContact: () -> Void
    var deleteContact: (Contact) -> Void

    var body: some View {
        List(selection: $selection) {
            ForEach(contacts) { contact in
                ContactRow(contact: contact)
                    .tag(contact)
            }
        }
        .navigationTitle("Contacts")
        .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 420)
        .overlay {
            if contacts.isEmpty {
                ContentUnavailableView(
                    "No Contacts",
                    systemImage: "person.crop.circle.badge.plus",
                    description: Text("Add a contact to get started.")
                )
            }
        }
        .onDeleteCommand {
            if let selection { deleteContact(selection) }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: addContact) {
                    Label("New Contact", systemImage: "plus")
                }
                .help("New Contact")
            }
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    if let selection { deleteContact(selection) }
                } label: {
                    Label("Delete Contact", systemImage: "trash")
                }
                .help("Delete Contact")
                .disabled(selection == nil)
            }
        }
    }
}

struct ContactRow: View {
    let contact: Contact

    var body: some View {
        HStack(spacing: 10) {
            AvatarView(contact: contact, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(contact.fullName)
                    .lineLimit(1)
                if !contact.emailAddress.isEmpty {
                    Text(contact.emailAddress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

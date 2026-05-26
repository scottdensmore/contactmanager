//
//  ContactListView.swift
//  ContactManager
//
//  Middle column: a searchable, alphabetically sectioned list of contacts
//  plus the sort and add/delete toolbar affordances.
//

import SwiftUI

struct ContactListView: View {
    let sections: [ContactSection]
    let totalCount: Int
    @Binding var searchText: String
    @Binding var sortOrder: ContactSortOrder
    @Binding var selection: Contact?
    var addContact: () -> Void
    var deleteContact: (Contact) -> Void

    var body: some View {
        List(selection: $selection) {
            ForEach(sections) { section in
                Section(section.title) {
                    ForEach(section.contacts) { contact in
                        ContactRow(contact: contact)
                            .tag(contact)
                    }
                }
            }
        }
        .navigationTitle("Contacts")
        .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 420)
        .searchable(text: $searchText, prompt: "Search Contacts")
        .overlay { emptyState }
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
            ToolbarItem {
                Menu {
                    Picker("Sort By", selection: $sortOrder) {
                        ForEach(ContactSortOrder.allCases) { order in
                            Text(order.title).tag(order)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
                .help("Sort Order")
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if sections.isEmpty {
            if !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else if totalCount == 0 {
                ContentUnavailableView(
                    "No Contacts",
                    systemImage: "person.crop.circle.badge.plus",
                    description: Text("Add a contact to get started.")
                )
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
                if let subtitle = contact.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

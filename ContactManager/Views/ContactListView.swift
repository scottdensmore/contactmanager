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
    @Binding var isInspectorVisible: Bool
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
        .navigationSplitViewColumnWidth(
            min: LayoutMetrics.listMinWidth,
            ideal: LayoutMetrics.listIdealWidth,
            max: LayoutMetrics.listMaxWidth
        )
        .animation(.smooth, value: sortOrder)
        // Place the search in the toolbar's principal (centered) area so the
        // field anchors to the middle of the window instead of stretching
        // across the trailing edge and overlapping the inspector pane.
        .searchable(text: $searchText, placement: .toolbarPrincipal, prompt: "Search Contacts")
        .overlay { emptyState }
        .onDeleteCommand {
            if let selection { deleteContact(selection) }
        }
        .toolbar {
            // One cohesive trailing group so the buttons render together in
            // a single Liquid Glass capsule. The destructive trash button is
            // gone; `.onDeleteCommand` above still handles ⌫ on selection.
            ToolbarItemGroup(placement: .primaryAction) {
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

                Button(action: addContact) {
                    Label("New Contact", systemImage: "plus")
                }
                .help("New Contact")

                Button {
                    isInspectorVisible.toggle()
                } label: {
                    Label("Inspector", systemImage: "sidebar.right")
                }
                .help("Toggle Inspector")
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if sections.isEmpty {
            if totalCount == 0 {
                // An empty store always reads as "No Contacts", even mid-search.
                ContentUnavailableView {
                    Label("No Contacts", systemImage: "person.crop.circle.badge.plus")
                } description: {
                    Text("Add a contact to get started.")
                } actions: {
                    Button("New Contact", action: addContact)
                        .buttonStyle(.glassProminent)
                }
            } else if !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
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

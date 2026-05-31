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
    /// Called when a `.vcf` file is dropped onto the list from Finder.
    var importVCardURLs: ([URL]) -> Void

    var body: some View {
        List(selection: $selection) {
            ForEach(sections) { section in
                Section(section.title) {
                    ForEach(section.contacts) { contact in
                        ContactRow(contact: contact)
                            .tag(contact)
                            // Drag a row to Finder to write `<Name>.vcf`.
                            .draggable(transfer(for: contact))
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
        .searchable(text: $searchText, prompt: "Search Contacts")
        .overlay { emptyState }
        // Accept `.vcf` drops from Finder. Filtering on extension keeps
        // arbitrary file drops from triggering a no-op import.
        .dropDestination(for: URL.self) { urls, _ in
            let vcards = urls.filter { $0.pathExtension.lowercased() == "vcf" }
            guard !vcards.isEmpty else { return false }
            importVCardURLs(vcards)
            return true
        }
        .onDeleteCommand {
            if let selection { deleteContact(selection) }
        }
        .toolbar {
            // One cohesive trailing group so sort and add render as a single
            // Liquid Glass capsule. ⌫ on the selected row deletes via
            // `.onDeleteCommand` above; no trash button needed.
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
            }
        }
    }

    private func transfer(for contact: Contact) -> VCardTransfer {
        VCardTransfer(
            suggestedName: VCardTransfer.suggestedFilename(for: contact.fullName),
            text: VCard.card(for: contact)
        )
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
        // Read the row as a single VoiceOver element ("John Smith, name@example.com")
        // rather than three (avatar + name + subtitle).
        .accessibilityElement(children: .combine)
    }
}

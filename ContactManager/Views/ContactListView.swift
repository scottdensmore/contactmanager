//
//  ContactListView.swift
//  ContactManager
//
//  Middle column: a searchable, alphabetically sectioned list of contacts
//  plus the sort and add/delete toolbar affordances.
//

import SwiftData
import SwiftUI

struct ContactListView: View {
    let title: String
    let sections: [ContactSection]
    let totalCount: Int
    let emptyTitle: String
    @Binding var searchText: String
    @Binding var sortOrder: ContactSortOrder
    @Binding var selection: Contact?
    @Binding var selectionIDs: Set<PersistentIdentifier>
    let groups: [ContactGroup]
    let tags: [ContactTag]
    var addContact: () -> Void
    var deleteContact: (Contact) -> Void
    var saveCurrentSearch: () -> Void
    var exportSelectedContacts: () -> Void
    var addSelectedContactsToGroup: (ContactGroup) -> Void
    var addSelectedContactsToTag: (ContactTag) -> Void
    var deleteSelectedContacts: () -> Void
    /// Called when a `.vcf` file is dropped onto the list from Finder.
    var importVCardURLs: ([URL]) -> Void

    /// SwiftUI's `OpenWindowAction` for the detached-contact window.
    @Environment(\.openWindow) private var openWindow

    /// Drives the search field's focus so the Find command (⌘F) can jump to it.
    @FocusState private var searchFocused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        List(selection: $selectionIDs) {
            ForEach(sections) { section in
                Section(section.title) {
                    ForEach(section.contacts) { contact in
                        ContactRow(contact: contact)
                            .tag(contact.persistentModelID)
                            .accessibilityIdentifier(contact.accessibilityRowIdentifier)
                            // Drag a row to Finder to write `<Name>.vcf`.
                            .draggable(transfer(for: contact))
                            .contextMenu { rowContextMenu(for: contact) }
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationSplitViewColumnWidth(
            min: LayoutMetrics.listMinWidth,
            ideal: LayoutMetrics.listIdealWidth,
            max: LayoutMetrics.listMaxWidth
        )
        .animation(reduceMotion ? nil : .smooth, value: sortOrder)
        .searchable(text: $searchText, prompt: "Search Contacts")
        .accessibilityIdentifier("contact-search")
        .searchFocused($searchFocused)
        // The Find menu command (⌘F) routes here to focus the search field.
        .onReceive(NotificationCenter.default.publisher(for: .focusSearchRequested)) { _ in
            searchFocused = true
        }
        .onChange(of: selectionIDs) { _, newValue in
            selection = contacts(in: newValue).first
        }
        .onChange(of: selection?.persistentModelID) { _, newValue in
            guard let newValue, !selectionIDs.contains(newValue) else { return }
            selectionIDs = [newValue]
        }
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
            if selectionIDs.count > 1 {
                deleteSelectedContacts()
            } else if let selection {
                deleteContact(selection)
            }
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

                Button(action: saveCurrentSearch) {
                    Label("Save Search", systemImage: "line.3.horizontal.decrease.circle")
                }
                .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Save Search")
                .accessibilityIdentifier("save-search-button")

                Menu {
                    Button("Export vCard…", action: exportSelectedContacts)
                    Menu("Add to Group") {
                        if groups.isEmpty {
                            Text("No Groups")
                        } else {
                            ForEach(groups) { group in
                                Button(group.displayName) {
                                    addSelectedContactsToGroup(group)
                                }
                            }
                        }
                    }
                    .accessibilityIdentifier("batch-add-to-group-menu")
                    Menu("Add to Tag") {
                        if tags.isEmpty {
                            Text("No Tags")
                        } else {
                            ForEach(tags) { tag in
                                Button(tag.displayName) {
                                    addSelectedContactsToTag(tag)
                                }
                            }
                        }
                    }
                    .accessibilityIdentifier("batch-add-to-tag-menu")
                    Divider()
                    Button("Delete", role: .destructive, action: deleteSelectedContacts)
                        .accessibilityIdentifier("batch-delete-button")
                } label: {
                    Label("Batch Actions", systemImage: "checklist")
                        .accessibilityIdentifier("batch-actions-menu")
                }
                .disabled(selectionIDs.isEmpty)
                .help("Batch Actions")

                Button(action: addContact) {
                    Label("New Contact", systemImage: "plus")
                }
                .help("New Contact")
                .accessibilityIdentifier("new-contact-button")
            }
        }
    }

    private func contacts(in ids: Set<PersistentIdentifier>) -> [Contact] {
        sections.flatMap(\.contacts).filter { ids.contains($0.persistentModelID) }
    }

    private func transfer(for contact: Contact) -> VCardTransfer {
        VCardTransfer(
            contactID: contact.persistentModelID.storedString ?? "",
            suggestedName: VCardTransfer.suggestedFilename(for: contact.fullName),
            text: VCard.card(for: contact)
        )
    }

    @ViewBuilder
    private func rowContextMenu(for contact: Contact) -> some View {
        Button("Open in New Window") {
            // The detached window resolves the contact via its encoded
            // `PersistentIdentifier` — the same scheme used by App
            // Intents/Spotlight, so closed windows can survive a relaunch
            // (or fail gracefully if the contact was deleted in between).
            if let encoded = contact.persistentModelID.storedString {
                openWindow(id: "contact", value: encoded)
            }
        }
        Divider()
        Button("Delete", role: .destructive) {
            deleteContact(contact)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if sections.isEmpty {
            if totalCount == 0 {
                // An empty store always reads as "No Contacts", even mid-search.
                ContentUnavailableView {
                    Label(emptyTitle, systemImage: "person.crop.circle.badge.plus")
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

private extension Contact {
    var accessibilityRowIdentifier: String {
        let name = fullName.normalizedIdentifier
        let persistentToken = persistentModelID.storedString ?? String(describing: persistentModelID)
        return "contact-row-\(name)-\(persistentToken.stableIdentifierHash)"
    }
}

private extension String {
    var normalizedIdentifier: String {
        lowercased()
            .map { $0.isLetter || $0.isNumber ? String($0) : "-" }
            .joined()
    }

    var stableIdentifierHash: String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}

struct ContactRow: View {
    let contact: Contact

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(contact: contact, size: 36)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(contact.fullName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .accessibilityIdentifier("contact-row-title-\(displayIdentifier)")
                if let role = contact.roleLine {
                    Text(role)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .accessibilityIdentifier("contact-row-role-\(displayIdentifier)")
                }
                if let metaLine = contact.listMetaLine {
                    Text(metaLine)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .accessibilityIdentifier("contact-row-meta-\(displayIdentifier)")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        // Read the row as a single VoiceOver element ("John Smith, name@example.com")
        // rather than three (avatar + name + subtitle).
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("contact-row-summary-\(displayIdentifier)")
    }

    private var displayIdentifier: String {
        contact.fullName.normalizedIdentifier
    }
}

private extension Contact {
    var listMetaLine: String? {
        let values = [primaryEmail, primaryPhone]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !values.isEmpty { return values.joined(separator: " · ") }

        let trimmedCompany = company.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedCompany.isEmpty ? nil : trimmedCompany
    }
}

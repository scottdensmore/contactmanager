//
//  ContentView.swift
//  ContactManager
//
//  Three-column NavigationSplitView shell: sidebar (groups) / contact list /
//  detail. Owns selection, create/delete, group management, and vCard
//  import/export.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.undoManager) private var undoManager

    @Query(sort: [SortDescriptor(\Contact.lastName), SortDescriptor(\Contact.firstName)])
    private var contacts: [Contact]

    @Query(sort: \ContactGroup.name) private var groups: [ContactGroup]

    @State private var sidebarSelection: SidebarItem? = .allContacts
    @State private var selectedContact: Contact?
    @State private var errorMessage: String?
    @State private var searchText = ""
    @AppStorage("contactSortOrder") private var sortOrder: ContactSortOrder = .lastName
    @AppStorage("contactInspectorVisible") private var isInspectorVisible = true

    @State private var isImportingVCard = false
    @State private var isExportingVCard = false
    @State private var exportDocument = VCardDocument(text: "")
    @State private var showingDuplicates = false

    private var store: ContactStore { ContactStore(context) }

    /// The group backing the current sidebar selection, if any.
    private var selectedGroup: ContactGroup? {
        guard case .group(let id) = sidebarSelection else { return nil }
        return groups.first { $0.persistentModelID == id }
    }

    /// Contacts shown for the current sidebar selection, before search.
    /// Reads a group's members from the relationship rather than scanning
    /// every contact's groups.
    private var scopedContacts: [Contact] {
        selectedGroup?.contacts ?? contacts
    }

    private var sections: [ContactSection] {
        ContactQuery.sections(
            ContactQuery.filtered(scopedContacts, matching: searchText),
            by: sortOrder
        )
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selection: $sidebarSelection,
                contactCount: contacts.count,
                groups: groups,
                addGroup: addGroup,
                renameGroup: renameGroup,
                deleteGroup: deleteGroup
            )
        } content: {
            ContactListView(
                sections: sections,
                totalCount: scopedContacts.count,
                searchText: $searchText,
                sortOrder: $sortOrder,
                isInspectorVisible: $isInspectorVisible,
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
        .inspector(isPresented: $isInspectorVisible) {
            if let selectedContact {
                ContactInspectorView(contact: selectedContact)
                    .id(selectedContact.persistentModelID)
                    .inspectorColumnWidth(min: 240, ideal: 300, max: 420)
            } else {
                ContentUnavailableView(
                    "No Contact Selected",
                    systemImage: "sidebar.right",
                    description: Text("Select a contact to see its details here.")
                )
                .inspectorColumnWidth(min: 240, ideal: 300, max: 420)
            }
        }
        // Grow the window's minimum width when the inspector is visible so
        // the 4-column layout has room: sidebar (180) + list (240) + detail
        // (~300) + inspector (240). Without the inspector, ~760 is plenty.
        .frame(minWidth: isInspectorVisible ? 980 : 760, minHeight: 480)
        .onAppear {
            // Route every ContactStore mutation through the window's undo
            // manager so Edit ▸ Undo/Redo (⌘Z / ⇧⌘Z) work.
            context.undoManager = undoManager
        }
        .onChange(of: undoManager) { _, new in
            context.undoManager = new
        }
        .onReceive(NotificationCenter.default.publisher(for: .newContactRequested)) { _ in
            addContact()
        }
        .onReceive(NotificationCenter.default.publisher(for: .importVCardRequested)) { _ in
            isImportingVCard = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportVCardRequested)) { _ in
            exportDocument = VCardDocument(text: store.exportVCards(contacts))
            isExportingVCard = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .findDuplicatesRequested)) { _ in
            showingDuplicates = true
        }
        .sheet(isPresented: $showingDuplicates) {
            DuplicatesView()
        }
        .fileImporter(isPresented: $isImportingVCard, allowedContentTypes: [.vCard]) { result in
            handleImport(result)
        }
        .fileExporter(
            isPresented: $isExportingVCard,
            document: exportDocument,
            contentType: .vCard,
            defaultFilename: "Contacts"
        ) { result in
            if case .failure(let error) = result {
                errorMessage = error.localizedDescription
            }
        }
        .alert(
            "Something Went Wrong",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }),
            presenting: errorMessage
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    // MARK: - Contact actions

    private func addContact() {
        do {
            // New contacts join the currently selected group, if any.
            let contact = try store.createContact(in: selectedGroup)
            withAnimation(.snappy) { selectedContact = contact }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteContact(_ contact: Contact) {
        let wasSelected = selectedContact?.persistentModelID == contact.persistentModelID
        do {
            try store.delete(contact)
            if wasSelected { selectedContact = nil }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Group actions

    private func addGroup() {
        do {
            let group = try store.createGroup()
            withAnimation(.snappy) { sidebarSelection = .group(group.persistentModelID) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func renameGroup(_ group: ContactGroup, to name: String) {
        do {
            try store.rename(group, to: name)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteGroup(_ group: ContactGroup) {
        let wasSelected = sidebarSelection == .group(group.persistentModelID)
        do {
            try store.delete(group)
            if wasSelected { sidebarSelection = .allContacts }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - vCard import

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let url):
            Task {
                // Read and parse off the main actor so large files don't block UI.
                let parsed: [ParsedContact]? = await Task.detached {
                    let didAccess = url.startAccessingSecurityScopedResource()
                    defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
                    guard let data = try? Data(contentsOf: url),
                          let text = String(data: data, encoding: .utf8) else { return nil }
                    return VCard.parse(text)
                }.value

                guard let parsed else {
                    errorMessage = "That file couldn't be read as a vCard."
                    return
                }
                guard !parsed.isEmpty else {
                    errorMessage = "No contacts were found in that file."
                    return
                }
                do {
                    try store.importContacts(parsed)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Contact.self, inMemory: true)
}

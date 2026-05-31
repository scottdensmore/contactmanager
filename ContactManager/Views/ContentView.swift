//
//  ContentView.swift
//  ContactManager
//
//  Three-column NavigationSplitView shell: sidebar (groups) / contact list /
//  detail. Owns selection, create/delete, group management, and vCard
//  import/export.
//

import CoreSpotlight
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
    // Internal so the import handlers in `ContentView+Import.swift` can
    // set this when a parse/insert fails.
    @State var errorMessage: String?
    @State private var searchText = ""
    @AppStorage("contactSortOrder") private var sortOrder: ContactSortOrder = .lastName
    @AppStorage("defaultGroupID") private var defaultGroupID: String = ""

    @State private var isImportingVCard = false
    @State private var isImportingCSV = false
    @State private var isExportingVCard = false
    @State private var exportDocument = VCardDocument(text: "")
    @State private var showingDuplicates = false

    /// Internal so the import handlers in `ContentView+Import.swift` can
    /// reach the same store the main view uses.
    var store: ContactStore { ContactStore(context) }

    /// The group backing the current sidebar selection, if any.
    private var selectedGroup: ContactGroup? {
        guard case .group(let id) = sidebarSelection else { return nil }
        return groups.first { $0.persistentModelID == id }
    }

    /// User-configured default group for new contacts when the sidebar is
    /// on All Contacts. Resolved by encoded `PersistentIdentifier` so it
    /// survives a rename; if the target group was deleted the lookup
    /// returns nil and SettingsView prunes the preference on next view.
    private var defaultGroup: ContactGroup? {
        guard let id = PersistentIdentifier.decode(stored: defaultGroupID) else { return nil }
        return groups.first { $0.persistentModelID == id }
    }

    /// Where a new contact should land. The default group is only used when
    /// the sidebar is explicitly on All Contacts — never as a silent rescue
    /// from a `.group(...)` selection whose target was deleted, which would
    /// surprise the user by adding their contact to an unrelated group.
    private var groupForNewContact: ContactGroup? {
        switch sidebarSelection {
        case .group: selectedGroup
        case .allContacts, .none: defaultGroup
        }
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
                selection: $selectedContact,
                addContact: addContact,
                deleteContact: deleteContact,
                importVCardURLs: importVCardURLs
            )
        } detail: {
            Group {
                if let selectedContact {
                    ContactDetailView(contact: selectedContact)
                        .id(selectedContact.persistentModelID)
                } else {
                    ContactPlaceholderView()
                }
            }
            // Without this the divider can be dragged left far enough that
            // the detail toolbar overlaps the contact list column.
            .navigationSplitViewColumnWidth(min: LayoutMetrics.detailMinWidth, ideal: 520)
        }
        .frame(
            minWidth: LayoutMetrics.windowMinWidth,
            minHeight: LayoutMetrics.windowMinHeight
        )
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
        .onReceive(NotificationCenter.default.publisher(for: .importCSVRequested)) { _ in
            isImportingCSV = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportVCardRequested)) { _ in
            exportDocument = VCardDocument(text: store.exportVCards(contacts))
            isExportingVCard = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .findDuplicatesRequested)) { _ in
            showingDuplicates = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .importSystemContactsRequested)) { _ in
            importSystemContacts()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openContactRequested)) { note in
            selectContact(byEncodedID: note.userInfo?["id"] as? String)
        }
        .onReceive(NotificationCenter.default.publisher(for: .contactsDidChange)) { _ in
            // The indexer fetches its own snapshot — `@Query`'s post-save
            // refresh is asynchronous and can still reflect pre-save state
            // when this notification fires.
            Task { await SpotlightIndexer.shared.reindex() }
        }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
            selectContact(byEncodedID: id)
        }
        .sheet(isPresented: $showingDuplicates) {
            DuplicatesView()
        }
        .fileImporter(isPresented: $isImportingVCard, allowedContentTypes: [.vCard]) { result in
            handleImport(result)
        }
        .fileImporter(isPresented: $isImportingCSV, allowedContentTypes: [.commaSeparatedText]) { result in
            handleCSVImport(result)
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
            let contact = try store.createContact(in: groupForNewContact)
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

    // MARK: - Open by ID (Spotlight + App Intents)

    private func selectContact(byEncodedID encoded: String?) {
        guard let encoded,
              let id = PersistentIdentifier.decode(stored: encoded),
              let contact = contacts.first(where: { $0.persistentModelID == id })
        else { return }
        // Drop a group selection so the contact is guaranteed visible in the
        // middle column even if the user arrived via Spotlight while a
        // narrower group was active.
        if case .group = sidebarSelection { sidebarSelection = .allContacts }
        withAnimation(.snappy) { selectedContact = contact }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Contact.self, inMemory: true)
}

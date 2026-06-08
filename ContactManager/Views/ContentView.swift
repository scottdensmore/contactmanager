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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query(sort: [SortDescriptor(\Contact.lastName), SortDescriptor(\Contact.firstName)])
    var contacts: [Contact]

    @Query(sort: \ContactGroup.name) private var groups: [ContactGroup]

    @State private var sidebarSelection: SidebarItem? = .allContacts
    @State private var selectedContact: Contact?
    @State private var contactPendingNameFocus: PersistentIdentifier?
    @State var errorMessage: String?
    @State var importProgress: ImportProgress?
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @AppStorage("contactSortOrder") private var sortOrder: ContactSortOrder = .lastName
    @AppStorage("defaultGroupID") private var defaultGroupID: String = ""

    @State private var isImportingVCard = false
    @State private var isImportingCSV = false
    @State private var isExportingVCard = false
    @State private var exportDocument = VCardDocument(text: "")
    @State private var showingDuplicates = false
    @State private var isExportingPDF = false
    @State private var pdfDocument = PDFExportDocument(data: Data())
    @State private var pdfFilename = "Contact"
    @State var importReviewItems: [ImportReviewItem] = []
    @State var isReviewingImport = false
    @State var importSummary: ImportReviewResult?

    var store: ContactStore { ContactStore(context) }

    private var selectedGroup: ContactGroup? {
        guard case .group(let id) = sidebarSelection else { return nil }
        return groups.first { $0.persistentModelID == id }
    }

    private var selectedSmartList: ContactSmartList? {
        guard case .smartList(let smartList) = sidebarSelection else { return nil }
        return smartList
    }

    private var smartListCounts: [ContactSmartList: Int] {
        Dictionary(uniqueKeysWithValues: ContactSmartList.allCases.map { smartList in
            (smartList, ContactQuery.filtered(contacts, by: smartList).count)
        })
    }

    private var defaultGroup: ContactGroup? {
        DefaultGroupPreference.group(stored: defaultGroupID, in: groups)
    }

    private var groupForNewContact: ContactGroup? {
        switch sidebarSelection {
        case .group: selectedGroup
        case .allContacts, .smartList, .none: defaultGroup
        }
    }

    private var scopedContacts: [Contact] {
        if let selectedGroup { return selectedGroup.contacts }
        if let selectedSmartList { return ContactQuery.filtered(contacts, by: selectedSmartList) }
        return contacts
    }

    private var listTitle: String {
        if let selectedGroup { return selectedGroup.displayName }
        if let selectedSmartList { return selectedSmartList.title }
        return "Contacts"
    }

    private var emptyListTitle: String {
        if selectedGroup != nil { return "No Contacts in Group" }
        if selectedSmartList != nil { return "No Contacts Match" }
        return "No Contacts"
    }

    private var sections: [ContactSection] {
        ContactQuery.sections(
            ContactQuery.filtered(scopedContacts, matching: debouncedSearchText),
            by: sortOrder
        )
    }

    var body: some View {
        let scene = splitView
            .task(id: searchText) {
                if searchText.isEmpty {
                    debouncedSearchText = ""
                    return
                }
                do {
                    try await Task.sleep(for: .milliseconds(150))
                    debouncedSearchText = searchText
                } catch {
                    // Task cancelled — a newer keystroke superseded this one.
                }
            }
            .onAppear {
                context.undoManager = undoManager
            }
            .onChange(of: undoManager) { _, new in
                context.undoManager = new
            }
        return handlingFileDialogs(handlingHandoff(handlingMenuCommands(scene)))
    }

    /// The three-column split view, window frame, and the import overlay.
    private var splitView: some View {
        NavigationSplitView {
            SidebarView(
                selection: $sidebarSelection,
                contactCount: contacts.count,
                smartListCounts: smartListCounts,
                groups: groups,
                addGroup: addGroup,
                renameGroup: renameGroup,
                deleteGroup: deleteGroup,
                addContacts: addContacts(encodedIDs:to:)
            )
        } content: {
            ContactListView(
                title: listTitle,
                sections: sections,
                totalCount: scopedContacts.count,
                emptyTitle: emptyListTitle,
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
                    ContactDetailView(
                        contact: selectedContact,
                        focusNameField: selectedContact.persistentModelID == contactPendingNameFocus,
                        onNameFieldFocused: { contactPendingNameFocus = nil },
                        markContacted: markContacted
                    )
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
        .overlay {
            if let importProgress {
                ImportProgressView(progress: importProgress)
            }
        }
    }

    // MARK: - Contact actions

    private func addContact() {
        do {
            let contact = try store.createContact(in: groupForNewContact)
            if selectedSmartList != nil { sidebarSelection = .allContacts }
            contactPendingNameFocus = contact.persistentModelID
            withAnimation(reduceMotion ? nil : .snappy) { selectedContact = contact }
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

    private func markContacted(_ contact: Contact) {
        do {
            try store.markContacted(contact)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Group actions

    private func addGroup() {
        do {
            let group = try store.createGroup()
            withAnimation(reduceMotion ? nil : .snappy) { sidebarSelection = .group(group.persistentModelID) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addContacts(encodedIDs ids: [String], to group: ContactGroup) {
        do {
            try store.addContacts(withEncodedIDs: ids, to: group)
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
        withAnimation(reduceMotion ? nil : .snappy) { selectedContact = contact }
    }
}

/// Body modifiers and command actions, split out of the main struct to keep
/// the SwiftUI type-checker (and the type-body length) happy. Same-file, so
/// these still see ContentView's private state.
private extension ContentView {
    /// Menu-command observers (New, imports/exports, Find Duplicates, Print/PDF,
    /// Spotlight open, and the incremental re-index on every mutation).
    func handlingMenuCommands(_ content: some View) -> some View {
        content
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
            .onReceive(NotificationCenter.default.publisher(for: .exportPDFRequested)) { _ in
                exportSelectedContactAsPDF()
            }
            .onReceive(NotificationCenter.default.publisher(for: .printContactRequested)) { _ in
                printSelectedContact()
            }
            .onReceive(NotificationCenter.default.publisher(for: .importSystemContactsRequested)) { _ in
                importSystemContacts()
            }
            .onReceive(NotificationCenter.default.publisher(for: .openContactRequested)) { note in
                selectContact(byEncodedID: note.userInfo?["id"] as? String)
            }
            .onReceive(NotificationCenter.default.publisher(for: .contactsDidChange)) { note in
                // The indexer fetches the affected contacts fresh by id, since
                // `@Query`'s post-save refresh can still reflect pre-save state
                // here. A post without a payload falls back to a full reindex.
                if let change = note.userInfo?[ContactChange.userInfoKey] as? ContactChange {
                    Task { await SpotlightIndexer.shared.apply(change) }
                } else {
                    Task { await SpotlightIndexer.shared.reindex() }
                }
            }
            .onContinueUserActivity(CSSearchableItemActionType) { activity in
                let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
                selectContact(byEncodedID: id)
            }
    }

    /// Advertises the open contact for Handoff, and accepts it back. The
    /// activity is only active once we have an encoded id, so the system never
    /// holds an activity without a valid contact identifier.
    func handlingHandoff(_ content: some View) -> some View {
        content
            .userActivity(
                ContactActivity.viewContactType,
                isActive: selectedContact?.persistentModelID.storedString != nil
            ) { activity in
                if let contact = selectedContact, let id = contact.persistentModelID.storedString {
                    ContactActivity.configure(activity, contactID: id, displayName: contact.fullName)
                }
            }
            .onContinueUserActivity(ContactActivity.viewContactType) { activity in
                selectContact(byEncodedID: ContactActivity.contactID(from: activity))
            }
    }

    /// The sheets, importers, exporters, and the error alert.
    func handlingFileDialogs(_ content: some View) -> some View {
        handlingImportAlerts(content
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
            .fileExporter(
                isPresented: $isExportingPDF,
                document: pdfDocument,
                contentType: .pdf,
                defaultFilename: pdfFilename
            ) { result in
                if case .failure(let error) = result {
                    errorMessage = error.localizedDescription
                }
            }
            .sheet(isPresented: $isReviewingImport) {
                ImportReviewView(items: $importReviewItems) { items in
                    Task { await applyImportReview(items) }
                }
            })
    }

    // MARK: - Print / PDF

    func exportSelectedContactAsPDF() {
        guard let contact = selectedContact else {
            errorMessage = "Select a contact to export as PDF."
            return
        }
        guard let data = ContactPDF.data(for: contact) else {
            errorMessage = "Couldn't generate a PDF for that contact."
            return
        }
        pdfDocument = PDFExportDocument(data: data)
        pdfFilename = ContactPDF.filename(for: contact)
        isExportingPDF = true
    }

    func printSelectedContact() {
        guard let contact = selectedContact else {
            errorMessage = "Select a contact to print."
            return
        }
        if !ContactPDF.print(contact) {
            errorMessage = "Couldn't prepare that contact for printing."
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Contact.self, inMemory: true)
}

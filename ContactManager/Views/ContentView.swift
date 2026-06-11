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
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.openWindow) var openWindow

    @Query(sort: [SortDescriptor(\Contact.lastName), SortDescriptor(\Contact.firstName)])
    var contacts: [Contact]

    @Query(sort: \ContactGroup.name) var groups: [ContactGroup]

    @Query(sort: \ContactTag.name) var tags: [ContactTag]

    @Query(sort: \ContactSavedSmartList.createdAt) var savedSmartLists: [ContactSavedSmartList]

    @State var sidebarSelection: SidebarItem? = .allContacts
    @State var selectedContact: Contact?
    @State var selectedContactIDs: Set<PersistentIdentifier> = []
    @State private var contactPendingNameFocus: PersistentIdentifier?
    @State var errorMessage: String?
    @State var isConfirmingBatchDelete = false
    @State var isShowingCommandPalette = false
    @State var commandPaletteQuery = ""
    @State var pendingCommandPaletteAction: (() -> Void)?
    @State var importProgress: ImportProgress?
    @State var searchText = ""
    @State private var debouncedSearchText = ""
    @AppStorage("contactSortOrder") private var sortOrder: ContactSortOrder = .lastName
    @AppStorage("defaultGroupID") private var defaultGroupID: String = ""

    @State var isImportingVCard = false
    @State var isImportingCSV = false
    @State var isExportingVCard = false
    @State var exportDocument = VCardDocument(text: "")
    @State var showingDuplicates = false
    @State var isExportingPDF = false
    @State var pdfDocument = PDFExportDocument(data: Data())
    @State var pdfFilename = "Contact"
    @State var isExportingBackup = false
    @State var isPreparingEncryptedBackup = false
    @State var isExportingEncryptedBackup = false
    @State var isRestoringBackup = false
    @State var backupDocument = ContactBackupDocument()
    @State var encryptedBackupDocument = EncryptedContactBackupDocument()
    @State var pendingRestoreBackup: ContactBackup?
    @State var restorePreview: ContactBackupPreview?
    @State var isReviewingRestore = false
    @State var pendingEncryptedBackupData: Data?
    @State var isUnlockingEncryptedBackup = false
    @State var importReviewItems: [ImportReviewItem] = []
    @State var isReviewingImport = false
    @State var importSummary: ImportReviewResult?
    @State var restoreSummary: BackupRestoreResult?
    @State private var didPresentUITestImportReview = false

    var store: ContactStore { ContactStore(context) }

    private var selectedGroup: ContactGroup? {
        guard case .group(let id) = sidebarSelection else { return nil }
        return groups.first { $0.persistentModelID == id }
    }

    private var selectedTag: ContactTag? {
        guard case .tag(let id) = sidebarSelection else { return nil }
        return tags.first { $0.persistentModelID == id }
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

    var selectedContacts: [Contact] {
        contacts.filter { selectedContactIDs.contains($0.persistentModelID) }
    }

    private var groupForNewContact: ContactGroup? {
        switch sidebarSelection {
        case .group: selectedGroup
        case .allContacts, .smartList, .savedSmartList, .tag, .none: defaultGroup
        }
    }

    private var scopedContacts: [Contact] {
        if let selectedGroup { return selectedGroup.contacts }
        if let selectedTag { return selectedTag.contacts }
        if let selectedSmartList { return ContactQuery.filtered(contacts, by: selectedSmartList) }
        if let selectedSavedSmartList { return ContactQuery.filtered(contacts, by: selectedSavedSmartList) }
        return contacts
    }

    private var listTitle: String {
        if let selectedGroup { return selectedGroup.displayName }
        if let selectedTag { return selectedTag.displayName }
        if let selectedSmartList { return selectedSmartList.title }
        if let selectedSavedSmartList { return selectedSavedSmartList.displayName }
        return "Contacts"
    }

    private var emptyListTitle: String {
        if selectedGroup != nil { return "No Contacts in Group" }
        if selectedTag != nil { return "No Contacts with Tag" }
        if selectedSmartList != nil || selectedSavedSmartList != nil { return "No Contacts Match" }
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
                presentUITestImportReviewIfNeeded()
            }
            .onChange(of: undoManager) { _, new in
                context.undoManager = new
            }
        return handlingCommandPalette(handlingFileDialogs(handlingHandoff(handlingMenuCommands(scene))))
    }

    /// The three-column split view, window frame, and the import overlay.
    private var splitView: some View {
        NavigationSplitView {
            SidebarView(
                selection: $sidebarSelection,
                contactCount: contacts.count,
                smartListCounts: smartListCounts,
                savedSmartLists: savedSmartLists,
                savedSmartListCounts: savedSmartListCounts,
                groups: groups,
                tags: tags,
                addGroup: addGroup,
                addTag: addTag,
                renameSavedSmartList: renameSavedSmartList,
                deleteSavedSmartList: deleteSavedSmartList,
                renameGroup: renameGroup,
                deleteGroup: deleteGroup,
                renameTag: renameTag,
                deleteTag: deleteTag,
                addContactsToGroup: addContacts(encodedIDs:to:),
                addContactsToTag: addContacts(encodedIDs:to:)
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
                selectionIDs: $selectedContactIDs,
                groups: groups,
                tags: tags,
                addContact: addContact,
                deleteContact: deleteContact,
                saveCurrentSearch: saveCurrentSearchAsSmartList,
                exportSelectedContacts: exportSelectedContactsAsVCard,
                addSelectedContactsToGroup: addSelectedContacts(to:),
                addSelectedContactsToTag: addSelectedContacts(to:),
                deleteSelectedContacts: requestDeleteSelectedContacts,
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

    func addContact() {
        do {
            let contact = try store.createContact(in: groupForNewContact)
            if let selectedTag {
                try store.setMembership(of: contact, in: selectedTag, isMember: true)
            }
            if selectedSmartList != nil || selectedSavedSmartList != nil { sidebarSelection = .allContacts }
            contactPendingNameFocus = contact.persistentModelID
            selectedContactIDs = [contact.persistentModelID]
            withAnimation(reduceMotion ? nil : .snappy) { selectedContact = contact }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteContact(_ contact: Contact) {
        let wasSelected = selectedContact?.persistentModelID == contact.persistentModelID
        do {
            try store.delete(contact)
            selectedContactIDs.remove(contact.persistentModelID)
            if wasSelected { selectedContact = nil }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markContacted(_ contact: Contact) {
        do {
            try store.markContacted(contact)
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
        if case .tag = sidebarSelection { sidebarSelection = .allContacts }
        withAnimation(reduceMotion ? nil : .snappy) { selectedContact = contact }
    }
}

/// Body modifiers and command actions, split out of the main struct to keep
/// the SwiftUI type-checker (and the type-body length) happy. Same-file, so
/// these still see ContentView's private state.
private extension ContentView {
    func presentUITestImportReviewIfNeeded() {
        guard !didPresentUITestImportReview,
              ProcessInfo.processInfo.environment["CONTACTMANAGER_UI_TEST_MODE"] != nil,
              ProcessInfo.processInfo.environment["CONTACTMANAGER_UI_TEST_IMPORT_REVIEW"] != nil
        else { return }

        didPresentUITestImportReview = true
        var ada = ParsedContact(firstName: "Ada", lastName: "Lovelace")
        ada.emails = [(.work, "ada@analytical.engine")]
        ada.phones = [(.mobile, "555-0200")]
        let katherine = ParsedContact(firstName: "Katherine", lastName: "Johnson")
        importReviewItems = ImportReview.makeItems(for: [ada, katherine], existing: contacts)
        isReviewingImport = true
    }

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
            .onReceive(NotificationCenter.default.publisher(for: .exportBackupRequested)) { _ in
                exportBackup()
            }
            .onReceive(NotificationCenter.default.publisher(for: .exportEncryptedBackupRequested)) { _ in
                isPreparingEncryptedBackup = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .restoreBackupRequested)) { _ in
                isRestoringBackup = true
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
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Contact.self, ContactField.self, ContactGroup.self, ContactInteraction.self, ContactSavedSmartList.self,
            ContactTag.self,
        ], inMemory: true)
}

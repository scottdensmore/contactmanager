//
//  ContentView.swift
//  ContactManager
//
//  Three-column NavigationSplitView shell: sidebar (groups) / contact list /
//  detail. Owns selection, create/delete, group management, and vCard
//  import/export.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Contact.lastName), SortDescriptor(\Contact.firstName)])
    private var contacts: [Contact]

    @Query(sort: \ContactGroup.name) private var groups: [ContactGroup]

    @State private var sidebarSelection: SidebarItem? = .allContacts
    @State private var selectedContact: Contact?
    @State private var errorMessage: String?
    @State private var searchText = ""
    @AppStorage("contactSortOrder") private var sortOrder: ContactSortOrder = .lastName

    @State private var isImportingVCard = false
    @State private var isExportingVCard = false
    @State private var exportDocument = VCardDocument(text: "")

    /// Contacts shown for the current sidebar selection, before search.
    private var scopedContacts: [Contact] {
        guard case .group(let id) = sidebarSelection else { return contacts }
        return contacts.filter { contact in
            contact.groups.contains { $0.persistentModelID == id }
        }
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
        .onReceive(NotificationCenter.default.publisher(for: .importVCardRequested)) { _ in
            isImportingVCard = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportVCardRequested)) { _ in
            exportDocument = VCardDocument(text: VCard.makeDocument(from: ContactQuery.sorted(contacts)))
            isExportingVCard = true
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
        let contact = Contact()
        // New contacts join the currently selected group, if any.
        if case .group(let id) = sidebarSelection,
           let group = groups.first(where: { $0.persistentModelID == id }) {
            contact.groups = [group]
        }
        context.insert(contact)
        do {
            try context.save()
            selectedContact = contact
        } catch {
            context.delete(contact)
            errorMessage = error.localizedDescription
        }
    }

    private func deleteContact(_ contact: Contact) {
        let wasSelected = selectedContact?.persistentModelID == contact.persistentModelID
        context.delete(contact)
        do {
            try context.save()
            if wasSelected { selectedContact = nil }
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Group actions

    private func addGroup() {
        let group = ContactGroup(name: "New Group")
        context.insert(group)
        do {
            try context.save()
            sidebarSelection = .group(group.persistentModelID)
        } catch {
            context.delete(group)
            errorMessage = error.localizedDescription
        }
    }

    private func renameGroup(_ group: ContactGroup, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        group.name = trimmed
        try? context.save()
    }

    private func deleteGroup(_ group: ContactGroup) {
        if case .group(let id) = sidebarSelection, id == group.persistentModelID {
            sidebarSelection = .allContacts
        }
        context.delete(group)
        try? context.save()
    }

    // MARK: - vCard import

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let url):
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

            guard let data = try? Data(contentsOf: url),
                  let text = String(data: data, encoding: .utf8) else {
                errorMessage = "That file couldn't be read as a vCard."
                return
            }

            let parsed = VCard.parse(text)
            guard !parsed.isEmpty else {
                errorMessage = "No contacts were found in that file."
                return
            }

            for card in parsed {
                context.insert(makeContact(from: card))
            }
            do { try context.save() } catch { errorMessage = error.localizedDescription }
        }
    }

    private func makeContact(from parsed: ParsedContact) -> Contact {
        let contact = Contact(
            firstName: parsed.firstName, lastName: parsed.lastName,
            company: parsed.company, jobTitle: parsed.jobTitle,
            street: parsed.street, city: parsed.city, state: parsed.state,
            postalCode: parsed.postalCode, country: parsed.country,
            birthday: parsed.birthday, notes: parsed.notes
        )
        var fields: [ContactField] = []
        for (index, email) in parsed.emails.enumerated() {
            fields.append(ContactField(kind: .email, label: email.label, value: email.value, sortIndex: index))
        }
        for (index, phone) in parsed.phones.enumerated() {
            fields.append(ContactField(kind: .phone, label: phone.label, value: phone.value, sortIndex: index))
        }
        contact.fields = fields
        return contact
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Contact.self, inMemory: true)
}

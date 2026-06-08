//
//  ContactDetailView.swift
//  ContactManager
//
//  The detail column: an identity header (photo well + name/role + quick
//  primary email/phone) followed by an editable form. Text fields and the
//  birthday toggle bind directly to the SwiftData model (autosaved by the
//  context); structural and group/photo/field mutations go through
//  ContactStore so they're atomic, undoable, and rolled back on failure.
//

import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ContactDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var contact: Contact
    /// Set for a just-created contact so the form opens with the cursor in
    /// First Name; the view clears it via `onNameFieldFocused` after focusing.
    var focusNameField = false
    var onNameFieldFocused: () -> Void = {}
    var markContacted: (Contact) -> Void = { _ in }
    @Query(sort: \ContactGroup.name) private var allGroups: [ContactGroup]
    @State private var isImportingPhoto = false
    // Not private: the photo handlers in ContactDetailView+Photo.swift read them.
    @State var errorMessage: String?
    @FocusState private var nameFieldFocused: Bool
    @State var lastSavedFingerprint = ""
    @State var interactionKind: ContactInteractionKind = .note
    @State var interactionSummary = ""

    var store: ContactStore { ContactStore(context) }

    var editFingerprint: String {
        ContactEditFingerprint.make(for: contact)
    }

    var body: some View {
        Form {
            Section { identityHeader }

            quickInfoSection

            Section("Name") {
                TextField("First Name", text: $contact.firstName)
                    .focused($nameFieldFocused)
                    .accessibilityIdentifier("contact-first-name-field")
                TextField("Last Name", text: $contact.lastName)
                    .accessibilityIdentifier("contact-last-name-field")
            }

            Section("Work") {
                TextField("Company", text: $contact.company)
                    .accessibilityIdentifier("contact-company-field")
                TextField("Job Title", text: $contact.jobTitle)
                    .accessibilityIdentifier("contact-job-title-field")
            }

            Section("Relationship") {
                LabeledContent("Last Contacted") {
                    if let lastContactedAt = contact.lastContactedAt {
                        Text(lastContactedAt, format: .dateTime.month().day().year())
                    } else {
                        Text("Never")
                            .foregroundStyle(.secondary)
                    }
                }
                Button {
                    markContacted(contact)
                } label: {
                    Label("Mark Contacted Today", systemImage: "checkmark.circle")
                }
                .accessibilityIdentifier("mark-contacted-button")
            }

            historySection

            fieldSection("Email", kind: .email, fields: contact.emails)
            fieldSection("Phone", kind: .phone, fields: contact.phones)

            Section("Address") {
                TextField("Street", text: $contact.street)
                    .accessibilityIdentifier("contact-street-field")
                TextField("City", text: $contact.city)
                    .accessibilityIdentifier("contact-city-field")
                TextField("State / Province", text: $contact.state)
                    .accessibilityIdentifier("contact-state-field")
                TextField("Postal Code", text: $contact.postalCode)
                    .accessibilityIdentifier("contact-postal-code-field")
                TextField("Country", text: $contact.country)
                    .accessibilityIdentifier("contact-country-field")
            }

            Section("Birthday") {
                Toggle("Has Birthday", isOn: birthdayEnabled)
                if let birthday = contact.birthday {
                    Toggle("Include Year", isOn: birthdayIncludesYear)
                    if Birthday.fields(of: birthday).year == nil {
                        // Year unknown (a vCard `--MMDD` or a yearless Contacts
                        // card): edit month/day only so the sentinel year never
                        // shows and can't be accidentally "confirmed".
                        MonthDayPicker(month: birthdayMonth, day: birthdayDay)
                    } else {
                        DatePicker("Date", selection: birthdayValue, displayedComponents: .date)
                            // Birthdays are stored anchored to UTC; show/edit them
                            // in the same calendar (its time zone is UTC) so the
                            // picked day matches what's saved and what other devices
                            // see, regardless of the local time zone.
                            .environment(\.calendar, Birthday.calendar)
                    }
                }
            }

            Section("Groups") {
                if allGroups.isEmpty {
                    Text("No groups yet. Create one in the sidebar.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(allGroups) { group in
                        Toggle(group.displayName, isOn: membership(in: group))
                    }
                }
            }

            Section("Notes") {
                TextField("Notes", text: $contact.notes, axis: .vertical)
                    .lineLimit(3 ... 10)
                    .accessibilityIdentifier("contact-notes-field")
            }
        }
        .formStyle(.grouped)
        .navigationTitle(contact.fullName)
        // A freshly created contact opens with the cursor in First Name so you
        // can type a name immediately instead of reaching for the mouse.
        .onAppear {
            lastSavedFingerprint = editFingerprint
            if focusNameField { nameFieldFocused = true }
        }
        .task(id: editFingerprint) {
            guard editFingerprint != lastSavedFingerprint else { return }
            do {
                try await Task.sleep(for: .milliseconds(400))
                flushPendingEdits()
            } catch {
                // A newer edit cancelled this debounce.
            }
        }
        .onDisappear {
            flushPendingEdits()
        }
        // Clear the parent's one-shot flag only once focus has actually landed,
        // so a missed/late focus application isn't dropped without a retry.
        .onChange(of: nameFieldFocused) { _, focused in
            if focused { onNameFieldFocused() }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    markContacted(contact)
                } label: {
                    Label("Mark Contacted Today", systemImage: "checkmark.circle")
                }
                .help("Mark Contacted Today")
                .accessibilityIdentifier("mark-contacted-toolbar-button")
            }
            ToolbarItem {
                ShareLink(item: vcardTransfer, preview: SharePreview(shareTitle))
                    .help("Share this contact as a vCard")
            }
        }
        .alert(
            "Couldn't Save Changes",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }),
            presenting: errorMessage
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    // MARK: - Identity header

    private var identityHeader: some View {
        HStack(spacing: 16) {
            photoWell
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.fullName)
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                if let role = contact.roleLine {
                    Text(role).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    /// Tappable avatar offering Choose / Remove Photo.
    private var photoWell: some View {
        Menu {
            Button("Choose Photo…") { isImportingPhoto = true }
            if contact.photoData != nil {
                Button("Remove Photo", role: .destructive, action: removePhoto)
            }
        } label: {
            AvatarView(contact: contact, size: 72)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "camera.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .blue)
                        .font(.system(size: 22))
                        .background(.white, in: Circle())
                }
        }
        .buttonStyle(.plain)
        .help("Change Photo")
        .accessibilityLabel("Change Photo")
        .fileImporter(
            isPresented: $isImportingPhoto,
            allowedContentTypes: [.image]
        ) { result in
            handleImport(result)
        }
        // Drop an image from Finder (or another app) directly on the avatar.
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            handleImport(.success(url))
            return true
        }
    }

    // MARK: - Quick primary info

    @ViewBuilder
    private var quickInfoSection: some View {
        if contact.primaryEmail != nil || contact.primaryPhone != nil {
            Section {
                if let email = contact.primaryEmail {
                    quickRow(kind: .email, value: email)
                }
                if let phone = contact.primaryPhone {
                    quickRow(kind: .phone, value: phone)
                }
            }
        }
    }

    // MARK: - Repeatable field sections

    private func fieldSection(_ title: String, kind: FieldKind, fields: [ContactField]) -> some View {
        Section(title) {
            ForEach(fields) { field in
                ContactFieldRow(field: field)
            }
            .onDelete { offsets in
                delete(offsets, from: fields)
            }

            Button {
                addField(kind: kind)
            } label: {
                Label("Add \(title)", systemImage: "plus.circle.fill")
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Field actions

    private func addField(kind: FieldKind) {
        do {
            try store.addField(kind, to: contact)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ offsets: IndexSet, from fields: [ContactField]) {
        do {
            try store.delete(offsets.map { fields[$0] })
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Group membership

    private func membership(in group: ContactGroup) -> Binding<Bool> {
        Binding(
            get: { contact.groups.contains { $0.persistentModelID == group.persistentModelID } },
            set: { isMember in
                do {
                    try store.setMembership(of: contact, in: group, isMember: isMember)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        )
    }
}

/// Non-view helpers, kept in an extension so the main view body stays focused
/// on layout.
private extension ContactDetailView {
    // MARK: - Sharing

    /// The contact rendered as a shareable vCard file (same payload as a
    /// drag-to-Finder), built fresh so edits are reflected when shared.
    var vcardTransfer: VCardTransfer {
        VCardTransfer(
            suggestedName: VCardTransfer.suggestedFilename(for: contact.fullName),
            text: VCard.card(for: contact)
        )
    }

    /// Share-sheet title; falls back to "Contact" for an unnamed contact.
    var shareTitle: String {
        let name = contact.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Contact" : name
    }

    // MARK: - Birthday bindings

    var birthdayEnabled: Binding<Bool> {
        Binding(
            get: { contact.birthday != nil },
            set: { contact.birthday = $0 ? (contact.birthday ?? .now) : nil }
        )
    }

    var birthdayValue: Binding<Date> {
        Binding(
            get: { contact.birthday ?? .now },
            set: { contact.birthday = $0 }
        )
    }
}

struct ContactPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "No Contact Selected",
            systemImage: "person.crop.circle",
            description: Text("Select a contact to view and edit their details.")
        )
    }
}

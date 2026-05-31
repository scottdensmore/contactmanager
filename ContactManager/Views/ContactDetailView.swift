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
    @Query(sort: \ContactGroup.name) private var allGroups: [ContactGroup]
    @State private var isImportingPhoto = false
    @State private var errorMessage: String?

    private var store: ContactStore { ContactStore(context) }

    var body: some View {
        Form {
            Section { identityHeader }

            quickInfoSection

            Section("Name") {
                TextField("First Name", text: $contact.firstName)
                TextField("Last Name", text: $contact.lastName)
            }

            Section("Work") {
                TextField("Company", text: $contact.company)
                TextField("Job Title", text: $contact.jobTitle)
            }

            fieldSection("Email", kind: .email, fields: contact.emails)
            fieldSection("Phone", kind: .phone, fields: contact.phones)

            Section("Address") {
                TextField("Street", text: $contact.street)
                TextField("City", text: $contact.city)
                TextField("State / Province", text: $contact.state)
                TextField("Postal Code", text: $contact.postalCode)
                TextField("Country", text: $contact.country)
            }

            Section("Birthday") {
                Toggle("Has Birthday", isOn: birthdayEnabled)
                if contact.birthday != nil {
                    DatePicker("Date", selection: birthdayValue, displayedComponents: .date)
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
            }
        }
        .formStyle(.grouped)
        .navigationTitle(contact.fullName)
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
                let role = [contact.jobTitle, contact.company]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
                if !role.isEmpty {
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
    }

    // MARK: - Quick primary info

    @ViewBuilder
    private var quickInfoSection: some View {
        if contact.primaryEmail != nil || contact.primaryPhone != nil {
            Section {
                if let email = contact.primaryEmail {
                    quickRow(label: "Email", value: email)
                }
                if let phone = contact.primaryPhone {
                    quickRow(label: "Phone", value: phone)
                }
            }
        }
    }

    private func quickRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
            Button {
                copyToPasteboard(value)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("Copy \(label)")
            .accessibilityLabel("Copy \(label)")
        }
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
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

    // MARK: - Photo actions

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let url):
            Task {
                // Read the file and run the avatar pipeline off the main actor
                // so a multi-megabyte photo can't hitch the UI.
                let avatar: Data? = await Task.detached {
                    let didAccess = url.startAccessingSecurityScopedResource()
                    defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
                    guard let fileData = try? Data(contentsOf: url) else { return nil }
                    return ImageProcessing.avatarData(from: fileData)
                }.value

                guard let avatar else {
                    errorMessage = "That file couldn't be read as an image."
                    return
                }
                do {
                    try store.setPhotoData(avatar, on: contact)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func removePhoto() {
        do {
            try store.setPhotoData(nil, on: contact)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Birthday bindings

    private var birthdayEnabled: Binding<Bool> {
        Binding(
            get: { contact.birthday != nil },
            set: { contact.birthday = $0 ? (contact.birthday ?? .now) : nil }
        )
    }

    private var birthdayValue: Binding<Date> {
        Binding(
            get: { contact.birthday ?? .now },
            set: { contact.birthday = $0 }
        )
    }
}

/// A single editable email/phone row: a label picker plus its value.
private struct ContactFieldRow: View {
    @Bindable var field: ContactField

    var body: some View {
        HStack {
            Picker("", selection: $field.label) {
                ForEach(FieldLabel.allCases) { label in
                    Text(label.title).tag(label)
                }
            }
            .labelsHidden()
            .fixedSize()

            TextField(placeholder, text: $field.value)
                .textContentType(field.kind == .email ? .emailAddress : .telephoneNumber)
        }
    }

    private var placeholder: String {
        field.kind == .email ? "name@example.com" : "Phone"
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

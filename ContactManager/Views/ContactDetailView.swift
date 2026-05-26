//
//  ContactDetailView.swift
//  ContactManager
//
//  Trailing column: an editable form bound directly to the SwiftData model.
//  Edits autosave through the model context.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContactDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var contact: Contact
    @Query(sort: \ContactGroup.name) private var allGroups: [ContactGroup]
    @State private var isImportingPhoto = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            header

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
                    .lineLimit(3...10)
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

    // MARK: - Header

    private var header: some View {
        Section {
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
    }

    /// Tappable avatar that offers choosing or removing a photo.
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

    // MARK: - Repeatable field sections

    @ViewBuilder
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

    // MARK: - Actions

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let url):
            // Read the picked file while its security scope is held, then hand
            // the bytes off; downscaling happens off the main actor below.
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                let fileData = try Data(contentsOf: url)
                processPhoto(fileData)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func processPhoto(_ fileData: Data) {
        Task {
            // Decode/downscale off the main actor so large images don't block UI.
            let avatar = await Task.detached { ImageProcessing.avatarData(from: fileData) }.value
            guard let avatar else {
                errorMessage = "That file couldn't be read as an image."
                return
            }
            contact.photoData = avatar
            do { try context.save() } catch { errorMessage = error.localizedDescription }
        }
    }

    private func removePhoto() {
        contact.photoData = nil
        try? context.save()
    }

    private func addField(kind: FieldKind) {
        // Use max+1 (not count) so indices stay strictly increasing even after
        // rows are deleted, keeping insertion order stable.
        let nextIndex = (contact.fields(of: kind).map(\.sortIndex).max() ?? -1) + 1
        let field = ContactField(
            kind: kind,
            label: kind.defaultLabel,
            sortIndex: nextIndex
        )
        field.contact = contact
        context.insert(field)
        try? context.save()
    }

    private func delete(_ offsets: IndexSet, from fields: [ContactField]) {
        for index in offsets {
            context.delete(fields[index])
        }
        try? context.save()
    }

    // MARK: - Group membership

    private func membership(in group: ContactGroup) -> Binding<Bool> {
        Binding(
            get: { contact.groups.contains { $0.persistentModelID == group.persistentModelID } },
            set: { isMember in
                if isMember {
                    if !contact.groups.contains(where: { $0.persistentModelID == group.persistentModelID }) {
                        contact.groups.append(group)
                    }
                } else {
                    contact.groups.removeAll { $0.persistentModelID == group.persistentModelID }
                }
                do { try context.save() } catch {
                    context.rollback()
                    errorMessage = error.localizedDescription
                }
            }
        )
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

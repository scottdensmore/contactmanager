//
//  ContactDetailView.swift
//  ContactManager
//
//  The detail column's editable form. Focuses on text fields and uses the
//  ContactStore for mutations; the avatar, photo controls, quick-copy
//  email/phone, and group membership live in the trailing inspector pane.
//

import SwiftData
import SwiftUI

struct ContactDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var contact: Contact
    @State private var errorMessage: String?

    private var store: ContactStore { ContactStore(context) }

    var body: some View {
        Form {
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

    // MARK: - Actions

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

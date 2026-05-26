//
//  ContactDetailView.swift
//  ContactManager
//
//  Trailing column: an editable form bound directly to the SwiftData model.
//  Edits autosave through the model context.
//

import SwiftUI
import SwiftData

struct ContactDetailView: View {
    @Bindable var contact: Contact

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    AvatarView(contact: contact, size: 72)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.fullName)
                            .font(.title2.weight(.semibold))
                        if !contact.emailAddress.isEmpty {
                            Text(contact.emailAddress)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            Section("Name") {
                TextField("First Name", text: $contact.firstName)
                TextField("Last Name", text: $contact.lastName)
            }

            Section("Contact") {
                TextField("Email", text: $contact.emailAddress)
                    .textContentType(.emailAddress)
                TextField("Phone", text: $contact.phoneNumber)
                    .textContentType(.telephoneNumber)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(contact.fullName)
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

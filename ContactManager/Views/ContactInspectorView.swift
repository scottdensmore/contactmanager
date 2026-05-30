//
//  ContactInspectorView.swift
//  ContactManager
//
//  Trailing inspector pane that shows a contact's identity (avatar + photo
//  controls, name, role), quick-copy primary email/phone, and group
//  membership toggles — keeping the detail form focused on text fields.
//

import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ContactInspectorView: View {
    @Environment(\.modelContext) private var context
    @Bindable var contact: Contact
    @Query(sort: \ContactGroup.name) private var allGroups: [ContactGroup]

    @State private var isImportingPhoto = false
    @State private var errorMessage: String?

    private var store: ContactStore { ContactStore(context) }

    var body: some View {
        Form {
            Section { identityHeader }

            Section("Email") {
                if let email = contact.primaryEmail {
                    quickRow(email)
                } else {
                    Text("No email").foregroundStyle(.secondary)
                }
            }

            Section("Phone") {
                if let phone = contact.primaryPhone {
                    quickRow(phone)
                } else {
                    Text("No phone").foregroundStyle(.secondary)
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
        }
        .formStyle(.grouped)
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

    // MARK: - Identity

    private var identityHeader: some View {
        VStack(spacing: 10) {
            photoWell
            VStack(spacing: 2) {
                Text(contact.fullName)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                let role = [contact.jobTitle, contact.company]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
                if !role.isEmpty {
                    Text(role)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    /// Tappable avatar that offers choosing or removing a photo.
    private var photoWell: some View {
        Menu {
            Button("Choose Photo…") { isImportingPhoto = true }
            if contact.photoData != nil {
                Button("Remove Photo", role: .destructive, action: removePhoto)
            }
        } label: {
            AvatarView(contact: contact, size: 96)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "camera.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .blue)
                        .font(.system(size: 26))
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

    // MARK: - Quick rows

    private func quickRow(_ text: String) -> some View {
        HStack {
            Text(text)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button {
                copyToPasteboard(text)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("Copy")
            .accessibilityLabel("Copy \(text)")
        }
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
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
            let avatar = await Task.detached { ImageProcessing.avatarData(from: fileData) }.value
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

    private func removePhoto() {
        do {
            try store.setPhotoData(nil, on: contact)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

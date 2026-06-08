//
//  QuickCaptureView.swift
//  ContactManager
//
//  Compact keyboard-first contact capture window.
//

import SwiftData
import SwiftUI

struct QuickCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @FocusState private var entryFocused: Bool

    @State private var entry = ""
    @State private var errorMessage: String?
    @State private var createdMessage: String?

    private var draft: QuickCaptureDraft {
        QuickCaptureParser.parse(entry)
    }

    private var store: ContactStore {
        ContactStore(context)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Ada Lovelace, ada@example.com, birthday Dec 10", text: $entry)
                .textFieldStyle(.roundedBorder)
                .focused($entryFocused)
                .accessibilityIdentifier("quick-capture-entry-field")
                .onSubmit(createContact)

            QuickCapturePreview(draft: draft)

            HStack {
                if let createdMessage {
                    Text(createdMessage)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("quick-capture-status")
                }
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .accessibilityIdentifier("quick-capture-done-button")
                Button("Create", action: createContact)
                    .buttonStyle(.glassProminent)
                    .disabled(draft.isEmpty)
                    .accessibilityIdentifier("quick-capture-create-button")
            }
        }
        .padding(20)
        .frame(minWidth: 420, idealWidth: 520, minHeight: 180)
        .onAppear { entryFocused = true }
        .alert("Couldn't Create Contact", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func createContact() {
        let parsed = draft
        guard !parsed.isEmpty else { return }
        do {
            let contact = try store.createContact(from: parsed)
            if let encoded = contact.persistentModelID.storedString {
                NotificationCenter.default.post(
                    name: .openContactRequested,
                    object: nil,
                    userInfo: ["id": encoded]
                )
            }
            createdMessage = "Created \(contact.fullName)"
            entry = ""
            entryFocused = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct QuickCapturePreview: View {
    var draft: QuickCaptureDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(draft.displayName)
                .font(.headline)
                .lineLimit(1)
                .accessibilityIdentifier("quick-capture-preview-name")
            HStack(spacing: 10) {
                if let email = draft.emails.first?.value {
                    Label(email, systemImage: "envelope")
                }
                if let phone = draft.phones.first?.value {
                    Label(phone, systemImage: "phone")
                }
                if !draft.company.isBlank {
                    Label(draft.company, systemImage: "building.2")
                }
                if let birthday = draft.birthday {
                    Label(Birthday.formatted(birthday), systemImage: "gift")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .accessibilityIdentifier("quick-capture-preview-details")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

#Preview {
    QuickCaptureView()
        .modelContainer(
            for: [Contact.self, ContactField.self, ContactGroup.self, ContactInteraction.self],
            inMemory: true
        )
}

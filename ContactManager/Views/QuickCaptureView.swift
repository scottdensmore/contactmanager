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
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(previewItems, id: \.id) { item in
                        HStack(spacing: 6) {
                            Image(systemName: item.systemImage)
                                .accessibilityHidden(true)
                            Text(item.title)
                                .lineLimit(1)
                                .accessibilityIdentifier(item.accessibilityIdentifier)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxHeight: 120, alignment: .top)
            .accessibilityLabel("Quick capture preview details")
            .accessibilityIdentifier("quick-capture-preview-details")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private var previewItems: [QuickCapturePreviewItem] {
        var items: [QuickCapturePreviewItem] = []
        if !draft.company.isBlank {
            items.append(.init(
                id: "company",
                title: draft.company,
                systemImage: "building.2",
                accessibilityIdentifier: "quick-capture-preview-company"
            ))
        }
        if let birthday = draft.birthday {
            items.append(.init(
                id: "birthday",
                title: Birthday.formatted(birthday),
                systemImage: "gift",
                accessibilityIdentifier: "quick-capture-preview-birthday"
            ))
        }
        items.append(contentsOf: draft.emails.enumerated().map { index, field in
            .init(
                id: "email-\(index)",
                title: "\(field.label.title): \(field.value)",
                systemImage: "envelope",
                accessibilityIdentifier: "quick-capture-preview-email-\(index)"
            )
        })
        items.append(contentsOf: draft.phones.enumerated().map { index, field in
            .init(
                id: "phone-\(index)",
                title: "\(field.label.title): \(field.value)",
                systemImage: "phone",
                accessibilityIdentifier: "quick-capture-preview-phone-\(index)"
            )
        })
        items.append(contentsOf: draft.tags.enumerated().map { index, tag in
            .init(
                id: "tag-\(index)",
                title: tag,
                systemImage: "tag",
                accessibilityIdentifier: "quick-capture-preview-tag-\(index)"
            )
        })
        items.append(contentsOf: draft.groups.enumerated().map { index, group in
            .init(
                id: "group-\(index)",
                title: group,
                systemImage: "folder",
                accessibilityIdentifier: "quick-capture-preview-group-\(index)"
            )
        })
        return items
    }
}

private struct QuickCapturePreviewItem {
    var id: String
    var title: String
    var systemImage: String
    var accessibilityIdentifier: String
}

#Preview {
    QuickCaptureView()
        .modelContainer(
            for: [Contact.self, ContactField.self, ContactGroup.self, ContactInteraction.self, ContactTag.self],
            inMemory: true
        )
}

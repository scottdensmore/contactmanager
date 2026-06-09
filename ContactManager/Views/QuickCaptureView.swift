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

    @Query private var contacts: [Contact]

    @State private var entry = ""
    @State private var errorMessage: String?
    @State private var createdMessage: String?

    private var draft: QuickCaptureDraft {
        QuickCaptureParser.parse(entry)
    }

    private var match: QuickCaptureMatch? {
        QuickCaptureMatcher.bestMatch(for: draft, in: contacts)
    }

    private var canUpdateWithReturn: Bool {
        match?.confidence == .likely || match?.confidence == .exact
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
                .onSubmit(submitPrimaryAction)

            QuickCapturePreview(draft: draft)
            QuickCaptureWarnings(warnings: draft.parseWarnings)
            if let match {
                QuickCaptureMatchView(match: match)
            }

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
                if match != nil {
                    Button("Create New", action: createContact)
                        .disabled(draft.isEmpty)
                        .accessibilityIdentifier("quick-capture-create-button")
                    Button("Update Existing", action: updateExistingContact)
                        .buttonStyle(.glassProminent)
                        .disabled(draft.isEmpty)
                        .accessibilityIdentifier("quick-capture-update-existing-button")
                } else {
                    Button("Create", action: createContact)
                        .buttonStyle(.glassProminent)
                        .disabled(draft.isEmpty)
                        .accessibilityIdentifier("quick-capture-create-button")
                }
            }
        }
        .padding(20)
        .frame(minWidth: 420, idealWidth: 520, minHeight: 210)
        .onAppear { entryFocused = true }
        .alert("Couldn't Save Contact", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func submitPrimaryAction() {
        if canUpdateWithReturn {
            updateExistingContact()
        } else {
            createContact()
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

    private func updateExistingContact() {
        let parsed = draft
        guard !parsed.isEmpty, let match else { return }
        do {
            try store.updateContact(match.contact, from: parsed)
            if let encoded = match.contact.persistentModelID.storedString {
                NotificationCenter.default.post(
                    name: .openContactRequested,
                    object: nil,
                    userInfo: ["id": encoded]
                )
            }
            createdMessage = "Updated \(match.contact.fullName)"
            entry = ""
            entryFocused = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct QuickCapturePreview: View {
    private let maxVisiblePreviewItems = 6

    var draft: QuickCaptureDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(draft.displayName)
                .font(.headline)
                .lineLimit(1)
                .accessibilityIdentifier("quick-capture-preview-name")
            VStack(alignment: .leading, spacing: 4) {
                ForEach(visiblePreviewItems, id: \.id) { item in
                    QuickCapturePreviewRow(item: item)
                }
                if overflowCount > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "ellipsis.circle")
                            .accessibilityHidden(true)
                        Text("+\(overflowCount) more")
                            .lineLimit(1)
                    }
                    .accessibilityLabel("+\(overflowCount) more")
                    .accessibilityIdentifier("quick-capture-preview-overflow")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("quick-capture-preview-details")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private var visiblePreviewItems: [QuickCapturePreviewItem] {
        Array(previewItems.prefix(maxVisiblePreviewItems))
    }

    private var overflowCount: Int {
        max(0, previewItems.count - maxVisiblePreviewItems)
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

private struct QuickCapturePreviewRow: View {
    var item: QuickCapturePreviewItem

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: item.systemImage)
                .accessibilityHidden(true)
            Text(item.title)
                .lineLimit(1)
        }
        .accessibilityLabel(item.title)
        .accessibilityIdentifier(item.accessibilityIdentifier)
    }
}

private struct QuickCaptureMatchView: View {
    var match: QuickCaptureMatch

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(match.confidence.title)
                    .font(.caption.weight(.semibold))
                    .accessibilityIdentifier("quick-capture-match-confidence")
                Text(match.contact.fullName)
                    .font(.subheadline)
                    .lineLimit(1)
                    .accessibilityIdentifier("quick-capture-match-name")
                Text(match.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("quick-capture-match-reason")
            }
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(match.confidence.title), \(match.contact.fullName), \(match.reason)")
        .accessibilityIdentifier("quick-capture-match-row")
    }
}

private struct QuickCaptureWarnings: View {
    private let maxVisibleWarnings = 3

    var warnings: [String]

    var body: some View {
        if !warnings.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(visibleWarnings.enumerated()), id: \.offset) { index, warning in
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                            .accessibilityHidden(true)
                        Text(warning)
                            .lineLimit(1)
                    }
                    .accessibilityLabel(warning)
                    .accessibilityIdentifier("quick-capture-warning-\(index)")
                }
                if overflowCount > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "ellipsis.circle")
                            .accessibilityHidden(true)
                        Text("+\(overflowCount) more warnings")
                            .lineLimit(1)
                    }
                    .accessibilityLabel("+\(overflowCount) more warnings")
                    .accessibilityIdentifier("quick-capture-warning-overflow")
                }
            }
            .font(.caption)
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("quick-capture-warnings")
        }
    }

    private var visibleWarnings: [String] {
        Array(warnings.prefix(maxVisibleWarnings))
    }

    private var overflowCount: Int {
        max(0, warnings.count - maxVisibleWarnings)
    }
}

#Preview {
    QuickCaptureView()
        .modelContainer(
            for: [Contact.self, ContactField.self, ContactGroup.self, ContactInteraction.self, ContactTag.self],
            inMemory: true
        )
}

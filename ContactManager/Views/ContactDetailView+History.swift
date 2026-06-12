//
//  ContactDetailView+History.swift
//  ContactManager
//
//  Contact-history controls for the detail form.
//

import SwiftUI

extension ContactDetailView {
    var historySection: some View {
        Section("History") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Picker("Kind", selection: $interactionKind) {
                        ForEach(ContactInteractionKind.allCases) { kind in
                            Label(kind.title, systemImage: kind.systemImage)
                                .tag(kind)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 180, alignment: .leading)
                    .accessibilityIdentifier("interaction-kind-picker")

                    Button {
                        addInteraction()
                    } label: {
                        Label("Add to History", systemImage: "plus.circle.fill")
                    }
                    .disabled(interactionSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("add-interaction-button")
                }

                freeformEditor(
                    text: $interactionSummary,
                    configuration: .historyNote(systemImage: interactionKind.systemImage)
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(contact.sortedInteractions.prefix(5)) { interaction in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Label(interaction.kind.title, systemImage: interaction.kind.systemImage)
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(interaction.summary)
                        Text(interaction.date, format: .dateTime.month().day().year())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    func addInteraction() {
        do {
            try store.addInteraction(to: contact, kind: interactionKind, summary: interactionSummary)
            interactionSummary = ""
            interactionKind = .note
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func freeformEditor(text: Binding<String>, configuration: FreeformEditorConfiguration) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(configuration.title, systemImage: configuration.systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.quaternary, lineWidth: 1)
                    )
                    .accessibilityHidden(true)

                TextEditor(text: text)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                    .frame(height: configuration.height)
                    .accessibilityLabel(configuration.title)
                    .accessibilityIdentifier(configuration.fieldIdentifier)

                if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(configuration.placeholder)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: 460, minHeight: configuration.height, maxHeight: configuration.height)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(configuration.containerIdentifier)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FreeformEditorConfiguration {
    var title: String
    var systemImage: String
    var placeholder: String
    var height: CGFloat
    var containerIdentifier: String
    var fieldIdentifier: String

    static let notes = FreeformEditorConfiguration(
        title: "Notes",
        systemImage: "note.text",
        placeholder: "Add context, preferences, or anything worth remembering",
        height: 92,
        containerIdentifier: "contact-notes-editor",
        fieldIdentifier: "contact-notes-field"
    )

    static func historyNote(systemImage: String) -> FreeformEditorConfiguration {
        FreeformEditorConfiguration(
            title: "History Note",
            systemImage: systemImage,
            placeholder: "Add a quick note about this interaction",
            height: 74,
            containerIdentifier: "interaction-summary-editor",
            fieldIdentifier: "interaction-summary-field"
        )
    }
}

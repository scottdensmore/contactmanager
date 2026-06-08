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
            Picker("Kind", selection: $interactionKind) {
                ForEach(ContactInteractionKind.allCases) { kind in
                    Label(kind.title, systemImage: kind.systemImage)
                        .tag(kind)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("interaction-kind-picker")

            TextField("Add a note", text: $interactionSummary, axis: .vertical)
                .lineLimit(2 ... 4)
                .accessibilityIdentifier("interaction-summary-field")

            Button {
                addInteraction()
            } label: {
                Label("Add to History", systemImage: "plus.circle.fill")
            }
            .disabled(interactionSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("add-interaction-button")

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
}

//
//  ImportReviewView.swift
//  ContactManager
//
//  Lets the user inspect parsed contacts before import and choose how each
//  likely duplicate should be handled.
//

import SwiftUI

struct ImportReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var items: [ImportReviewItem]
    var importAction: ([ImportReviewItem]) -> Void

    private var importCount: Int {
        items.filter { $0.decision != .skip }.count
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach($items) { $item in
                    ImportReviewRow(item: $item)
                }
            }
            .navigationTitle("Review Import")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(importButtonTitle) {
                        let reviewed = items
                        dismiss()
                        importAction(reviewed)
                    }
                    .disabled(importCount == 0)
                    .accessibilityIdentifier("confirm-reviewed-import-button")
                }
            }
        }
        .frame(minWidth: 560, minHeight: 420)
    }

    private var importButtonTitle: String {
        importCount == 1 ? "Import 1 Contact" : "Import \(importCount) Contacts"
    }
}

private struct ImportReviewRow: View {
    @Binding var item: ImportReviewItem

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayName)
                    .font(.headline)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let matched = item.matchedContact {
                    Text("Matches \(matched.fullName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("New contact")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Picker("Import Action", selection: $item.decision) {
                ForEach(item.availableDecisions) { decision in
                    Text(decision.title).tag(decision)
                }
            }
            .labelsHidden()
            .frame(width: 160)
            .accessibilityIdentifier("import-review-action-picker")
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("import-review-row-\(item.displayName.normalizedIdentifier)")
    }
}

private extension String {
    var normalizedIdentifier: String {
        lowercased()
            .map { $0.isLetter || $0.isNumber ? String($0) : "-" }
            .joined()
    }
}

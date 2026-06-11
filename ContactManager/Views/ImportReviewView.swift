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

    private var summary: ImportReviewPendingSummary {
        ImportReviewPendingSummary(items: items)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                reviewSummary
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                Divider()
                List {
                    ForEach($items) { $item in
                        ImportReviewRow(item: $item)
                    }
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
                    .disabled(summary.totalToWrite == 0)
                    .accessibilityIdentifier("confirm-reviewed-import-button")
                }
            }
        }
        .frame(minWidth: 560, minHeight: 420)
    }

    private var reviewSummary: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.reviewText)
                    .font(.headline)
                    .lineLimit(1)
                    .accessibilityLabel(summary.reviewText)
                    .accessibilityIdentifier("import-review-summary")
                Text(parsedContactCountText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("import-review-total-count")
            }
            Spacer()
            Menu {
                ForEach(ImportDecision.allCases) { decision in
                    Button("Set All to \(decision.title)") {
                        ImportReview.apply(decision, to: &items)
                    }
                    .disabled(!items.contains { $0.availableDecisions.contains(decision) })
                    .accessibilityIdentifier("import-review-batch-\(decision.rawValue)")
                }
            } label: {
                Label("Batch Actions", systemImage: "checklist")
            }
            .accessibilityIdentifier("import-review-batch-menu")
        }
    }

    private var importButtonTitle: String {
        summary.importButtonTitle
    }

    private var parsedContactCountText: String {
        items.count == 1 ? "1 parsed contact" : "\(items.count) parsed contacts"
    }
}

private struct ImportReviewRow: View {
    @Binding var item: ImportReviewItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
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
                    Text(matchDescription(matched))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("New contact")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                matchBadge
                Picker("Import Action", selection: $item.decision) {
                    ForEach(item.availableDecisions) { decision in
                        Text(decision.title).tag(decision)
                    }
                }
                .labelsHidden()
                .frame(width: 160)
                .accessibilityIdentifier("import-review-action-picker")
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("import-review-row-\(item.displayName.normalizedIdentifier)")
    }

    private var matchBadge: some View {
        Label(badgeTitle, systemImage: badgeImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(badgeColor)
            .lineLimit(1)
            .accessibilityIdentifier("import-review-confidence-badge")
    }

    private var badgeTitle: String {
        item.confidence?.title ?? "New"
    }

    private var badgeImage: String {
        switch item.confidence {
        case .exact: "checkmark.seal"
        case .likely: "person.crop.circle.badge.checkmark"
        case .possible: "questionmark.circle"
        case nil: "plus.circle"
        }
    }

    private var badgeColor: Color {
        switch item.confidence {
        case .exact: .green
        case .likely: .blue
        case .possible: .orange
        case nil: .secondary
        }
    }

    private func matchDescription(_ matched: Contact) -> String {
        let confidence = item.confidence?.title ?? "Possible match"
        if let reason = item.matchReason {
            return "\(confidence) · \(reason) · \(matched.fullName)"
        }
        return "\(confidence) · \(matched.fullName)"
    }
}

private extension String {
    var normalizedIdentifier: String {
        lowercased()
            .map { $0.isLetter || $0.isNumber ? String($0) : "-" }
            .joined()
    }
}

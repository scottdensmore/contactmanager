//
//  RestoreBackupPreviewView.swift
//  ContactManager
//
//  Restore confirmation sheet for decoded backups.
//

import SwiftUI

struct RestoreBackupPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    var preview: ContactBackupPreview
    var restoreAction: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Backup Contents") {
                    labeledRow("Exported", value: preview.exportedAt.formatted(date: .abbreviated, time: .shortened))
                    labeledRow("Summary", value: preview.summary)
                    labeledRow("Contacts", value: "\(preview.contactCount)")
                    labeledRow("Groups", value: "\(preview.groupCount)")
                    labeledRow("Smart Lists", value: "\(preview.savedSmartListCount)")
                    labeledRow("Emails", value: "\(preview.emailCount)")
                    labeledRow("Phones", value: "\(preview.phoneCount)")
                    labeledRow("History Notes", value: "\(preview.historyNoteCount)")
                    labeledRow("Photos", value: "\(preview.photoCount)")
                }

                if !preview.sampleContactNames.isEmpty {
                    Section("Sample Contacts") {
                        ForEach(preview.sampleContactNames, id: \.self) { name in
                            Text(name)
                        }
                    }
                }
            }
            .accessibilityIdentifier("restore-backup-preview")
            .navigationTitle("Review Backup")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(restoreButtonTitle) {
                        restoreAction()
                        dismiss()
                    }
                    .disabled(preview.isEmpty)
                    .accessibilityIdentifier("confirm-restore-backup-button")
                }
            }
        }
        .frame(minWidth: 460, minHeight: 420)
    }

    private var restoreButtonTitle: String {
        guard preview.contactCount > 0 else { return "Restore Backup" }
        return preview.contactCount == 1 ? "Restore 1 Contact" : "Restore \(preview.contactCount) Contacts"
    }

    private func labeledRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

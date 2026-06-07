//
//  ImportProgressView.swift
//  ContactManager
//
//  A small modal-style overlay shown while a vCard/CSV/system-Contacts import
//  is parsing and inserting, so a large file no longer looks like a frozen UI.
//

import SwiftUI

/// State for the import overlay. `total == nil` means the parse phase is still
/// running (indeterminate); once inserting begins, `total` is the contact count
/// and `done` climbs per saved chunk.
struct ImportProgress: Equatable {
    var done = 0
    var total: Int?
}

struct ImportProgressView: View {
    let progress: ImportProgress

    var body: some View {
        VStack(spacing: 12) {
            if let total = progress.total {
                ProgressView(value: Double(progress.done), total: Double(max(total, 1))) {
                    Text("Importing Contacts")
                }
                Text("\(progress.done) of \(total)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } else {
                ProgressView { Text("Preparing Import…") }
            }
        }
        .padding(24)
        .frame(width: 260)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        guard let total = progress.total else { return "Preparing import" }
        return "Importing contacts, \(progress.done) of \(total)"
    }
}

//
//  DuplicatesView.swift
//  ContactManager
//
//  A review sheet listing groups of likely-duplicate contacts, each with a
//  Merge action. Detection is delegated to the pure `DuplicateFinder`; merging
//  goes through `ContactStore`.
//

import SwiftData
import SwiftUI

struct DuplicatesView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\Contact.lastName), SortDescriptor(\Contact.firstName)])
    private var contacts: [Contact]

    @State private var errorMessage: String?

    private var store: ContactStore { ContactStore(context) }

    private var duplicateGroups: [DuplicateGroup] {
        DuplicateFinder.duplicateGroups(in: contacts).map { group in
            DuplicateGroup(id: group.map(\.persistentModelID).hashValue, contacts: group)
        }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Duplicates")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                .alert(
                    "Couldn't Merge",
                    isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }),
                    presenting: errorMessage
                ) { _ in
                    Button("OK", role: .cancel) {}
                } message: { message in
                    Text(message)
                }
        }
        .frame(minWidth: 440, minHeight: 380)
    }

    @ViewBuilder
    private var content: some View {
        if duplicateGroups.isEmpty {
            ContentUnavailableView(
                "No Duplicates",
                systemImage: "person.crop.circle.badge.checkmark",
                description: Text("Every contact looks unique.")
            )
        } else {
            List {
                ForEach(duplicateGroups) { group in
                    Section {
                        ForEach(group.contacts) { contact in
                            DuplicateRow(contact: contact)
                        }
                    } header: {
                        HStack {
                            Text("^[\(group.contacts.count) possible duplicate](inflect: true)")
                            Spacer()
                            Button("Merge") { merge(group.contacts) }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
        }
    }

    private func merge(_ group: [Contact]) {
        do {
            try store.merge(group)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct DuplicateGroup: Identifiable {
    let id: Int
    let contacts: [Contact]
}

private struct DuplicateRow: View {
    let contact: Contact

    var body: some View {
        HStack(spacing: 10) {
            AvatarView(contact: contact, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(contact.fullName)
                if let subtitle = contact.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

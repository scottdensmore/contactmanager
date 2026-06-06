//
//  SettingsView.swift
//  ContactManager
//
//  The macOS Settings scene (ContactManager ▸ Settings…, ⌘,). All values
//  are persisted via `@AppStorage` and read directly by the views that
//  care, so changes apply live without any plumbing.
//

import SwiftData
import SwiftUI

struct SettingsView: View {
    @AppStorage("contactSortOrder") private var sortOrder: ContactSortOrder = .lastName
    /// JSON-encoded `PersistentIdentifier` of the default group, or "" for
    /// "no group". Storing the PID (not the group's name) means renaming the
    /// group keeps the preference pointed at the right model and avoids
    /// ambiguity when two groups share a name.
    @AppStorage("defaultGroupID") private var defaultGroupID: String = ""

    @Query(sort: \ContactGroup.name) private var groups: [ContactGroup]

    var body: some View {
        Form {
            Section("Defaults") {
                Picker("Sort Contacts By", selection: $sortOrder) {
                    ForEach(ContactSortOrder.allCases) { order in
                        Text(order.title).tag(order)
                    }
                }

                Picker("New Contact Joins", selection: $defaultGroupID) {
                    Text("No Group").tag("")
                    if !groups.isEmpty {
                        Divider()
                        ForEach(groups) { group in
                            Text(group.displayName)
                                .tag(group.persistentModelID.storedString ?? "")
                        }
                    }
                }
                .help("When the sidebar is on All Contacts, new contacts join this group.")
            }

            Section {
                Button("Restore Defaults", role: .destructive) {
                    sortOrder = .lastName
                    defaultGroupID = ""
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 240)
        // Prune the preference if its target group was renamed (the encoded
        // PID stays valid) or deleted (the lookup now misses) — keeps the
        // picker's selection consistent with what's actually on disk.
        .onChange(of: groups) { _, _ in pruneStaleDefaultGroup() }
        .onAppear { pruneStaleDefaultGroup() }
    }

    private func pruneStaleDefaultGroup() {
        guard !defaultGroupID.isEmpty,
              let id = PersistentIdentifier.decode(stored: defaultGroupID)
        else {
            if !defaultGroupID.isEmpty { defaultGroupID = "" }
            return
        }
        guard groups.contains(where: { $0.persistentModelID == id }) else {
            defaultGroupID = ""
            return
        }
        // Re-store in the canonical (sorted-key) encoding. A value written by
        // an older build used a non-deterministic key order, so its string
        // wouldn't match the freshly-encoded picker tags; normalizing here
        // keeps the selection highlighted without a separate migration.
        if let canonical = id.storedString, canonical != defaultGroupID {
            defaultGroupID = canonical
        }
    }
}

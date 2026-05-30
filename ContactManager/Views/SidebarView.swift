//
//  SidebarView.swift
//  ContactManager
//
//  Leading column: the built-in "All Contacts" smart group plus user-defined
//  groups, with create / rename / delete.
//

import SwiftData
import SwiftUI

enum SidebarItem: Hashable {
    case allContacts
    case group(PersistentIdentifier)
}

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    let contactCount: Int
    let groups: [ContactGroup]
    var addGroup: () -> Void
    var renameGroup: (ContactGroup, String) -> Void
    var deleteGroup: (ContactGroup) -> Void

    @State private var renameTarget: ContactGroup?
    @State private var renameText = ""

    var body: some View {
        List(selection: $selection) {
            Section("Contacts") {
                Label("All Contacts", systemImage: "person.2.fill")
                    .badge(contactCount)
                    .tag(SidebarItem.allContacts)
            }

            Section("Groups") {
                if groups.isEmpty {
                    Text("Use the + button above to add one.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(groups) { group in
                        Label(group.displayName, systemImage: "folder")
                            .badge(group.contacts.count)
                            .tag(SidebarItem.group(group.persistentModelID))
                            .contextMenu {
                                Button("Rename…") { beginRename(group) }
                                Button("Delete", role: .destructive) { deleteGroup(group) }
                            }
                    }
                }
            }
        }
        .navigationTitle("Groups")
        .navigationSplitViewColumnWidth(min: 180, ideal: 215, max: 320)
        .toolbar {
            ToolbarItem {
                Button(action: addGroup) {
                    Label("New Group", systemImage: "folder.badge.plus")
                }
                .help("New Group")
            }
        }
        .alert("Rename Group", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) { renameTarget = nil }
            Button("Rename") {
                if let target = renameTarget { renameGroup(target, renameText) }
                renameTarget = nil
            }
        }
    }

    private func beginRename(_ group: ContactGroup) {
        renameText = group.name
        renameTarget = group
    }
}

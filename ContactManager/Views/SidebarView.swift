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
    case smartList(ContactSmartList)
    case group(PersistentIdentifier)
}

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    let contactCount: Int
    let smartListCounts: [ContactSmartList: Int]
    let groups: [ContactGroup]
    var addGroup: () -> Void
    var renameGroup: (ContactGroup, String) -> Void
    var deleteGroup: (ContactGroup) -> Void
    /// Adds the dropped contacts (by encoded id) to a group — sidebar drag target.
    var addContacts: ([String], ContactGroup) -> Void

    @State private var renameTarget: ContactGroup?
    @State private var renameText = ""

    var body: some View {
        List(selection: $selection) {
            Section("Contacts") {
                Label("All Contacts", systemImage: "person.2.fill")
                    .badge(contactCount)
                    .tag(SidebarItem.allContacts)
                    .accessibilityIdentifier("sidebar-all-contacts-row")
            }

            Section("Smart Lists") {
                ForEach(ContactSmartList.allCases) { smartList in
                    Label(smartList.title, systemImage: smartList.systemImage)
                        .badge(smartListCounts[smartList] ?? 0)
                        .tag(SidebarItem.smartList(smartList))
                        .accessibilityIdentifier("sidebar-smart-list-row-\(smartList.rawValue)")
                }
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
                            .accessibilityIdentifier("sidebar-group-row-\(group.displayName.normalizedIdentifier)")
                            .contextMenu {
                                Button("Rename…") { beginRename(group) }
                                Button("Delete", role: .destructive) { deleteGroup(group) }
                            }
                            // Drag contacts from the list onto a group to add
                            // them. The transfer exposes the contact id as text;
                            // reject drops that carry no valid contact id (e.g.
                            // unrelated selected text) so they aren't "accepted".
                            .dropDestination(for: String.self) { ids, _ in
                                let valid = ids.filter { PersistentIdentifier.decode(stored: $0) != nil }
                                guard !valid.isEmpty else { return false }
                                addContacts(valid, group)
                                return true
                            }
                    }
                }
            }
        }
        .navigationTitle("Groups")
        .navigationSplitViewColumnWidth(
            min: LayoutMetrics.sidebarMinWidth,
            ideal: LayoutMetrics.sidebarIdealWidth,
            max: LayoutMetrics.sidebarMaxWidth
        )
        .toolbar {
            // `.primaryAction` keeps + visible at every window width;
            // the default `.automatic` placement lets the chevron eat it.
            ToolbarItem(placement: .primaryAction) {
                Button(action: addGroup) {
                    Label("New Group", systemImage: "folder.badge.plus")
                }
                .help("New Group")
                .accessibilityIdentifier("new-group-button")
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

private extension String {
    var normalizedIdentifier: String {
        lowercased()
            .map { $0.isLetter || $0.isNumber ? String($0) : "-" }
            .joined()
    }
}

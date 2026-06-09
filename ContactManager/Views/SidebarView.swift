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
    case savedSmartList(PersistentIdentifier)
    case group(PersistentIdentifier)
    case tag(PersistentIdentifier)
}

struct SidebarView: View {
    @Environment(\.cloudSyncStatus) private var cloudSyncStatus

    @Binding var selection: SidebarItem?
    let contactCount: Int
    let smartListCounts: [ContactSmartList: Int]
    let savedSmartLists: [ContactSavedSmartList]
    let savedSmartListCounts: [PersistentIdentifier: Int]
    let groups: [ContactGroup]
    let tags: [ContactTag]
    var addGroup: () -> Void
    var addTag: () -> Void
    var renameSavedSmartList: (ContactSavedSmartList, String) -> Void
    var deleteSavedSmartList: (ContactSavedSmartList) -> Void
    var renameGroup: (ContactGroup, String) -> Void
    var deleteGroup: (ContactGroup) -> Void
    var renameTag: (ContactTag, String) -> Void
    var deleteTag: (ContactTag) -> Void
    /// Adds the dropped contacts (by encoded id) to a group — sidebar drag target.
    var addContactsToGroup: ([String], ContactGroup) -> Void
    /// Adds the dropped contacts (by encoded id) to a tag — sidebar drag target.
    var addContactsToTag: ([String], ContactTag) -> Void

    @State private var renameTarget: ContactGroup?
    @State private var renameTagTarget: ContactTag?
    @State private var renameSavedSmartListTarget: ContactSavedSmartList?
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

                ForEach(savedSmartLists) { savedList in
                    Label(savedList.displayName, systemImage: "line.3.horizontal.decrease.circle")
                        .badge(savedSmartListCounts[savedList.persistentModelID] ?? 0)
                        .tag(SidebarItem.savedSmartList(savedList.persistentModelID))
                        .accessibilityIdentifier(
                            "sidebar-saved-smart-list-row-\(savedList.displayName.normalizedIdentifier)"
                        )
                        .contextMenu {
                            Button("Rename…") { beginRename(savedList) }
                            Button("Delete", role: .destructive) { deleteSavedSmartList(savedList) }
                        }
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
                                addContactsToGroup(valid, group)
                                return true
                            }
                    }
                }
            }

            Section("Tags") {
                if tags.isEmpty {
                    Text("Use the tag button above to add one.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(tags) { tag in
                        Label(tag.displayName, systemImage: "tag")
                            .badge(tag.contacts.count)
                            .tag(SidebarItem.tag(tag.persistentModelID))
                            .accessibilityIdentifier("sidebar-tag-row-\(tag.displayName.normalizedIdentifier)")
                            .contextMenu {
                                Button("Rename…") { beginRename(tag) }
                                Button("Delete", role: .destructive) { deleteTag(tag) }
                            }
                            .dropDestination(for: String.self) { ids, _ in
                                let valid = ids.filter { PersistentIdentifier.decode(stored: $0) != nil }
                                guard !valid.isEmpty else { return false }
                                addContactsToTag(valid, tag)
                                return true
                            }
                    }
                }
            }

            Section("Sync") {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cloudSyncStatus.title)
                        Text(cloudSyncStatus.shortMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: cloudSyncStatus.systemImage)
                }
                .accessibilityIdentifier("sidebar-sync-status")
            }
        }
        .navigationTitle("Contacts")
        .navigationSplitViewColumnWidth(
            min: LayoutMetrics.sidebarMinWidth,
            ideal: LayoutMetrics.sidebarIdealWidth,
            max: LayoutMetrics.sidebarMaxWidth
        )
        .toolbar {
            // `.primaryAction` keeps + visible at every window width;
            // the default `.automatic` placement lets the chevron eat it.
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 8) {
                    Button(action: addGroup) {
                        Label("New Group", systemImage: "folder.badge.plus")
                    }
                    .help("New Group")
                    .accessibilityIdentifier("new-group-button")

                    Button(action: addTag) {
                        Label("New Tag", systemImage: "tag")
                    }
                    .help("New Tag")
                    .accessibilityIdentifier("new-tag-button")
                }
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
        .alert("Rename Smart List", isPresented: Binding(
            get: { renameSavedSmartListTarget != nil },
            set: { if !$0 { renameSavedSmartListTarget = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) { renameSavedSmartListTarget = nil }
            Button("Rename") {
                if let target = renameSavedSmartListTarget {
                    renameSavedSmartList(target, renameText)
                }
                renameSavedSmartListTarget = nil
            }
        }
        .alert("Rename Tag", isPresented: Binding(
            get: { renameTagTarget != nil },
            set: { if !$0 { renameTagTarget = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) { renameTagTarget = nil }
            Button("Rename") {
                if let target = renameTagTarget { renameTag(target, renameText) }
                renameTagTarget = nil
            }
        }
    }

    private func beginRename(_ group: ContactGroup) {
        renameText = group.name
        renameTarget = group
    }

    private func beginRename(_ tag: ContactTag) {
        renameText = tag.name
        renameTagTarget = tag
    }

    private func beginRename(_ savedList: ContactSavedSmartList) {
        renameText = savedList.displayName
        renameSavedSmartListTarget = savedList
    }
}

private extension String {
    var normalizedIdentifier: String {
        lowercased()
            .map { $0.isLetter || $0.isNumber ? String($0) : "-" }
            .joined()
    }
}

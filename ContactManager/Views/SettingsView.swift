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
    /// The default group is stored by name rather than `PersistentIdentifier`
    /// because PI isn't a friendly `@AppStorage` value; the trade-off is that
    /// renaming a group silently clears the default.
    @AppStorage("defaultGroupName") private var defaultGroupName: String = ""

    @Query(sort: \ContactGroup.name) private var groups: [ContactGroup]

    var body: some View {
        Form {
            Section("Defaults") {
                Picker("Sort Contacts By", selection: $sortOrder) {
                    ForEach(ContactSortOrder.allCases) { order in
                        Text(order.title).tag(order)
                    }
                }

                Picker("New Contact Joins", selection: $defaultGroupName) {
                    Text("No Group").tag("")
                    if !groups.isEmpty {
                        Divider()
                        ForEach(groups) { group in
                            Text(group.displayName).tag(group.name)
                        }
                    }
                }
                .help("When the sidebar is on All Contacts, new contacts join this group.")
            }

            Section {
                Button("Restore Defaults", role: .destructive) {
                    sortOrder = .lastName
                    defaultGroupName = ""
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 240)
    }
}

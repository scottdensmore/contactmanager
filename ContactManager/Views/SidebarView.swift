//
//  SidebarView.swift
//  ContactManager
//
//  Leading column of the split view. For now it lists the built-in "All
//  Contacts" smart group; user-defined groups arrive in a later milestone.
//

import SwiftUI

enum SidebarItem: Hashable {
    case allContacts
}

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    let contactCount: Int

    var body: some View {
        List(selection: $selection) {
            Section("Contacts") {
                Label("All Contacts", systemImage: "person.2.fill")
                    .badge(contactCount)
                    .tag(SidebarItem.allContacts)
            }
        }
        .navigationTitle("Groups")
        .navigationSplitViewColumnWidth(min: 180, ideal: 215, max: 320)
    }
}

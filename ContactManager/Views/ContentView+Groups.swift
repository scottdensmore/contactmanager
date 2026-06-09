//
//  ContentView+Groups.swift
//  ContactManager
//
//  Sidebar group mutations.
//

import SwiftUI

extension ContentView {
    func addGroup() {
        do {
            let group = try store.createGroup()
            withAnimation(reduceMotion ? nil : .snappy) { sidebarSelection = .group(group.persistentModelID) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addContacts(encodedIDs ids: [String], to group: ContactGroup) {
        do {
            try store.addContacts(withEncodedIDs: ids, to: group)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renameGroup(_ group: ContactGroup, to name: String) {
        do {
            try store.rename(group, to: name)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteGroup(_ group: ContactGroup) {
        let wasSelected = sidebarSelection == .group(group.persistentModelID)
        do {
            try store.delete(group)
            if wasSelected { sidebarSelection = .allContacts }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

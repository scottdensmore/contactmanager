//
//  ContentView+Tags.swift
//  ContactManager
//
//  Sidebar tag mutations.
//

import SwiftUI

extension ContentView {
    func addTag() {
        do {
            let tag = try store.createTag()
            withAnimation(reduceMotion ? nil : .snappy) { sidebarSelection = .tag(tag.persistentModelID) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addContacts(encodedIDs ids: [String], to tag: ContactTag) {
        do {
            try store.addContacts(withEncodedIDs: ids, to: tag)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renameTag(_ tag: ContactTag, to name: String) {
        do {
            try store.rename(tag, to: name)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteTag(_ tag: ContactTag) {
        let wasSelected = sidebarSelection == .tag(tag.persistentModelID)
        do {
            try store.delete(tag)
            if wasSelected { sidebarSelection = .allContacts }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

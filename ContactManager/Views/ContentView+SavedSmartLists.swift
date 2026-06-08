//
//  ContentView+SavedSmartLists.swift
//  ContactManager
//
//  Saved-search selection and mutation actions.
//

import SwiftData
import SwiftUI

extension ContentView {
    var selectedSavedSmartList: ContactSavedSmartList? {
        guard case .savedSmartList(let id) = sidebarSelection else { return nil }
        return savedSmartLists.first { $0.persistentModelID == id }
    }

    var savedSmartListCounts: [PersistentIdentifier: Int] {
        Dictionary(uniqueKeysWithValues: savedSmartLists.map { savedList in
            (savedList.persistentModelID, ContactQuery.filtered(contacts, by: savedList).count)
        })
    }

    func saveCurrentSearchAsSmartList() {
        do {
            let savedList = try store.createSavedSmartList(query: searchText)
            withAnimation(reduceMotion ? nil : .snappy) {
                sidebarSelection = .savedSmartList(savedList.persistentModelID)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renameSavedSmartList(_ savedList: ContactSavedSmartList, to name: String) {
        do {
            try store.rename(savedList, to: name)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteSavedSmartList(_ savedList: ContactSavedSmartList) {
        let wasSelected = sidebarSelection == .savedSmartList(savedList.persistentModelID)
        do {
            try store.delete(savedList)
            if wasSelected { sidebarSelection = .allContacts }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

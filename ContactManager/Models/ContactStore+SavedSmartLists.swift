//
//  ContactStore+SavedSmartLists.swift
//  ContactManager
//
//  Durable mutations for user-saved contact searches.
//

import Foundation

extension ContactStore {
    @discardableResult
    func createSavedSmartList(named name: String? = nil, query: String) throws -> ContactSavedSmartList {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { throw ContactStoreError.blankSavedSmartListQuery }

        let trimmedName = (name ?? trimmedQuery).trimmingCharacters(in: .whitespacesAndNewlines)
        return try mutate("New Smart List") {
            let savedList = ContactSavedSmartList(name: trimmedName, query: trimmedQuery)
            context.insert(savedList)
            return savedList
        }
    }

    func rename(_ savedList: ContactSavedSmartList, to name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try mutate("Rename Smart List") {
            savedList.name = trimmed
        }
    }

    func delete(_ savedList: ContactSavedSmartList) throws {
        try mutate("Delete Smart List") {
            context.delete(savedList)
        }
    }
}

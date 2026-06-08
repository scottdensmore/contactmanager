//
//  ContactSavedSmartList.swift
//  ContactManager
//
//  A user-saved contact search that stays live as contacts change.
//

import Foundation
import SwiftData

@Model
final class ContactSavedSmartList {
    var name: String = ""
    var query: String = ""
    var createdAt: Date = Date.now

    init(name: String = "", query: String = "", createdAt: Date = .now) {
        self.name = name
        self.query = query
        self.createdAt = createdAt
    }
}

extension ContactSavedSmartList {
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedQuery.isEmpty ? "Untitled Smart List" : trimmedQuery
    }
}

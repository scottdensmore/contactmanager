//
//  ContactTag.swift
//  ContactManager
//
//  A lightweight user-defined label that can be assigned to many contacts.
//

import Foundation
import SwiftData

@Model
final class ContactTag {
    var name: String = ""
    var createdAt: Date = Date.now

    /// Contacts carrying this tag. Deleting a tag nullifies membership rather
    /// than deleting the contacts themselves.
    @Relationship(deleteRule: .nullify, inverse: \Contact.tags)
    var contacts: [Contact] = []

    init(name: String = "", createdAt: Date = .now) {
        self.name = name
        self.createdAt = createdAt
    }
}

extension ContactTag {
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Tag" : trimmed
    }
}

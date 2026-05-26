//
//  ContactGroup.swift
//  ContactManager
//
//  A user-defined group/tag that contacts can belong to (many-to-many).
//

import Foundation
import SwiftData

@Model
final class ContactGroup {
    var name: String = ""
    var createdAt: Date = Date.now

    /// Members of this group. Deleting a group nullifies membership rather
    /// than deleting the contacts themselves.
    @Relationship(deleteRule: .nullify, inverse: \Contact.groups)
    var contacts: [Contact] = []

    init(name: String = "", createdAt: Date = .now) {
        self.name = name
        self.createdAt = createdAt
    }
}

extension ContactGroup {
    /// Group name shown in the UI, falling back to a placeholder.
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Untitled Group" : trimmed
    }
}

//
//  ContactQuery.swift
//  ContactManager
//
//  Pure, testable helpers for filtering and sorting contacts. Keeping this
//  logic out of the views makes it straightforward to unit test.
//

import Foundation

enum ContactQuery {
    /// Sorts contacts by last name, then first name, case-insensitively.
    static func sorted(_ contacts: [Contact]) -> [Contact] {
        contacts.sorted { lhs, rhs in
            if lhs.sortKey != rhs.sortKey {
                return lhs.sortKey < rhs.sortKey
            }
            return lhs.firstNameSortKey < rhs.firstNameSortKey
        }
    }

    /// Filters contacts whose name, company, job title, notes, or any email/
    /// phone field value contains the query. An empty query returns every
    /// contact unchanged.
    static func filtered(_ contacts: [Contact], matching query: String) -> [Contact] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return contacts }

        return contacts.filter { contact in
            let haystacks = [
                contact.fullName,
                contact.company,
                contact.jobTitle,
                contact.notes,
            ] + contact.fields.map(\.value)

            return haystacks.contains { $0.lowercased().contains(needle) }
        }
    }
}

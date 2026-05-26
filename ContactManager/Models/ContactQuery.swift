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

    /// Filters contacts whose name, email, or phone contains the query.
    /// An empty query returns every contact unchanged.
    static func filtered(_ contacts: [Contact], matching query: String) -> [Contact] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return contacts }

        return contacts.filter { contact in
            contact.fullName.lowercased().contains(needle)
                || contact.emailAddress.lowercased().contains(needle)
                || contact.phoneNumber.lowercased().contains(needle)
        }
    }
}

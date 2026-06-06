//
//  ContactQuery.swift
//  ContactManager
//
//  Pure, testable helpers for filtering, sorting, and sectioning contacts.
//  Keeping this logic out of the views makes it straightforward to unit test.
//

import Foundation

/// The order contacts are sorted and grouped by.
enum ContactSortOrder: String, CaseIterable, Identifiable {
    case lastName
    case firstName

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lastName: "Last Name"
        case .firstName: "First Name"
        }
    }
}

/// An alphabetical group of contacts, titled by initial ("A"…"Z" or "#").
struct ContactSection: Identifiable {
    let title: String
    let contacts: [Contact]
    var id: String { title }
}

enum ContactQuery {
    /// Sorts contacts by the given order's primary key, then its secondary key.
    static func sorted(_ contacts: [Contact], by order: ContactSortOrder = .lastName) -> [Contact] {
        contacts.sorted { lhs, rhs in
            let lhsKeys = lhs.sortKeys(for: order)
            let rhsKeys = rhs.sortKeys(for: order)
            if lhsKeys.primary != rhsKeys.primary {
                return lhsKeys.primary < rhsKeys.primary
            }
            return lhsKeys.secondary < rhsKeys.secondary
        }
    }

    /// Filters contacts whose name, company, job title, notes, or any email/
    /// phone field value contains the query. An empty query returns every
    /// contact unchanged.
    ///
    /// Uses `localizedCaseInsensitiveContains` (no per-string `.lowercased()`
    /// allocation) and short-circuits on the cheap scalar attributes before
    /// walking the to-many `fields` relationship.
    static func filtered(_ contacts: [Contact], matching query: String) -> [Contact] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return contacts }

        return contacts.filter { contact in
            if contact.fullName.localizedCaseInsensitiveContains(needle) { return true }
            if contact.company.localizedCaseInsensitiveContains(needle) { return true }
            if contact.jobTitle.localizedCaseInsensitiveContains(needle) { return true }
            if contact.notes.localizedCaseInsensitiveContains(needle) { return true }
            return contact.fields.contains { $0.value.localizedCaseInsensitiveContains(needle) }
        }
    }

    /// Groups contacts into alphabetical sections by their initial, sorted
    /// within each section. Names that don't start with a letter land in a
    /// trailing "#" section.
    static func sections(_ contacts: [Contact], by order: ContactSortOrder = .lastName) -> [ContactSection] {
        let ordered = sorted(contacts, by: order)
        let grouped = Dictionary(grouping: ordered) { sectionTitle(for: $0, order: order) }

        let titles = grouped.keys.sorted { lhs, rhs in
            if lhs == "#" { return false } // "#" always sorts last
            if rhs == "#" { return true }
            return lhs < rhs
        }

        return titles.map { ContactSection(title: $0, contacts: grouped[$0] ?? []) }
    }

    private static func sectionTitle(for contact: Contact, order: ContactSortOrder) -> String {
        guard let first = contact.sortKeys(for: order).primary.first, first.isLetter else {
            return "#"
        }
        return String(first).uppercased()
    }
}

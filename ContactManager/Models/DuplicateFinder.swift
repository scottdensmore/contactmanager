//
//  DuplicateFinder.swift
//  ContactManager
//
//  Pure, testable duplicate detection. Two contacts are treated as duplicates
//  when they share a normalized email, phone number, or full name. Matches are
//  surfaced for the user to review before merging, so the heuristic favors
//  recall over precision.
//

import Foundation

enum DuplicateFinder {
    /// Groups of contacts that look like duplicates of one another. Only groups
    /// with more than one contact are returned, each sorted, and the groups are
    /// ordered for stable presentation.
    static func duplicateGroups(in contacts: [Contact]) -> [[Contact]] {
        guard contacts.count > 1 else { return [] }

        var unionFind = UnionFind(count: contacts.count)
        var ownerOfKey: [ContactMatchKey: Int] = [:]

        for (index, contact) in contacts.enumerated() {
            for key in matchKeys(for: contact) {
                if let owner = ownerOfKey[key] {
                    unionFind.union(owner, index)
                } else {
                    ownerOfKey[key] = index
                }
            }
        }

        var groupsByRoot: [Int: [Contact]] = [:]
        for index in contacts.indices {
            groupsByRoot[unionFind.root(of: index), default: []].append(contacts[index])
        }

        return groupsByRoot.values
            .filter { $0.count > 1 }
            .map { ContactQuery.sorted($0) }
            .sorted { ($0.first?.sortKey ?? "") < ($1.first?.sortKey ?? "") }
    }

    /// Normalized keys identifying a contact for matching. A shared key between
    /// two contacts marks them as duplicates.
    static func matchKeys(for contact: Contact) -> Set<ContactMatchKey> {
        ContactMatchKey.keys(
            firstName: contact.firstName,
            lastName: contact.lastName,
            emails: contact.emails.map(\.value),
            phones: contact.phones.map(\.value)
        )
    }
}

/// A normalized identity fragment used for duplicate detection and import
/// review. Shared by `DuplicateFinder` and `ImportReview` so both features
/// agree on what counts as "the same person".
enum ContactMatchKey: Hashable {
    case email(String)
    case phone(String)
    case name(String)

    static func keys(
        firstName: String,
        lastName: String,
        emails: [String],
        phones: [String]
    ) -> Set<ContactMatchKey> {
        var keys: Set<ContactMatchKey> = []

        for email in emails {
            let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !normalized.isEmpty { keys.insert(.email(normalized)) }
        }
        for phone in phones {
            let digits = String(phone.filter(\.isNumber))
            // Ignore very short fragments (e.g. extensions) to avoid false matches.
            if digits.count >= 7 { keys.insert(.phone(digits)) }
        }

        let name = [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if !name.isEmpty { keys.insert(.name(name)) }

        return keys
    }
}

/// Minimal weighted-free union-find with path compression, over array indices.
private struct UnionFind {
    private var parent: [Int]

    init(count: Int) {
        parent = Array(0 ..< count)
    }

    mutating func root(of index: Int) -> Int {
        var current = index
        while parent[current] != current {
            parent[current] = parent[parent[current]] // path halving
            current = parent[current]
        }
        return current
    }

    mutating func union(_ lhs: Int, _ rhs: Int) {
        let lhsRoot = root(of: lhs)
        let rhsRoot = root(of: rhs)
        if lhsRoot != rhsRoot { parent[lhsRoot] = rhsRoot }
    }
}

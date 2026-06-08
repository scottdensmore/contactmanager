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

/// Built-in relationship-oriented lists. They are computed locally from the
/// contact model rather than persisted, so they stay current as edits save.
enum ContactSmartList: String, CaseIterable, Identifiable, Hashable {
    case recentlyContacted
    case needsFollowUp
    case noEmail
    case birthdaysSoon

    static let recentContactDays = 14
    static let followUpDays = 30
    static let birthdayWindowDays = 30

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recentlyContacted: "Recently Contacted"
        case .needsFollowUp: "Needs Follow-up"
        case .noEmail: "No Email"
        case .birthdaysSoon: "Birthdays Soon"
        }
    }

    var systemImage: String {
        switch self {
        case .recentlyContacted: "clock.arrow.circlepath"
        case .needsFollowUp: "bell.badge"
        case .noEmail: "envelope.badge"
        case .birthdaysSoon: "gift"
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

    static func filtered(
        _ contacts: [Contact],
        by smartList: ContactSmartList,
        now: Date = .now
    ) -> [Contact] {
        contacts.filter { contact in
            switch smartList {
            case .recentlyContacted:
                guard let lastContactedAt = contact.lastContactedAt else { return false }
                let daysSinceContact = daysBetween(lastContactedAt, and: now)
                return daysSinceContact >= 0 && daysSinceContact <= ContactSmartList.recentContactDays
            case .needsFollowUp:
                guard let lastContactedAt = contact.lastContactedAt else { return true }
                let daysSinceContact = daysBetween(lastContactedAt, and: now)
                return daysSinceContact > ContactSmartList.followUpDays
            case .noEmail:
                return contact.primaryEmail == nil
            case .birthdaysSoon:
                guard let birthday = contact.birthday else { return false }
                return birthdayIsSoon(birthday, now: now)
            }
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

    private static func daysBetween(_ start: Date, and end: Date) -> Int {
        let startOfStart = Birthday.calendar.startOfDay(for: start)
        let startOfEnd = Birthday.calendar.startOfDay(for: end)
        return Birthday.calendar.dateComponents([.day], from: startOfStart, to: startOfEnd).day ?? 0
    }

    private static func birthdayIsSoon(_ birthday: Date, now: Date) -> Bool {
        let today = Birthday.calendar.startOfDay(for: now)
        let fields = Birthday.fields(of: birthday)
        let currentYear = Birthday.calendar.component(.year, from: today)
        let nextBirthday = birthdayDate(month: fields.month, day: fields.day, year: currentYear, today: today)
        let days = Birthday.calendar.dateComponents([.day], from: today, to: nextBirthday).day
        return (days ?? Int.max) <= ContactSmartList.birthdayWindowDays
    }

    private static func birthdayDate(month: Int, day: Int, year: Int, today: Date) -> Date {
        for candidateYear in year ... (year + 4) {
            let candidate = exactBirthdayDate(month: month, day: day, year: candidateYear)
                ?? Birthday.date(
                    year: candidateYear,
                    month: month,
                    day: Birthday.clampDay(day, month: month, year: candidateYear)
                )
            if let candidate, candidate >= today {
                return candidate
            }
        }
        return today
    }

    private static func exactBirthdayDate(month: Int, day: Int, year: Int) -> Date? {
        guard let date = Birthday.date(year: year, month: month, day: day) else { return nil }
        let fields = Birthday.fields(of: date)
        return fields.month == month && fields.day == day ? date : nil
    }
}

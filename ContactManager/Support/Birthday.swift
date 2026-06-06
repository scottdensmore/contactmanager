//
//  Birthday.swift
//  ContactManager
//
//  A birthday is a date-only value, but the model persists it as `Date`
//  (retyping the stored attribute would break the CloudKit schema, whose
//  fields can only be added, not changed). To keep "the day" unambiguous
//  regardless of the device's time zone — and across CloudKit sync between
//  devices in different zones — every birthday `Date` is anchored to UTC and
//  always read back through the same calendar here. Without this, a `Date`
//  set at local midnight in one zone reads as the previous/next day in
//  another (the Tokyo→US day-shift).
//

import Foundation

enum Birthday {
    /// Gregorian calendar pinned to UTC — the single source of truth for
    /// turning a birthday into and out of a `Date`. Used by `VCard`,
    /// `ContactsBridge`, and the detail-view `DatePicker` so all three agree
    /// on which calendar day a stored `Date` represents.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    /// Year stored for birthdays whose source omitted it (a vCard `--MMDD`,
    /// or a Contacts card with no year). Predates any living person, so export
    /// can recognize it and round-trip back to the year-less form rather than
    /// emitting a fabricated year.
    static let omittedYear = 1604

    /// Builds a UTC-anchored birthday `Date` from calendar fields. A `nil`
    /// `year` means "year unknown" and stores the sentinel.
    static func date(year: Int?, month: Int, day: Int) -> Date? {
        var components = DateComponents()
        components.year = year ?? omittedYear
        components.month = month
        components.day = day
        return calendar.date(from: components)
    }

    /// A birthday split into UTC calendar fields. `year` is `nil` when the
    /// source omitted it (the sentinel).
    struct Fields {
        var year: Int?
        var month: Int
        var day: Int
    }

    /// Splits a birthday `Date` back into UTC calendar fields, reporting
    /// `year == nil` when it carries the omitted-year sentinel.
    static func fields(of date: Date) -> Fields {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year == omittedYear ? nil : parts.year
        return Fields(year: year, month: parts.month ?? 1, day: parts.day ?? 1)
    }
}

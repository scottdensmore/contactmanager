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
    /// or a Contacts card with no year), so export can recognize it and
    /// round-trip back to the year-less form rather than emitting a
    /// fabricated year. A *future* leap year: impossible for a real (past)
    /// birthday — so a genuine historical year like 1604 keeps its year — and
    /// a leap year so a year-less Feb 29 survives.
    static let omittedYear = 9996

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

    /// Parses a date-only birthday string into a UTC-anchored `Date`. Accepts
    /// the year-less `--MMDD` / `--MM-DD` forms (storing the sentinel year) as
    /// well as `YYYY-MM-DD` / `YYYYMMDD`, ignoring any `T` time suffix.
    /// Returns `nil` when no month/day can be read, so junk is dropped rather
    /// than mis-parsed. Shared by the vCard and CSV importers so every entry
    /// path lands on the same UTC convention.
    static func parse(_ string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("--") {
            let digits = trimmed.dropFirst(2).filter(\.isNumber)
            guard digits.count >= 4,
                  let month = Int(digits.prefix(2)),
                  let day = Int(digits.dropFirst(2).prefix(2))
            else { return nil }
            return date(year: nil, month: month, day: day)
        }
        let datePart = trimmed.split(separator: "T").first.map(String.init) ?? trimmed
        let digits = datePart.filter(\.isNumber)
        guard digits.count >= 8,
              let year = Int(digits.prefix(4)),
              let month = Int(digits.dropFirst(4).prefix(2)),
              let day = Int(digits.dropFirst(6).prefix(2))
        else { return nil }
        return date(year: year, month: month, day: day)
    }
}

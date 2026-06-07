//
//  BirthdayTests.swift
//  ContactManagerTests
//
//  Covers the pure field/year helpers behind the detail view's year-less
//  birthday editor: clamping the day to a month, counting a month's days
//  (including the leap-year sentinel), and adding/removing the year while
//  preserving month and day on the shared UTC calendar.
//

@testable import ContactManager
import Foundation
import Testing

struct BirthdayTests {
    // MARK: - daysInMonth

    @Test func countsDaysInLongAndShortMonths() {
        #expect(Birthday.daysInMonth(1, year: 2025) == 31)
        #expect(Birthday.daysInMonth(4, year: 2025) == 30)
    }

    @Test func februaryFollowsTheYearsLeapness() {
        #expect(Birthday.daysInMonth(2, year: 2020) == 29)
        #expect(Birthday.daysInMonth(2, year: 2021) == 28)
    }

    @Test func yearlessFebruaryAllowsTheTwentyNinth() {
        // The omitted-year sentinel is a leap year so a year-less Feb 29 (a
        // valid --0229 birthday) stays selectable.
        #expect(Birthday.daysInMonth(2, year: nil) == 29)
    }

    // MARK: - clampDay

    @Test func clampsDayDownToMonthLength() {
        // Jan 31 → Feb should land on the last valid day, not roll forward.
        #expect(Birthday.clampDay(31, month: 2, year: 2021) == 28)
        #expect(Birthday.clampDay(31, month: 2, year: 2020) == 29)
        #expect(Birthday.clampDay(31, month: 4, year: 2025) == 30)
    }

    @Test func leavesValidDayUntouched() {
        #expect(Birthday.clampDay(15, month: 6, year: 2025) == 15)
        #expect(Birthday.clampDay(0, month: 6, year: 2025) == 1)
    }

    // MARK: - setting(year:of:)

    @Test func dropsTheYearWhilePreservingMonthAndDay() throws {
        let dated = try #require(Birthday.date(year: 1990, month: 7, day: 4))
        let yearless = try #require(Birthday.setting(year: nil, of: dated))
        let fields = Birthday.fields(of: yearless)
        #expect(fields.year == nil)
        #expect(fields.month == 7)
        #expect(fields.day == 4)
    }

    @Test func addsAYearWhilePreservingMonthAndDay() throws {
        let yearless = try #require(Birthday.date(year: nil, month: 4, day: 15))
        let dated = try #require(Birthday.setting(year: 2001, of: yearless))
        let fields = Birthday.fields(of: dated)
        #expect(fields.year == 2001)
        #expect(fields.month == 4)
        #expect(fields.day == 15)
    }

    @Test func clampsTheDayWhenAddingANonLeapYearToFeb29() throws {
        // A year-less Feb 29 gaining a non-leap year must clamp to Feb 28
        // rather than silently rolling into March.
        let leapDay = try #require(Birthday.date(year: nil, month: 2, day: 29))
        let dated = try #require(Birthday.setting(year: 2021, of: leapDay))
        let fields = Birthday.fields(of: dated)
        #expect(fields.year == 2021)
        #expect(fields.month == 2)
        #expect(fields.day == 28)
    }

    // MARK: - formatted

    @Test func formattedIncludesYearWhenPresent() throws {
        // Derive the localized month name from the same calendar so the
        // expectation holds regardless of the runner's locale.
        let march = Birthday.calendar.monthSymbols[2]
        let date = try #require(Birthday.date(year: 1990, month: 3, day: 4))
        #expect(Birthday.formatted(date) == "\(march) 4, 1990")
    }

    @Test func formattedOmitsYearForYearlessBirthday() throws {
        let december = Birthday.calendar.monthSymbols[11]
        let date = try #require(Birthday.date(year: nil, month: 12, day: 25))
        #expect(Birthday.formatted(date) == "\(december) 25")
    }

    @Test func formattedReadsBackTheStoredUTCDay() throws {
        // The day shown must match the stored UTC day, not shift by time zone.
        let leapDay = try #require(Birthday.date(year: nil, month: 2, day: 29))
        let february = Birthday.calendar.monthSymbols[1]
        #expect(Birthday.formatted(leapDay) == "\(february) 29")
    }
}

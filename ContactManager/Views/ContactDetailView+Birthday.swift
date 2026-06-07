//
//  ContactDetailView+Birthday.swift
//  ContactManager
//
//  The birthday editor's year-aware bindings and the month/day-only control.
//  Split out of ContactDetailView so the main file stays focused on layout.
//  Year-less birthdays (a vCard `--MMDD` or a yearless Contacts card) store a
//  sentinel year; everything here reads/writes through `Birthday` so that
//  sentinel — and the UTC convention — never leaks into the UI.
//

import Foundation
import SwiftUI

extension ContactDetailView {
    /// Whether the stored birthday carries a real year. Toggling on stamps the
    /// current year; toggling off drops to the year-less form. Both go through
    /// `Birthday.setting` so the month/day and UTC convention are preserved.
    var birthdayIncludesYear: Binding<Bool> {
        Binding(
            get: { contact.birthday.map { Birthday.fields(of: $0).year != nil } ?? false },
            set: { include in
                guard let birthday = contact.birthday else { return }
                let year = include ? Birthday.fields(of: .now).year : nil
                contact.birthday = Birthday.setting(year: year, of: birthday)
            }
        )
    }

    /// Month (1–12) of a year-less birthday. The setter clamps the day so
    /// switching to a shorter month doesn't roll the date into the next one.
    var birthdayMonth: Binding<Int> {
        Binding(
            get: { contact.birthday.map { Birthday.fields(of: $0).month } ?? 1 },
            set: { month in
                guard let birthday = contact.birthday else { return }
                let parts = Birthday.fields(of: birthday)
                let day = Birthday.clampDay(parts.day, month: month, year: parts.year)
                contact.birthday = Birthday.date(year: parts.year, month: month, day: day)
            }
        )
    }

    /// Day-of-month of a year-less birthday.
    var birthdayDay: Binding<Int> {
        Binding(
            get: { contact.birthday.map { Birthday.fields(of: $0).day } ?? 1 },
            set: { day in
                guard let birthday = contact.birthday else { return }
                let parts = Birthday.fields(of: birthday)
                contact.birthday = Birthday.date(year: parts.year, month: parts.month, day: day)
            }
        )
    }
}

/// Month + day pickers for a year-less birthday, so the editor never surfaces
/// the omitted-year sentinel. The day range follows the selected month (using
/// the UTC calendar birthdays are stored in, whose sentinel year is a leap year
/// so Feb 29 stays available).
struct MonthDayPicker: View {
    @Binding var month: Int
    @Binding var day: Int

    /// Nominative month names ("January", not "of January") for the picker.
    private static let monthNames: [String] = {
        let formatter = DateFormatter()
        formatter.calendar = Birthday.calendar
        return formatter.standaloneMonthSymbols ?? formatter.monthSymbols
    }()

    var body: some View {
        HStack {
            Text("Date")
            Spacer()
            Picker("Month", selection: $month) {
                ForEach(Array(Self.monthNames.enumerated()), id: \.offset) { index, name in
                    Text(name).tag(index + 1)
                }
            }
            .labelsHidden()
            .fixedSize()
            .accessibilityLabel("Birthday month")

            Picker("Day", selection: $day) {
                ForEach(1 ... Birthday.daysInMonth(month, year: nil), id: \.self) { value in
                    Text(value.formatted()).tag(value)
                }
            }
            .labelsHidden()
            .fixedSize()
            .accessibilityLabel("Birthday day")
        }
    }
}

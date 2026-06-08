//
//  QuickCapture.swift
//  ContactManager
//
//  Pure parsing for the quick-entry window. It intentionally accepts a small,
//  memorable grammar instead of trying to be a chatbot: comma/semicolon/newline
//  fragments, obvious emails/phones, `birthday ...`, `at ...`, `title ...`,
//  and `notes ...`.
//

import Foundation

struct QuickCaptureDraft {
    var firstName = ""
    var lastName = ""
    var company = ""
    var jobTitle = ""
    var birthday: Date?
    var notes = ""
    var emails: [(label: FieldLabel, value: String)] = []
    var phones: [(label: FieldLabel, value: String)] = []

    var isEmpty: Bool {
        firstName.isBlank
            && lastName.isBlank
            && company.isBlank
            && jobTitle.isBlank
            && birthday == nil
            && notes.isBlank
            && emails.isEmpty
            && phones.isEmpty
    }

    var displayName: String {
        let name = [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if !name.isEmpty { return name }
        return company.isBlank ? "New Contact" : company
    }
}

enum QuickCaptureParser {
    static func parse(_ text: String) -> QuickCaptureDraft {
        var draft = QuickCaptureDraft()
        let fragments = text
            .split(whereSeparator: { ",;\n".contains($0) })
            .map { clean(String($0)) }
            .filter { !$0.isEmpty }

        for fragment in fragments {
            apply(fragment, to: &draft)
        }

        return draft
    }

    private static func apply(_ fragment: String, to draft: inout QuickCaptureDraft) {
        if let email = email(in: fragment) {
            draft.emails.append((label: .home, value: email))
            return
        }

        if let birthday = birthday(in: fragment) {
            draft.birthday = birthday
            return
        }

        if let value = value(in: fragment, after: ["notes", "note"]) {
            draft.notes = append(draft.notes, value)
            return
        }

        if let value = value(in: fragment, after: ["title", "role"]) {
            draft.jobTitle = value
            return
        }

        if let value = value(in: fragment, after: ["company"]) {
            draft.company = value
            return
        }

        if let phone = phone(in: fragment) {
            draft.phones.append(phone)
            return
        }

        applyNameAndCompany(fragment, to: &draft)
    }

    private static func applyNameAndCompany(_ fragment: String, to draft: inout QuickCaptureDraft) {
        let pieces = fragment.components(separatedBy: " at ")
        let name = pieces[0].trimmingCharacters(in: .whitespacesAndNewlines)
        if pieces.count > 1, draft.company.isBlank {
            draft.company = pieces.dropFirst().joined(separator: " at ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard draft.firstName.isBlank, draft.lastName.isBlank else {
            draft.notes = append(draft.notes, fragment)
            return
        }

        let words = name.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return }
        if words.count == 1 {
            draft.firstName = words[0]
        } else {
            draft.firstName = words.dropLast().joined(separator: " ")
            draft.lastName = words.last ?? ""
        }
    }

    private static func email(in fragment: String) -> String? {
        let tokens = fragment.split(separator: " ").map(String.init)
        return tokens
            .map { clean($0) }
            .first { token in
                token.contains("@") && token.contains(".")
            }
    }

    private static func phone(in fragment: String) -> (label: FieldLabel, value: String)? {
        var value = fragment
        let label = phoneLabel(in: fragment, value: &value)
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = value.filter(\.isNumber)
        guard digits.count >= 7 else { return nil }
        return (label: label, value: value)
    }

    private static func phoneLabel(in fragment: String, value: inout String) -> FieldLabel {
        let prefixes: [(String, FieldLabel)] = [
            ("mobile", .mobile),
            ("cell", .mobile),
            ("work", .work),
            ("home", .home),
            ("phone", .mobile),
            ("tel", .mobile),
        ]
        let lower = fragment.lowercased()
        for (prefix, label) in prefixes where lower.hasPrefix(prefix + " ") || lower == prefix {
            value = String(fragment.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            return label
        }
        return .mobile
    }

    private static func birthday(in fragment: String) -> Date? {
        guard let value = value(in: fragment, after: ["birthday", "bday", "born"]) else {
            return nil
        }
        return parseBirthday(value)
    }

    private static func parseBirthday(_ value: String) -> Date? {
        if let parsed = Birthday.parse(value) { return parsed }

        let cleaned = clean(value)
        if let numeric = parseNumericBirthday(cleaned) { return numeric }
        return parseMonthNameBirthday(cleaned)
    }

    private static func parseNumericBirthday(_ value: String) -> Date? {
        let pieces = value
            .split(whereSeparator: { "/.-".contains($0) })
            .compactMap { Int($0) }
        guard pieces.count >= 2 else { return nil }

        if pieces[0] > 31, pieces.count >= 3 {
            return Birthday.date(year: pieces[0], month: pieces[1], day: pieces[2])
        }
        let year = pieces.count >= 3 ? pieces[2] : nil
        return Birthday.date(year: year, month: pieces[0], day: pieces[1])
    }

    private static func parseMonthNameBirthday(_ value: String) -> Date? {
        let tokens = value
            .replacingOccurrences(of: ",", with: " ")
            .split(separator: " ")
            .map { clean(String($0)) }
            .filter { !$0.isEmpty }
        guard tokens.count >= 2,
              let month = monthNumber(tokens[0]),
              let day = Int(tokens[1].filter(\.isNumber))
        else { return nil }
        let year = tokens.count >= 3 ? Int(tokens[2].filter(\.isNumber)) : nil
        return Birthday.date(year: year, month: month, day: day)
    }

    private static func monthNumber(_ token: String) -> Int? {
        let lower = token.lowercased()
        let months = [
            "january", "february", "march", "april", "may", "june",
            "july", "august", "september", "october", "november", "december",
        ]
        for (index, month) in months.enumerated() where month.hasPrefix(lower) {
            return index + 1
        }
        return nil
    }

    private static func value(in fragment: String, after prefixes: [String]) -> String? {
        let lower = fragment.lowercased()
        for prefix in prefixes {
            if lower == prefix { return "" }
            if lower.hasPrefix(prefix + " ") {
                return clean(String(fragment.dropFirst(prefix.count)))
            }
            if lower.hasPrefix(prefix + ":") {
                return clean(String(fragment.dropFirst(prefix.count + 1)))
            }
        }
        return nil
    }

    private static func append(_ existing: String, _ value: String) -> String {
        if existing.isBlank { return value }
        if value.isBlank { return existing }
        return "\(existing)\n\(value)"
    }

    private static func clean(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
    }
}

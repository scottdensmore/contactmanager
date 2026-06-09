//
//  QuickCapture.swift
//  ContactManager
//
//  Pure parsing for the quick-entry window. It intentionally accepts a small,
//  memorable grammar instead of trying to be a chatbot: comma/semicolon/newline
//  fragments, obvious emails/phones, `birthday ...`, `at ...`, `title ...`,
//  `tag ...`, `group ...`, and `notes ...`.
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
    var tags: [String] = []
    var groups: [String] = []
    var parseWarnings: [String] = []

    var isEmpty: Bool {
        firstName.isBlank
            && lastName.isBlank
            && company.isBlank
            && jobTitle.isBlank
            && birthday == nil
            && notes.isBlank
            && emails.isEmpty
            && phones.isEmpty
            && tags.isEmpty
            && groups.isEmpty
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
        if applyEmailFragment(fragment, to: &draft) {
            return
        }

        if applyPrefixedFragment(fragment, to: &draft) {
            return
        }

        if applyPhoneFragment(fragment, to: &draft) {
            return
        }

        if let email = email(in: fragment) {
            draft.emails.append(email)
            return
        }

        if let phone = phone(in: fragment) {
            draft.phones.append(phone)
            return
        }

        applyNameAndCompany(fragment, to: &draft)
    }

    private static func applyEmailFragment(_ fragment: String, to draft: inout QuickCaptureDraft) -> Bool {
        guard hasKindWord(in: fragment, kindWords: ["email", "mail"], defaultLabel: .home) else {
            return false
        }
        if let email = email(in: fragment) {
            draft.emails.append(email)
        } else if let warning = invalidFieldWarning(
            in: fragment,
            kindWords: ["email", "mail"],
            fieldName: "email",
            defaultLabel: .home
        ) {
            draft.parseWarnings.append(warning)
        }
        return true
    }

    private static func applyPrefixedFragment(_ fragment: String, to draft: inout QuickCaptureDraft) -> Bool {
        if let value = value(in: fragment, after: ["birthday", "bday", "born"]) {
            applyBirthday(value, fallback: fragment, to: &draft)
            return true
        }
        if let value = value(in: fragment, after: ["notes", "note"]) {
            if let value = nonBlank(value, emptyWarning: "Ignored empty note", warnings: &draft.parseWarnings) {
                draft.notes = append(draft.notes, value)
            }
            return true
        }
        if let value = value(in: fragment, after: ["title", "role"]) {
            if let value = nonBlank(value, emptyWarning: "Ignored empty title", warnings: &draft.parseWarnings) {
                draft.jobTitle = value
            }
            return true
        }
        if let value = value(in: fragment, after: ["company"]) {
            if let value = nonBlank(value, emptyWarning: "Ignored empty company", warnings: &draft.parseWarnings) {
                draft.company = value
            }
            return true
        }
        if let value = value(in: fragment, after: ["tag", "tags"]) {
            let tag = nonBlank(value, emptyWarning: "Ignored empty tag", warnings: &draft.parseWarnings)
            appendUnique(tag, to: &draft.tags)
            return true
        }
        if let value = value(in: fragment, after: ["group", "groups"]) {
            let group = nonBlank(value, emptyWarning: "Ignored empty group", warnings: &draft.parseWarnings)
            appendUnique(group, to: &draft.groups)
            return true
        }
        return false
    }

    private static func applyPhoneFragment(_ fragment: String, to draft: inout QuickCaptureDraft) -> Bool {
        guard hasKindWord(
            in: fragment,
            kindWords: ["phone", "tel", "telephone", "number"],
            defaultLabel: .mobile
        ) else {
            return false
        }
        if let phone = phone(in: fragment) {
            draft.phones.append(phone)
        } else if let warning = invalidFieldWarning(
            in: fragment,
            kindWords: ["phone", "tel", "telephone", "number"],
            fieldName: "phone",
            defaultLabel: .mobile
        ) {
            draft.parseWarnings.append(warning)
        }
        return true
    }
}

private extension QuickCaptureParser {
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

    private static func email(in fragment: String) -> (label: FieldLabel, value: String)? {
        let field = labeledValue(in: fragment, kindWords: ["email", "mail"], defaultLabel: .home)
        let tokens = field.value.split(separator: " ").map(String.init)
        guard let value = (tokens
            .map { clean($0) }
            .first { token in
                token.contains("@") && token.contains(".")
            })
        else { return nil }
        return (label: field.label, value: value)
    }

    private static func phone(in fragment: String) -> (label: FieldLabel, value: String)? {
        let field = labeledValue(
            in: fragment,
            kindWords: ["phone", "tel", "telephone", "number"],
            defaultLabel: .mobile
        )
        let value = field.value.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = value.filter(\.isNumber)
        guard digits.count >= 7 else { return nil }
        return (label: field.label, value: value)
    }

    private static func labeledValue(
        in fragment: String,
        kindWords: Set<String>,
        defaultLabel: FieldLabel
    ) -> LabeledValue {
        var label = defaultLabel
        var hasKindWord = false
        var pieces = fragment.split(separator: " ").map(String.init)
        while let first = pieces.first {
            let token = clean(first).lowercased()
            if let parsed = fieldLabel(token) {
                label = parsed
                pieces.removeFirst()
            } else if kindWords.contains(token) {
                hasKindWord = true
                pieces.removeFirst()
            } else {
                break
            }
        }
        return LabeledValue(
            label: label,
            value: pieces.joined(separator: " "),
            hasKindWord: hasKindWord
        )
    }

    private static func fieldLabel(_ token: String) -> FieldLabel? {
        switch token {
        case "home":
            .home
        case "work", "office":
            .work
        case "mobile", "cell", "cellular":
            .mobile
        case "main":
            .main
        case "other":
            .other
        default:
            nil
        }
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

    private static func invalidFieldWarning(
        in fragment: String,
        kindWords: Set<String>,
        fieldName: String,
        defaultLabel: FieldLabel
    ) -> String? {
        let field = labeledValue(in: fragment, kindWords: kindWords, defaultLabel: defaultLabel)
        guard field.hasKindWord else { return nil }
        if field.value.isBlank { return "Ignored empty \(fieldName)" }
        return "Ignored \(fieldName): \(field.value)"
    }

    private static func hasKindWord(
        in fragment: String,
        kindWords: Set<String>,
        defaultLabel: FieldLabel
    ) -> Bool {
        labeledValue(in: fragment, kindWords: kindWords, defaultLabel: defaultLabel).hasKindWord
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

    private static func appendUnique(_ value: String, to values: inout [String]) {
        let trimmed = clean(value)
        guard !trimmed.isBlank else { return }
        let normalized = trimmed.lowercased()
        guard !values.contains(where: { $0.lowercased() == normalized }) else { return }
        values.append(trimmed)
    }

    private static func appendUnique(_ value: String?, to values: inout [String]) {
        guard let value else { return }
        appendUnique(value, to: &values)
    }

    private static func applyBirthday(_ value: String, fallback: String, to draft: inout QuickCaptureDraft) {
        if let birthday = parseBirthday(value) {
            draft.birthday = birthday
        } else {
            draft.parseWarnings.append("Couldn't parse birthday: \(warningValue(value, fallback: fallback))")
        }
    }

    private static func nonBlank(_ value: String, emptyWarning: String, warnings: inout [String]) -> String? {
        if value.isBlank {
            warnings.append(emptyWarning)
            return nil
        }
        return value
    }

    private static func warningValue(_ value: String, fallback: String) -> String {
        let trimmed = clean(value)
        return trimmed.isBlank ? clean(fallback) : trimmed
    }

    private static func clean(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
    }
}

private struct LabeledValue {
    var label: FieldLabel
    var value: String
    var hasKindWord: Bool
}

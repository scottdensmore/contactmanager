//
//  VCard.swift
//  ContactManager
//
//  Pure vCard 3.0 reading and writing. Kept free of SwiftData/UI types so it
//  is straightforward to unit test; the import/export views map between these
//  values and `Contact` models.
//

import Foundation

/// A contact decoded from a vCard, independent of SwiftData.
struct ParsedContact: Equatable {
    var firstName = ""
    var lastName = ""
    var company = ""
    var jobTitle = ""
    var notes = ""
    var birthday: Date?
    var street = ""
    var city = ""
    var state = ""
    var postalCode = ""
    var country = ""
    var emails: [(label: FieldLabel, value: String)] = []
    var phones: [(label: FieldLabel, value: String)] = []

    static func == (lhs: ParsedContact, rhs: ParsedContact) -> Bool {
        lhs.firstName == rhs.firstName && lhs.lastName == rhs.lastName
            && lhs.company == rhs.company && lhs.jobTitle == rhs.jobTitle
            && lhs.notes == rhs.notes && lhs.birthday == rhs.birthday
            && lhs.street == rhs.street && lhs.city == rhs.city
            && lhs.state == rhs.state && lhs.postalCode == rhs.postalCode
            && lhs.country == rhs.country
            && lhs.emails.map(\.value) == rhs.emails.map(\.value)
            && lhs.emails.map(\.label) == rhs.emails.map(\.label)
            && lhs.phones.map(\.value) == rhs.phones.map(\.value)
            && lhs.phones.map(\.label) == rhs.phones.map(\.label)
    }
}

enum VCard {
    private static let lineEnding = "\r\n"

    private static let birthdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    // MARK: - Writing

    /// Serializes contacts into a single vCard document.
    static func makeDocument(from contacts: [Contact]) -> String {
        contacts.map(card(for:)).joined()
    }

    static func card(for contact: Contact) -> String {
        var lines = ["BEGIN:VCARD", "VERSION:3.0"]

        let last = escape(contact.lastName)
        let first = escape(contact.firstName)
        lines.append("N:\(last);\(first);;;")
        lines.append("FN:\(escape(contact.fullName))")

        if !contact.company.isEmpty { lines.append("ORG:\(escape(contact.company))") }
        if !contact.jobTitle.isEmpty { lines.append("TITLE:\(escape(contact.jobTitle))") }

        for email in contact.emails where !email.value.isEmpty {
            lines.append("EMAIL;TYPE=\(typeName(email.label)):\(escape(email.value))")
        }
        for phone in contact.phones where !phone.value.isEmpty {
            lines.append("TEL;TYPE=\(typeName(phone.label)):\(escape(phone.value))")
        }

        if hasAddress(contact) {
            let parts = [contact.street, contact.city, contact.state, contact.postalCode, contact.country]
                .map(escape)
            lines.append("ADR;TYPE=HOME:;;\(parts.joined(separator: ";"))")
        }

        if let birthday = contact.birthday {
            lines.append("BDAY:\(birthdayFormatter.string(from: birthday))")
        }
        if !contact.notes.isEmpty {
            lines.append("NOTE:\(escape(contact.notes))")
        }

        lines.append("END:VCARD")
        return lines.joined(separator: lineEnding) + lineEnding
    }

    // MARK: - Reading

    /// Parses one or more vCards from a document.
    static func parse(_ text: String) -> [ParsedContact] {
        var results: [ParsedContact] = []
        var current: ParsedContact?

        for line in unfold(text) {
            let upper = line.uppercased()
            if upper == "BEGIN:VCARD" {
                current = ParsedContact()
            } else if upper == "END:VCARD" {
                if let card = current { results.append(card) }
                current = nil
            } else if current != nil {
                apply(line: line, to: &current!)
            }
        }
        return results
    }

    private static func apply(line: String, to card: inout ParsedContact) {
        guard let colon = line.firstIndex(of: ":") else { return }
        let descriptor = String(line[line.startIndex..<colon])
        let value = String(line[line.index(after: colon)...])

        let segments = descriptor.uppercased().split(separator: ";").map(String.init)
        guard let property = segments.first else { return }
        let params = Array(segments.dropFirst())

        switch property {
        case "N":
            let comps = splitStructured(value)
            card.lastName = comps.count > 0 ? comps[0] : ""
            card.firstName = comps.count > 1 ? comps[1] : ""
        case "FN":
            // Only use FN for names if N didn't provide them.
            if card.firstName.isEmpty && card.lastName.isEmpty {
                let unescaped = unescape(value)
                let pieces = unescaped.split(separator: " ", maxSplits: 1).map(String.init)
                card.firstName = pieces.first ?? unescaped
                card.lastName = pieces.count > 1 ? pieces[1] : ""
            }
        case "ORG":
            card.company = splitStructured(value).first ?? unescape(value)
        case "TITLE":
            card.jobTitle = unescape(value)
        case "EMAIL":
            card.emails.append((label(from: params), unescape(value)))
        case "TEL":
            card.phones.append((label(from: params), unescape(value)))
        case "ADR":
            let comps = splitStructured(value)
            // ADR: pobox;ext;street;city;state;postal;country
            card.street = comps.count > 2 ? comps[2] : ""
            card.city = comps.count > 3 ? comps[3] : ""
            card.state = comps.count > 4 ? comps[4] : ""
            card.postalCode = comps.count > 5 ? comps[5] : ""
            card.country = comps.count > 6 ? comps[6] : ""
        case "BDAY":
            card.birthday = birthdayFormatter.date(from: String(value.prefix(10)))
        case "NOTE":
            card.notes = unescape(value)
        default:
            break
        }
    }

    // MARK: - Label mapping

    private static func typeName(_ label: FieldLabel) -> String {
        switch label {
        case .home: return "HOME"
        case .work: return "WORK"
        case .mobile: return "CELL"
        case .main: return "MAIN"
        case .other: return "OTHER"
        }
    }

    private static func label(from params: [String]) -> FieldLabel {
        let types = params
            .flatMap { $0.replacingOccurrences(of: "TYPE=", with: "").split(separator: ",") }
            .map { String($0).uppercased() }
        if types.contains("CELL") || types.contains("MOBILE") { return .mobile }
        if types.contains("WORK") { return .work }
        if types.contains("HOME") { return .home }
        if types.contains("MAIN") { return .main }
        return .other
    }

    // MARK: - Escaping & folding

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: ";", with: "\\;")
    }

    private static func unescape(_ value: String) -> String {
        var result = ""
        var iterator = value.makeIterator()
        while let char = iterator.next() {
            if char == "\\", let next = iterator.next() {
                switch next {
                case "n", "N": result.append("\n")
                default: result.append(next)
                }
            } else {
                result.append(char)
            }
        }
        return result
    }

    /// Splits a structured value (`;`-separated) honoring escaped separators,
    /// unescaping each component.
    private static func splitStructured(_ value: String) -> [String] {
        var components: [String] = []
        var current = ""
        var iterator = value.makeIterator()
        while let char = iterator.next() {
            if char == "\\", let next = iterator.next() {
                if next == "n" || next == "N" { current.append("\n") } else { current.append(next) }
            } else if char == ";" {
                components.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        components.append(current)
        return components
    }

    /// Unfolds wrapped lines (continuation lines start with a space or tab).
    private static func unfold(_ text: String) -> [String] {
        let rawLines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var lines: [String] = []
        for raw in rawLines {
            if let first = raw.first, first == " " || first == "\t", !lines.isEmpty {
                lines[lines.count - 1] += raw.dropFirst()
            } else {
                lines.append(raw)
            }
        }
        return lines.filter { !$0.isEmpty }
    }

    private static func hasAddress(_ contact: Contact) -> Bool {
        ![contact.street, contact.city, contact.state, contact.postalCode, contact.country]
            .allSatisfy(\.isEmpty)
    }
}

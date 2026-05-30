//
//  VCard.swift
//  ContactManager
//
//  vCard 3.0 reading and writing. The reading side returns plain
//  `ParsedContact` values (independent of SwiftData); the writing side reads
//  directly from `Contact` for convenience and runs on the main actor.
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
    var photoData: Data?
    var emails: [(label: FieldLabel, value: String)] = []
    var phones: [(label: FieldLabel, value: String)] = []

    static func == (lhs: ParsedContact, rhs: ParsedContact) -> Bool {
        lhs.firstName == rhs.firstName && lhs.lastName == rhs.lastName
            && lhs.company == rhs.company && lhs.jobTitle == rhs.jobTitle
            && lhs.notes == rhs.notes && lhs.birthday == rhs.birthday
            && lhs.street == rhs.street && lhs.city == rhs.city
            && lhs.state == rhs.state && lhs.postalCode == rhs.postalCode
            && lhs.country == rhs.country
            && lhs.photoData == rhs.photoData
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
        // Use the local time zone so the serialized day matches the day the
        // user picked (birthdays are date-only, stored as a local midnight).
        formatter.timeZone = .autoupdatingCurrent
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
        if let photo = contact.photoData {
            // 3.0 inline base64: PHOTO;ENCODING=b;TYPE=JPEG:<base64>
            lines.append("PHOTO;ENCODING=b;TYPE=JPEG:\(photo.base64EncodedString())")
        }

        lines.append("END:VCARD")
        return lines.map(fold).joined(separator: lineEnding) + lineEnding
    }

    /// Folds a logical line to the vCard 3.0 75-octet limit. Continuation
    /// lines begin with a single space, which `unfold` strips on read.
    private static func fold(_ line: String) -> String {
        let limit = 75
        guard line.utf8.count > limit else { return line }

        var folded = ""
        var segment = ""
        var octets = 0
        var isFirstSegment = true

        for character in line {
            let charOctets = String(character).utf8.count
            // Continuation lines spend one octet on the leading space.
            let segmentLimit = isFirstSegment ? limit : limit - 1
            if octets + charOctets > segmentLimit {
                folded += (isFirstSegment ? "" : " ") + segment + lineEnding
                isFirstSegment = false
                segment = ""
                octets = 0
            }
            segment.append(character)
            octets += charOctets
        }
        folded += (isFirstSegment ? "" : " ") + segment
        return folded
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
            } else if var card = current {
                apply(line: line, to: &card)
                current = card
            }
        }
        return results
    }

    private static func apply(line: String, to card: inout ParsedContact) {
        guard let colon = line.firstIndex(of: ":") else { return }
        let descriptor = String(line[line.startIndex ..< colon])
        let value = String(line[line.index(after: colon)...])

        let segments = descriptor.uppercased().split(separator: ";").map(String.init)
        guard let property = segments.first else { return }
        let params = Array(segments.dropFirst())

        switch property {
        case "N":
            let comps = splitStructured(value)
            card.lastName = comps.first ?? ""
            card.firstName = comps.count > 1 ? comps[1] : ""
        case "FN":
            // Only use FN for names if N didn't provide them.
            if card.firstName.isEmpty, card.lastName.isEmpty {
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
        case "PHOTO":
            card.photoData = decodePhoto(value)
        default:
            break
        }
    }

    /// Decodes the value of a PHOTO line into the raw image bytes. Tolerates
    /// vCard 4.0 data-URI prefixes (`data:image/...;base64,`) and any stray
    /// whitespace left over after line unfolding.
    private static func decodePhoto(_ value: String) -> Data? {
        var clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = clean.range(of: "base64,", options: .caseInsensitive) {
            clean = String(clean[range.upperBound...])
        }
        clean = String(clean.filter { !$0.isWhitespace })
        return Data(base64Encoded: clean)
    }

    // MARK: - Label mapping

    private static func typeName(_ label: FieldLabel) -> String {
        switch label {
        case .home: "HOME"
        case .work: "WORK"
        case .mobile: "CELL"
        case .main: "MAIN"
        case .other: "OTHER"
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

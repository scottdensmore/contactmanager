//
//  CSV.swift
//  ContactManager
//
//  A small RFC-4180-ish CSV reader plus a header-based mapper that turns
//  Google Contacts / Outlook / Apple CSV exports into `ParsedContact`
//  values so they flow through the same `ContactStore.importContacts`
//  pipeline used by vCard and the macOS Contacts bridge.
//
//  Scope choices for the first version:
//  - Birthdays are accepted in ISO `yyyy-MM-dd` form only (Google's
//    export format). Locale-dependent forms fall through silently —
//    same behavior as the vCard reader.
//  - "Address 1 - …" columns from Google fill the single address slot
//    we model. Address 2+ is intentionally dropped; we don't have
//    multi-address support today.
//  - Custom-labelled email/phone columns ("Home Phone", "E-mail 1 -
//    Value", etc.) collect into the contact's `emails`/`phones` list
//    in column order, preserving the label encoded in the header.
//

import Foundation

enum CSV {
    // MARK: - Parsing

    /// Parses a CSV document into rows of fields. Handles `CR`/`LF`/`CRLF`
    /// line endings, double-quoted fields containing commas or newlines,
    /// and `""` as the escape for a literal quote inside a quoted field.
    /// A leading UTF-8 BOM (`\u{FEFF}`) is stripped.
    static func parse(_ text: String) -> [[String]] {
        var input = text
        if input.first == "\u{FEFF}" { input.removeFirst() }

        var state = ParseState()
        var cursor = input.startIndex
        while cursor < input.endIndex {
            let char = input[cursor]
            cursor = state.inQuotes
                ? state.handleQuoted(char: char, cursor: cursor, in: input)
                : state.handleUnquoted(char: char, cursor: cursor, in: input)
        }
        // Trailing field/row when the file doesn't end with a newline.
        if !state.field.isEmpty || !state.row.isEmpty {
            state.endRow()
        }
        return state.rows
    }

    /// Mutable scratchpad used by `parse(_:)`. Pulled out so each
    /// transition stays small enough for SwiftLint's body-length budget.
    private struct ParseState {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false

        mutating func endField() {
            row.append(field); field = ""
        }

        mutating func endRow() {
            endField(); rows.append(row); row = []
        }

        mutating func handleQuoted(char: Character, cursor: String.Index, in input: String) -> String.Index {
            if char == "\"" {
                let next = input.index(after: cursor)
                if next < input.endIndex, input[next] == "\"" {
                    // Doubled-quote escape: keep one literal quote.
                    field.append("\"")
                    return input.index(after: next)
                }
                inQuotes = false
            } else {
                field.append(char)
            }
            return input.index(after: cursor)
        }

        mutating func handleUnquoted(
            char: Character, cursor: String.Index, in input: String
        ) -> String.Index {
            switch char {
            case "\"": inQuotes = true
            case ",": endField()
            // Swift collapses CRLF into a single `Character`, so the third
            // case below catches `\r\n` files (Windows / Excel exports);
            // standalone `\r` (classic Mac) still wraps the row.
            case "\n", "\r", "\r\n": endRow()
            default: field.append(char)
            }
            return input.index(after: cursor)
        }
    }

    // MARK: - Mapping

    /// Parses a CSV contact export. Returns `nil` if the header row
    /// doesn't include any column we recognize — the caller surfaces
    /// "couldn't recognize this CSV" instead of importing nothing.
    static func parseContacts(_ text: String) -> [ParsedContact]? {
        var rows = parse(text)
        guard let headers = rows.first else { return nil }
        rows.removeFirst()

        let columns = headers.map(column(forHeader:))
        guard columns.contains(where: { $0 != nil }) else { return nil }

        return rows.compactMap { row in
            let contact = makeContact(row: row, columns: columns)
            // Skip rows where literally nothing mapped — empty trailing
            // lines or schema-only stub rows shouldn't become contacts.
            return contact.isEmpty ? nil : contact
        }
    }

    private static func makeContact(
        row: [String], columns: [Column?]
    ) -> ParsedContact {
        var parsed = ParsedContact()
        // The "full name" column is handled after the loop so explicit
        // First/Last columns win regardless of column ordering.
        var fullName = ""
        for (index, column) in columns.enumerated() {
            guard let column, index < row.count else { continue }
            let value = row[index].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }
            if case .scalar(.fullName) = column {
                fullName = value
                continue
            }
            apply(column: column, value: value, to: &parsed)
        }
        if parsed.firstName.isEmpty, parsed.lastName.isEmpty, !fullName.isEmpty {
            splitName(fullName, into: &parsed)
        }
        return parsed
    }

    private static func apply(
        column: Column, value: String, to parsed: inout ParsedContact
    ) {
        switch column {
        case .scalar(.firstName): parsed.firstName = value
        case .scalar(.lastName): parsed.lastName = value
        case .scalar(.fullName): break // handled in makeContact
        case .scalar(.company): parsed.company = value
        case .scalar(.jobTitle): parsed.jobTitle = value
        case .scalar(.notes): parsed.notes = value
        case .scalar(.birthday): parsed.birthday = parseBirthday(value)
        case .scalar(.street): parsed.street = value
        case .scalar(.city): parsed.city = value
        case .scalar(.state): parsed.state = value
        case .scalar(.postalCode): parsed.postalCode = value
        case .scalar(.country): parsed.country = value
        case .email(let label): parsed.emails.append((label, value))
        case .phone(let label): parsed.phones.append((label, value))
        }
    }

    private static func splitName(_ name: String, into parsed: inout ParsedContact) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let lastSpace = trimmed.lastIndex(of: " ") {
            parsed.firstName = String(trimmed[..<lastSpace])
                .trimmingCharacters(in: .whitespaces)
            parsed.lastName = String(trimmed[trimmed.index(after: lastSpace)...])
                .trimmingCharacters(in: .whitespaces)
        } else {
            parsed.firstName = trimmed
        }
    }

    private static let isoBirthdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .autoupdatingCurrent
        return formatter
    }()

    private static func parseBirthday(_ value: String) -> Date? {
        isoBirthdayFormatter.date(from: value)
    }

    // MARK: - Header → column

    /// Which `ParsedContact` field a scalar column writes to. Kept at the
    /// top of `CSV` (not nested inside `Column`) so SwiftLint's nesting
    /// rule stays happy.
    enum ScalarColumn: Equatable {
        case firstName, lastName, fullName
        case company, jobTitle, notes, birthday
        case street, city, state, postalCode, country
    }

    /// Internal column kinds. Scalars overwrite the matching `ParsedContact`
    /// field; `.email`/`.phone` append to their list so multiple columns
    /// map to multiple values.
    enum Column: Equatable {
        case scalar(ScalarColumn)
        case email(FieldLabel)
        case phone(FieldLabel)
    }

    /// Direct header-name → column map. Keys are the normalized form
    /// (`normalize(_:)` strips spaces/punctuation and lowercases), so
    /// `"First Name"`, `"first_name"`, and `"first.name"` all match
    /// `"firstname"`. Lookup keeps `column(forHeader:)` data-driven
    /// instead of a giant `switch`.
    private static let headerTable: [String: Column] = [
        "firstname": .scalar(.firstName), "givenname": .scalar(.firstName),
        "lastname": .scalar(.lastName), "surname": .scalar(.lastName),
        "familyname": .scalar(.lastName),
        "name": .scalar(.fullName), "fullname": .scalar(.fullName),
        "displayname": .scalar(.fullName),
        "company": .scalar(.company), "companyname": .scalar(.company),
        "organization": .scalar(.company), "organizationname": .scalar(.company),
        "jobtitle": .scalar(.jobTitle), "title": .scalar(.jobTitle),
        "organizationtitle": .scalar(.jobTitle), "position": .scalar(.jobTitle),
        "notes": .scalar(.notes), "note": .scalar(.notes),
        "birthday": .scalar(.birthday), "dob": .scalar(.birthday),
        "dateofbirth": .scalar(.birthday),
        "street": .scalar(.street), "address": .scalar(.street),
        "streetaddress": .scalar(.street),
        "homestreet": .scalar(.street), "businessstreet": .scalar(.street),
        "city": .scalar(.city),
        "homecity": .scalar(.city), "businesscity": .scalar(.city),
        "state": .scalar(.state), "region": .scalar(.state),
        "province": .scalar(.state),
        "homestate": .scalar(.state), "businessstate": .scalar(.state),
        "zip": .scalar(.postalCode), "zipcode": .scalar(.postalCode),
        "postalcode": .scalar(.postalCode),
        "homepostalcode": .scalar(.postalCode),
        "businesspostalcode": .scalar(.postalCode),
        "country": .scalar(.country),
        "homecountry": .scalar(.country), "businesscountry": .scalar(.country),
        "email": .email(.home), "emailaddress": .email(.home),
        "primaryemail": .email(.home),
        "homeemail": .email(.home), "personalemail": .email(.home),
        "workemail": .email(.work), "businessemail": .email(.work),
        "phone": .phone(.mobile), "phonenumber": .phone(.mobile),
        "primaryphone": .phone(.mobile),
        "homephone": .phone(.home),
        "workphone": .phone(.work), "businessphone": .phone(.work),
        "mobilephone": .phone(.mobile), "mobile": .phone(.mobile),
        "cellphone": .phone(.mobile), "cell": .phone(.mobile),
        "mainphone": .phone(.main),
        "otherphone": .phone(.other),
    ]

    /// Google Contacts "Address 1 - …" columns after stripping the prefix.
    private static let address1Table: [String: ScalarColumn] = [
        "street": .street, "city": .city,
        "region": .state, "state": .state,
        "postalcode": .postalCode, "country": .country,
    ]

    /// Matches a single CSV header cell. Returns `nil` for headers we
    /// don't model (custom fields, separator columns like "E-mail 1 -
    /// Type"). The lookup is case- and punctuation-insensitive.
    static func column(forHeader raw: String) -> Column? {
        let header = normalize(raw)
        if let direct = headerTable[header] { return direct }
        // Google Contacts "Address 1 - …" columns.
        if let suffix = stripPrefix(header, prefix: "address1"),
           let scalar = address1Table[suffix] {
            return .scalar(scalar)
        }
        // Google's indexed multi-value columns: "E-mail 1 - Value" /
        // "Phone 2 - Value". After normalize: "email1value" / "phone2value".
        if isIndexedColumn(header, base: "email", suffix: "value") {
            return .email(.home)
        }
        if isIndexedColumn(header, base: "phone", suffix: "value") {
            return .phone(.mobile)
        }
        return nil
    }

    /// Lowercases and strips characters that vary across exporters (spaces,
    /// hyphens, underscores, slashes, dots) so headers compare structurally.
    private static func normalize(_ raw: String) -> String {
        var out = ""
        out.reserveCapacity(raw.count)
        for char in raw.lowercased() where char.isLetter || char.isNumber {
            out.append(char)
        }
        return out
    }

    private static func stripPrefix(_ haystack: String, prefix: String) -> String? {
        guard haystack.hasPrefix(prefix) else { return nil }
        return String(haystack.dropFirst(prefix.count))
    }

    private static func isIndexedColumn(_ header: String, base: String, suffix: String) -> Bool {
        guard header.hasPrefix(base), header.hasSuffix(suffix) else { return false }
        let middle = header.dropFirst(base.count).dropLast(suffix.count)
        return !middle.isEmpty && middle.allSatisfy(\.isNumber)
    }
}

// MARK: - ParsedContact helpers used during CSV mapping

extension ParsedContact {
    /// Considered "empty" for the purpose of dropping schema-only stub
    /// rows: every scalar field is blank and there are no fields/photos.
    var isEmpty: Bool {
        firstName.isEmpty && lastName.isEmpty && company.isEmpty
            && jobTitle.isEmpty && notes.isEmpty && birthday == nil
            && street.isEmpty && city.isEmpty && state.isEmpty
            && postalCode.isEmpty && country.isEmpty
            && emails.isEmpty && phones.isEmpty
            && photoData == nil
    }
}

//
//  CSVTests.swift
//  ContactManagerTests
//
//  Coverage for the pure CSV reader plus the header-based mapper that
//  turns Google Contacts / Outlook / Apple exports into ParsedContacts.
//

@testable import ContactManager
import Foundation
import Testing

struct CSVTests {
    // MARK: - Parser

    @Test func parsesSimpleRows() {
        let rows = CSV.parse("a,b,c\n1,2,3\n")
        #expect(rows == [["a", "b", "c"], ["1", "2", "3"]])
    }

    @Test func parsesWithoutTrailingNewline() {
        let rows = CSV.parse("a,b,c\n1,2,3")
        #expect(rows.count == 2)
        #expect(rows.last == ["1", "2", "3"])
    }

    @Test func handlesQuotedFieldsWithCommas() {
        let rows = CSV.parse("name,note\n\"Doe, John\",\"hello, world\"\n")
        #expect(rows == [["name", "note"], ["Doe, John", "hello, world"]])
    }

    @Test func handlesEscapedQuotesInsideQuotedField() {
        let rows = CSV.parse("a,b\n\"she said \"\"hi\"\"\",ok\n")
        #expect(rows.last == ["she said \"hi\"", "ok"])
    }

    @Test func handlesEmbeddedNewlinesInQuotedFields() {
        let rows = CSV.parse("note\n\"line one\nline two\"\n")
        #expect(rows.last == ["line one\nline two"])
    }

    @Test func handlesCRLFAndLineFeedLineEndings() {
        let crlf = CSV.parse("a,b\r\n1,2\r\n")
        let lineFeed = CSV.parse("a,b\n1,2\n")
        #expect(crlf == lineFeed)
        #expect(crlf == [["a", "b"], ["1", "2"]])
    }

    @Test func stripsLeadingUTF8BOM() {
        let rows = CSV.parse("\u{FEFF}a,b\n1,2\n")
        #expect(rows.first == ["a", "b"])
    }

    @Test func emptyFieldsRoundTrip() {
        let rows = CSV.parse("a,b,c\n,,3\n")
        #expect(rows.last == ["", "", "3"])
    }

    // MARK: - Header mapping

    @Test func recognizesGoogleContactsHeaders() {
        #expect(CSV.column(forHeader: "First Name") == .scalar(.firstName))
        #expect(CSV.column(forHeader: "Last Name") == .scalar(.lastName))
        #expect(CSV.column(forHeader: "Organization Name") == .scalar(.company))
        #expect(CSV.column(forHeader: "Organization Title") == .scalar(.jobTitle))
        #expect(CSV.column(forHeader: "E-mail 1 - Value") == .email(.home))
        #expect(CSV.column(forHeader: "Phone 1 - Value") == .phone(.mobile))
        #expect(CSV.column(forHeader: "Address 1 - Street") == .scalar(.street))
        #expect(CSV.column(forHeader: "Address 1 - City") == .scalar(.city))
        #expect(CSV.column(forHeader: "Address 1 - Region") == .scalar(.state))
        #expect(CSV.column(forHeader: "Address 1 - Postal Code") == .scalar(.postalCode))
        #expect(CSV.column(forHeader: "Address 1 - Country") == .scalar(.country))
        #expect(CSV.column(forHeader: "Birthday") == .scalar(.birthday))
    }

    @Test func recognizesOutlookHeaders() {
        #expect(CSV.column(forHeader: "Company") == .scalar(.company))
        #expect(CSV.column(forHeader: "Job Title") == .scalar(.jobTitle))
        #expect(CSV.column(forHeader: "E-mail Address") == .email(.home))
        #expect(CSV.column(forHeader: "Home Phone") == .phone(.home))
        #expect(CSV.column(forHeader: "Business Phone") == .phone(.work))
        #expect(CSV.column(forHeader: "Mobile Phone") == .phone(.mobile))
        #expect(CSV.column(forHeader: "Home Street") == .scalar(.street))
        #expect(CSV.column(forHeader: "Business City") == .scalar(.city))
    }

    @Test func ignoresUnknownHeaders() {
        #expect(CSV.column(forHeader: "Yomi Name") == nil)
        #expect(CSV.column(forHeader: "Custom Field 1") == nil)
        #expect(CSV.column(forHeader: "Photo") == nil)
    }

    @Test func doesNotConflateOutlookTitleWithJobTitle() {
        // "Title" in Outlook/Apple exports is the honorific (Mr./Mrs./Dr.),
        // not the role. It must not map to jobTitle or it would overwrite
        // a real "Job Title" cell depending on column order.
        #expect(CSV.column(forHeader: "Title") == nil)
        #expect(CSV.column(forHeader: "Job Title") == .scalar(.jobTitle))
    }

    @Test func headersAreCaseAndPunctuationInsensitive() {
        #expect(CSV.column(forHeader: "FIRST_NAME") == .scalar(.firstName))
        #expect(CSV.column(forHeader: "first.name") == .scalar(.firstName))
        #expect(CSV.column(forHeader: "  Mobile Phone  ") == .phone(.mobile))
    }

    // MARK: - Contact mapping

    @Test func parsesGoogleContactsExport() throws {
        let headerLine = "First Name,Last Name,Organization Name,Organization Title,"
            + "E-mail 1 - Value,Phone 1 - Value,Address 1 - Street,"
            + "Address 1 - City,Address 1 - Region,Address 1 - Postal Code,"
            + "Address 1 - Country,Birthday"
        let valueLine = "Ada,Lovelace,Analytical Engine Co.,Mathematician,"
            + "ada@analytical.engine,+1 555 0100,12 Mayfair,London,,W1,"
            + "United Kingdom,1815-12-10"
        let csv = "\(headerLine)\n\(valueLine)"
        let parsed = try #require(CSV.parseContacts(csv))
        #expect(parsed.count == 1)
        let row = parsed[0]
        #expect(row.firstName == "Ada")
        #expect(row.lastName == "Lovelace")
        #expect(row.company == "Analytical Engine Co.")
        #expect(row.jobTitle == "Mathematician")
        #expect(row.street == "12 Mayfair")
        #expect(row.city == "London")
        #expect(row.postalCode == "W1")
        #expect(row.country == "United Kingdom")
        #expect(row.emails.count == 1)
        #expect(row.emails[0].value == "ada@analytical.engine")
        #expect(row.emails[0].label == .home)
        #expect(row.phones.count == 1)
        #expect(row.phones[0].value == "+1 555 0100")
        #expect(row.phones[0].label == .mobile)
        // Read back through the UTC-anchored calendar the importer uses, so
        // the assertion doesn't depend on the test machine's time zone.
        let fields = try Birthday.fields(of: #require(row.birthday))
        #expect(fields.year == 1815)
        #expect(fields.month == 12)
        #expect(fields.day == 10)
    }

    @Test func parsesYearlessBirthdayColumn() throws {
        let csv = "First Name,Birthday\nNoYear,--04-15"
        let parsed = try #require(CSV.parseContacts(csv))
        let fields = try Birthday.fields(of: #require(parsed.first?.birthday))
        #expect(fields.year == nil)
        #expect(fields.month == 4)
        #expect(fields.day == 15)
    }

    @Test func parsesOutlookExportWithLabeledPhones() throws {
        let csv = """
        First Name,Last Name,Company,E-mail Address,Home Phone,Mobile Phone,Business Phone
        Grace,Hopper,US Navy,grace@navy.mil,+1 555 0001,+1 555 0002,+1 555 0003
        """
        let parsed = try #require(CSV.parseContacts(csv))
        let row = parsed[0]
        #expect(row.emails.map(\.value) == ["grace@navy.mil"])
        #expect(row.phones.map(\.value) == ["+1 555 0001", "+1 555 0002", "+1 555 0003"])
        #expect(row.phones.map(\.label) == [.home, .mobile, .work])
    }

    @Test func collectsMultipleIndexedEmailsFromGoogle() throws {
        let csv = """
        First Name,E-mail 1 - Value,E-mail 2 - Value
        Margaret,first@example.com,second@example.com
        """
        let parsed = try #require(CSV.parseContacts(csv))
        #expect(parsed[0].emails.map(\.value) == ["first@example.com", "second@example.com"])
    }

    @Test func splitsFullNameOnLastSpaceWhenFirstAndLastAreMissing() throws {
        let csv = """
        Name,Email
        Søren Kierkegaard,soren@example.com
        """
        let parsed = try #require(CSV.parseContacts(csv))
        #expect(parsed[0].firstName == "Søren")
        #expect(parsed[0].lastName == "Kierkegaard")
    }

    @Test func keepsExplicitFirstAndLastWhenAFullNameColumnIsAlsoPresent() throws {
        let csv = """
        Name,First Name,Last Name
        Alan M. Turing,Alan,Turing
        """
        let parsed = try #require(CSV.parseContacts(csv))
        #expect(parsed[0].firstName == "Alan")
        #expect(parsed[0].lastName == "Turing")
    }

    @Test func returnsNilForUnrecognizedHeaders() {
        let csv = "Yomi Name,Custom Field\nAlan,Whatever\n"
        #expect(CSV.parseContacts(csv) == nil)
    }

    @Test func dropsEmptyRows() throws {
        let csv = """
        First Name,Email
        Ada,ada@example.com
        ,
        Grace,grace@example.com
        """
        let parsed = try #require(CSV.parseContacts(csv))
        #expect(parsed.count == 2)
        #expect(parsed.map(\.firstName) == ["Ada", "Grace"])
    }

    @Test func handlesQuotedFieldsWithCommasInValues() throws {
        let csv = """
        First Name,Last Name,Notes
        Ada,Lovelace,"Loves semicolons, commas, and Bernoulli numbers."
        """
        let parsed = try #require(CSV.parseContacts(csv))
        #expect(parsed[0].notes == "Loves semicolons, commas, and Bernoulli numbers.")
    }

    @Test func skipsValuesWithUnparseableBirthdays() throws {
        let csv = """
        First Name,Birthday
        Ada,Dec 10 1815
        """
        let parsed = try #require(CSV.parseContacts(csv))
        // Non-ISO format → no birthday rather than wrong birthday.
        #expect(parsed[0].birthday == nil)
        #expect(parsed[0].firstName == "Ada")
    }
}

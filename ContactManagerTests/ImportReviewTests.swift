//
//  ImportReviewTests.swift
//  ContactManagerTests
//
//  Tests the preflight review that keeps imports from blindly appending
//  duplicates. The write path still goes through ContactStore, so decisions
//  are saved, undoable, and indexed like other mutations.
//

@testable import ContactManager
import SwiftData
import Testing

@MainActor
@Suite(.serialized)
struct ImportReviewTests {
    let container: ModelContainer
    let store: ContactStore
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: Contact.self, ContactField.self, ContactGroup.self, ContactInteraction.self,
            ContactTag.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = ContactStore(container.mainContext)
    }

    private func allContacts() throws -> [Contact] {
        try context.fetch(FetchDescriptor<Contact>())
    }

    @Test func newContactsDefaultToAdd() throws {
        let parsed = ParsedContact(firstName: "Ada", lastName: "Lovelace")

        let item = try #require(ImportReview.makeItems(for: [parsed], existing: []).first)

        #expect(item.decision == .add)
        #expect(item.matchedContact == nil)
    }

    @Test func exactDuplicatesDefaultToSkip() throws {
        let existing = try store.createContact()
        existing.firstName = "Ada"
        existing.lastName = "Lovelace"
        try store.addField(.email, value: "ada@example.com", to: existing)
        try context.save()
        var parsed = ParsedContact(firstName: "Ada", lastName: "Lovelace")
        parsed.emails = [(.home, "ADA@example.com")]

        let item = try #require(ImportReview.makeItems(for: [parsed], existing: [existing]).first)

        #expect(item.decision == .skip)
        #expect(item.matchedContact?.persistentModelID == existing.persistentModelID)
        #expect(item.confidence == .exact)
        #expect(item.matchReason == "same email")
    }

    @Test func partialMatchesDefaultToUpdateExisting() throws {
        let existing = try store.createContact()
        existing.firstName = "Ada"
        existing.lastName = "Lovelace"
        try store.addField(.email, value: "ada@example.com", to: existing)
        try context.save()
        var parsed = ParsedContact(firstName: "Ada", lastName: "Lovelace", company: "Analytical Engine Co.")
        parsed.emails = [(.home, "ada@example.com")]
        parsed.phones = [(.mobile, "+1 555 0100")]

        let item = try #require(ImportReview.makeItems(for: [parsed], existing: [existing]).first)

        #expect(item.decision == .updateExisting)
        #expect(item.confidence == .likely)
        #expect(item.matchReason == "same email")
    }

    @Test func nameOnlyMatchesArePossible() throws {
        let existing = try store.createContact()
        existing.firstName = "Katherine"
        existing.lastName = "Johnson"
        try context.save()
        let parsed = ParsedContact(firstName: "Katherine", lastName: "Johnson", company: "NASA")

        let item = try #require(ImportReview.makeItems(for: [parsed], existing: [existing]).first)

        #expect(item.decision == .updateExisting)
        #expect(item.confidence == .possible)
        #expect(item.matchReason == "same full name")
    }

    @Test func applyingReviewAddsUpdatesSkipsAndMerges() throws {
        let exact = try store.createContact()
        exact.firstName = "Ada"
        exact.lastName = "Lovelace"
        try store.addField(.email, value: "ada@example.com", to: exact)

        let partial = try store.createContact()
        partial.firstName = "Alan"
        partial.lastName = "Turing"
        try store.addField(.email, value: "alan@example.com", to: partial)

        let conflicting = try store.createContact()
        conflicting.firstName = "Grace"
        conflicting.lastName = "Hopper"
        conflicting.company = "Navy"
        try store.addField(.email, value: "grace@example.com", to: conflicting)
        try context.save()

        var exactParsed = ParsedContact(firstName: "Ada", lastName: "Lovelace")
        exactParsed.emails = [(.home, "ada@example.com")]
        var partialParsed = ParsedContact(firstName: "Alan", lastName: "Turing", company: "Bletchley Park")
        partialParsed.emails = [(.home, "alan@example.com")]
        partialParsed.phones = [(.mobile, "555-0101")]
        let newParsed = ParsedContact(firstName: "Katherine", lastName: "Johnson")
        var conflictingParsed = ParsedContact(firstName: "Grace", lastName: "Hopper", company: "ACM")
        conflictingParsed.emails = [(.home, "grace@example.com")]
        conflictingParsed.phones = [(.work, "555-0102")]

        var items = ImportReview.makeItems(
            for: [exactParsed, partialParsed, newParsed, conflictingParsed],
            existing: [exact, partial, conflicting]
        )
        items[3].decision = .merge

        let applied = try store.applyImportReview(items)

        #expect(applied.added == 1)
        #expect(applied.updated == 1)
        #expect(applied.merged == 1)
        #expect(applied.skipped == 1)
        #expect(try allContacts().count == 4)
        #expect(partial.company == "Bletchley Park")
        #expect(partial.phones.map(\.value) == ["555-0101"])
        #expect(conflicting.company == "Navy")
        #expect(conflicting.phones.map(\.value) == ["555-0102"])
    }

    @Test func importSummaryFormatsOnlyNonZeroCounts() {
        let result = ImportReviewResult(added: 2, updated: 1, merged: 0, skipped: 3)

        #expect(result.title == "Imported 3 Contacts")
        #expect(result.message == "Added 2, updated 1, skipped 3.")
    }

    @Test func importSummaryCombinesChunkResults() {
        var result = ImportReviewResult(added: 1, updated: 0, merged: 1, skipped: 0)

        result.add(ImportReviewResult(added: 0, updated: 2, merged: 0, skipped: 4))

        #expect(result.added == 1)
        #expect(result.updated == 2)
        #expect(result.merged == 1)
        #expect(result.skipped == 4)
        #expect(result.totalWritten == 4)
    }

    @Test func pendingSummaryCountsDecisionsAndFormatsThemForReview() throws {
        let existing = try store.createContact()
        existing.firstName = "Ada"
        existing.lastName = "Lovelace"
        try store.addField(.email, value: "ada@example.com", to: existing)
        try context.save()

        var matchedParsed = ParsedContact(firstName: "Ada", lastName: "Lovelace", company: "Analytical Engine Co.")
        matchedParsed.emails = [(.home, "ada@example.com")]
        let newParsed = ParsedContact(firstName: "Katherine", lastName: "Johnson")

        var items = ImportReview.makeItems(for: [matchedParsed, newParsed], existing: [existing])
        items[0].decision = .updateExisting
        items[1].decision = .skip

        let summary = ImportReviewPendingSummary(items: items)

        #expect(summary.add == 0)
        #expect(summary.updateExisting == 1)
        #expect(summary.merge == 0)
        #expect(summary.skip == 1)
        #expect(summary.totalToWrite == 1)
        #expect(summary.reviewText == "Update Existing 1, Skip 1")
        #expect(summary.importButtonTitle == "Import 1 Contact")
    }

    @Test func applyingBatchDecisionOnlyChangesEligibleRows() throws {
        let existing = try store.createContact()
        existing.firstName = "Ada"
        existing.lastName = "Lovelace"
        try store.addField(.email, value: "ada@example.com", to: existing)
        try context.save()

        var matchedParsed = ParsedContact(firstName: "Ada", lastName: "Lovelace", company: "Analytical Engine Co.")
        matchedParsed.emails = [(.home, "ada@example.com")]
        let newParsed = ParsedContact(firstName: "Katherine", lastName: "Johnson")

        var items = ImportReview.makeItems(for: [matchedParsed, newParsed], existing: [existing])

        ImportReview.apply(.merge, to: &items)

        #expect(items[0].decision == .merge)
        #expect(items[1].decision == .add)

        ImportReview.apply(.skip, to: &items)

        #expect(items.map(\.decision) == [.skip, .skip])
    }
}

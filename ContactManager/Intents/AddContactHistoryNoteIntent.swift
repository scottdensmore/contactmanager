//
//  AddContactHistoryNoteIntent.swift
//  ContactManager
//
//  Shortcut action for appending relationship history to an existing contact.
//

import AppIntents
import Foundation

struct AddContactHistoryNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Contact History Note"
    static let description = IntentDescription(
        "Add a dated call, email, meeting, message, or note to a ContactManager contact."
    )

    @Parameter(title: "Contact") var contact: ContactEntity
    @Parameter(title: "Kind") var kind: ContactInteractionKind?
    @Parameter(title: "Summary") var summary: String
    @Parameter(title: "Date") var date: Date?

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ContactEntity> {
        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSummary.isEmpty else { throw ContactIntentError.blankHistorySummary }

        let container = try ContactIntentResolver.container()
        let context = container.mainContext
        let resolvedContact = try ContactIntentResolver.contact(matching: contact, in: context)
        try ContactStore(context).addInteraction(
            to: resolvedContact,
            kind: kind ?? .note,
            summary: trimmedSummary,
            at: date ?? .now
        )
        return .result(value: ContactEntity(contact: resolvedContact))
    }
}

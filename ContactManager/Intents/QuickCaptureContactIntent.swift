//
//  QuickCaptureContactIntent.swift
//  ContactManager
//
//  Shortcut action that creates a contact from the same natural-language-ish
//  entry format as the app's quick capture window.
//

import AppIntents
import Foundation

struct QuickCaptureContactIntent: AppIntent {
    static let title: LocalizedStringResource = "Quick Capture Contact"
    static let description = IntentDescription(
        "Create a ContactManager contact from a quick entry like \"Ada Lovelace, ada@example.com, birthday Dec 10\"."
    )

    @Parameter(title: "Text") var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ContactEntity> {
        let draft = QuickCaptureParser.parse(text)
        guard !draft.isEmpty else { throw ContactIntentError.blankContactInput }

        let container = try ContactIntentResolver.container()
        let contact = try ContactStore(container.mainContext).createContact(from: draft)
        return .result(value: ContactEntity(contact: contact))
    }
}

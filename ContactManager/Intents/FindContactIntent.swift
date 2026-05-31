//
//  FindContactIntent.swift
//  ContactManager
//
//  Shortcut/Siri action: returns contacts matching a query string. The
//  results can be piped into downstream actions (e.g. Open Contact).
//

import AppIntents
import Foundation

struct FindContactIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Contact"
    static let description = IntentDescription(
        "Search ContactManager by name, company, email, or notes."
    )

    @Parameter(title: "Query") var query: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[ContactEntity]> {
        let matches = try await ContactEntityQuery().entities(matching: query)
        return .result(value: matches)
    }
}

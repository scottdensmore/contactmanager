//
//  OpenContactIntentTests.swift
//  ContactManagerTests
//
//  Verifies the Open Contact App Intent posts the selection notification
//  ContentView listens for, carrying the contact's encoded id.
//

@testable import ContactManager
import Foundation
import Testing

@MainActor
struct OpenContactIntentTests {
    @Test func performPostsOpenRequestWithContactID() async throws {
        // Use an explicit, known id so the test proves the posted payload
        // carries *this* identifier — not just that two (possibly empty)
        // strings happen to match.
        let knownID = "contact-id-under-test"
        let entity = ContactEntity(
            id: knownID, displayName: "Ada Lovelace",
            company: "", jobTitle: "", emails: [], phones: []
        )

        var capturedID: String?
        let token = NotificationCenter.default.addObserver(
            forName: .openContactRequested, object: nil, queue: nil
        ) { note in
            capturedID = note.userInfo?["id"] as? String
        }
        defer { NotificationCenter.default.removeObserver(token) }

        var intent = OpenContactIntent()
        intent.target = entity
        _ = try await intent.perform()

        #expect(capturedID == knownID)
    }
}

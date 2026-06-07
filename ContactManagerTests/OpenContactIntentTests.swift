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
        let entity = ContactEntity(contact: Contact(firstName: "Ada", lastName: "Lovelace"))

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

        #expect(capturedID == entity.id)
    }
}

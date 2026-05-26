//
//  SampleData.swift
//  ContactManager
//
//  Seeds a fresh store with a few sample contacts so the app has something
//  to show on first launch.
//

import Foundation
import SwiftData

enum SampleData {
    /// Number of contacts produced by `makeContacts()`.
    static let count = 3

    /// Builds a fresh set of sample contacts. Each call returns brand-new
    /// instances so they can be safely inserted into any model context.
    static func makeContacts() -> [Contact] {
        [
            Contact(firstName: "Ada", lastName: "Lovelace",
                    emailAddress: "ada@analytical.engine", phoneNumber: "+1 (555) 0100"),
            Contact(firstName: "Alan", lastName: "Turing",
                    emailAddress: "alan@bletchley.uk", phoneNumber: "+44 20 7555 0142"),
            Contact(firstName: "Grace", lastName: "Hopper",
                    emailAddress: "grace@navy.mil", phoneNumber: "+1 (555) 0199"),
        ]
    }

    /// Inserts the sample contacts only when the store is verified empty.
    /// Throws if the store can't be read or saved, so callers can react to a
    /// genuine store problem instead of masking it as "empty".
    @MainActor
    static func seedIfNeeded(_ context: ModelContext) throws {
        guard try context.fetchCount(FetchDescriptor<Contact>()) == 0 else { return }

        for contact in makeContacts() {
            context.insert(contact)
        }
        try context.save()
    }
}

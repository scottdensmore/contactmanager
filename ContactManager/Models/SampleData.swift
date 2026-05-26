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
        let ada = Contact(
            firstName: "Ada", lastName: "Lovelace",
            company: "Analytical Engine Co.", jobTitle: "Mathematician",
            city: "London", country: "United Kingdom",
            notes: "First computer programmer."
        )
        ada.fields = [
            ContactField(kind: .email, label: .work, value: "ada@analytical.engine", sortIndex: 0),
            ContactField(kind: .phone, label: .mobile, value: "+1 (555) 0100", sortIndex: 0),
        ]

        let alan = Contact(
            firstName: "Alan", lastName: "Turing",
            company: "Bletchley Park", jobTitle: "Cryptanalyst",
            city: "Milton Keynes", country: "United Kingdom"
        )
        alan.fields = [
            ContactField(kind: .email, label: .work, value: "alan@bletchley.uk", sortIndex: 0),
            ContactField(kind: .phone, label: .work, value: "+44 20 7555 0142", sortIndex: 0),
        ]

        let grace = Contact(
            firstName: "Grace", lastName: "Hopper",
            company: "US Navy", jobTitle: "Rear Admiral",
            city: "Arlington", state: "VA", country: "USA"
        )
        grace.fields = [
            ContactField(kind: .email, label: .work, value: "grace@navy.mil", sortIndex: 0),
            ContactField(kind: .phone, label: .main, value: "+1 (555) 0199", sortIndex: 0),
        ]

        return [ada, alan, grace]
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

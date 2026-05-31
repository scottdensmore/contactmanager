//
//  ContactEntity.swift
//  ContactManager
//
//  The App Intents identity for a `Contact`. Conforms to `IndexedEntity`
//  so the same value also drives the CoreSpotlight attribute set,
//  avoiding a parallel "Spotlight model" alongside the intents model.
//

import AppIntents
import CoreSpotlight
import Foundation

struct ContactEntity: AppEntity, IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Contact")
    static let defaultQuery = ContactEntityQuery()

    /// Stable identifier: the contact's `PersistentIdentifier` encoded as
    /// a string (same scheme used by the default-group preference).
    var id: String
    var displayName: String
    var company: String
    var jobTitle: String
    var emails: [String]
    var phones: [String]

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(displayName)",
            subtitle: subtitleText.map { "\($0)" }
        )
    }

    /// CoreSpotlight metadata built from the same fields the entity carries,
    /// so Spotlight's preview shows the same info Shortcuts/Siri reads.
    var attributeSet: CSSearchableItemAttributeSet {
        let attrs = CSSearchableItemAttributeSet(contentType: .contact)
        attrs.displayName = displayName
        attrs.contentDescription = subtitleText
        if !emails.isEmpty { attrs.emailAddresses = emails }
        if !phones.isEmpty { attrs.phoneNumbers = phones }
        if !company.isBlank { attrs.organizations = [company] }
        if !jobTitle.isBlank { attrs.title = jobTitle }
        return attrs
    }

    /// Subtitle preferences match the contact list row: primary email, then
    /// primary phone, then company. Whitespace-only values are treated as
    /// empty (same as `Contact.subtitle`) so Shortcuts/Spotlight never show
    /// a blank-looking subtitle.
    private var subtitleText: String? {
        if let first = emails.first(where: { !$0.isBlank }) { return first }
        if let first = phones.first(where: { !$0.isBlank }) { return first }
        if !company.isBlank { return company }
        return nil
    }
}

extension ContactEntity {
    /// Snapshot a SwiftData `Contact` into an entity value. Safe to call
    /// off the main actor as long as the `Contact` is fetched there too.
    init(contact: Contact) {
        id = contact.persistentModelID.storedString ?? ""
        displayName = contact.fullName
        company = contact.company
        jobTitle = contact.jobTitle
        // Drop blank/whitespace-only values so Spotlight doesn't index
        // empty rows. Matches `Contact.primaryEmail/primaryPhone` semantics.
        emails = contact.emails.map(\.value).filter { !$0.isBlank }
        phones = contact.phones.map(\.value).filter { !$0.isBlank }
    }
}

private extension String {
    /// Treats whitespace-only strings as empty, matching how the rest of
    /// the codebase decides whether a contact field is "set".
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

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
        if !company.isEmpty { attrs.organizations = [company] }
        if !jobTitle.isEmpty { attrs.title = jobTitle }
        return attrs
    }

    /// Subtitle preferences match the contact list row: primary email, then
    /// primary phone, then company. Returns `nil` if everything is empty.
    private var subtitleText: String? {
        if let first = emails.first, !first.isEmpty { return first }
        if let first = phones.first, !first.isEmpty { return first }
        if !company.isEmpty { return company }
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
        emails = contact.emails.map(\.value).filter { !$0.isEmpty }
        phones = contact.phones.map(\.value).filter { !$0.isEmpty }
    }
}

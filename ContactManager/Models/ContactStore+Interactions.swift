//
//  ContactStore+Interactions.swift
//  ContactManager
//
//  Relationship-history mutations.
//

import Foundation

extension ContactStore {
    @discardableResult
    func addInteraction(
        to contact: Contact,
        kind: ContactInteractionKind = .note,
        summary: String,
        at date: Date = .now
    ) throws -> ContactInteraction {
        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return try mutate("Add History Note") {
            let interaction = ContactInteraction(kind: kind, summary: trimmedSummary, date: date)
            interaction.contact = contact
            context.insert(interaction)
            if contact.lastContactedAt.map({ date > $0 }) ?? true {
                contact.lastContactedAt = date
            }
            return interaction
        }
    }

    func delete(_ interaction: ContactInteraction) throws {
        try mutate("Delete History Note") {
            context.delete(interaction)
        }
    }

    func adoptInteractions(into primary: Contact, from other: Contact) {
        for interaction in other.sortedInteractions {
            interaction.contact = primary
        }
    }
}

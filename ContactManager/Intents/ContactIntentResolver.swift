//
//  ContactIntentResolver.swift
//  ContactManager
//
//  Shared lookup helpers for App Intent mutations.
//

import Foundation
import SwiftData

enum ContactIntentResolver {
    static func container() throws -> ModelContainer {
        guard let container = EntityModelContainer.shared else {
            throw ContactIntentError.missingContainer
        }
        return container
    }

    @MainActor
    static func contact(matching entity: ContactEntity, in context: ModelContext) throws -> Contact {
        let contacts = try context.fetch(FetchDescriptor<Contact>())
        guard let contact = contacts.first(where: { $0.persistentModelID.storedString == entity.id }) else {
            throw ContactIntentError.missingContact
        }
        return contact
    }
}

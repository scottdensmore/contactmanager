//
//  ContactStore+Batch.swift
//  ContactManager
//
//  Multi-contact mutations used by batch actions.
//

extension ContactStore {
    @discardableResult
    func delete(_ contacts: [Contact]) throws -> Int {
        guard !contacts.isEmpty else { return 0 }
        return try mutate("Delete Contacts") {
            contacts.forEach(context.delete)
            return contacts.count
        }
    }

    @discardableResult
    func addContacts(_ contacts: [Contact], to group: ContactGroup) throws -> Int {
        let groupID = group.persistentModelID
        let toAdd = contacts.filter { contact in
            !contact.groups.contains { $0.persistentModelID == groupID }
        }
        guard !toAdd.isEmpty else { return 0 }
        return try mutate("Add to Group") {
            toAdd.forEach { $0.groups.append(group) }
            return toAdd.count
        }
    }
}

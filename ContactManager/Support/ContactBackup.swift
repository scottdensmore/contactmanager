//
//  ContactBackup.swift
//  ContactManager
//
//  Codable snapshot format for ContactManager backups.
//

import Foundation
import SwiftData

struct ContactBackup: Codable, Equatable {
    static let currentVersion = 2

    var version: Int
    var exportedAt: Date
    var groups: [GroupRecord]
    var savedSmartLists: [SavedSmartListRecord]
    var contacts: [ContactRecord]

    init(
        version: Int = Self.currentVersion,
        exportedAt: Date = .now,
        groups: [GroupRecord] = [],
        savedSmartLists: [SavedSmartListRecord] = [],
        contacts: [ContactRecord] = []
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.groups = groups
        self.savedSmartLists = savedSmartLists
        self.contacts = contacts
    }

    static func make(
        contacts: [Contact],
        groups: [ContactGroup],
        savedSmartLists: [ContactSavedSmartList] = [],
        exportedAt: Date = .now
    ) -> ContactBackup {
        let groupIDs = Dictionary(uniqueKeysWithValues: groups.map { group in
            (group.persistentModelID, backupID(for: group))
        })
        return ContactBackup(
            exportedAt: exportedAt,
            groups: groups
                .sorted { lhs, rhs in
                    if lhs.displayName != rhs.displayName { return lhs.displayName < rhs.displayName }
                    return lhs.createdAt < rhs.createdAt
                }
                .map { GroupRecord(id: backupID(for: $0), name: $0.name, createdAt: $0.createdAt) },
            savedSmartLists: savedSmartLists
                .sorted { lhs, rhs in
                    if lhs.displayName != rhs.displayName { return lhs.displayName < rhs.displayName }
                    return lhs.createdAt < rhs.createdAt
                }
                .map { SavedSmartListRecord(name: $0.name, query: $0.query, createdAt: $0.createdAt) },
            contacts: ContactQuery.sorted(contacts).map { contact in
                ContactRecord(contact: contact, groupIDs: groupIDs)
            }
        )
    }

    private static func backupID(for group: ContactGroup) -> String {
        group.persistentModelID.storedString ?? String(describing: group.persistentModelID)
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case exportedAt
        case groups
        case savedSmartLists
        case contacts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        groups = try container.decode([GroupRecord].self, forKey: .groups)
        savedSmartLists = try container.decodeIfPresent([SavedSmartListRecord].self, forKey: .savedSmartLists) ?? []
        contacts = try container.decode([ContactRecord].self, forKey: .contacts)
    }
}

extension ContactBackup {
    struct GroupRecord: Codable, Equatable, Identifiable {
        var id: String
        var name: String
        var createdAt: Date
    }

    struct SavedSmartListRecord: Codable, Equatable {
        var name: String
        var query: String
        var createdAt: Date
    }

    struct ContactRecord: Codable, Equatable, Identifiable {
        var id: String
        var firstName: String
        var lastName: String
        var company: String
        var jobTitle: String
        var street: String
        var city: String
        var state: String
        var postalCode: String
        var country: String
        var birthday: Date?
        var lastContactedAt: Date?
        var notes: String
        var createdAt: Date
        var photoData: Data?
        var fields: [FieldRecord]
        var groupIDs: [String]
        var interactions: [InteractionRecord]

        init(contact: Contact, groupIDs: [PersistentIdentifier: String]) {
            id = contact.persistentModelID.storedString ?? String(describing: contact.persistentModelID)
            firstName = contact.firstName
            lastName = contact.lastName
            company = contact.company
            jobTitle = contact.jobTitle
            street = contact.street
            city = contact.city
            state = contact.state
            postalCode = contact.postalCode
            country = contact.country
            birthday = contact.birthday
            lastContactedAt = contact.lastContactedAt
            notes = contact.notes
            createdAt = contact.createdAt
            photoData = contact.photoData
            fields = contact.fields
                .sorted { lhs, rhs in
                    if lhs.kind != rhs.kind { return lhs.kind.rawValue < rhs.kind.rawValue }
                    return lhs.sortIndex < rhs.sortIndex
                }
                .map(FieldRecord.init(field:))
            self.groupIDs = contact.groups.compactMap { groupIDs[$0.persistentModelID] }.sorted()
            interactions = contact.sortedInteractions.map(InteractionRecord.init(interaction:))
        }
    }

    struct FieldRecord: Codable, Equatable {
        var kind: FieldKind
        var label: FieldLabel
        var value: String
        var sortIndex: Int

        init(field: ContactField) {
            kind = field.kind
            label = field.label
            value = field.value
            sortIndex = field.sortIndex
        }
    }

    struct InteractionRecord: Codable, Equatable {
        var date: Date
        var kind: ContactInteractionKind
        var summary: String

        init(interaction: ContactInteraction) {
            date = interaction.date
            kind = interaction.kind
            summary = interaction.summary
        }
    }
}

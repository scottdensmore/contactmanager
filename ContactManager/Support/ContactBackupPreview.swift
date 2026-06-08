//
//  ContactBackupPreview.swift
//  ContactManager
//
//  Summary data for inspecting a backup before restore.
//

import Foundation

struct ContactBackupPreview: Equatable {
    var exportedAt: Date
    var contactCount: Int
    var groupCount: Int
    var emailCount: Int
    var phoneCount: Int
    var historyNoteCount: Int
    var photoCount: Int
    var sampleContactNames: [String]

    var isEmpty: Bool {
        contactCount == 0 && groupCount == 0 && historyNoteCount == 0
    }

    init(backup: ContactBackup) {
        exportedAt = backup.exportedAt
        contactCount = backup.contacts.count
        groupCount = backup.groups.count
        emailCount = backup.contacts.flatMap(\.fields).filter { $0.kind == .email }.count
        phoneCount = backup.contacts.flatMap(\.fields).filter { $0.kind == .phone }.count
        historyNoteCount = backup.contacts.flatMap(\.interactions).count
        photoCount = backup.contacts.filter { $0.photoData != nil }.count
        sampleContactNames = backup.contacts
            .map(\.displayName)
            .prefix(5)
            .map(\.self)
    }

    var summary: String {
        let parts = [
            count(contactCount, singular: "contact"),
            count(groupCount, singular: "group"),
            count(emailCount, singular: "email"),
            count(phoneCount, singular: "phone"),
            count(historyNoteCount, singular: "history note"),
            count(photoCount, singular: "photo"),
        ].compactMap(\.self)
        return parts.isEmpty ? "0 contacts" : parts.joined(separator: ", ")
    }

    private func count(_ value: Int, singular: String) -> String? {
        guard value > 0 else { return nil }
        let label = value == 1 ? singular : "\(singular)s"
        return "\(value) \(label)"
    }
}

private extension ContactBackup.ContactRecord {
    var displayName: String {
        let name = [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if !name.isEmpty { return name }
        let trimmedCompany = company.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCompany.isEmpty { return trimmedCompany }
        return "Contact"
    }
}

//
//  ContactBackupTests.swift
//  ContactManagerTests
//
//  Backup/export and additive restore coverage.
//

@testable import ContactManager
import Foundation
import SwiftData
import Testing

@MainActor
@Suite(.serialized)
struct ContactBackupTests {
    let container: ModelContainer
    let store: ContactStore
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: Contact.self, ContactField.self, ContactGroup.self, ContactInteraction.self,
            ContactSavedSmartList.self, ContactTag.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = ContactStore(container.mainContext)
    }

    private func allContacts() throws -> [Contact] {
        try context.fetch(FetchDescriptor<Contact>())
    }

    private func allGroups() throws -> [ContactGroup] {
        try context.fetch(FetchDescriptor<ContactGroup>())
    }

    private func allSavedSmartLists() throws -> [ContactSavedSmartList] {
        try context.fetch(FetchDescriptor<ContactSavedSmartList>())
    }

    private func allTags() throws -> [ContactTag] {
        try context.fetch(FetchDescriptor<ContactTag>())
    }

    @Test func backupCapturesContactsGroupsFieldsAndHistory() throws {
        let contact = try makePopulatedContact()
        let savedList = try store.createSavedSmartList(named: "Engine People", query: "engine")
        let tag = try store.createTag(named: "VIP")
        try store.setMembership(of: contact, in: tag, isMember: true)
        let contacts = try allContacts()
        let groups = try allGroups()
        let tags = try allTags()

        let backup = ContactBackup.make(
            contacts: contacts,
            groups: groups,
            tags: tags,
            savedSmartLists: [savedList],
            exportedAt: Date(timeIntervalSinceReferenceDate: 42)
        )

        let record = try #require(backup.contacts.first)
        #expect(backup.exportedAt == Date(timeIntervalSinceReferenceDate: 42))
        #expect(record.firstName == "Ada")
        #expect(record.fields.map(\.value) == ["ada@example.com"])
        #expect(record.groupIDs.count == 1)
        #expect(record.tagIDs.count == 1)
        #expect(record.interactions.map(\.summary) == ["Met at WWDC."])
        #expect(record.lastContactedAt == contact.lastContactedAt)
        #expect(backup.groups.map(\.name) == ["Work"])
        #expect(backup.tags.map(\.name) == ["VIP"])
        #expect(backup.savedSmartLists.map(\.name) == ["Engine People"])
        #expect(backup.savedSmartLists.map(\.query) == ["engine"])
    }

    @Test func restoreBackupRecreatesContactsGroupsFieldsAndHistory() throws {
        let contact = try makePopulatedContact()
        let savedList = try store.createSavedSmartList(named: "Engine People", query: "engine")
        let tag = try store.createTag(named: "VIP")
        try store.setMembership(of: contact, in: tag, isMember: true)
        let groups = try allGroups()
        let tags = try allTags()
        let original = ContactBackup.make(
            contacts: [contact],
            groups: groups,
            tags: tags,
            savedSmartLists: [savedList],
            exportedAt: Date(timeIntervalSinceReferenceDate: 42)
        )

        let contactsBeforeRestore = try allContacts()
        let groupsBeforeRestore = try allGroups()
        let savedListsBeforeRestore = try allSavedSmartLists()
        let tagsBeforeRestore = try allTags()
        let contactBeforeRestore = try #require(contactsBeforeRestore.first)
        let groupBeforeRestore = try #require(groupsBeforeRestore.first)
        let savedListBeforeRestore = try #require(savedListsBeforeRestore.first)
        let tagBeforeRestore = try #require(tagsBeforeRestore.first)
        try store.delete(contactBeforeRestore)
        try store.delete(groupBeforeRestore)
        try store.delete(savedListBeforeRestore)
        try store.delete(tagBeforeRestore)

        let result = try store.restoreBackup(original)

        let restoredContacts = try allContacts()
        let restoredSavedLists = try allSavedSmartLists()
        let restoredTags = try allTags()
        let restored = try #require(restoredContacts.first)
        #expect(result.contactsRestored == 1)
        #expect(result.groupsRestored == 1)
        #expect(result.tagsRestored == 1)
        #expect(result.savedSmartListsRestored == 1)
        #expect(result.interactionsRestored == 1)
        #expect(restored.fullName == "Ada Lovelace")
        #expect(restored.lastContactedAt == Date(timeIntervalSinceReferenceDate: 200))
        #expect(restored.emails.map(\.value) == ["ada@example.com"])
        #expect(restored.groups.map(\.displayName) == ["Work"])
        #expect(restored.tags.map(\.displayName) == ["VIP"])
        #expect(restored.sortedInteractions.map(\.summary) == ["Met at WWDC."])
        #expect(restoredTags.map(\.displayName) == ["VIP"])
        #expect(restoredSavedLists.map(\.displayName) == ["Engine People"])
        #expect(restoredSavedLists.map(\.query) == ["engine"])
    }

    @Test func backupDocumentRoundTripsJSON() throws {
        let contact = try makePopulatedContact()
        let groups = try allGroups()
        let backup = ContactBackup.make(
            contacts: [contact],
            groups: groups,
            exportedAt: Date(timeIntervalSinceReferenceDate: 42)
        )

        let data = try ContactBackupDocument.encode(backup)
        let decoded = try ContactBackupDocument.decode(data)

        #expect(decoded == backup)
    }

    @Test func backupDocumentDecodesLegacyBackupsWithoutSavedSmartLists() throws {
        let legacyJSON = """
        {
          "contacts" : [],
          "exportedAt" : 42,
          "groups" : [],
          "version" : 1
        }
        """

        let decoded = try ContactBackupDocument.decode(Data(legacyJSON.utf8))

        #expect(decoded.version == 1)
        #expect(decoded.tags.isEmpty)
        #expect(decoded.savedSmartLists.isEmpty)
    }

    @Test func encryptedBackupDocumentRoundTripsWithPassword() throws {
        let contact = try makePopulatedContact()
        let groups = try allGroups()
        let backup = ContactBackup.make(
            contacts: [contact],
            groups: groups,
            exportedAt: Date(timeIntervalSinceReferenceDate: 42)
        )

        let data = try EncryptedContactBackupDocument.encode(backup, password: "correct horse battery staple")
        let decoded = try EncryptedContactBackupDocument.decode(data, password: "correct horse battery staple")

        #expect(EncryptedContactBackupDocument.isEncrypted(data))
        #expect(!data.contains(Data("Ada".utf8)))
        #expect(decoded == backup)
        #expect(try ContactBackupDocument.decode(ContactBackupDocument.encode(backup)) == backup)
    }

    @Test func encryptedBackupDocumentRejectsWrongPassword() throws {
        let contact = try makePopulatedContact()
        let groups = try allGroups()
        let backup = ContactBackup.make(contacts: [contact], groups: groups)
        let data = try EncryptedContactBackupDocument.encode(backup, password: "correct")

        do {
            _ = try EncryptedContactBackupDocument.decode(data, password: "wrong")
            Issue.record("Expected encrypted backup decode to reject the wrong password.")
        } catch let error as ContactBackupEncryptionError {
            #expect(error == .invalidPassword)
        }
    }

    @Test func emptyRestoreSummaryExplainsNothingWasRestored() throws {
        let result = try store.restoreBackup(ContactBackup())

        #expect(result.contactsRestored == 0)
        #expect(result.title == "Restored 0 Contacts")
        #expect(result.message == "No contacts, groups, tags, smart lists, or history notes restored.")
    }

    @Test func backupPreviewSummarizesContentsBeforeRestore() throws {
        let contact = try makePopulatedContact()
        let savedList = try store.createSavedSmartList(named: "Engine People", query: "engine")
        let tag = try store.createTag(named: "VIP")
        try store.setMembership(of: contact, in: tag, isMember: true)
        let groups = try allGroups()
        let tags = try allTags()
        let backup = ContactBackup.make(
            contacts: [contact],
            groups: groups,
            tags: tags,
            savedSmartLists: [savedList],
            exportedAt: Date(timeIntervalSinceReferenceDate: 42)
        )

        let preview = ContactBackupPreview(backup: backup)

        #expect(preview.exportedAt == Date(timeIntervalSinceReferenceDate: 42))
        #expect(preview.contactCount == 1)
        #expect(preview.groupCount == 1)
        #expect(preview.tagCount == 1)
        #expect(preview.savedSmartListCount == 1)
        #expect(preview.emailCount == 1)
        #expect(preview.phoneCount == 0)
        #expect(preview.historyNoteCount == 1)
        #expect(preview.photoCount == 1)
        #expect(preview.sampleContactNames == ["Ada Lovelace"])
        #expect(preview.summary == "1 contact, 1 group, 1 tag, 1 smart list, 1 email, 1 history note, 1 photo")
    }

    @Test func emptyBackupPreviewHasAPlainSummary() {
        let preview = ContactBackupPreview(backup: ContactBackup())

        #expect(preview.contactCount == 0)
        #expect(preview.groupCount == 0)
        #expect(preview.tagCount == 0)
        #expect(preview.savedSmartListCount == 0)
        #expect(preview.isEmpty)
        #expect(preview.sampleContactNames.isEmpty)
        #expect(preview.summary == "0 contacts")
    }

    @Test func groupsOnlyBackupPreviewCanStillRestore() {
        let group = ContactBackup.GroupRecord(
            id: "group-1",
            name: "Friends",
            createdAt: Date(timeIntervalSinceReferenceDate: 10)
        )
        let preview = ContactBackupPreview(backup: ContactBackup(groups: [group]))

        #expect(preview.contactCount == 0)
        #expect(preview.groupCount == 1)
        #expect(!preview.isEmpty)
        #expect(preview.summary == "1 group")
    }

    @discardableResult
    private func makePopulatedContact() throws -> Contact {
        let group = try store.createGroup(named: "Work")
        let contact = try store.createContact(in: group)
        contact.firstName = "Ada"
        contact.lastName = "Lovelace"
        contact.company = "Analytical Engine Co."
        contact.lastContactedAt = Date(timeIntervalSinceReferenceDate: 200)
        contact.createdAt = Date(timeIntervalSinceReferenceDate: 100)
        contact.photoData = Data([0x01, 0x02, 0x03])
        try store.addField(.email, value: "ada@example.com", to: contact)
        _ = try store.addInteraction(
            to: contact,
            kind: .meeting,
            summary: "Met at WWDC.",
            at: Date(timeIntervalSinceReferenceDate: 150)
        )
        return contact
    }
}

//
//  ContactStoreTests.swift
//  ContactManagerTests
//
//  End-to-end "user journey" tests that drive the real ContactStore operations
//  against an in-memory SwiftData container — the same code the views call.
//

@testable import ContactManager
import CoreGraphics
import Foundation
import ImageIO
import SwiftData
import Testing
import UniformTypeIdentifiers

@MainActor
@Suite(.serialized)
struct ContactStoreTests {
    let container: ModelContainer
    let store: ContactStore
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: Contact.self, ContactField.self, ContactGroup.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = ContactStore(container.mainContext)
    }

    private func allContacts() throws -> [Contact] {
        try context.fetch(FetchDescriptor<Contact>())
    }

    private func count<T: PersistentModel>(_: T.Type) throws -> Int {
        try context.fetchCount(FetchDescriptor<T>())
    }

    // MARK: - Journey: create a contact and edit it

    // MARK: - Journey: delete a contact (cascades to its fields)

    @Test func deleteContactCascadesToFields() throws {
        let contact = try store.createContact()
        try store.addField(.email, to: contact)
        try store.addField(.phone, to: contact)
        #expect(try count(ContactField.self) == 2)

        try store.delete(contact)
        #expect(try count(Contact.self) == 0)
        #expect(try count(ContactField.self) == 0)
    }

    // MARK: - Journey: add/remove emails & phones keep a stable order

    @Test func fieldSortIndicesStayStrictlyIncreasing() throws {
        let contact = try store.createContact()
        let first = try store.addField(.email, to: contact)
        _ = try store.addField(.email, to: contact)
        #expect(contact.emails.map(\.sortIndex) == [0, 1])

        // Deleting the first then adding another must not reuse index 0.
        try store.delete([first])
        let third = try store.addField(.email, to: contact)
        #expect(third.sortIndex == 2)
        #expect(contact.emails.map(\.sortIndex) == [1, 2])
    }

    // MARK: - Journey: a new contact joins the selected group

    @Test func newContactJoinsSelectedGroup() throws {
        let group = try store.createGroup(named: "Work")
        let contact = try store.createContact(in: group)

        #expect(contact.groups.map(\.name) == ["Work"])
        #expect(group.contacts.count == 1)
    }

    // MARK: - Journey: organize into a group, then delete the group

    @Test func groupMembershipScopesContactsAndDeleteClearsIt() throws {
        let group = try store.createGroup(named: "Friends")
        let ada = try store.createContact()
        let alan = try store.createContact()

        try store.setMembership(of: ada, in: group, isMember: true)
        #expect(group.contacts.map(\.persistentModelID) == [ada.persistentModelID])

        // Toggling membership on again is a no-op (no duplicates).
        try store.setMembership(of: ada, in: group, isMember: true)
        #expect(group.contacts.count == 1)

        try store.rename(group, to: "Besties")
        #expect(group.displayName == "Besties")

        // Deleting the group keeps both contacts and clears membership.
        try store.delete(group)
        #expect(try count(ContactGroup.self) == 0)
        #expect(try count(Contact.self) == 2)
        #expect(ada.groups.isEmpty)
        #expect(alan.groups.isEmpty)
    }

    @Test func deletingContactRemovesItFromItsGroup() throws {
        let group = try store.createGroup(named: "Work")
        let contact = try store.createContact(in: group)
        #expect(group.contacts.count == 1)

        try store.delete(contact)
        #expect(group.contacts.isEmpty)
        #expect(try count(ContactGroup.self) == 1)
    }

    @Test func blankGroupRenameIsIgnored() throws {
        let group = try store.createGroup(named: "Work")
        try store.rename(group, to: "   ")
        #expect(group.name == "Work")
    }

    // MARK: - Journey: set and clear a contact photo

    @Test func setAndClearPhoto() throws {
        let contact = try store.createContact()
        try store.setPhotoData(Data([0xFF, 0xD8, 0xFF]), on: contact)
        #expect(contact.photoData != nil)

        try store.setPhotoData(nil, on: contact)
        #expect(contact.photoData == nil)
    }

    // MARK: - Journey: track relationship activity

    @Test func markContactedStoresTheContactDate() throws {
        let contactedAt = try #require(Birthday.calendar.date(from: DateComponents(
            year: 2026, month: 6, day: 7, hour: 12
        )))
        let contact = try store.createContact()

        try store.markContacted(contact, at: contactedAt)

        #expect(contact.lastContactedAt == contactedAt)
    }

    // MARK: - Journey: import contacts from a vCard

    @Test func importVCardCreatesContactsWithFields() throws {
        let document = """
        BEGIN:VCARD
        VERSION:3.0
        FN:Ada Lovelace
        N:Lovelace;Ada;;;
        ORG:Analytical Engine Co.
        EMAIL;TYPE=WORK:ada@analytical.engine
        TEL;TYPE=CELL:+1 (555) 0100
        END:VCARD
        BEGIN:VCARD
        VERSION:3.0
        FN:Alan Turing
        N:Turing;Alan;;;
        END:VCARD
        """
        let imported = try store.importVCards(from: document)
        #expect(imported.count == 2)
        #expect(try count(Contact.self) == 2)

        let ada = try #require(try allContacts().first { $0.lastName == "Lovelace" })
        #expect(ada.company == "Analytical Engine Co.")
        #expect(ada.primaryEmail == "ada@analytical.engine")
        #expect(ada.primaryPhone == "+1 (555) 0100")
        #expect(ada.emails.first?.label == .work)
    }

    // MARK: - Journey: export contacts, then re-import them

    @Test func exportThenReimportRoundTrips() throws {
        let ada = try store.createContact()
        ada.firstName = "Ada"
        ada.lastName = "Lovelace"
        ada.company = "Analytical Engine Co."
        ada.notes = "Notes with ; and , characters"
        try store.addField(.email, value: "ada@analytical.engine", to: ada)
        try store.addField(.phone, value: "+1 (555) 0100", to: ada)
        try context.save()

        let document = try store.exportVCards(allContacts())

        // Wipe, then re-import from the exported document.
        for contact in try allContacts() {
            try store.delete(contact)
        }
        #expect(try count(Contact.self) == 0)

        let reimported = try store.importVCards(from: document)
        let restored = try #require(reimported.first)
        #expect(reimported.count == 1)
        #expect(restored.fullName == "Ada Lovelace")
        #expect(restored.company == "Analytical Engine Co.")
        #expect(restored.notes == "Notes with ; and , characters")
        #expect(restored.primaryEmail == "ada@analytical.engine")
        #expect(restored.primaryPhone == "+1 (555) 0100")
    }

    // MARK: - Journey: merge duplicates

    @Test func mergeUnionsFieldsAndKeepsEarliestAsPrimary() throws {
        let older = try store.createContact()
        older.firstName = "Ada"
        try store.addField(.email, value: "ada@work.com", to: older)

        let newer = try store.createContact()
        newer.lastName = "Lovelace"
        newer.company = "Analytical"
        try store.addField(.email, value: "ada@work.com", to: newer) // duplicate email
        try store.addField(.phone, value: "+1 (555) 0100", to: newer)
        try context.save()

        // Order in the argument shouldn't matter — earliest created wins.
        let merged = try store.merge([newer, older])
        #expect(merged.persistentModelID == older.persistentModelID)
        #expect(try count(Contact.self) == 1)

        #expect(merged.emails.map(\.value) == ["ada@work.com"]) // de-duplicated
        #expect(merged.phones.map(\.value) == ["+1 (555) 0100"])
        #expect(try count(ContactField.self) == 2)

        // Empty fields filled from the other contact.
        #expect(merged.firstName == "Ada")
        #expect(merged.lastName == "Lovelace")
        #expect(merged.company == "Analytical")
    }

    @Test func mergeUnionsGroupsAndAdoptsMissingPhoto() throws {
        let work = try store.createGroup(named: "Work")
        let friends = try store.createGroup(named: "Friends")

        let primary = try store.createContact(in: work)
        primary.firstName = "Ada"
        let other = try store.createContact(in: friends)
        other.firstName = "Ada"
        try store.setPhotoData(Data([0x01, 0x02, 0x03]), on: other)
        try context.save()

        let merged = try store.merge([primary, other])
        #expect(Set(merged.groups.map(\.name)) == ["Work", "Friends"])
        #expect(merged.photoData != nil) // adopted from the other contact
        #expect(try count(Contact.self) == 1)
        #expect(try count(ContactGroup.self) == 2) // groups themselves survive
    }

    @Test func mergeDropsBlankFields() throws {
        let withBlank = try store.createContact()
        withBlank.firstName = "Ada"
        try store.addField(.email, to: withBlank) // blank value

        let withEmail = try store.createContact()
        withEmail.firstName = "Ada"
        try store.addField(.email, value: "ada@x.com", to: withEmail)
        try context.save()

        let merged = try store.merge([withBlank, withEmail])
        #expect(merged.emails.map(\.value) == ["ada@x.com"])
    }

    @Test func mergingASingleContactIsANoOp() throws {
        let contact = try store.createContact()
        let result = try store.merge([contact])
        #expect(result.persistentModelID == contact.persistentModelID)
        #expect(try count(Contact.self) == 1)
    }

    // MARK: - Journey: photo round-trips through vCard export/import

    @Test func photoRoundTripsThroughVCard() throws {
        // Mirror the real app flow: a picked photo is normalized through
        // ImageProcessing before being stored.
        let png = try makePNGData(width: 200, height: 150)
        let jpeg = try #require(ImageProcessing.avatarData(from: png))

        let contact = try store.createContact()
        contact.firstName = "Ada"
        try store.setPhotoData(jpeg, on: contact)
        try context.save()

        let document = try store.exportVCards(allContacts())
        // Real JPEG bytes are advertised with their detected TYPE.
        #expect(document.contains("PHOTO;ENCODING=b;TYPE=JPEG"))

        for existing in try allContacts() {
            try store.delete(existing)
        }

        let reimported = try store.importVCards(from: document)
        let restored = try #require(reimported.first)

        let imageData = try #require(restored.photoData)
        let source = try #require(CGImageSourceCreateWithData(imageData as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        // Imported photo is normalized via ImageProcessing.
        #expect(max(image.width, image.height) <= Int(ImageProcessing.maxPixelSize))
    }

    /// Synthesizes a solid-color PNG of the given size for tests.
    private func makePNGData(width: Int, height: Int) throws -> Data {
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())

        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    // MARK: - Journey: search across the store

    @Test func searchSpansNameCompanyEmailAndNotes() throws {
        let ada = try store.createContact()
        ada.firstName = "Ada"
        ada.lastName = "Lovelace"
        ada.company = "Analytical"
        try store.addField(.email, value: "ada@analytical.engine", to: ada)

        let alan = try store.createContact()
        alan.firstName = "Alan"
        alan.lastName = "Turing"
        alan.notes = "Enigma"
        try context.save()

        let all = try allContacts()
        #expect(ContactQuery.filtered(all, matching: "lovelace").count == 1)
        #expect(ContactQuery.filtered(all, matching: "analytical").count == 1) // company + email
        #expect(ContactQuery.filtered(all, matching: "enigma").first?.firstName == "Alan")
        #expect(ContactQuery.filtered(all, matching: "zzz").isEmpty)
    }
}

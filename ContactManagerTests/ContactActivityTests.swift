//
//  ContactActivityTests.swift
//  ContactManagerTests
//
//  Covers the Handoff NSUserActivity payload for the open contact.
//

@testable import ContactManager
import Foundation
import Testing

struct ContactActivityTests {
    @Test func configurePopulatesHandoffPayload() {
        let activity = NSUserActivity(activityType: ContactActivity.viewContactType)
        ContactActivity.configure(activity, contactID: "encoded-id-1", displayName: "Ada Lovelace")

        #expect(activity.title == "Ada Lovelace")
        #expect(activity.targetContentIdentifier == "encoded-id-1")
        #expect(activity.isEligibleForHandoff)
        #expect(activity.userInfo?[ContactActivity.idKey] as? String == "encoded-id-1")
    }

    @Test func contactIDRoundTripsThroughActivity() {
        let activity = NSUserActivity(activityType: ContactActivity.viewContactType)
        ContactActivity.configure(activity, contactID: "encoded-id-2", displayName: "Alan Turing")
        #expect(ContactActivity.contactID(from: activity) == "encoded-id-2")
    }

    @Test func contactIDIsNilWhenAbsent() {
        let activity = NSUserActivity(activityType: ContactActivity.viewContactType)
        #expect(ContactActivity.contactID(from: activity) == nil)
    }
}

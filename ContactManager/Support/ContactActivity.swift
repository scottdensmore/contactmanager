//
//  ContactActivity.swift
//  ContactManager
//
//  The `NSUserActivity` for "viewing a contact" — advertised for Handoff so
//  the contact open on one device can be continued on another, and consumed
//  on the receiving side. The activity type is also declared in the app's
//  Info.plist (INFOPLIST_KEY_NSUserActivityTypes) so the system advertises it.
//

import Foundation

enum ContactActivity {
    /// Handoff activity type for the currently open contact.
    static let viewContactType = "com.scottdensmore.ContactManager.viewContact"
    /// `userInfo` key holding the contact's encoded `PersistentIdentifier`.
    static let idKey = "id"

    /// Populates an activity (e.g. the one SwiftUI's `.userActivity` hands us)
    /// to advertise the given contact for Handoff. Kept separate from the view
    /// so the payload is unit-tested.
    static func configure(_ activity: NSUserActivity, contactID: String, displayName: String) {
        activity.title = displayName
        activity.userInfo = [idKey: contactID]
        activity.targetContentIdentifier = contactID
        activity.isEligibleForHandoff = true
        // Spotlight indexing is handled separately by `SpotlightIndexer`.
        activity.isEligibleForSearch = false
    }

    /// The encoded contact id carried by a continued activity, if any.
    static func contactID(from activity: NSUserActivity) -> String? {
        activity.userInfo?[idKey] as? String
    }
}

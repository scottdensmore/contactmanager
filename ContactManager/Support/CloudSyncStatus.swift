//
//  CloudSyncStatus.swift
//  ContactManager
//
//  User-facing sync status derived from the CloudKit container load path.
//

import SwiftUI

struct CloudSyncStatus: Equatable {
    enum Kind: Equatable {
        case localOnly
        case cloudKit
        case fallbackToLocal
        case testing
    }

    var kind: Kind

    static func resolved(
        hasCloudKitEntitlement: Bool,
        didFallBackToLocal: Bool,
        isUITestMode: Bool = false
    ) -> CloudSyncStatus {
        if isUITestMode { return CloudSyncStatus(kind: .testing) }
        if didFallBackToLocal { return CloudSyncStatus(kind: .fallbackToLocal) }
        if hasCloudKitEntitlement { return CloudSyncStatus(kind: .cloudKit) }
        return CloudSyncStatus(kind: .localOnly)
    }

    var title: String {
        switch kind {
        case .localOnly: "Local Only"
        case .cloudKit: "iCloud Sync Enabled"
        case .fallbackToLocal: "Fallback to Local"
        case .testing: "Testing Store"
        }
    }

    var shortMessage: String {
        switch kind {
        case .localOnly:
            "Stored on this Mac"
        case .cloudKit:
            "Using the app's iCloud container"
        case .fallbackToLocal:
            "iCloud unavailable for this launch"
        case .testing:
            "Using isolated test data"
        }
    }

    var detailMessage: String {
        switch kind {
        case .localOnly:
            "Contacts are stored on this Mac. They do not sync to iCloud unless this build has an iCloud container."
        case .cloudKit:
            "Contacts are stored in the app's private CloudKit container and can sync through your iCloud account."
        case .fallbackToLocal:
            "The app could not open the CloudKit-backed store, so this launch is using the local store instead."
        case .testing:
            "Automation runs use an isolated in-memory store so real contacts never sync during UI tests."
        }
    }

    var systemImage: String {
        switch kind {
        case .localOnly: "internaldrive"
        case .cloudKit: "icloud"
        case .fallbackToLocal: "icloud.slash"
        case .testing: "testtube.2"
        }
    }
}

private struct CloudSyncStatusKey: EnvironmentKey {
    static let defaultValue = CloudSyncStatus(kind: .localOnly)
}

extension EnvironmentValues {
    var cloudSyncStatus: CloudSyncStatus {
        get { self[CloudSyncStatusKey.self] }
        set { self[CloudSyncStatusKey.self] = newValue }
    }
}

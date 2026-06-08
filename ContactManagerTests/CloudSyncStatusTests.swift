//
//  CloudSyncStatusTests.swift
//  ContactManagerTests
//
//  Covers the user-facing sync state derived from the app's CloudKit
//  entitlement/container decisions.
//

@testable import ContactManager
import Testing

struct CloudSyncStatusTests {
    @Test func localOnlyWhenNoCloudKitEntitlementIsPresent() {
        let status = CloudSyncStatus.resolved(
            hasCloudKitEntitlement: false,
            didFallBackToLocal: false
        )

        #expect(status.kind == .localOnly)
        #expect(status.title == "Local Only")
        #expect(status.systemImage == "internaldrive")
    }

    @Test func cloudKitWhenEntitlementLoadsWithoutFallback() {
        let status = CloudSyncStatus.resolved(
            hasCloudKitEntitlement: true,
            didFallBackToLocal: false
        )

        #expect(status.kind == .cloudKit)
        #expect(status.title == "iCloud Sync Enabled")
        #expect(status.systemImage == "icloud")
    }

    @Test func fallbackWhenCloudKitLoadFallsBackToLocalStore() {
        let status = CloudSyncStatus.resolved(
            hasCloudKitEntitlement: true,
            didFallBackToLocal: true
        )

        #expect(status.kind == .fallbackToLocal)
        #expect(status.title == "Fallback to Local")
        #expect(status.systemImage == "icloud.slash")
    }

    @Test func uiTestsReportAnIsolatedLocalStore() {
        let status = CloudSyncStatus.resolved(
            hasCloudKitEntitlement: true,
            didFallBackToLocal: false,
            isUITestMode: true
        )

        #expect(status.kind == .testing)
        #expect(status.title == "Testing Store")
        #expect(status.systemImage == "testtube.2")
    }
}

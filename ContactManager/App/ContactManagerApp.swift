//
//  ContactManagerApp.swift
//  ContactManager
//
//  SwiftUI entry point. Replaces the legacy AppDelegate / main.m / MainMenu.xib
//  AppKit launch path.
//

import Security
import SwiftData
import SwiftUI

@main
struct ContactManagerApp: App {
    @Environment(\.openWindow) private var openWindow
    @State private var loadState: ContainerLoadState

    init() {
        _loadState = State(initialValue: Self.loadContainer())
    }

    var body: some Scene {
        WindowGroup {
            switch loadState {
            case .ready(let container):
                ContentView()
                    .modelContainer(container)
            case .testing:
                EmptyView()
            case .failed(let message):
                StoreErrorView(message: message) {
                    loadState = Self.loadContainer(resettingStore: true)
                }
            }
        }
        // Detached single-contact window. The value type is the encoded
        // `PersistentIdentifier` string (the same scheme used by App
        // Intents/Spotlight) so it round-trips cleanly through
        // `OpenWindowAction` and SwiftUI's window-restoration store.
        WindowGroup(id: "contact", for: String.self) { $encodedID in
            switch loadState {
            case .ready(let container):
                ContactWindowView(encodedID: encodedID)
                    .modelContainer(container)
            case .testing, .failed:
                EmptyView()
            }
        }
        .defaultSize(width: 520, height: 640)
        WindowGroup(id: "quickCapture") {
            switch loadState {
            case .ready(let container):
                QuickCaptureView()
                    .modelContainer(container)
            case .testing, .failed:
                EmptyView()
            }
        }
        .defaultSize(width: 520, height: 220)
        Settings {
            // The Settings scene gets its own model container injection so
            // the default-group picker can @Query groups. When the store
            // hasn't loaded we point the user back to the main window
            // instead of showing an empty preferences pane.
            switch loadState {
            case .ready(let container):
                SettingsView()
                    .modelContainer(container)
            case .testing, .failed:
                Text("Open ContactManager to manage preferences.")
                    .padding()
                    .frame(width: 360, height: 120)
            }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Contact") {
                    NotificationCenter.default.post(name: .newContactRequested, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
                Button("Quick Capture…") {
                    openWindow(id: "quickCapture")
                }
                .keyboardShortcut("n", modifiers: [.command, .option])
            }
            CommandGroup(after: .textEditing) {
                Button("Find") {
                    NotificationCenter.default.post(name: .focusSearchRequested, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
            }
            CommandGroup(after: .pasteboard) {
                Button("Find Duplicates…") {
                    NotificationCenter.default.post(name: .findDuplicatesRequested, object: nil)
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .importExport) {
                Button("Import from Contacts…") {
                    NotificationCenter.default.post(name: .importSystemContactsRequested, object: nil)
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
                Button("Import vCard…") {
                    NotificationCenter.default.post(name: .importVCardRequested, object: nil)
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                Button("Import CSV…") {
                    NotificationCenter.default.post(name: .importCSVRequested, object: nil)
                }
                Button("Export vCard…") {
                    NotificationCenter.default.post(name: .exportVCardRequested, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                Button("Export Backup…") {
                    NotificationCenter.default.post(name: .exportBackupRequested, object: nil)
                }
                Button("Restore Backup…") {
                    NotificationCenter.default.post(name: .restoreBackupRequested, object: nil)
                }
                Button("Export as PDF…") {
                    NotificationCenter.default.post(name: .exportPDFRequested, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .printItem) {
                Button("Print…") {
                    NotificationCenter.default.post(name: .printContactRequested, object: nil)
                }
                .keyboardShortcut("p", modifiers: .command)
            }
        }
    }

    // MARK: - Container loading

    private static func loadContainer(resettingStore: Bool = false) -> ContainerLoadState {
        // UI test mode is detected via env var and pre-empts the unit-test
        // guard below: XCUITest injects an automation-support library
        // that drags `XCTestCase` into the app's loaded classes, so the
        // `NSClassFromString` check would short-circuit to `.testing` and
        // render `EmptyView()`. UI tests run against an in-memory,
        // CloudKit-disabled container so they never touch the user's real
        // on-disk store or push sample contacts into iCloud.
        let isUITestMode = ProcessInfo.processInfo
            .environment["CONTACTMANAGER_UI_TEST_MODE"] != nil

        if !isUITestMode {
            // When hosting the unit tests, skip building the app's model
            // container entirely so the test target owns the only
            // container in the process.
            let isUnitTesting = ProcessInfo.processInfo
                .environment["XCTestConfigurationFilePath"] != nil
                || NSClassFromString("XCTestCase") != nil
            if isUnitTesting { return .testing }
        }

        if resettingStore {
            deleteDefaultStore()
        }

        let schema = Schema([Contact.self, ContactField.self, ContactGroup.self, ContactInteraction.self])

        // UI-test mode uses an in-memory, CloudKit-disabled container so
        // tests are deterministic and can't sync sample contacts to a
        // signed-in iCloud account or pollute the user's local store.
        if isUITestMode {
            return loadUITestContainer(schema: schema)
        }

        // Use CloudKit only when the iCloud capability is actually configured
        // (an iCloud container in the entitlements). A fresh clone has none, so
        // it runs fully local and works out of the box; enabling iCloud in
        // Signing & Capabilities (see README) switches on sync with no code
        // change — `.automatic` then resolves the configured container.
        let cloudKitEnabled = hasCloudKitEntitlement()
        let container: ModelContainer
        var didFallBackToLocal = false
        do {
            let configuration = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: cloudKitEnabled ? .automatic : .none
            )
            container = try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // Only a CloudKit-backed attempt is worth retrying as local; if the
            // local attempt itself failed there's nothing left to fall back to.
            guard cloudKitEnabled else { return .failed(error.localizedDescription) }
            print("ContactManager: CloudKit container failed (\(error.localizedDescription)); retrying local-only.")
            do {
                let localConfiguration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
                container = try ModelContainer(for: schema, configurations: localConfiguration)
                didFallBackToLocal = true
            } catch {
                return .failed(error.localizedDescription)
            }
        }

        // Seed sample data only for a genuinely local store. A CloudKit-backed
        // store may be about to sync the user's real contacts down (a fresh
        // install on a second device); seeding then would push the samples into
        // their iCloud and propagate to every device.
        let isLocalOnly = !cloudKitEnabled || didFallBackToLocal
        if isLocalOnly {
            do {
                try SampleData.seedIfNeeded(container.mainContext)
            } catch {
                print("ContactManager: sample data seeding skipped — \(error)")
            }
        }
        // Publish the container for App Intents (Shortcuts/Spotlight queries)
        // and kick off an initial Spotlight reindex.
        EntityModelContainer.shared = container
        Task.detached { await SpotlightIndexer.shared.reindex() }
        return .ready(container)
    }

    /// Whether the app was built with an iCloud container in its entitlements
    /// (i.e. someone enabled iCloud ▸ CloudKit in Signing & Capabilities). Read
    /// from the running binary's own entitlements, so we can choose CloudKit vs
    /// local without any build-time flag — a plain clone has none and runs
    /// local-only.
    private static func hasCloudKitEntitlement() -> Bool {
        guard let task = SecTaskCreateFromSelf(nil),
              let containers = SecTaskCopyValueForEntitlement(
                  task, "com.apple.developer.icloud-container-identifiers" as CFString, nil
              ) as? [String]
        else { return false }
        return !containers.isEmpty
    }

    private static func loadUITestContainer(schema: Schema) -> ContainerLoadState {
        do {
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: configuration)
            do {
                try SampleData.seedIfNeeded(container.mainContext)
            } catch {
                print("ContactManager: sample data seeding skipped — \(error)")
            }
            EntityModelContainer.shared = container
            return .ready(container)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Removes the default SwiftData store files so a corrupt store can be
    /// recovered from without reinstalling the app.
    private static func deleteDefaultStore() {
        let fileManager = FileManager.default
        guard let support = try? fileManager.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false
        ) else { return }

        for suffix in ["", "-wal", "-shm"] {
            try? fileManager.removeItem(at: support.appending(path: "default.store\(suffix)"))
        }
    }
}

private enum ContainerLoadState {
    case ready(ModelContainer)
    case testing
    case failed(String)
}

/// Shown when the persistent store can't be opened, offering a recovery path
/// instead of crashing the app.
private struct StoreErrorView: View {
    let message: String
    let onReset: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Couldn't Open Your Contacts", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Reset Data", role: .destructive, action: onReset)
                .buttonStyle(.glassProminent)
        }
        .frame(minWidth: 360, minHeight: 240)
    }
}

extension Notification.Name {
    /// Posted by menu commands and observed by the relevant view — most by
    /// `ContentView`, except `.focusSearchRequested`, handled by
    /// `ContactListView` where the search field lives.
    static let newContactRequested = Notification.Name("ContactManager.newContactRequested")
    static let importVCardRequested = Notification.Name("ContactManager.importVCardRequested")
    static let importCSVRequested = Notification.Name("ContactManager.importCSVRequested")
    static let importSystemContactsRequested = Notification.Name("ContactManager.importSystemContactsRequested")
    static let exportVCardRequested = Notification.Name("ContactManager.exportVCardRequested")
    static let exportBackupRequested = Notification.Name("ContactManager.exportBackupRequested")
    static let restoreBackupRequested = Notification.Name("ContactManager.restoreBackupRequested")
    /// Posted by the Export as PDF / Print commands; handled by `ContentView`
    /// for the selected contact.
    static let exportPDFRequested = Notification.Name("ContactManager.exportPDFRequested")
    static let printContactRequested = Notification.Name("ContactManager.printContactRequested")
    static let findDuplicatesRequested = Notification.Name("ContactManager.findDuplicatesRequested")
    /// Posted by the Find menu command (⌘F); focuses the contact search field.
    static let focusSearchRequested = Notification.Name("ContactManager.focusSearchRequested")
    /// Posted by App Intents (and `Spotlight` taps via `ContentView`'s
    /// `onContinueUserActivity`). UserInfo carries `id: String` — the
    /// encoded `PersistentIdentifier` of the contact to select.
    static let openContactRequested = Notification.Name("ContactManager.openContactRequested")
    /// Posted by `ContactStore` after every successful mutation so observers
    /// (currently the Spotlight indexer) can refresh derived state.
    static let contactsDidChange = Notification.Name("ContactManager.contactsDidChange")
}

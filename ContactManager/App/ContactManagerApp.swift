//
//  ContactManagerApp.swift
//  ContactManager
//
//  SwiftUI entry point. Replaces the legacy AppDelegate / main.m / MainMenu.xib
//  AppKit launch path.
//

import SwiftData
import SwiftUI

@main
struct ContactManagerApp: App {
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
            }
        }
    }

    // MARK: - Container loading

    private static func loadContainer(resettingStore: Bool = false) -> ContainerLoadState {
        // When hosting the unit tests, skip building the app's model container
        // entirely so the test target owns the only container in the process.
        let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
        if isTesting { return .testing }

        if resettingStore {
            deleteDefaultStore()
        }

        // Build a CloudKit-backed container when the iCloud capability is
        // present, and fall back to a local-only container otherwise so the
        // app still runs without iCloud.
        let schema = Schema([Contact.self, ContactField.self, ContactGroup.self])

        let container: ModelContainer
        var isLocalOnlyFallback = false
        do {
            // `.automatic` uses the project's iCloud container when an iCloud
            // entitlement is present; without one it still loads successfully
            // and behaves as a local-only store.
            let cloudConfiguration = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            container = try ModelContainer(for: schema, configurations: cloudConfiguration)
        } catch {
            print("ContactManager: CloudKit container failed (\(error.localizedDescription)); using local.")
            do {
                let localConfiguration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
                container = try ModelContainer(for: schema, configurations: localConfiguration)
                isLocalOnlyFallback = true
            } catch {
                return .failed(error.localizedDescription)
            }
        }

        // Only seed sample data on the confirmed local-only fallback. On a
        // CloudKit-capable container the user's real contacts might be about
        // to sync down (a fresh install on a second device); seeding then
        // would race the sync and propagate the samples to every device.
        if isLocalOnlyFallback {
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
    /// Posted by menu commands; observed by `ContentView`.
    static let newContactRequested = Notification.Name("ContactManager.newContactRequested")
    static let importVCardRequested = Notification.Name("ContactManager.importVCardRequested")
    static let importCSVRequested = Notification.Name("ContactManager.importCSVRequested")
    static let importSystemContactsRequested = Notification.Name("ContactManager.importSystemContactsRequested")
    static let exportVCardRequested = Notification.Name("ContactManager.exportVCardRequested")
    static let findDuplicatesRequested = Notification.Name("ContactManager.findDuplicatesRequested")
    /// Posted by App Intents (and `Spotlight` taps via `ContentView`'s
    /// `onContinueUserActivity`). UserInfo carries `id: String` — the
    /// encoded `PersistentIdentifier` of the contact to select.
    static let openContactRequested = Notification.Name("ContactManager.openContactRequested")
    /// Posted by `ContactStore` after every successful mutation so observers
    /// (currently the Spotlight indexer) can refresh derived state.
    static let contactsDidChange = Notification.Name("ContactManager.contactsDidChange")
}

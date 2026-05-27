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
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Contact") {
                    NotificationCenter.default.post(name: .newContactRequested, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(replacing: .importExport) {
                Button("Import vCard…") {
                    NotificationCenter.default.post(name: .importVCardRequested, object: nil)
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
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

        do {
            let container = try ModelContainer(for: Contact.self, ContactField.self, ContactGroup.self)
            do {
                try SampleData.seedIfNeeded(container.mainContext)
            } catch {
                // Seeding is best-effort; a failure here shouldn't block launch.
                print("ContactManager: sample data seeding skipped — \(error)")
            }
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
    /// Posted by menu commands; observed by `ContentView`.
    static let newContactRequested = Notification.Name("ContactManager.newContactRequested")
    static let importVCardRequested = Notification.Name("ContactManager.importVCardRequested")
    static let exportVCardRequested = Notification.Name("ContactManager.exportVCardRequested")
}

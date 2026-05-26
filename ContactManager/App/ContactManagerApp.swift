//
//  ContactManagerApp.swift
//  ContactManager
//
//  SwiftUI entry point. Replaces the legacy AppDelegate / main.m / MainMenu.xib
//  AppKit launch path.
//

import SwiftUI
import SwiftData

@main
struct ContactManagerApp: App {
    private let container: ModelContainer?

    init() {
        // When hosting the unit tests, skip building the app's model container
        // entirely so the test target owns the only container in the process.
        let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil

        if isTesting {
            container = nil
            return
        }

        do {
            let built = try ModelContainer(for: Contact.self)
            SampleData.seedIfNeeded(built.mainContext)
            container = built
        } catch {
            fatalError("Failed to create the SwiftData ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                ContentView()
                    .modelContainer(container)
            } else {
                EmptyView()
            }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Contact") {
                    NotificationCenter.default.post(name: .newContactRequested, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    /// Posted by the New Contact menu command; observed by `ContentView`.
    static let newContactRequested = Notification.Name("ContactManager.newContactRequested")
}

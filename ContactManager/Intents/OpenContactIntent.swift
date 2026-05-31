//
//  OpenContactIntent.swift
//  ContactManager
//
//  Shortcut/Siri action: brings ContactManager forward and selects the
//  chosen contact. The actual navigation is handled by `ContentView`
//  observing `Notification.Name.openContactRequested`.
//

import AppIntents
import Foundation

struct OpenContactIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Contact"
    static let description = IntentDescription(
        "Opens ContactManager and selects the chosen contact."
    )
    /// Tells the system to launch the app for us before `perform()` runs.
    static let openAppWhenRun = true

    @Parameter(title: "Contact") var target: ContactEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: .openContactRequested,
            object: nil,
            userInfo: ["id": target.id]
        )
        return .result()
    }
}

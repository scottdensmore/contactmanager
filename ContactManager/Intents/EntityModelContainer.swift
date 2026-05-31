//
//  EntityModelContainer.swift
//  ContactManager
//
//  A process-wide handle to the app's `ModelContainer`. App Intents and
//  CoreSpotlight queries need to read contacts without going through the
//  SwiftUI environment; the app sets this once after `loadContainer()`
//  succeeds and the entity query reads it from any actor.
//
//  Access is guarded by an `OSAllocatedUnfairLock` so concurrent reads
//  during a launch-time setup are well-defined. The lock is held only
//  long enough to read or write the container reference itself.
//

import Foundation
import os
import SwiftData

enum EntityModelContainer {
    private static let storage = OSAllocatedUnfairLock<ModelContainer?>(initialState: nil)

    /// The shared container, populated by `ContactManagerApp` after the
    /// store loads. `nil` if loading failed or we're running under tests.
    static var shared: ModelContainer? {
        get { storage.withLock { $0 } }
        set { storage.withLock { $0 = newValue } }
    }
}

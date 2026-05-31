//
//  EntityModelContainer.swift
//  ContactManager
//
//  A process-wide handle to the app's `ModelContainer`. App Intents and
//  CoreSpotlight queries need to read contacts without going through the
//  SwiftUI environment; the app sets this once after `loadContainer()`
//  succeeds and the entity query reads it from any actor.
//

import Foundation
import SwiftData

enum EntityModelContainer {
    /// The shared container, populated by `ContactManagerApp` after the
    /// store loads. `nil` if loading failed or we're running under tests.
    /// Reads are nominally racy but in practice the container is set once
    /// during app launch before any query runs.
    nonisolated(unsafe) static var shared: ModelContainer?
}

//
//  ContactManagerUITests.swift
//  ContactManagerUITests
//
//  End-to-end smoke tests against a live ContactManager.app process.
//
//  Each test launches a fresh app instance with the
//  `CONTACTMANAGER_UI_TEST_MODE` environment variable set, which makes
//  the app delete its on-disk store and re-seed the standard three
//  sample contacts (Ada Lovelace, Alan Turing, Grace Hopper) before
//  loading. The `-ApplePersistenceIgnoreState YES` launch argument
//  disables SwiftUI window-state restoration so the test doesn't
//  inherit a stale identifier from a previous run.
//
//  Scope is intentionally narrow: the unit-test layer (`ContactStore`,
//  `VCard`, `CSV`, `ContactEntity`, `DuplicateFinder`, …) already
//  exercises every CRUD / group / import / undo / dedup journey at the
//  data layer. These UI tests guard against the regressions the unit
//  tests can't catch — the app fails to launch, the menu bar drops a
//  command, the seeded data doesn't render — without trying to drive
//  every interactive widget through XCUITest's macOS quirks.
//

import XCTest

final class ContactManagerUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app?.terminate()
    }

    // MARK: - Launch + menus

    /// Smoke test: the app launches under `CONTACTMANAGER_UI_TEST_MODE`
    /// and the main window renders. Catches the "WindowGroup body
    /// silently rendered EmptyView" failure mode the unit tests can't
    /// see — the rest of the journey (seeded data, list interaction,
    /// edits) is covered by the unit-test layer.
    func test_appLaunchesWithMainWindow() {
        let app = bootSeededApp()
        XCTAssertTrue(app.windows.firstMatch.exists)
        // The search field anchors the contact-list toolbar; if it's
        // present the main list rendered, not the StoreErrorView fallback.
        XCTAssertTrue(
            app.searchFields.firstMatch.waitForExistence(timeout: 3),
            "Contact-list search field should render"
        )
    }

    /// Verifies the File menu wires the Import / Export commands the
    /// unit tests can't probe directly.
    func test_fileMenuExposesImportAndExportCommands() {
        let app = bootSeededApp()
        app.menuBars.menuBarItems["File"].click()
        XCTAssertTrue(app.menuItems["New Contact"].exists)
        XCTAssertTrue(app.menuItems["Quick Capture…"].exists)
        XCTAssertTrue(app.menuItems["Import from Contacts…"].exists)
        XCTAssertTrue(app.menuItems["Import vCard…"].exists)
        XCTAssertTrue(app.menuItems["Import CSV…"].exists)
        XCTAssertTrue(app.menuItems["Export vCard…"].exists)
        XCTAssertTrue(app.menuItems["Export as PDF…"].exists)
        XCTAssertTrue(app.menuItems["Print…"].exists)
    }

    /// Verifies the Edit menu wires the search / dedup commands. The behaviors
    /// (⌘F focus, merge) are covered at the unit/interaction layer; this just
    /// guards the menu wiring so a dropped command is caught.
    func test_editMenuExposesFindCommands() {
        let app = bootSeededApp()
        app.menuBars.menuBarItems["Edit"].click()
        XCTAssertTrue(app.menuItems["Find"].exists)
        XCTAssertTrue(app.menuItems["Find Duplicates…"].exists)
    }

    /// Verifies Edit ▸ Find Duplicates… opens the sheet. Sheet content
    /// is covered by `DuplicateFinder` + `ContactStore.merge` unit tests.
    func test_findDuplicatesShortcutOpensTheSheet() {
        let app = bootSeededApp()
        app.typeKey("d", modifierFlags: [.command, .shift])
        XCTAssertTrue(
            app.buttons["Done"].waitForExistence(timeout: 3),
            "Duplicates sheet's Done button should appear after ⌘⇧D"
        )
    }

    /// Verifies the core keyboard-first loop: create a contact, edit its name,
    /// then find it through the list search field.
    func test_createEditAndSearchContact() {
        let app = bootSeededApp()
        app.typeKey("n", modifierFlags: .command)

        let firstName = app.textFields["contact-first-name-field"]
        XCTAssertTrue(firstName.waitForExistence(timeout: 3))
        firstName.typeText("Test")

        let lastName = app.textFields["contact-last-name-field"]
        XCTAssertTrue(lastName.waitForExistence(timeout: 3))
        lastName.click()
        lastName.typeText("Person")

        app.typeKey("f", modifierFlags: .command)
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.typeText("Test")

        XCTAssertTrue(
            app.staticTexts["Test Person"].waitForExistence(timeout: 3),
            "Newly edited contact should be searchable in the list"
        )
    }

    /// Verifies the quick-capture command opens a focused capture window and
    /// creates a searchable contact from natural text.
    func test_quickCaptureCreatesSearchableContact() {
        let app = bootSeededApp()
        app.typeKey("n", modifierFlags: [.command, .option])

        let entry = app.textFields["quick-capture-entry-field"]
        XCTAssertTrue(entry.waitForExistence(timeout: 3))
        entry.click()
        entry.typeText("Test Capture, capture@example.com, birthday Dec 10")

        let create = app.buttons["quick-capture-create-button"]
        XCTAssertTrue(create.waitForExistence(timeout: 3))
        create.click()

        XCTAssertTrue(
            app.staticTexts["Created Test Capture"].waitForExistence(timeout: 3),
            "Quick capture should confirm the saved contact"
        )
    }

    // MARK: - Helpers

    /// Launches a fresh app instance with the seeded UI-test container.
    /// Returns the `XCUIApplication` so each test can scope its
    /// assertions to a known-good handle.
    private func bootSeededApp() -> XCUIApplication {
        app = XCUIApplication()
        app.launchEnvironment["CONTACTMANAGER_UI_TEST_MODE"] = "1"
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        XCTAssertTrue(
            app.windows.firstMatch.waitForExistence(timeout: 10),
            "Main window didn't appear within 10s"
        )
        return app
    }
}

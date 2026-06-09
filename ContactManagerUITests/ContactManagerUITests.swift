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
        XCTAssertTrue(
            app.descendants(matching: .any)["sidebar-sync-status"].waitForExistence(timeout: 3),
            "Sidebar sync status should render"
        )
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(app.textFields["contact-first-name-field"].waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.menuButtons["batch-actions-menu"].waitForExistence(timeout: 3),
            "Batch actions menu should render"
        )
        app.typeKey("k", modifierFlags: .command)
        XCTAssertTrue(
            app.textFields["command-palette-search-field"].waitForExistence(timeout: 3),
            "Command palette should open from ⌘K"
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
        XCTAssertTrue(app.menuItems["Export Backup…"].exists)
        XCTAssertTrue(app.menuItems["Export Encrypted Backup…"].exists)
        XCTAssertTrue(app.menuItems["Restore Backup…"].exists)
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

    /// Verifies the relationship-intelligence affordances render in the live
    /// app: smart-list sidebar rows, mark-contacted, and contact-history
    /// controls. Filtering and persistence behavior stay in deterministic unit
    /// tests.
    func test_smartListsAndMarkContactedControlsRender() {
        let app = bootSeededApp()

        XCTAssertTrue(app.staticTexts["Recently Contacted"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Needs Follow-up"].exists)
        XCTAssertTrue(app.staticTexts["No Email"].exists)
        XCTAssertTrue(app.staticTexts["Birthdays Soon"].exists)

        app.typeKey("n", modifierFlags: .command)

        XCTAssertTrue(app.buttons["mark-contacted-button"].waitForExistence(timeout: 3))
        let historyNote = app.descendants(matching: .any)["interaction-summary-field"]
        XCTAssertTrue(historyNote.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["add-interaction-button"].exists)

        app.typeKey("f", modifierFlags: .command)
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.typeText("Ada")
        let saveSearch = app.buttons["save-search-button"]
        XCTAssertTrue(saveSearch.waitForExistence(timeout: 3))
        saveSearch.click()
        XCTAssertTrue(
            app.descendants(matching: .any)["sidebar-saved-smart-list-row-ada"].waitForExistence(timeout: 3),
            "Saving a search should add a saved smart-list row"
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

    /// Verifies Quick Capture warns before creating an obvious duplicate and
    /// can update the existing contact instead.
    func test_quickCaptureShowsDuplicateMatchAndUpdatesExisting() {
        let app = bootSeededApp()
        app.typeKey("n", modifierFlags: [.command, .option])

        let entry = app.textFields["quick-capture-entry-field"]
        XCTAssertTrue(entry.waitForExistence(timeout: 3))
        entry.click()
        entry.typeText("Ada Lovelace, ada@analytical.engine, mobile 555-0200, tag VIP")

        let matchRow = app.descendants(matching: .any)["quick-capture-match-row"]
        XCTAssertTrue(
            matchRow.waitForExistence(timeout: 3),
            "Quick capture should show a duplicate match before saving"
        )
        let matchText = [matchRow.label, matchRow.value as? String ?? ""]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        XCTAssertTrue(matchText.contains("Ada Lovelace"), "Match row text was: \(matchText)")
        XCTAssertTrue(matchText.contains("same email"), "Match row text was: \(matchText)")

        let update = app.buttons["quick-capture-update-existing-button"]
        XCTAssertTrue(update.waitForExistence(timeout: 3))
        update.click()

        XCTAssertTrue(
            app.staticTexts["Updated Ada Lovelace"].waitForExistence(timeout: 3),
            "Quick capture should confirm the existing contact was updated"
        )
    }

    /// Verifies the quick-capture preview renders all parsed detail kinds
    /// before saving, so users can trust what the one-line parser understood.
    func test_quickCapturePreviewShowsParsedDetails() {
        let app = bootSeededApp()
        app.typeKey("n", modifierFlags: [.command, .option])

        let entry = app.textFields["quick-capture-entry-field"]
        XCTAssertTrue(entry.waitForExistence(timeout: 3))
        entry.click()
        entry.typeText(
            "Preview Person, home email home@example.com, work email work@example.com, " +
                "mobile 555-0101, home phone 555-0102, tag VIP, group Friends"
        )

        let details = app.descendants(matching: .any)["quick-capture-preview-details"]
        XCTAssertTrue(details.waitForExistence(timeout: 3))

        let expectedRows = [
            ("quick-capture-preview-email-0", "Home: home@example.com"),
            ("quick-capture-preview-email-1", "Work: work@example.com"),
            ("quick-capture-preview-phone-0", "Mobile: 555-0101"),
            ("quick-capture-preview-phone-1", "Home: 555-0102"),
            ("quick-capture-preview-tag-0", "VIP"),
            ("quick-capture-preview-group-0", "Friends"),
        ]
        for (identifier, expectedText) in expectedRows {
            let row = app.descendants(matching: .any)[identifier]
            XCTAssertTrue(row.waitForExistence(timeout: 3), "\(identifier) should render")
            let accessibleText = [row.label, row.value as? String ?? ""]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            XCTAssertTrue(
                accessibleText.contains(expectedText),
                "\(identifier) should contain \(expectedText); got \(accessibleText)"
            )
        }
    }

    /// Verifies long quick-capture input stays compact and surfaces
    /// parse feedback before saving.
    func test_quickCapturePreviewShowsWarningsAndOverflow() {
        let app = bootSeededApp()
        app.typeKey("n", modifierFlags: [.command, .option])

        let entry = app.textFields["quick-capture-entry-field"]
        XCTAssertTrue(entry.waitForExistence(timeout: 3))
        entry.click()
        entry.typeText(
            "Overflow Person, home email one@example.com, work email two@example.com, " +
                "mobile 555-0101, home phone 555-0102, tag VIP, tag Team, " +
                "group Friends, group Family, email nope"
        )

        let warning = app.descendants(matching: .any)["quick-capture-warning-0"]
        XCTAssertTrue(warning.waitForExistence(timeout: 3))
        let warningText = [warning.label, warning.value as? String ?? ""]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        XCTAssertTrue(warningText.contains("Ignored email: nope"))

        let overflow = app.descendants(matching: .any)["quick-capture-preview-overflow"]
        XCTAssertTrue(overflow.waitForExistence(timeout: 3))
        let overflowText = [overflow.label, overflow.value as? String ?? ""]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        XCTAssertTrue(overflowText.contains("+2 more"))
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

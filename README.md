# Contact Manager

**ContactManager** is a native macOS contact manager built with **SwiftUI** and **SwiftData**, targeting the modern macOS Tahoe (macOS 26) look and feel. It has **zero third-party runtime dependencies**.

The app was originally an Objective-C / AppKit / Core Data demo and was rebuilt, in focused increments, into a polished native Tahoe application.

---

## Architecture

- **Platform**: macOS 26.0+ (Tahoe)
- **UI**: SwiftUI — a three-column `NavigationSplitView` (groups sidebar / contact list / detail) that automatically adopts the Liquid Glass appearance when built against the macOS 26 SDK.
- **Persistence**: SwiftData (`@Model`, `ModelContainer`, `@Query`), replacing the legacy Core Data stack. The container is **CloudKit-ready** (`cloudKitDatabase: .automatic`) and falls back to a local-only store when no iCloud capability is present.
- **System integration**: App Intents (Shortcuts / Siri), Core Spotlight indexing, the macOS Contacts framework, and drag-and-drop.
- **Language**: Swift (language mode 5; full Swift 6 concurrency is a future migration).
- **Testing**: Swift Testing (unit) backed by an in-memory `ModelContainer`, plus a small XCUITest smoke suite.

### Source layout

```
ContactManager/
├── App/      ContactManagerApp.swift     – @main entry, ModelContainer, menu commands, scenes
├── Models/   Contact.swift               – the @Model contact entity + derived values
│             ContactField.swift          – labeled, repeatable email/phone child entity
│             ContactGroup.swift          – user group/tag (many-to-many with Contact)
│             ContactStore.swift          – data layer: every mutation, saved + undoable
│             ContactQuery.swift          – pure filter/sort/section helpers
│             DuplicateFinder.swift       – groups likely-duplicate contacts
│             DefaultGroupPreference.swift – resolves the "new contacts join" preference
│             SampleData.swift            – first-launch seed data
├── Support/  VCard / VCardDocument / VCardTransfer – vCard 3.0 read/write, export, drag
│             CSV.swift                   – Google/Outlook/Apple CSV reader
│             ContactsBridge.swift        – import from the macOS Contacts app
│             ImageProcessing.swift       – downscales picked images into avatar JPEGs
│             Birthday.swift              – UTC-anchored date-only birthday handling
│             ContactLink.swift           – mailto:/tel: URL construction
│             ContactPDF / PDFExportDocument – contact-card PDF render + export
│             Chunking.swift              – batches large imports
│             SpotlightIndexer.swift      – incremental Core Spotlight indexing
│             PersistentIdentifierEncoding.swift – stable encoded model ids
├── Intents/  ContactEntity / ContactEntityQuery – App Intents identity + Spotlight attributes
│             FindContactIntent / OpenContactIntent – Shortcuts/Siri actions
│             EntityModelContainer.swift  – process-wide container handle for intents
└── Views/    ContentView (+Import)       – split-view shell, selection, import/export, progress
              SidebarView                 – groups sidebar (create/rename/delete, drop target)
              ContactListView             – searchable, sectioned list + toolbar + drag
              ContactDetailView (+Photo, +Birthday) – editable detail, photo well, share, actions
              ContactWindowView           – single-contact detached window
              PrintableContactView        – print/PDF card layout
              SettingsView · DuplicatesView · ImportProgressView · AvatarView · LayoutMetrics
```

---

## Features

- Three-column native layout with a Liquid Glass toolbar and smooth list/selection animations.
- Create, edit (inline, autosaving), and delete contacts, with full **Undo/Redo** (⌘Z / ⇧⌘Z).
- Multiple labeled emails and phone numbers, company, job title, postal address, birthday (year optional), and notes.
- Click-to-mail / click-to-call (`mailto:` / `tel:`) on the contact's primary email and phone.
- Live, debounced search across name, company, title, notes, and field values, with alphabetical sections and a first-name / last-name sort toggle. **⌘F** focuses the search field.
- Contact photos (downscaled on import, streamed via ImageIO) with an initials avatar fallback.
- User-defined groups (sidebar create/rename/delete); drag contacts onto a group to add them.
- Duplicate detection & merge (Edit ▸ Find Duplicates…).
- **Import**: vCard `.vcf`, CSV (Google / Outlook / Apple exports), and the macOS **Contacts** app — chunked with a progress overlay. **Export / share**: vCard via File ▸ Export vCard… or the detail Share button.
- **Print** a contact card and **Export as PDF** (⌘P / ⇧⌘P).
- **Drag and drop**: drag a contact to Finder as a `.vcf`, drop a `.vcf` onto the list to import, drop an image onto the avatar.
- **Open in New Window** for a single contact (the window closes itself if that contact is deleted).
- **Shortcuts & Siri** via App Intents (Find / Open Contact) and **Spotlight** indexing with tap-to-open.
- **iCloud sync** when the capability is enabled in Xcode, with a graceful local-only fallback.
- Runs under the **App Sandbox** with the hardened runtime.

---

## Development

A `Makefile` wraps the common tasks (install tooling once with `make bootstrap`, which runs `brew bundle`):

| Task | Command |
| --- | --- |
| Build | `make build` |
| Test | `make test` |
| Lint | `make lint` (autofix: `make lint-fix`) |
| Format | `make format` (check only: `make format-check`) |
| Pre-PR gate | `make check` (format-check + lint + test) |

Tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`/`#require`). Linting and formatting are **SwiftLint** + **SwiftFormat**; CI (`.github/workflows/ci.yml`) runs `swiftformat --lint` and `swiftlint --strict` on every PR. Contributor and agent conventions live in `CLAUDE.md`.

### Building & Running

Open `ContactManager.xcodeproj` in Xcode (26 or later, macOS 26 SDK), select the **ContactManager** scheme, and press `Cmd + R` — or run `make build`.

### Running the Tests

```shell
make test            # unit + UI tests via xcodebuild
```

### iCloud sync (optional)

The app runs **local-only out of the box** — clone, build, and run with no
account or extra setup (a fresh store is seeded with a few sample contacts).
It's also **CloudKit-ready**: at launch it checks whether an iCloud container is
configured in its entitlements and, if so, opens the SwiftData store with
`cloudKitDatabase: .automatic` to sync across your devices; otherwise it stays
local. Nothing about CloudKit is committed to the project, so a download is never
blocked by a provisioning profile you don't own, and **no code changes are
needed** to switch sync on — the app detects the capability at runtime.

**Prerequisite:** a paid **Apple Developer Program** membership. iCloud/CloudKit
capabilities aren't available to a free "Personal Team" — Xcode won't let you add
the container without one.

To turn on sync for your own build:

1. In Xcode, select the **ContactManager** target ▸ **Signing & Capabilities**.
2. Turn on *Automatically manage signing* and set your **Team**. (The repo ships
   with an empty `DEVELOPMENT_TEAM` on purpose.)
3. Click **+ Capability** ▸ **iCloud**, check **CloudKit**, and add a container
   (the default `iCloud.<your-bundle-id>` is fine — use your own bundle id).
4. Click **+ Capability** ▸ **Push Notifications** so the store receives CloudKit
   change pushes. (This is the macOS capability; a Mac target has no "Background
   Modes ▸ Remote notifications" toggle.)
5. Sign the Mac in to **iCloud** (System Settings ▸ your Apple ID), using the
   same account on every device you want to sync.
6. **Start clean (recommended):** if you've run the app locally before, its store
   already holds the seeded sample contacts, which would upload to your real
   iCloud on the first sync. Delete the local store first so you start empty:
   ```shell
   rm -rf ~/Library/Containers/com.scottdensmore.ContactManager/Data/Library/Application\ Support/default.store*
   ```
   (In CloudKit mode the app skips seeding, so it stays empty until data syncs.)
7. Build and run. Verify sync via the **CloudKit Console**
   (developer.apple.com ▸ CloudKit ▸ your container ▸ *Records*, Development
   environment) or a second Mac signed in to the same account.

**Shipping a release build:** SwiftData auto-creates the schema in CloudKit's
**Development** environment. Before distributing, open the **CloudKit Console ▸
Deploy Schema Changes** to promote it to **Production**, or a release/TestFlight
build will see an empty production schema.

**If sync stays silent** after all of the above, add **App Sandbox ▸ Outgoing
Connections (`com.apple.security.network.client`)** to the entitlements. CloudKit
is normally brokered by a system daemon and works without it, but it's the first
thing to try.

> Steps 2–4 modify the target's entitlements and signing settings. **Don't commit
> those changes** — leaving them out is what keeps the project buildable by anyone
> who clones it without your team or container.

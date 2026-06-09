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
| Test | `make test` (unit + UI) · `make test-unit` (unit only) |
| Lint | `make lint` (autofix: `make lint-fix`) |
| Format | `make format` (check only: `make format-check`) |
| Pre-PR gate | `make check` + `code-review` subagent |

Tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`/`#require`); `make build`/`make test` disable code signing (compile + test gates — a signed build for distribution is done from Xcode), so they run identically locally and in CI. Linting and formatting are **SwiftLint** + **SwiftFormat**. Before opening a PR, run `make check` and the repo-local `code-review` subagent; fix any actionable review findings and rerun it until it reports no remaining findings. CI (`.github/workflows/ci.yml`) runs two jobs on every PR: **Lint & Format** (`swiftformat --lint` + `swiftlint --strict`) and **Build & Test** (`make build` + `make test-unit` on a macOS 26 runner). The XCUITest smoke suite (`make test`) is run from Xcode, not CI. After CI passes on `main`, a **Release** workflow auto-bumps the version patch + build number, tags `v{version}`, and publishes a GitHub release with generated notes (bump the major/minor by hand when it's warranted). Contributor and agent conventions live in `AGENTS.md`.

### Building & Running

Open `ContactManager.xcodeproj` in Xcode (26 or later, macOS 26 SDK), select the **ContactManager** scheme, and press `Cmd + R` — or run `make build`. `make build` needs no signing setup (it builds unsigned). For a **signed run from Xcode**, run **`./setup.sh`** once (prompts for your Apple Developer team id and a reverse-domain organization identifier) — it writes a local, gitignored `DeveloperSettings.xcconfig`. Your team/org aren't committed (a fresh clone uses a placeholder `com.example` and builds unsigned), and `ORGANIZATION_IDENTIFIER` drives the bundle id so you get your own — no provisioning collisions. See [CONTRIBUTING.md](CONTRIBUTING.md).

### Running the Tests

```shell
make test            # unit + UI tests via xcodebuild
```

### iCloud sync (optional)

The app runs **local-only by default** — no iCloud account or sync setup is
required to build and use it (a fresh store is seeded with a few sample
contacts). It's also **CloudKit-ready**: at launch it checks whether an iCloud container is
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
2. Make sure signing uses **your Team** (keep *Automatically manage signing*).
   The team isn't committed — run `./setup.sh` once (prompts for your team id
   and org identifier), which writes the gitignored
   `ContactManager/DeveloperSettings.xcconfig` that the build pulls in.
3. Click **+ Capability** ▸ **iCloud**, check **CloudKit**, and add a container
   (the default `iCloud.<your-bundle-id>` is fine — use your own bundle id).
4. Click **+ Capability** ▸ **Push Notifications** so the store receives CloudKit
   change pushes. (This is the macOS capability; a Mac target has no "Background
   Modes ▸ Remote notifications" toggle.)
5. Sign the Mac in to **iCloud** (System Settings ▸ your Apple ID), using the
   same account on every device you want to sync.
6. **Start clean (recommended):** if you've run the app locally before, its store
   already holds the seeded sample contacts, which would upload to your real
   iCloud on the first sync. Delete the local store first so you start empty —
   the sandbox container path uses the app's bundle id (replace it if you've
   changed `PRODUCT_BUNDLE_IDENTIFIER`):
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

> Steps 3–4 edit the shared `ContactManager.entitlements` (adding your iCloud
> container). **Don't commit that change** — it's what would block anyone who
> clones without your container. Your `DeveloperSettings.xcconfig` from step 2 is
> already gitignored.

### App Store privacy readiness

The app includes `ContactManager/PrivacyInfo.xcprivacy`, currently declaring
UserDefaults access for app preferences such as sort order and default group.
Before TestFlight or App Store submission, keep that manifest aligned with any
new required-reason APIs and complete App Store Connect's privacy details,
including the privacy policy URL and any collected-data disclosures.

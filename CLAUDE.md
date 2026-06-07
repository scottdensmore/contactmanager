# ContactManager — Contributor & Agent Guide

Native **macOS Tahoe (macOS 26)** contact manager built with **SwiftUI + SwiftData**.
Zero third-party *runtime* dependencies. Code here is reviewed by humans, not just
agents — keep it readable and idiomatic.

## Commands

| Task | Command |
| --- | --- |
| Build | `make build` |
| Test | `make test` (unit + UI) / `make test-unit` (unit only) |
| Lint | `make lint` (autofix: `make lint-fix`) |
| Format | `make format` (check only: `make format-check`) |
| Pre-PR gate | `make check` (format-check + lint + unit tests) |
| Install tooling | `make bootstrap` (runs `brew bundle`) |

Tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`/`#require`) — not XCTest.
`make build`/`make test` pass `CODE_SIGNING_ALLOWED=NO` (compile + test gates; a signed
build for distribution is done from Xcode), so they run identically locally and in CI.
`check` runs the **unit** tests (`ContactManagerTests`) — fast and deterministic; the
XCUITest smoke suite (`make test`) is run from Xcode, since it flakes on app activation
when the foreground is busy and isn't part of CI.

## Layout

```
ContactManager/App/      @main entry, ModelContainer, menu commands
ContactManager/Models/   SwiftData @Models, ContactStore (data layer), pure helpers (ContactQuery)
ContactManager/Support/  Non-UI utilities (VCard, ImageProcessing, VCardDocument)
ContactManager/Views/    SwiftUI views
ContactManagerTests/     Swift Testing suites
```

## Code style

Run `make format` and `make lint` before committing; both must pass (or `make check`).
Configs: `.swiftformat`, `.swiftlint.yml`. Linting is intentionally **not** an Xcode
build phase: the project enables `ENABLE_USER_SCRIPT_SANDBOXING`, which blocks a
whole-tree SwiftLint run script from reading sources. Instead, CI
(`.github/workflows/ci.yml`) enforces it on every PR: a **Lint & Format** job
(`swiftformat --lint` + `swiftlint --strict`) and a **Build & Test** job
(`make build` + `make test-unit`, code signing disabled), so enforcement happens with
zero local build/commit friction.

- 4-space indent; opening braces on the same line; trailing commas in multiline
  literals (SwiftFormat owns comma style — SwiftLint's `trailing_comma` is disabled
  so they don't fight).
- No force-unwraps (`!`) — SwiftLint enforces `force_unwrapping`. Use `guard`/`if let`,
  or `#require` in tests.
- Route create/edit/delete, group, and vCard operations through `ContactStore`
  (each op saves and rolls back on failure), so views stay thin and the journeys are
  tested in `ContactStoreTests` against an in-memory container. Every `ContactStore`
  mutation also wraps its body in a named undo group via `mutate("…") { … }`, so
  Edit ▸ Undo/Redo (⌘Z / ⇧⌘Z) shows the right action name and reverses what it can.
  (SwiftData's automatic undo doesn't always recreate models after a `save`+`delete`;
  the menu name is still set so future improvements are observable.)
- Keep views thin: put pure, testable logic in `Models/` or `Support/` and unit-test it
  there rather than in views.
- User-initiated actions surface persistence errors (alert + `context.rollback()`);
  don't swallow them with `try?`.

## Xcode project (`.pbxproj`)

Edit it **only** via the Ruby `xcodeproj` gem — never by hand. When you add a Swift file,
register it on the correct target with a small ruby script (see prior commits for the
pattern), then build to confirm it compiles.

## SwiftData

- Top-level models are listed in the `Schema` built in `ContactManagerApp.loadContainer`:
  `Contact`, `ContactField`, `ContactGroup`.
- **Migration:** every new *non-optional scalar* attribute MUST have an inline default
  (e.g. `var city: String = ""`), or in-place migration fails (`NSCocoaError 134110`).
  Optional attributes and relationships migrate cleanly. Verify by launching against an
  existing store.
- **CloudKit (opt-in, non-blocking):** `loadContainer` checks the running binary's
  entitlements (`hasCloudKitEntitlement()` via `SecTask`) for an iCloud container. If one
  is configured it opens the store with `cloudKitDatabase: .automatic` (sync); otherwise
  `.none` (local) and it seeds sample data. A try/catch falls back to local on failure.
  **Do not commit an iCloud entitlement / container** — it would break signing for anyone
  who clones without that team/container; enabling iCloud is a documented local opt-in
  (README ▸ "iCloud sync"). Seed only when local-only, so samples never sync into a real
  iCloud account. To keep the schema sync-compatible, every non-optional attribute needs an
  inline default (already covered by the migration rule), every to-many relationship needs
  `= []`, and we avoid `@Attribute(.unique)` and `.deny` delete rules.
- **Tests:** use an in-memory `ModelContainer`; the suite is `@MainActor @Suite(.serialized)`
  and holds the container as a stored property. The app skips creating its own container
  under tests (`XCTestConfigurationFilePath`) so the test owns the only one — keep that guard.

## Platform / Liquid Glass

- Toolbars and `NavigationSplitView` adopt Liquid Glass automatically on the macOS 26 SDK.
  The `.glassEffect()` modifier / `GlassEffectContainer` are not in this SDK's SwiftUI
  interface; use `.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)` for explicit glass.
- `SWIFT_VERSION` is 5.0 (language mode 5). Full Swift 6 strict-concurrency is a future migration.
- Build settings are per-configuration: Debug uses `SWIFT_OPTIMIZATION_LEVEL = -Onone`
  (required for SwiftUI `#Preview`), Release uses `-O` + `SWIFT_COMPILATION_MODE = wholemodule`.

## Workflow

- Ship focused, single-purpose PRs. Keep the README and this file in sync.
- Use the GitHub CLI (`gh`) for all GitHub operations, and address Copilot review comments
  before merging.

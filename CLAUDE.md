# ContactManager — Contributor & Agent Guide

Native **macOS Tahoe (macOS 26)** contact manager built with **SwiftUI + SwiftData**.
Zero third-party *runtime* dependencies. Code here is reviewed by humans, not just
agents — keep it readable and idiomatic.

## Commands

| Task | Command |
| --- | --- |
| Build | `make build` |
| Test | `make test` |
| Lint | `make lint` (autofix: `make lint-fix`) |
| Format | `make format` (check only: `make format-check`) |
| Pre-PR gate | `make check` (format-check + lint + test) |
| Install tooling | `make bootstrap` (runs `brew bundle`) |

Tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`/`#require`) — not XCTest.

## Layout

```
ContactManager/App/      @main entry, ModelContainer, menu commands
ContactManager/Models/   SwiftData @Models + pure helpers (ContactQuery)
ContactManager/Support/  Non-UI utilities (VCard, ImageProcessing, VCardDocument)
ContactManager/Views/    SwiftUI views
ContactManagerTests/     Swift Testing suites
```

## Code style

Run `make format` and `make lint` before committing; both must pass (or `make check`).
Configs: `.swiftformat`, `.swiftlint.yml`. Linting is intentionally **not** an Xcode
build phase: the project enables `ENABLE_USER_SCRIPT_SANDBOXING`, which blocks a
whole-tree SwiftLint run script from reading sources. Lint from the command line / CI.

- 4-space indent; opening braces on the same line; trailing commas in multiline
  literals (SwiftFormat owns comma style — SwiftLint's `trailing_comma` is disabled
  so they don't fight).
- No force-unwraps (`!`) — SwiftLint enforces `force_unwrapping`. Use `guard`/`if let`,
  or `#require` in tests.
- Keep views thin: put pure, testable logic in `Models/` or `Support/` and unit-test it
  there rather than in views.
- User-initiated actions surface persistence errors (alert + `context.rollback()`);
  don't swallow them with `try?`.

## Xcode project (`.pbxproj`)

Edit it **only** via the Ruby `xcodeproj` gem — never by hand. When you add a Swift file,
register it on the correct target with a small ruby script (see prior commits for the
pattern), then build to confirm it compiles.

## SwiftData

- Top-level models must be listed in the `ModelContainer(for:)` call in
  `ContactManagerApp.swift`: `Contact`, `ContactField`, `ContactGroup`.
- **Migration:** every new *non-optional scalar* attribute MUST have an inline default
  (e.g. `var city: String = ""`), or in-place migration fails (`NSCocoaError 134110`).
  Optional attributes and relationships migrate cleanly. Verify by launching against an
  existing store.
- **Tests:** use an in-memory `ModelContainer`; the suite is `@MainActor @Suite(.serialized)`
  and holds the container as a stored property. The app skips creating its own container
  under tests (`XCTestConfigurationFilePath`) so the test owns the only one — keep that guard.

## Platform / Liquid Glass

- Toolbars and `NavigationSplitView` adopt Liquid Glass automatically on the macOS 26 SDK.
  The `.glassEffect()` modifier / `GlassEffectContainer` are not in this SDK's SwiftUI
  interface; use `.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)` for explicit glass.
- `SWIFT_VERSION` is 5.0 (language mode 5). Full Swift 6 strict-concurrency is a future migration.

## Workflow

- Ship focused, single-purpose PRs. Keep the README roadmap and this file in sync.
- Use the GitHub CLI (`gh`) for all GitHub operations, and address Copilot review comments
  before merging.

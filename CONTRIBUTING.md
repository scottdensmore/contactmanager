# Contributing

## Getting started

1. **Install tooling** (SwiftLint, SwiftFormat via Homebrew):
   ```shell
   make bootstrap
   ```
2. **Set up signing** so you can build with your own Apple Developer team and a
   bundle id you own:
   ```shell
   ./setup.sh                 # prompts for your team id + org identifier
   # or non-interactively:
   ./setup.sh --non-interactive --dev-team-id ABCDE12345 --org-identifier com.example
   # or via make:
   make setup TEAM=ABCDE12345 ORG=com.example
   ```
   This writes the gitignored `ContactManager/DeveloperSettings.xcconfig` from
   the tracked `DeveloperSettings.template.xcconfig`. `ORGANIZATION_IDENTIFIER`
   drives the bundle id (and iCloud container), so every developer builds with
   their own — no provisioning collisions. You only need this for **signed**
   runs from Xcode; `make build` builds with signing off and skips it.
3. **Build / test / run**:
   ```shell
   make build       # unsigned compile gate
   make test        # unit + UI tests (Xcode)
   make check       # format-check + lint + unit tests
   ```
   Or open `ContactManager.xcodeproj` and press `Cmd + R`.

Optional iCloud sync setup is documented in the [README](README.md#icloud-sync-optional).

## Workflow

- Branch per focused change; keep each PR scoped to one logical feature/fix/chore.
- Write tests first (TDD) whenever the change is testable.
- Run `make check` (format check, lint, unit tests) before opening a PR.
- Open a PR against `main`.
- **Squash merge** and delete the branch.


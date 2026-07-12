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
   runs from Xcode; `make build` / CI build with signing off and skip it.
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
- After implementation, inspect the complete diff, then run the repo-local
  `ui-review` and address every actionable UI or accessibility finding.
- Run the repo-local `verifier` and resolve every build, test, lint, format,
  coverage, flake, or environment finding. Rerun it after code fixes.
- Before every commit, run the repo-local `code-review` against the branch diff
  and all staged, unstaged, and untracked files. Fix every actionable finding.
- Before opening a PR, confirm verification remains valid. Rerun `code-review`
  only if the reviewed state changed; do not repeat it for an unchanged diff and
  worktree.
- Open a PR against `main` and **merge once all required checks pass** (Lint & Format +
  Build & Test) and GitHub reports a clean merge state. Self-merges are allowed;
  Copilot review isn't a gate.
- **Squash merge** and delete the branch; a successful merge auto-tags and publishes a release.

More detailed conventions (architecture, SwiftData rules, style) live in
[`AGENTS.md`](AGENTS.md).

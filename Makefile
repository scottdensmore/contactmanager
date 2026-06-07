PROJECT := ContactManager.xcodeproj
SCHEME := ContactManager
DESTINATION := platform=macOS
# Code signing is off for build/test: these are compile + test gates (CI has no
# Apple account, and a signed build for distribution is done from Xcode). Keeps
# the local and CI invocations identical.
XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' CODE_SIGNING_ALLOWED=NO

.DEFAULT_GOAL := help

.PHONY: help bootstrap setup build test test-unit lint lint-fix format format-check check

help: ## List available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

bootstrap: ## Install developer tooling (SwiftLint, SwiftFormat) via Homebrew
	./scripts/bootstrap.sh

setup: ## Create the local DeveloperSettings.xcconfig (signing). Optional: TEAM=… ORG=…
	./setup.sh $(if $(TEAM),--dev-team-id $(TEAM)) $(if $(ORG),--org-identifier $(ORG))

build: ## Build the app
	$(XCODEBUILD) build

test: ## Run the full test suite (unit + UI)
	$(XCODEBUILD) test

test-unit: ## Run the unit tests only (deterministic; used by CI and `check`)
	$(XCODEBUILD) test -only-testing:ContactManagerTests

lint: ## Lint sources with SwiftLint (strict — matches CI; warnings fail)
	swiftlint lint --quiet --strict

lint-fix: ## Autocorrect SwiftLint violations where possible
	swiftlint --fix

format: ## Format sources in place with SwiftFormat
	swiftformat .

format-check: ## Verify formatting without modifying files
	swiftformat --lint .

check: format-check lint test-unit ## Run format check, lint, and unit tests (CI gate)

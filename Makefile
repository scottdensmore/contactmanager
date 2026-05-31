PROJECT := ContactManager.xcodeproj
SCHEME := ContactManager
DESTINATION := platform=macOS

.DEFAULT_GOAL := help

.PHONY: help bootstrap build test lint lint-fix format format-check check

help: ## List available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

bootstrap: ## Install developer tooling (SwiftLint, SwiftFormat) via Homebrew
	./scripts/bootstrap.sh

build: ## Build the app
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' build

test: ## Run the test suite
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' test

lint: ## Lint sources with SwiftLint (strict — matches CI; warnings fail)
	swiftlint lint --quiet --strict

lint-fix: ## Autocorrect SwiftLint violations where possible
	swiftlint --fix

format: ## Format sources in place with SwiftFormat
	swiftformat .

format-check: ## Verify formatting without modifying files
	swiftformat --lint .

check: format-check lint test ## Run format check, lint, and tests (CI gate)

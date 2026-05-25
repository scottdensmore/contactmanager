# Contact Manager

**ContactManager** is a native, modern macOS desktop application demonstrating best practices in desktop architecture, persistence, and unit testing.

The project is **100% self-contained and standalone**, featuring zero third-party dependencies. It has been fully modernized to target macOS 13.0+ and compiles under modern Xcode toolchains with zero warnings.

---

## Key Modernization Features

1. **Modern Persistence Stack**:
   - Replaced legacy manual Core Data lifecycle management with Apple's standard **`NSPersistentContainer`** framework.
   - Core Data stores are fully loaded synchronously on initialization for deterministic runtime behavior.
   - Built-in automatic migration support and clean directory setup inside standard Application Support paths.

2. **Objective-C Modernization**:
   - **Full Nullability Coverage**: Entire codebase annotated with `NS_ASSUME_NONNULL` and proper pointer specifiers (`nonnull`, `nullable`) for complete type safety and seamless Swift interoperability.
   - **Type-Safe Generics**: Standardized all collections (e.g. `NSArray<Contact *> *` and `NSFetchRequest<__kindof NSManagedObject *> *`) to enable compile-time type checking.
   - **Memory Safety**: Converted delegates and interface outlets to modern `weak` pointers to eliminate risk of retain cycles.
   - **Unavailable Initializers**: Standardized designated initializers and marked legacy default `init`/`new` initializers as `NS_UNAVAILABLE` to guarantee correct instance construction.

3. **Zero-Dependency Testing**:
   - Swapped out the legacy third-party `OCMock` framework in favor of lightweight native testing constructs.
   - Integration tests are backed by a real, blazing-fast, in-memory Core Data stack (`NSInMemoryStoreType`), executing type-safe code without polluting local developer filesystems.
   - Subclassed view controllers directly inside the test target to spy on KVO bindings.

---

## Tech Stack & Architecture

- **Platform**: macOS 13.0+ (AppKit)
- **Language**: Objective-C (Automatic Reference Counting, LLVM Modules enabled)
- **Database**: Core Data (`NSPersistentContainer`)
- **UI Binding**: Cocoa Bindings & Key-Value Observing (KVO)
- **Unit Testing**: XCTest

---

## Getting Started

### Prerequisites

No dependency managers (such as Carthage, CocoaPods, or Swift Package Manager) are required.

To prepare the local homebrew build environment (if any tools are missing):
```shell
./scripts/bootstrap.sh
```

### Building & Running

Open `ContactManager.xcodeproj` in Xcode and select the **ContactManager** scheme. Press `Cmd + R` to build and run.

### Running the Test Suite

To run all 31 unit tests directly from the command line:
```shell
xcodebuild -project ContactManager.xcodeproj -scheme ContactManager -configuration Debug test
```
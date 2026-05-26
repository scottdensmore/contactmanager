# Contact Manager

**ContactManager** is a native macOS contact manager built with **SwiftUI** and **SwiftData**, targeting the modern macOS Tahoe (macOS 26) look and feel. It is **100% self-contained** with zero third-party dependencies.

The app was originally an Objective-C / AppKit / Core Data demo and is being rebuilt, in focused increments, into a polished native Tahoe application.

---

## Architecture

- **Platform**: macOS 26.0+ (Tahoe)
- **UI**: SwiftUI — a three-column `NavigationSplitView` (sidebar / contact list / detail) that automatically adopts the Liquid Glass appearance when built against the macOS 26 SDK.
- **Persistence**: SwiftData (`@Model`, `ModelContainer`, `@Query`), replacing the legacy Core Data stack.
- **Language**: Swift
- **Testing**: Swift Testing, backed by an in-memory `ModelContainer`.

### Source layout

```
ContactManager/
├── App/      ContactManagerApp.swift   – @main entry point, model container, menu commands
├── Models/   Contact.swift             – the @Model contact entity + derived values
│             ContactField.swift        – labeled, repeatable email/phone child entity
│             ContactQuery.swift        – pure, testable filter/sort helpers
│             SampleData.swift          – first-launch seed data
└── Views/    ContentView.swift         – NavigationSplitView shell + create/delete actions
              SidebarView.swift         – groups sidebar (All Contacts)
              ContactListView.swift     – selectable contact list + toolbar
              ContactDetailView.swift   – editable detail form
              AvatarView.swift          – initials avatar with a per-contact tint
```

---

## Features

- Three-column native layout with a Liquid Glass toolbar.
- Create, edit (inline, autosaving), and delete contacts.
- Multiple labeled emails and phone numbers per contact (add/remove inline).
- Company, job title, postal address, birthday, and free-form notes.
- Initials-based avatars.
- Sample contacts seeded on first launch.

### Roadmap

Shipped as small, single-purpose PRs:

1. ✅ **Foundation** — SwiftUI + SwiftData rewrite, CRUD, project modernized to macOS 26.
2. ✅ **Richer fields** — multiple emails/phones, company/title, address, birthday, notes.
3. **Search & sections** — live search and alphabetical sectioning.
4. **Contact photos** — photo import with initials fallback.
5. **Groups & vCard** — user groups/tags and `.vcf` import/export.
6. **Tahoe polish** — Liquid Glass refinements, animations, and richer empty states.

---

## Getting Started

### Prerequisites

Xcode 26 or later (macOS 26 SDK). No dependency managers required.

### Building & Running

Open `ContactManager.xcodeproj` in Xcode, select the **ContactManager** scheme, and press `Cmd + R`.

### Running the Test Suite

```shell
xcodebuild -project ContactManager.xcodeproj -scheme ContactManager -destination 'platform=macOS' test
```

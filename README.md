# Contact Manager

**ContactManager** is a native macOS contact manager built with **SwiftUI** and **SwiftData**, targeting the modern macOS Tahoe (macOS 26) look and feel. It is **100% self-contained** with zero third-party dependencies.

The app was originally an Objective-C / AppKit / Core Data demo and was rebuilt, in focused increments, into a polished native Tahoe application.

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
│             ContactGroup.swift        – user group/tag (many-to-many with Contact)
│             ContactQuery.swift        – pure, testable filter/sort/section helpers
│             SampleData.swift          – first-launch seed data
├── Support/  ImageProcessing.swift     – downscales picked images into avatar JPEGs
│             VCard.swift               – pure vCard 3.0 reader/writer
│             VCardDocument.swift       – FileDocument for the export dialog
└── Views/    ContentView.swift         – NavigationSplitView shell, group + import/export logic
              SidebarView.swift         – groups sidebar with create/rename/delete
              ContactListView.swift     – searchable, sectioned contact list + toolbar
              ContactDetailView.swift   – editable detail form + photo well + group toggles
              AvatarView.swift          – photo or initials avatar with a per-contact tint
```

---

## Features

- Three-column native layout with a Liquid Glass toolbar.
- Create, edit (inline, autosaving), and delete contacts.
- Multiple labeled emails and phone numbers per contact (add/remove inline).
- Company, job title, postal address, birthday, and free-form notes.
- Live search across name, company, title, notes, and field values.
- Alphabetical sections with a first-name / last-name sort toggle.
- Contact photos (downscaled on import) with an initials avatar fallback.
- User-defined groups (sidebar create/rename/delete) with per-contact membership.
- vCard 3.0 import and export (File ▸ Import/Export vCard…).
- Duplicate detection & merge (Edit ▸ Find Duplicates…) — review and combine contacts that share an email, phone, or name.
- Liquid Glass styling, glass-prominent actions, and smooth list/selection animations.
- Sample contacts seeded on first launch.

### Roadmap

Shipped as small, single-purpose PRs:

1. ✅ **Foundation** — SwiftUI + SwiftData rewrite, CRUD, project modernized to macOS 26.
2. ✅ **Richer fields** — multiple emails/phones, company/title, address, birthday, notes.
3. ✅ **Search & sections** — live search and alphabetical sectioning.
4. ✅ **Contact photos** — photo import with initials fallback.
5. ✅ **Groups & vCard** — user groups/tags and `.vcf` import/export.
6. ✅ **Tahoe polish** — Liquid Glass refinements, animations, and richer empty states.

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

//
//  CreateContactIntent.swift
//  ContactManager
//
//  Shortcut action for creating a contact from structured fields.
//

import AppIntents
import Foundation

struct CreateContactIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Contact"
    static let description = IntentDescription(
        "Create a ContactManager contact with name, company, email, phone, and notes."
    )

    @Parameter(title: "First Name") var firstName: String?
    @Parameter(title: "Last Name") var lastName: String?
    @Parameter(title: "Company") var company: String?
    @Parameter(title: "Job Title") var jobTitle: String?
    @Parameter(title: "Email") var email: String?
    @Parameter(title: "Phone") var phone: String?
    @Parameter(title: "Notes") var notes: String?

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ContactEntity> {
        let draft = QuickCaptureDraft(
            firstName: firstName.cleanedIntentValue,
            lastName: lastName.cleanedIntentValue,
            company: company.cleanedIntentValue,
            jobTitle: jobTitle.cleanedIntentValue,
            notes: notes.cleanedIntentValue,
            emails: email.cleanedIntentField.map { [(.home, $0)] } ?? [],
            phones: phone.cleanedIntentField.map { [(.mobile, $0)] } ?? []
        )
        guard !draft.isEmpty else { throw ContactIntentError.blankContactInput }

        let container = try ContactIntentResolver.container()
        let contact = try ContactStore(container.mainContext).createContact(from: draft)
        return .result(value: ContactEntity(contact: contact))
    }
}

private extension String? {
    var cleanedIntentValue: String {
        self?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var cleanedIntentField: String? {
        let value = cleanedIntentValue
        return value.isEmpty ? nil : value
    }
}

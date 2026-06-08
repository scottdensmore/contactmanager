//
//  BackupPasswordPromptView.swift
//  ContactManager
//
//  Password entry sheet for encrypted backup export and restore.
//

import SwiftUI

struct BackupPasswordPromptView: View {
    enum Mode {
        case export
        case unlock
    }

    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var confirmation = ""
    @State private var validationMessage: String?

    var mode: Mode
    var action: (String) -> Bool

    var body: some View {
        NavigationStack {
            Form {
                SecureField("Password", text: $password)
                    .accessibilityIdentifier("backup-password-field")

                if mode == .export {
                    SecureField("Confirm Password", text: $confirmation)
                        .accessibilityIdentifier("backup-confirm-password-field")
                }

                if let validationMessage {
                    Text(validationMessage)
                        .foregroundStyle(.red)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(buttonTitle) {
                        submit()
                    }
                    .disabled(!canSubmit)
                    .accessibilityIdentifier("backup-password-submit-button")
                }
            }
        }
        .frame(minWidth: 420, minHeight: 220)
    }

    private var title: String {
        switch mode {
        case .export: "Encrypt Backup"
        case .unlock: "Unlock Backup"
        }
    }

    private var buttonTitle: String {
        switch mode {
        case .export: "Export"
        case .unlock: "Unlock"
        }
    }

    private var canSubmit: Bool {
        switch mode {
        case .export: !password.isEmpty && !confirmation.isEmpty
        case .unlock: !password.isEmpty
        }
    }

    private func submit() {
        if mode == .export, password != confirmation {
            validationMessage = "Passwords do not match."
            return
        }
        validationMessage = nil
        if action(password) {
            dismiss()
        }
    }
}

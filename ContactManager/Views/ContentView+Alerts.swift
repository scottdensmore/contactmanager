//
//  ContentView+Alerts.swift
//  ContactManager
//
//  Alert modifiers split out so ContentView stays within lint limits.
//

import SwiftUI

extension ContentView {
    func handlingImportAlerts(_ content: some View) -> some View {
        content
            .alert(
                "Something Went Wrong",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }),
                presenting: errorMessage
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
            .alert(
                importSummary?.title ?? "Import Complete",
                isPresented: Binding(get: { importSummary != nil }, set: { if !$0 { importSummary = nil } }),
                presenting: importSummary
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { summary in
                Text(summary.message)
            }
            .alert(
                restoreSummary?.title ?? "Restore Complete",
                isPresented: Binding(get: { restoreSummary != nil }, set: { if !$0 { restoreSummary = nil } }),
                presenting: restoreSummary
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { summary in
                Text(summary.message)
            }
    }
}

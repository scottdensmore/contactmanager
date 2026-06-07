//
//  ContactStore+PendingEdits.swift
//  ContactManager
//
//  Saves direct SwiftData edits made by form bindings.
//

extension ContactStore {
    /// Saves direct SwiftUI/SwiftData edits (text fields, pickers, birthday
    /// bindings) through the same rollback + Spotlight notification path as
    /// structural mutations. Returns an empty change when there is nothing
    /// pending so debounced callers can invoke it freely.
    @discardableResult
    func savePendingEdits(actionName: String) throws -> ContactChange {
        let pending = pendingContactChange()
        guard context.hasChanges else { return pending.contactChange() }
        do {
            try context.save()
            let change = pending.contactChange()
            context.undoManager?.setActionName(actionName)
            post(change)
            return change
        } catch {
            context.rollback()
            throw error
        }
    }
}

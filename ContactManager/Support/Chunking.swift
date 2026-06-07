//
//  Chunking.swift
//  ContactManager
//
//  Splits a collection into fixed-size batches. Used to import contacts a
//  chunk at a time (one save + progress tick per chunk) instead of building
//  the whole set on the main actor in a single mega-undo step.
//

extension Array {
    /// Splits the array into consecutive sub-arrays of at most `size` elements.
    /// A non-positive `size` returns the whole array as a single chunk (or no
    /// chunks when empty), so callers can't accidentally spin forever.
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return isEmpty ? [] : [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

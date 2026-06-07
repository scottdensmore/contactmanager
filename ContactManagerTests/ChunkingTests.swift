//
//  ChunkingTests.swift
//  ContactManagerTests
//
//  Covers Array.chunked(into:), which batches contacts for chunked import.
//

@testable import ContactManager
import Testing

struct ChunkingTests {
    @Test func splitsIntoFullAndRemainderChunks() {
        let chunks = Array(1 ... 10).chunked(into: 4)
        #expect(chunks == [[1, 2, 3, 4], [5, 6, 7, 8], [9, 10]])
    }

    @Test func returnsOneChunkWhenSmallerThanSize() {
        #expect([1, 2, 3].chunked(into: 10) == [[1, 2, 3]])
    }

    @Test func dividesEvenlyWithoutAnEmptyTrailingChunk() {
        let chunks = Array(1 ... 6).chunked(into: 3)
        #expect(chunks == [[1, 2, 3], [4, 5, 6]])
    }

    @Test func emptyArrayYieldsNoChunks() {
        #expect([Int]().chunked(into: 5).isEmpty)
    }

    @Test func nonPositiveSizeDoesNotSpin() {
        // Guard against an accidental 0/negative size looping forever.
        #expect([1, 2, 3].chunked(into: 0) == [[1, 2, 3]])
        #expect([Int]().chunked(into: 0).isEmpty)
    }
}

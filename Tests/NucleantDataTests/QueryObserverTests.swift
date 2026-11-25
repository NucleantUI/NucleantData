//
//  QueryObserverTests.swift
//  NucleantDataTests
//
//  The observer behind `@Query`, against a real context: what it fetches,
//  what it learns of each write, and that one is shared per predicate.
//

import Foundation
import Observation
import Testing
@testable import NucleantData

@MainActor
struct QueryObserverTests {

    private func observer(
        _ predicate: Predicate<Note>,
        in container: ModelContainer
    ) throws -> QueryObserver<Note> {
        QueryObserver.shared(for: try ModelPredicate(predicate), in: container.context)
    }

    @Test func fetchesWhatMatches() throws {
        let container = try makeContainer()
        try insert(["milk", "eggs"], into: container)
        try insert(["bread"], done: true, into: container)

        let open = try observer(#Predicate<Note> { !$0.isDone }, in: container)
        #expect(Set(open.results.map(\.title)) == ["milk", "eggs"])

        let done = try observer(#Predicate<Note> { $0.isDone }, in: container)
        #expect(done.results.map(\.title) == ["bread"])
    }

    @Test func oneObserverPerPredicate() throws {
        let container = try makeContainer()
        let first = try observer(#Predicate<Note> { !$0.isDone }, in: container)
        let second = try observer(#Predicate<Note> { !$0.isDone }, in: container)
        let other = try observer(#Predicate<Note> { $0.isDone }, in: container)
        #expect(first === second)
        #expect(first !== other)

        let elsewhere = try observer(#Predicate<Note> { !$0.isDone }, in: try makeContainer())
        #expect(first !== elsewhere)
    }

    @Test func learnsOfInsertsThatMatch() async throws {
        let container = try makeContainer()
        let open = try observer(#Predicate<Note> { !$0.isDone }, in: container)
        #expect(open.results.isEmpty)

        try insert(["milk"], into: container)
        try insert(["bread"], done: true, into: container)
        #expect(await eventually { open.results.map(\.title) == ["milk"] })

        // Another type's insert is not this query's.
        try container.context.insert(Tag(name: "dairy"))
        try insert(["eggs"], into: container)
        #expect(await eventually { open.results.map(\.title) == ["milk", "eggs"] })
    }

    @Test func followsAModelChangingOutAndIn() async throws {
        let container = try makeContainer()
        let milk = try insert(["milk"], into: container)[0]
        let open = try observer(#Predicate<Note> { !$0.isDone }, in: container)
        let done = try observer(#Predicate<Note> { $0.isDone }, in: container)
        #expect(open.results.map(\.title) == ["milk"])
        #expect(done.results.isEmpty)

        milk.isDone = true
        #expect(await eventually { open.results.isEmpty && done.results.map(\.title) == ["milk"] })

        milk.isDone = false
        #expect(await eventually { open.results.map(\.title) == ["milk"] && done.results.isEmpty })
    }

    @Test func aChangeThatKeepsMatchingIsStillAChange() async throws {
        let container = try makeContainer()
        let milk = try insert(["milk"], into: container)[0]
        let open = try observer(#Predicate<Note> { !$0.isDone }, in: container)

        // Set from the change handler, which may run on any thread.
        let changed = Mutex(false)
        withObservationTracking {
            _ = open.results
        } onChange: {
            changed.value = true
        }
        milk.title = "oat milk"
        #expect(await eventually { changed.value })
        #expect(open.results.count == 1)
        #expect(open.results.first === milk)
    }

    @Test func learnsOfDeletes() async throws {
        let container = try makeContainer()
        let notes = try insert(["milk", "eggs"], into: container)
        let open = try observer(#Predicate<Note> { !$0.isDone }, in: container)
        #expect(open.results.count == 2)

        try container.context.delete(notes[0])
        try container.context.save()
        #expect(await eventually { open.results.map(\.title) == ["eggs"] })
    }

    @Test func aModelInsertedTwiceIsListedOnce() async throws {
        let container = try makeContainer()
        let milk = try insert(["milk"], into: container)[0]
        let open = try observer(#Predicate<Note> { !$0.isDone }, in: container)

        open.appendAny([milk, milk])
        #expect(open.results.count == 1)
    }
}

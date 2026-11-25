//
//  QueryViewTests.swift
//  NucleantDataTests
//
//  `@Query` in views hosted the way a window hosts them: what each body
//  sees after the database changes under it, after its parent hands it a
//  new predicate, and before and after `VeinContainer` has migrated.
//
//  Serialized: every host shares the framework's one invalidator.
//

import Foundation
import NucleantUI
import Observation
import Testing
@testable import NucleantData

// MARK: - Probe views

/// The notes still open, A–Z.
@View
struct OpenNotes {
    @Query(#Predicate<Note> { !$0.isDone }, sortBy: [SortRule(\Note.title)])
    private var notes
    let seen: Seen

    var body: some View {
        Text(seen.record(notes))
    }
}

/// Two views with the same query, side by side.
@View
struct TwoOpenLists {
    let left: Seen
    let right: Seen

    var body: some View {
        VStack {
            OpenNotes(seen: left)
            OpenNotes(seen: right)
        }
    }
}

/// Which notes the parent wants shown.
@MainActor
@Observable
final class NoteFilter {
    var showsDone = false
}

/// Hands its child a query made from the filter as it is now.
@View
struct FilteredNotes {
    let filter: NoteFilter
    let seen: Seen

    var body: some View {
        NotesMatching(done: filter.showsDone, seen: seen)
    }
}

@View
struct NotesMatching {
    @Query private var notes: [Note]
    let seen: Seen

    init(done: Bool, seen: Seen, _viewID: ViewID = #viewID) {
        _notes = Query(#Predicate<Note> { $0.isDone == done }, sortBy: [SortRule(\Note.title)])
        self.seen = seen
        self._viewID = _viewID
    }

    var body: some View {
        Text(seen.record(notes))
    }
}

/// Every note, by the default query.
@View
struct AllNotes {
    @Query private var notes: [Note]
    let seen: Seen

    init(seen: Seen, _viewID: ViewID = #viewID) {
        self.seen = seen
        self._viewID = _viewID
    }

    var body: some View {
        Text(seen.record(notes))
    }
}

@MainActor
private func host<Root: View>(_ root: Root) -> ViewHost {
    let host = ViewHost(root: root)
    host.setSize(Size(width: 320, height: 240))
    return host
}

// MARK: - Tests

@MainActor
@Suite(.serialized)
struct QueryViewTests {

    @Test func bodySeesTheFetchedModelsSorted() async throws {
        let container = try makeContainer()
        try insert(["milk", "bread", "eggs"], into: container)
        try insert(["jam"], done: true, into: container)
        let seen = Seen()
        let host = host(VeinContainer { OpenNotes(seen: seen) }.modelContainer(container))

        #expect(await eventually(host) { seen.last == ["bread", "eggs", "milk"] })
    }

    @Test func bodyRunsAgainForEachWrite() async throws {
        let container = try makeContainer()
        let notes = try insert(["milk", "bread"], into: container)
        let seen = Seen()
        let host = host(VeinContainer { OpenNotes(seen: seen) }.modelContainer(container))
        #expect(await eventually(host) { seen.last == ["bread", "milk"] })

        // Inserted: joins, in its place.
        try insert(["apples"], into: container)
        #expect(await eventually(host) { seen.last == ["apples", "bread", "milk"] })

        // Changed so it no longer matches: leaves.
        notes[1].isDone = true
        #expect(await eventually(host) { seen.last == ["apples", "milk"] })

        // Changed but still matching: stays, sorted anew.
        notes[0].title = "almond milk"
        #expect(await eventually(host) { seen.last == ["almond milk", "apples"] })

        // Deleted: leaves.
        try container.context.delete(notes[0])
        #expect(await eventually(host) { seen.last == ["apples"] })
    }

    @Test func viewsWithTheSameQueryBothFollow() async throws {
        let container = try makeContainer()
        try insert(["milk"], into: container)
        let left = Seen()
        let right = Seen()
        let host = host(VeinContainer { TwoOpenLists(left: left, right: right) }.modelContainer(container))
        #expect(await eventually(host) { left.last == ["milk"] && right.last == ["milk"] })

        try insert(["eggs"], into: container)
        #expect(await eventually(host) { left.last == ["eggs", "milk"] && right.last == ["eggs", "milk"] })
    }

    @Test func aNewPredicateFromTheParentTakesEffect() async throws {
        let container = try makeContainer()
        try insert(["milk", "eggs"], into: container)
        try insert(["jam"], done: true, into: container)
        let filter = NoteFilter()
        let seen = Seen()
        let host = host(VeinContainer { FilteredNotes(filter: filter, seen: seen) }.modelContainer(container))
        #expect(await eventually(host) { seen.last == ["eggs", "milk"] })

        filter.showsDone = true
        #expect(await eventually(host) { seen.last == ["jam"] })

        // The new query is live, not a one-off fetch.
        try insert(["butter"], done: true, into: container)
        #expect(await eventually(host) { seen.last == ["butter", "jam"] })

        filter.showsDone = false
        #expect(await eventually(host) { seen.last == ["eggs", "milk"] })
    }

    @Test func defaultQueryIsEveryModelOfItsType() async throws {
        let container = try makeContainer()
        try insert(["milk"], into: container)
        try insert(["jam"], done: true, into: container)
        let seen = Seen()
        let host = host(VeinContainer { AllNotes(seen: seen) }.modelContainer(container))

        #expect(await eventually(host) { seen.last.map(Set.init) == ["milk", "jam"] })
    }

    @Test func contentWaitsForTheMigration() async throws {
        let container = try makeContainer(migrated: false)
        let seen = Seen()
        let host = host(VeinContainer { OpenNotes(seen: seen) }.modelContainer(container))

        host.update()
        #expect(seen.runs.isEmpty)
        // Migrated by the container view itself, then shown.
        #expect(await eventually(host) { seen.last == [] })
        try insert(["milk"], into: container)
        #expect(await eventually(host) { seen.last == ["milk"] })
    }

    @Test func noContainerShowsNoContent() async throws {
        let seen = Seen()
        let host = host(VeinContainer { OpenNotes(seen: seen) })
        for _ in 0..<20 {
            host.update()
            await Task.yield()
        }
        #expect(seen.runs.isEmpty)
    }
}

// MARK: - Environment and failures

@MainActor
struct ContainerEnvironmentTests {

    @Test func containerAndContextRoundTrip() throws {
        let container = try makeContainer()
        var environment = EnvironmentValues()
        #expect(environment.modelContainer == nil)
        environment.modelContainer = container
        #expect(environment.modelContainer === container)
        #expect(environment.modelContext === container.context)
    }

    private struct Unreadable: LocalizedError {
        var errorDescription: String? { "The file is not a database." }
        var failureReason: String? { "Its header is wrong." }
        var recoverySuggestion: String? { "Restore it from a backup." }
    }

    private struct Plain: Error {}

    @Test func migrationFailureKeepsWhatTheErrorSaid() {
        let failure = MigrationFailure(Unreadable())
        #expect(failure.description == "The file is not a database.")
        #expect(failure.reason == "Its header is wrong.")
        #expect(failure.suggestion == "Restore it from a backup.")

        let plain = MigrationFailure(Plain())
        #expect(!plain.description.isEmpty)
        #expect(plain.reason == nil)
        #expect(plain.suggestion == nil)
    }
}

//
//  Helpers.swift
//  NucleantDataTests
//
//  A schema of notes, an in-memory database of it, and the waiting both
//  kinds of test need: the context tells queries about a write on the main
//  actor *after* it, and a hosted view rebuilds on the frame after that.
//

import Foundation
import NucleantData
import NucleantUI

enum NotesV1: VersionedSchema {
    static let version = ModelVersion(1, 0, 0)
    static let models: [any PersistentModel.Type] = [Note.self, Tag.self]

    @Model
    final class Note {
        var title: String
        var isDone: Bool

        init(title: String, isDone: Bool = false) {
            self.title = title
            self.isDone = isDone
        }
    }

    /// A second model type, which no note query is about.
    @Model
    final class Tag {
        var name: String

        init(name: String) {
            self.name = name
        }
    }
}

typealias Note = NotesV1.Note
typealias Tag = NotesV1.Tag

enum NotesMigration: SchemaMigrationPlan {
    static let schemas: [VersionedSchema.Type] = [NotesV1.self]
    static let stages: [MigrationStage] = []
}

/// A database of its own in memory, migrated unless asked not to be.
@MainActor
func makeContainer(migrated: Bool = true) throws -> ModelContainer {
    let container = try ModelContainer(
        NotesV1.self,
        migration: NotesMigration.self,
        at: nil,
        appID: "ui.nucleant.data.tests",
        encryptionEnabled: false
    )
    if migrated {
        try container.migrate()
    }
    return container
}

/// `titles` inserted and saved, in that order.
@MainActor
@discardableResult
func insert(_ titles: [String], done: Bool = false, into container: ModelContainer) throws -> [Note] {
    let notes = titles.map { Note(title: $0, isDone: done) }
    for note in notes {
        try container.context.insert(note)
    }
    try container.context.save()
    return notes
}

/// Lets main-actor work queued behind the caller run until `condition`
/// holds, or gives up.
@MainActor
func eventually(_ condition: () -> Bool) async -> Bool {
    for _ in 0..<1000 {
        if condition() { return true }
        await Task.yield()
    }
    return condition()
}

/// Runs `host`'s frames, letting queued main-actor work in between, until
/// `condition` holds, or gives up.
@MainActor
func eventually(_ host: ViewHost, _ condition: () -> Bool) async -> Bool {
    for _ in 0..<1000 {
        host.update()
        if condition() { return true }
        await Task.yield()
    }
    return condition()
}

/// What a probe view's body saw, every time it ran.
@MainActor
final class Seen {
    private(set) var runs: [[String]] = []

    var last: [String]? { runs.last }

    /// Records `notes`' titles; returns them for the body to show.
    func record(_ notes: [Note]) -> String {
        let titles = notes.map(\.title)
        runs.append(titles)
        return titles.joined(separator: ", ")
    }
}

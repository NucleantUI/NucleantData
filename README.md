# NucleantData

[Vein](https://github.com/amethystsoft/vein)'s SQLite models in NucleantUI views.

`import NucleantData` brings all of Vein — `@Model`, `@Relationship`,
`ModelContainer`, predicates, sort rules, migrations — and adds what a view
needs to show them:

- `@Query`: the models matching a predicate, kept current as the context
  inserts, changes and deletes them.
- `\.modelContainer` and `\.modelContext` in the environment.
- `VeinContainer`: migrates the container set on it, then shows its content.

## Install

```swift
.package(url: "https://github.com/NucleantUI/NucleantData", .upToNextMinor(from: "0.0.0"))
```

```swift
.product(name: "NucleantData", package: "NucleantData")
```

## Use

Declare the models as Vein does:

```swift
import NucleantData

enum NotesV1: VersionedSchema {
    static let version = ModelVersion(1, 0, 0)
    static let models: [any PersistentModel.Type] = [Note.self]

    @Model
    final class Note {
        var title: String
        var isDone: Bool

        init(title: String) {
            self.title = title
            self.isDone = false
        }
    }
}

typealias Note = NotesV1.Note

enum NotesMigration: SchemaMigrationPlan {
    static let schemas: [VersionedSchema.Type] = [NotesV1.self]
    static let stages: [MigrationStage] = []
}
```

Set the container once, above everything that reads it:

```swift
@main
struct NotesApp: NucleantApp {
    private let container = try! ModelContainer(
        NotesV1.self,
        migration: NotesMigration.self,
        at: databasePath,
        appID: "com.example.notes"
    )

    var body: some Scene {
        WindowGroup("Notes") {
            VeinContainer {
                OpenNotes()
            }
            .modelContainer(container)
        }
    }
}
```

Query it in a view, and write through the context:

```swift
@View
struct OpenNotes {
    @Query(#Predicate<Note> { !$0.isDone }, sortBy: [SortRule(\Note.title)])
    private var notes: [Note]
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack {
            ForEach(notes, id: \.id) { note in
                Text(note.title)
            }
            Button("Add") {
                try? context.insert(Note(title: "New note"))
            }
        }
    }
}
```

To make the query from the view's inputs — a search string, a filter —
write the view's init and assign `_notes = Query(…)` there:

```swift
@View
struct MatchingNotes {
    @Query private var notes: [Note]

    init(search: String, _viewID: ViewID = #viewID) {
        _notes = Query(#Predicate<Note> { $0.title.contains(search) })
        self._viewID = _viewID
    }

    var body: some View { … }
}
```

A new predicate from the parent takes effect on the view's next build.

## Example

[`Examples/Groceries`](Examples/Groceries) is a shopping list kept in a
database, every list in it a `@Query`:

```sh
cd Examples/Groceries
swift run
```

//
//  VeinContainer.swift
//  NucleantData
//
//  Holds its content back until the model container in the environment is
//  migrated, so nothing below fetches from a schema that is not there yet.
//  A failed migration is shown in its place.
//

import NucleantUI

/// Shows `content` once the model container set on it has migrated.
///
/// ```swift
/// WindowGroup("Notes") {
///     VeinContainer {
///         NoteList()
///     }
///     .modelContainer(container)
/// }
/// ```
@View
public struct VeinContainer<Content: View> {
    @Environment(\.modelContainer) private var container
    @State private var isMigrated = false
    @State private var failure: MigrationFailure?

    private let content: () -> Content

    public init(_viewID: ViewID = #viewID, @ViewBuilder content: @escaping () -> Content) {
        self.content = content
        self._viewID = _viewID
    }

    public var body: some View {
        if let container {
            if isMigrated {
                content()
            } else if let failure {
                MigrationFailureView(failure: failure)
            } else {
                Color.clear
                    .task { migrate(container) }
            }
        } else {
            Color.clear
        }
    }

    private func migrate(_ container: ModelContainer) {
        do {
            try container.migrate()
            isMigrated = true
        } catch {
            failure = MigrationFailure(error)
        }
    }
}

@MainActor
extension VeinContainer {
    /// Sets `container` as the model container of everything inside.
    public func modelContainer(_ container: ModelContainer) -> some View {
        environment(\.modelContainer, container)
    }
}

/// What a failed migration said about itself, kept as text: the view shows
/// it and nothing else.
struct MigrationFailure: Equatable {
    let description: String
    let reason: String?
    let suggestion: String?

    init(_ error: some Error) {
        if let error = error as? LocalizedError {
            description = error.errorDescription ?? error.localizedDescription
            reason = error.failureReason
            suggestion = error.recoverySuggestion
        } else {
            description = error.localizedDescription
            reason = nil
            suggestion = nil
        }
    }
}

@View
struct MigrationFailureView {
    let failure: MigrationFailure

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("An error occurred while migrating the database:")
                .font(.title3)
            Text(failure.description)
                .foregroundStyle(.red)
            if let reason = failure.reason {
                Text(reason)
                    .foregroundStyle(.secondary)
            }
            if let suggestion = failure.suggestion {
                Text(suggestion)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

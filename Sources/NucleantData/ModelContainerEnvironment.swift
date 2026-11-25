//
//  ModelContainerEnvironment.swift
//  NucleantData
//
//  The database a subtree reads from. Set once near the root —
//  `VeinContainer { … }.modelContainer(container)` — and every `@Query`
//  below fetches from it; `@Environment(\.modelContext)` is what a view
//  inserts, deletes and saves through.
//

import NucleantUI

/// The key the model container is kept under in the environment.
public struct ContainerKey: EnvironmentKey {
    public static let defaultValue: ModelContainer? = nil
}

extension EnvironmentValues {
    /// The model container set above this view, or nil when none was.
    public var modelContainer: ModelContainer? {
        get { self[ContainerKey.self] }
        set { self[ContainerKey.self] = newValue }
    }

    /// The context of the model container set above this view. Reading it
    /// when none was set is a programming error.
    public var modelContext: ManagedObjectContext {
        guard let container = modelContainer else {
            preconditionFailure(
                "Read 'EnvironmentValues.modelContext' with no model container in the environment. "
                + "Set one above this view with .modelContainer(_:)."
            )
        }
        return container.context
    }
}

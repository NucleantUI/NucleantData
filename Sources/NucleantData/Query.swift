//
//  Query.swift
//  NucleantData
//
//  `@Query` — the models matching a predicate, kept current as they are
//  inserted, changed and deleted.
//
//  It is made of the framework's own dynamic properties: an `@State` slot
//  holding the view's observer, so the observer outlives the view value as
//  `@State` does, and an `@Environment` read of the model container. Its
//  `_bind` binds both, then points the slot at the shared observer for the
//  predicate this value carries — a new predicate from the parent (a search
//  string, a filter) takes effect on the next build, as it would in a
//  SwiftUI view.
//
//  The view is rebuilt by observation: `wrappedValue` reads the observer's
//  `results`, so the body that read them runs again after the next change.
//

import Foundation
import NucleantUI

/// The models of type `M` that match a predicate, in sorted order.
///
/// ```swift
/// @View
/// struct OpenItems {
///     @Query(#Predicate<Item> { !$0.isDone }, sortBy: [SortRule(\Item.title)])
///     private var items
///
///     var body: some View {
///         ForEach(items) { item in Text(item.title) }
///     }
/// }
/// ```
///
/// Fetches from the model container in the environment
/// (`.modelContainer(_:)` on a ``VeinContainer``) the first time the view
/// is built, and follows the context's inserts, changes and deletes from
/// then on. Every `@Query` with the same predicate shares one result.
///
/// Leave the property's type to be inferred, as `@Namespace`'s is: `@View`
/// makes a property with a written type and no `=` a parameter of the init
/// it generates.
@MainActor
@propertyWrapper
public struct Query<M: PersistentModel>: DynamicProperty {

    /// The view's observer, kept with the view's state.
    @State private var slot: QuerySlot<M> = QuerySlot()

    @Environment(\.modelContainer) private var container

    private let predicate: ModelPredicate<M>
    private let sortRules: [SortRule<M>]

    /// The models matching the predicate, sorted by the rules given.
    public var wrappedValue: [M] {
        guard let observer = slot.observer else {
            preconditionFailure(
                "@Query read before the view was built. Reading it outside of `body` is not supported."
            )
        }
        return observer.results.sorted(using: sortRules)
    }

    /// The models matching `predicate`, sorted by `rules` — by id, which
    /// is the order they were made in, unless told otherwise.
    public init(
        _ predicate: ModelPredicate<M> = ModelPredicate<M>.all,
        sortBy rules: [SortRule<M>] = [SortRule<M>(\.id)]
    ) {
        self.predicate = predicate
        self.sortRules = rules
    }

    /// The models matching `predicate`, sorted by `rules` — by id, which
    /// is the order they were made in, unless told otherwise.
    ///
    /// A predicate Vein cannot turn into SQL is a programming error.
    public init(
        _ predicate: Predicate<M>,
        sortBy rules: [SortRule<M>] = [SortRule<M>(\.id)]
    ) {
        do {
            self.predicate = try ModelPredicate(predicate)
        } catch {
            preconditionFailure(
                "Making a ModelPredicate from '\(predicate.expression)' failed: \(error.localizedDescription)"
            )
        }
        self.sortRules = rules
    }

    public mutating func _bind(to context: BindingContext) {
        _slot._bind(to: context)
        _container._bind(to: context)
        guard let container else {
            preconditionFailure(
                "@Query<\(M.self)> has no model container in the environment. "
                + "Set one above this view with .modelContainer(_:)."
            )
        }
        slot.point(at: predicate, in: container.context)
    }
}

extension Query: ViewInput {
    /// Sort rules hold closures, which cannot be told apart: two queries
    /// are never known to be the same, and a view holding one is built
    /// again whenever its parent is. The observer is kept regardless —
    /// it is the slot's, not the value's.
    public func _isEquivalent(to other: Query<M>) -> Bool { false }
}

/// Where a `@Query`'s observer is kept: its `@State` slot, which is never
/// written, only pointed at the observer for the predicate of the latest
/// view value bound.
@MainActor
final class QuerySlot<M: PersistentModel> {
    private(set) var observer: QueryObserver<M>?

    func point(at predicate: ModelPredicate<M>, in context: ManagedObjectContext) {
        if let observer, observer.predicate == predicate, observer.context === context { return }
        observer = QueryObserver.shared(for: predicate, in: context)
    }
}

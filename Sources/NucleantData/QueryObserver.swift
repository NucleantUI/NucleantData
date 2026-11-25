//
//  QueryObserver.swift
//  NucleantData
//
//  The live result of one predicate, kept by the context's query registry.
//
//  The context knows each observer by its model type and predicate: one
//  for each, held weakly, so every `@Query` with the same predicate shares
//  it and the first one fetches. From then on the context tells it about
//  every insert, change and delete of its model type — on the main actor,
//  after the write — and it keeps `results` to what matches.
//
//  It is `@Observable`, which is how the views reading it are rebuilt: a
//  `body` that read `results` is invalidated by the next change to them.
//  A change to a model that matches before and after changes no membership,
//  but what the view shows of it, or where it sorts, may have; that is a
//  change to `results` too.
//

import Foundation
import Logging
import NucleantUI
import Observation

@MainActor
@Observable
final class QueryObserver<M: PersistentModel> {

    /// What matches the predicate, in the order it was learned of: fetched
    /// first, then as inserted or changed into matching. `@Query` sorts it.
    private(set) var results: [M] = []

    @ObservationIgnored
    nonisolated let predicate: ModelPredicate<M>

    /// The context this observer is registered with.
    @ObservationIgnored
    let context: ManagedObjectContext

    private init(_ predicate: ModelPredicate<M>, context: ManagedObjectContext) {
        self.predicate = predicate
        self.context = context
    }

    /// The observer for `predicate` in `context`: the one already
    /// registered there, or a new one, fetched now.
    static func shared(for predicate: ModelPredicate<M>, in context: ManagedObjectContext) -> QueryObserver<M> {
        let made = QueryObserver(predicate, context: context)
        let registered = context.getOrCreateQueryObserver(for: M.typeIdentifier, predicate.identity) { made }
        guard let observer = registered as? QueryObserver<M> else {
            preconditionFailure(
                "The query registered for \(M.self) with this predicate is a \(type(of: registered)), "
                + "not NucleantData's — a context can serve one UI integration's queries."
            )
        }
        if observer === made {
            observer.fetch()
        }
        return observer
    }

    private func fetch() {
        do {
            results = try context.fetchAll(predicate)
        } catch {
            if context.modelContainer.logConfiguration.modelContextErrors {
                Logger(label: "NucleantData.Query<\(M.self)>")
                    .error("Failed to fetch the initial query results: \(error.localizedDescription)")
            }
            results = []
        }
    }

    private func contains(_ model: M) -> Bool {
        results.contains { $0.id == model.id }
    }
}

extension QueryObserver: AnyQueryObserver {

    func appendAny(_ models: [AnyObject]) {
        var added: [M] = []
        for case let model as M in models where predicate.runtimeFilter(model) {
            if !contains(model), !added.contains(where: { $0.id == model.id }) {
                added.append(model)
            }
        }
        guard !added.isEmpty else { return }
        results.append(contentsOf: added)
    }

    func handleUpdate(_ model: any PersistentModel, matchedBeforeChange: Bool) {
        guard let model = model as? M else { return }
        let matchesNow = predicate.runtimeFilter(model)
        if matchesNow {
            if contains(model) {
                // Still in: nothing joins or leaves, but the view showing it
                // has to see what changed.
                withMutation(keyPath: \.results) {}
            } else {
                results.append(model)
            }
        } else if matchedBeforeChange || contains(model) {
            results.removeAll { $0.id == model.id }
        }
    }

    nonisolated func doesMatch(_ model: any PersistentModel) -> Bool {
        guard let model = model as? M else { return false }
        return predicate.runtimeFilter(model)
    }

    func remove(_ model: any PersistentModel) {
        guard let model = model as? M, contains(model) else { return }
        results.removeAll { $0.id == model.id }
    }

    nonisolated var usedPredicate: any AnyPredicateBuilder { predicate }
}

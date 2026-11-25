//
//  Schema.swift
//  Groceries
//
//  The database: one table of items, each either still to buy or in the
//  basket.
//

import Foundation
import NucleantData

enum GroceriesV1: VersionedSchema {
    static let version = ModelVersion(1, 0, 0)
    static let models: [any PersistentModel.Type] = [Item.self]

    @Model
    final class Item {
        var name: String
        /// `name` lowercased: what a search is matched against, the same in
        /// SQL as in Swift, so a fetched list and a live one agree.
        var searchKey: String
        var isInBasket: Bool
        var addedAt: Date

        init(name: String) {
            self.name = name
            self.searchKey = name.lowercased()
            self.isInBasket = false
            self.addedAt = Date()
        }
    }
}

typealias Item = GroceriesV1.Item

enum GroceriesMigration: SchemaMigrationPlan {
    static let schemas: [VersionedSchema.Type] = [GroceriesV1.self]
    static let stages: [MigrationStage] = []
}

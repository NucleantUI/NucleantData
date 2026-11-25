//
//  GroceriesApp.swift
//  Groceries
//
//  A shopping list kept in a database. Add what you need; tick it off as
//  it goes in the basket and it moves down to "In the basket"; clear the
//  basket at the till. Search narrows the list, the order chips sort it,
//  and it is all still there the next time the app opens.
//
//  Every list on screen is a `@Query`: the app never fetches, it inserts,
//  changes and deletes through the context, and each list follows.
//

import Foundation
import NucleantData
import NucleantUI

@main
struct GroceriesApp: NucleantApp {
    private let container = GroceriesApp.openDatabase()

    var body: some Scene {
        WindowGroup("Groceries") {
            VeinContainer {
                GroceryList()
            }
            .modelContainer(container)
        }
        .defaultSize(width: 460, height: 680)
    }

    /// The list's database, in the app's support folder. Unencrypted: a
    /// shopping list is no secret, and an encrypted one keeps its key in
    /// the system's keychain.
    private static func openDatabase() -> ModelContainer {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Groceries", directoryHint: .isDirectory)
        let file = folder.appending(path: "groceries.sqlite3").path
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            return try ModelContainer(
                GroceriesV1.self,
                migration: GroceriesMigration.self,
                at: file,
                appID: "ui.nucleant.groceries",
                encryptionEnabled: false
            )
        } catch {
            preconditionFailure("Could not open the grocery list at \(file): \(error)")
        }
    }
}

//
//  NucleantData.swift
//  NucleantData
//
//  Vein's API is NucleantData's: an app imports this module alone and has
//  `@Model`, `@Relationship`, `ModelContainer`, `ModelPredicate`,
//  `SortRule`, migrations and all, next to the view side added here.
//
//  `VeinCore` is Vein with its UI-independent `@Model` macro and the public
//  `ModelContainer` initializers; it re-exports `Vein` itself, which is
//  named here too so the whole of it is plainly part of this module's API.
//

@_exported import Vein
@_exported import VeinCore

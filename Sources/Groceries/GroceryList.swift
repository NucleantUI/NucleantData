//
//  GroceryList.swift
//  Groceries
//
//  The window: a field to add with, search and order above, then the two
//  lists. Each list is its own view holding a `@Query`, made from the
//  search and order its parent has now — type in the search field and
//  "To buy" is a new query; tick an item and the change moves it from one
//  query's results to the other's.
//

import Foundation
import NucleantData
import NucleantUI

/// Surfaces follow the system's light or dark appearance; the accents are
/// fixed.
struct Theme {
    static let background = BackgroundStyle.background
    static let panel = BackgroundStyle.secondaryBackground
    static let row = BackgroundStyle.tertiaryBackground
    static let ring = DynamicShapeStyle(light: Color(white: 0, opacity: 0.25), dark: Color(white: 1, opacity: 0.25))
    static let accent = Color(hex: 0x3FA34D)
}

/// How both lists are sorted.
enum ListOrder: CaseIterable {
    case name, newest

    var title: String {
        switch self {
        case .name: "A–Z"
        case .newest: "Newest"
        }
    }

    var rules: [SortRule<Item>] {
        switch self {
        case .name: [SortRule(\Item.name)]
        case .newest: [SortRule(\Item.addedAt, order: .descending)]
        }
    }
}

// MARK: - Window

@View
struct GroceryList {
    @State private var search = ""
    @State private var order = ListOrder.name

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Groceries")
                .font(.system(size: 26, weight: .bold))
            AddItemBar()
            HStack(spacing: 8) {
                TextField("Search", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
                ForEach(ListOrder.allCases, id: \.self) { choice in
                    OrderChip(order: choice, selection: $order)
                }
            }
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 22) {
                    ToBuySection(search: search, order: order)
                    BasketSection(order: order)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.background)
        .tint(Theme.accent)
    }
}

@View
struct AddItemBar {
    @State private var name = ""
    @Environment(\.modelContext) private var context

    var body: some View {
        HStack(spacing: 8) {
            TextField("Add an item", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit { add() }
                .frame(maxWidth: .infinity)
            Button("Add") { add() }
                .disabled(trimmedName.isEmpty)
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func add() {
        let name = trimmedName
        guard !name.isEmpty else { return }
        do {
            try context.insert(Item(name: name))
            try context.save()
            self.name = ""
        } catch {
            print("Groceries: could not add \(name): \(error)")
        }
    }
}

@View
struct OrderChip {
    let order: ListOrder
    @Binding var selection: ListOrder

    var body: some View {
        Text(order.title)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(selection == order ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
            .frame(width: 64)
            .padding(horizontal: 0, vertical: 6)
            .background(selection == order ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.panel))
            .cornerRadius(14)
            .onTapGesture { selection = order }
    }
}

// MARK: - Lists

/// What is still to buy, narrowed by the search.
@View
struct ToBuySection {
    @Query private var items: [Item]
    private let isSearching: Bool

    init(search: String, order: ListOrder, _viewID: ViewID = #viewID) {
        let key = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if key.isEmpty {
            _items = Query(#Predicate<Item> { !$0.isInBasket }, sortBy: order.rules)
        } else {
            _items = Query(#Predicate<Item> { !$0.isInBasket && $0.searchKey.contains(key) }, sortBy: order.rules)
        }
        isSearching = !key.isEmpty
        self._viewID = _viewID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(title: "To buy", count: items.count)
            ForEach(items, id: \.id) { item in
                ItemRow(item: item)
            }
            if items.isEmpty {
                Placeholder(text: isSearching ? "Nothing to buy matches." : "Nothing left to buy.")
            }
        }
    }
}

/// What is in the basket, cleared at the till.
@View
struct BasketSection {
    @Query private var items: [Item]
    @Environment(\.modelContext) private var context

    init(order: ListOrder, _viewID: ViewID = #viewID) {
        _items = Query(#Predicate<Item> { $0.isInBasket }, sortBy: order.rules)
        self._viewID = _viewID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                SectionTitle(title: "In the basket", count: items.count)
                Button("Clear") { clear() }
                    .disabled(items.isEmpty)
            }
            ForEach(items, id: \.id) { item in
                ItemRow(item: item)
            }
            if items.isEmpty {
                Placeholder(text: "The basket is empty.")
            }
        }
    }

    private func clear() {
        do {
            for item in items {
                try context.delete(item)
            }
            try context.save()
        } catch {
            print("Groceries: could not clear the basket: \(error)")
        }
    }
}

@View
struct SectionTitle {
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.headline)
            Text("\(count)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)
            Spacer()
        }
    }
}

@View
struct Placeholder {
    let text: String

    var body: some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(24)
    }
}

// MARK: - Rows

@View
struct ItemRow {
    let item: Item
    @Environment(\.modelContext) private var context

    var body: some View {
        HStack(spacing: 12) {
            Tick(isOn: item.isInBasket)
                .onTapGesture { toggle() }
            Text(item.name)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(item.isInBasket ? .secondary : .primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(item.addedAt.formatted(date: .abbreviated, time: .omitted))
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Remove") { remove() }
        }
        .padding(horizontal: 14, vertical: 10)
        .background(Theme.row)
        .cornerRadius(10)
    }

    private func toggle() {
        item.isInBasket.toggle()
        do {
            try context.save()
        } catch {
            print("Groceries: could not save \(item.name): \(error)")
        }
    }

    private func remove() {
        do {
            try context.delete(item)
            try context.save()
        } catch {
            print("Groceries: could not remove \(item.name): \(error)")
        }
    }
}

/// A ring while the item is to buy; a filled disc with a check once it is
/// in the basket.
@View
struct Tick {
    let isOn: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(isOn ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.ring), lineWidth: 2)
            if isOn {
                Circle()
                    .fill(Theme.accent)
                PathShape { size in
                    var path = Path()
                    path.move(to: Point(x: size.width * 0.28, y: size.height * 0.52))
                    path.addLine(to: Point(x: size.width * 0.44, y: size.height * 0.68))
                    path.addLine(to: Point(x: size.width * 0.73, y: size.height * 0.34))
                    return path
                }
                .stroke(.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: 22, height: 22)
    }
}

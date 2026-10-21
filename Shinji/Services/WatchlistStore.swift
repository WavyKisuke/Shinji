import Foundation
import Combine

struct WatchlistItem: Identifiable, Codable, Equatable {
    let id: String
    var catalogID: String
    var type: String
    var title: String
    var posterURL: String?
    var description: String?
    var addonName: String
    var addedAt: Date
}

@MainActor
final class WatchlistStore: ObservableObject {
    static let shared = WatchlistStore()
    private let key = "shinji.watchlist.v1"

    @Published private(set) var items: [WatchlistItem] = []

    private init() { load() }

    func contains(catalogID: String, addonName: String) -> Bool {
        items.contains { $0.catalogID == catalogID && $0.addonName == addonName }
    }

    @discardableResult
    func add(_ item: AddonCatalogItem) -> Bool {
        guard !contains(catalogID: item.id, addonName: item.addonName) else { return false }

        let watchlistItem = WatchlistItem(
            id: "\(item.addonName)::\(item.id)",
            catalogID: item.id,
            type: item.type,
            title: item.name,
            posterURL: item.posterURL?.absoluteString,
            description: item.description,
            addonName: item.addonName,
            addedAt: Date()
        )
        items.insert(watchlistItem, at: 0)
        items = Array(items.prefix(100))
        save()
        objectWillChange.send()
        return true
    }

    @discardableResult
    func remove(catalogID: String, addonName: String) -> Bool {
        let before = items.count
        items.removeAll { $0.catalogID == catalogID && $0.addonName == addonName }
        guard items.count != before else { return false }
        save()
        objectWillChange.send()
        return true
    }

    func toggle(_ item: AddonCatalogItem) {
        if contains(catalogID: item.id, addonName: item.addonName) {
            _ = remove(catalogID: item.id, addonName: item.addonName)
        } else {
            _ = add(item)
        }
    }

    func remove(_ item: WatchlistItem) {
        items.removeAll { $0.id == item.id }
        save()
        objectWillChange.send()
    }

    func clearAll() {
        items.removeAll()
        save()
        objectWillChange.send()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([WatchlistItem].self, from: data) else { return }
        items = decoded.sorted { $0.addedAt > $1.addedAt }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

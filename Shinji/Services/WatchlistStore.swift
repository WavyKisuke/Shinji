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

    func toggle(_ item: AddonCatalogItem) {
        if let existing = items.first(where: { $0.catalogID == item.id && $0.addonName == item.addonName }) {
            items.removeAll { $0.id == existing.id }
        } else {
            let id = "\(item.addonName)::\(item.id)"
            items.insert(WatchlistItem(
                id: id,
                catalogID: item.id,
                type: item.type,
                title: item.name,
                posterURL: item.posterURL?.absoluteString,
                description: item.description,
                addonName: item.addonName,
                addedAt: Date()
            ), at: 0)
            items = Array(items.prefix(100))
        }
        save()
    }

    func remove(_ item: WatchlistItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func clearAll() {
        items.removeAll()
        save()
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

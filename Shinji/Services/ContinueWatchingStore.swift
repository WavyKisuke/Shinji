import Foundation
import Combine

struct ContinueWatchingItem: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var url: String
    var position: Double
    var duration: Double
    var headers: [String: String]
    var updatedAt: Date
}

final class ContinueWatchingStore: ObservableObject {
    static let shared = ContinueWatchingStore()
    private let key = "shinji.continueWatching.v1"

    @Published private(set) var items: [ContinueWatchingItem] = []

    private init() { load() }

    func item(for id: String) -> ContinueWatchingItem? {
        items.first(where: { $0.id == id })
    }

    func record(id: String, title: String, url: URL, position: Double, duration: Double, headers: [String: String] = [:]) {
        guard duration > 0, position >= 0 else { return }
        if position / duration >= 0.95 {
            remove(id: id)
            return
        }
        let value = ContinueWatchingItem(id: id, title: title, url: url.absoluteString, position: position, duration: duration, headers: headers, updatedAt: Date())
        items.removeAll { $0.id == id }
        items.insert(value, at: 0)
        items = Array(items.prefix(20))
        save()
    }

    func remove(id: String) {
        items.removeAll { $0.id == id }
        save()
    }

    func clearAll() {
        items.removeAll()
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([ContinueWatchingItem].self, from: data) else { return }
        items = decoded.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

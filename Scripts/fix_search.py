from pathlib import Path

# Add real Stremio catalog search support and a removable search history UI.
store = Path("Shinji/Services/AddonStore.swift")
text = store.read_text(encoding="utf-8")

if "func searchCatalogs(query: String, typeFilter: String = \"All\") async -> [AddonCatalogItem]" not in text:
    marker = "    private func streamURL(base: URL, item: AddonCatalogItem) -> URL? {"
    method = '''    func searchCatalogs(query: String, typeFilter: String = "All") async -> [AddonCatalogItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var loaded: [AddonCatalogItem] = []
        for addon in addons {
            guard addon.format == "Stremio", let manifestURL = addon.manifestURL else { continue }
            do {
                let manifestData = try await fetchJSON(from: manifestURL)
                for descriptor in parseCatalogs(from: manifestData) {
                    if typeFilter == "Movies" && descriptor.type.lowercased() != "movie" { continue }
                    if typeFilter == "Shows" && descriptor.type.lowercased() != "series" { continue }
                    guard let url = catalogURL(base: manifestURL, descriptor: descriptor, search: trimmed) else { continue }
                    do {
                        let data = try await fetchJSON(from: url)
                        loaded.append(contentsOf: parseMetas(from: data, type: descriptor.type, addonName: addon.name))
                    } catch {
                        // Keep searching other catalogs if one source does not support search.
                    }
                }
            } catch {
                // Keep other installed add-ons usable.
            }
        }

        var seen = Set<String>()
        return loaded.filter { seen.insert("\\($0.type)|\\($0.id)").inserted }
    }

'''
    if marker not in text:
        raise SystemExit("search insertion marker not found")
    text = text.replace(marker, method + marker, 1)

old = '''    private func catalogURL(base: URL, descriptor: StremioCatalogDescriptor) -> URL? {
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return nil }
        let safeType = descriptor.type.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? descriptor.type
        let safeID = descriptor.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? descriptor.id
        let prefix = addonPathPrefix(components.path)
        components.path = prefix + "catalog/\\(safeType)/\\(safeID).json"
        return components.url
    }
'''
new = '''    private func catalogURL(base: URL, descriptor: StremioCatalogDescriptor, search: String? = nil) -> URL? {
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return nil }
        let safeType = descriptor.type.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? descriptor.type
        let safeID = descriptor.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? descriptor.id
        let prefix = addonPathPrefix(components.path)
        var path = prefix + "catalog/\\(safeType)/\\(safeID)"
        if let search, !search.isEmpty {
            let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
            let safeSearch = search.addingPercentEncoding(withAllowedCharacters: allowed) ?? search
            path += "/search=\\(safeSearch)"
        }
        components.path = path + ".json"
        return components.url
    }
'''
if old not in text:
    raise SystemExit("catalogURL block not found")
text = text.replace(old, new, 1)
store.write_text(text, encoding="utf-8")

view = Path("Shinji/Views/SearchView.swift")
text = view.read_text(encoding="utf-8")
text = text.replace('    @State private var selectedType = "All"\n', '    @State private var selectedType = "All"\n    @State private var searchResults: [AddonCatalogItem] = []\n    @State private var isSearching = false\n    @AppStorage("shinjiSearchHistory") private var searchHistoryRaw = ""\n', 1)

start = text.index('    private var results: [AddonCatalogItem] {')
end = text.index('\n    var body: some View {', start)
replacement = '''    private var browseResults: [AddonCatalogItem] {
        var items = addonStore.catalogItems
        if selectedType == "Movies" { items = items.filter { $0.type.lowercased() == "movie" } }
        if selectedType == "Shows" { items = items.filter { $0.type.lowercased() == "series" } }
        var seen = Set<String>()
        return items.filter { seen.insert("\\($0.type)|\\($0.id)|\\($0.name.lowercased())").inserted }
    }

    private var results: [AddonCatalogItem] {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? browseResults : searchResults
    }

    private var searchHistory: [String] {
        searchHistoryRaw.split(separator: "\\u{1F}").map(String.init)
    }

    private func saveSearch(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var history = searchHistory.filter { !$0.caseInsensitiveCompare(trimmed).rawValue.isEqual(0) }
        history.insert(trimmed, at: 0)
        searchHistoryRaw = history.prefix(12).joined(separator: "\\u{1F}")
    }

    private func deleteSearch(_ value: String) {
        searchHistoryRaw = searchHistory.filter { $0 != value }.joined(separator: "\\u{1F}")
    }

    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        let found = await addonStore.searchCatalogs(query: trimmed, typeFilter: selectedType)
        guard query.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed else { return }
        searchResults = found
        isSearching = false
    }
'''
text = text[:start] + replacement + text[end:]

# Show removable recent searches below the field.
needle = '''                    searchField
                    typePicker
'''
insert = '''                    searchField
                    if query.isEmpty && !searchHistory.isEmpty {
                        recentSearches
                    }
                    typePicker
'''
text = text.replace(needle, insert, 1)

# Improve empty state while a remote search is running.
text = text.replace('''                    if results.isEmpty {
                        emptyState
                    } else {''', '''                    if isSearching {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Searching your installed sources…")
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else if results.isEmpty {
                        emptyState
                    } else {''', 1)

# Search on typing with a short debounce, and refresh when the type filter changes.
text = text.replace('''        .task { await addonStore.refreshCatalogs() }
''', '''        .task { await addonStore.refreshCatalogs() }
        .task(id: "\\(query)|\\(selectedType)") {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await performSearch()
        }
''', 1)

# Add submit behavior to the search field.
text = text.replace('''                .autocorrectionDisabled()
            if !query.isEmpty {''', '''                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { saveSearch(query) }
            if !query.isEmpty {''', 1)

# Add recent-search UI before the type picker.
marker = '    private var typePicker: some View {'
recent = '''    private var recentSearches: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent searches")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Button("Clear all") { searchHistoryRaw = "" }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(hex: accentHex))
                    .buttonStyle(.plain)
            }
            ForEach(searchHistory, id: \\.self) { value in
                HStack(spacing: 10) {
                    Button {
                        query = value
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: "clock.arrow.circlepath")
                            Text(value).lineLimit(1)
                            Spacer()
                        }
                        .foregroundStyle(.white.opacity(0.82))
                    }
                    .buttonStyle(.plain)
                    Button { deleteSearch(value) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.45))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 18)
    }

'''
text = text.replace(marker, recent + marker, 1)
view.write_text(text, encoding="utf-8")

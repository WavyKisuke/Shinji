from pathlib import Path

path = Path("Shinji/Services/AddonStore.swift")
text = path.read_text(encoding="utf-8")

if "let genres: [String]" not in text:
    text = text.replace(
        "    let year: String?\n    let addonName: String\n",
        "    let year: String?\n    let genres: [String]\n    let addonName: String\n",
        1,
    )

if "let genres: [String] =" not in text:
    old = '''            let year: String? = {
                if let value = meta["releaseInfo"] as? String, !value.isEmpty { return String(value.prefix(4)) }
                if let value = meta["year"] as? Int { return String(value) }
                if let value = meta["year"] as? String, !value.isEmpty { return String(value.prefix(4)) }
                return nil
            }()
            return AddonCatalogItem(
'''
    new = '''            let year: String? = {
                if let value = meta["releaseInfo"] as? String, !value.isEmpty { return String(value.prefix(4)) }
                if let value = meta["year"] as? Int { return String(value) }
                if let value = meta["year"] as? String, !value.isEmpty { return String(value.prefix(4)) }
                return nil
            }()
            var genres: [String] = []
            if let values = meta["genres"] as? [String] { genres.append(contentsOf: values) }
            else if let value = meta["genres"] as? String { genres.append(contentsOf: value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }) }
            if let values = meta["genre"] as? [String] { genres.append(contentsOf: values) }
            else if let value = meta["genre"] as? String { genres.append(contentsOf: value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }) }
            genres = Array(Set(genres.filter { !$0.isEmpty }))
            return AddonCatalogItem(
'''
    text = text.replace(old, new, 1)

if "genres: genres," not in text:
    text = text.replace(
        "                year: year,\n                addonName: addonName\n",
        "                year: year,\n                genres: genres,\n                addonName: addonName\n",
        1,
    )

path.write_text(text, encoding="utf-8")
print("Catalog year/genre metadata ensured.")

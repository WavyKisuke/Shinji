import SwiftUI

struct AddonsView: View {
    @EnvironmentObject private var store: AddonStore
    @State private var manifestURL = ""
    @State private var isInstalling = false

    var body: some View {
        NavigationStack {
            List {
                Section("Install from URL") {
                    TextField("https://example.org/addon.json", text: $manifestURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        Task {
                            isInstalling = true
                            await store.install(from: manifestURL)
                            isInstalling = false
                        }
                    } label: {
                        HStack {
                            if isInstalling { ProgressView() }
                            Text(isInstalling ? "Installing…" : "Install Add-on")
                        }
                    }
                    .disabled(isInstalling || manifestURL.isEmpty)
                    if let status = store.statusMessage {
                        Text(status).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section("Installed Add-ons") {
                    if store.addons.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "puzzlepiece.extension")
                                .font(.title)
                                .foregroundStyle(.secondary)
                            Text("No add-ons installed").font(.headline)
                            Text("Add a compatible HTTPS JSON manifest above.")
                                .font(.footnote).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        ForEach(store.addons) { addon in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(addon.name).font(.headline)
                                Text("v\(addon.version) • \(addon.publisher)")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text(addon.capabilities.joined(separator: ", "))
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            .swipeActions {
                                Button("Remove", role: .destructive) { store.remove(addon) }
                            }
                        }
                    }
                }
                Section {
                    Text("Add-ons are data manifests only. Do not install sources you do not trust or are not authorized to use.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add-ons")
        }
    }
}

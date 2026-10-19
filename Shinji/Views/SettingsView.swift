import SwiftUI

struct SettingsView: View {
    @AppStorage("preferAudioMixing") private var preferAudioMixing = true
    @AppStorage("selectedTheme") private var selectedTheme = "Dark"

    var body: some View {
        NavigationStack {
            Form {
                Section("Playback") {
                    Toggle("Mix with other audio apps", isOn: $preferAudioMixing)
                    Text("iOS and individual media sources can affect whether background music continues playing.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Appearance") {
                    Picker("Theme", selection: $selectedTheme) {
                        Text("Dark").tag("Dark")
                        Text("System").tag("System")
                    }
                }
                Section("About") {
                    LabeledContent("Version", value: "0.1.0")
                    Text("Shinji is a starter app. Add authorized catalog sources through Add-ons.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

import SwiftUI
import UIKit

struct SettingsView: View {
    @AppStorage("preferAudioMixing") private var preferAudioMixing = true
    @AppStorage("selectedTheme") private var selectedTheme = "Midnight Neon"
    @AppStorage("shinjiAccentHex") private var accentHex = "B64DFF"
    @AppStorage("shinjiGlowHex") private var glowHex = "4936FF"
    @AppStorage("shinjiAppearance") private var appearance = "Dark"
    @AppStorage("shinjiPlaybackQuality") private var playbackQuality = "Auto"
    @AppStorage("shinjiDownloadsEnabled") private var downloadsEnabled = true
    @AppStorage("shinjiParentalControls") private var parentalControls = false

    private let presets: [(name: String, accent: String, glow: String)] = [
        ("Midnight Neon", "B64DFF", "4936FF"),
        ("Cyber Ocean", "20D9FF", "245BFF"),
        ("Emerald Pulse", "35E6A1", "087F70"),
        ("Sunset Arcade", "FF6B9A", "FF8A3D"),
        ("Rose Quartz", "FF75D8", "8E48FF"),
        ("Golden Hour", "FFC857", "E66B2E"),
        ("Arctic", "E9F4FF", "73BFFF"),
        ("Mono", "FFFFFF", "777777")
    ]

    private var accentColor: Color { Color(hex: accentHex) }
    private var glowColor: Color { Color(hex: glowHex) }
    private var accentBinding: Binding<Color> {
        Binding(get: { accentColor }, set: { accentHex = $0.hexString; selectedTheme = "Custom" })
    }
    private var glowBinding: Binding<Color> {
        Binding(get: { glowColor }, set: { glowHex = $0.hexString; selectedTheme = "Custom" })
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        appearanceSettings
                    } label: {
                        settingsRow(icon: "circle.lefthalf.filled", title: "Appearance", subtitle: "Dark / Light / Auto", value: appearance)
                    }
                    NavigationLink {
                        playbackSettings
                    } label: {
                        settingsRow(icon: "playpause.fill", title: "Playback", subtitle: "Quality, Audio, Subtitles", value: nil)
                    }
                    NavigationLink {
                        downloadSettings
                    } label: {
                        settingsRow(icon: "arrow.down.to.line", title: "Download", subtitle: "Storage, Cache", value: nil)
                    }
                    NavigationLink {
                        accountSettings
                    } label: {
                        settingsRow(icon: "person.crop.circle", title: "Account", subtitle: "Profiles and parental controls", value: "Local")
                    }
                    NavigationLink {
                        privacySettings
                    } label: {
                        settingsRow(icon: "hand.raised.fill", title: "Privacy", subtitle: "Permissions, Data", value: nil)
                    }
                    NavigationLink {
                        aboutSettings
                    } label: {
                        settingsRow(icon: "info.circle", title: "About", subtitle: "Version 0.1.0", value: nil)
                    }
                }
                .listRowBackground(Color.white.opacity(0.045))
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Settings")
            .tint(accentColor)
        }
        .preferredColorScheme(appearance == "Light" ? .light : .dark)
    }

    private func settingsRow(icon: String, title: String, subtitle: String, value: String?) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(accentColor)
                .frame(width: 42, height: 42)
                .background(accentColor.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 16, weight: .semibold))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if let value {
                Text(value).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }

    private var appearanceSettings: some View {
        Form {
            Section("Appearance mode") {
                Picker("Mode", selection: $appearance) {
                    Text("Dark").tag("Dark")
                    Text("Light").tag("Light")
                    Text("Auto").tag("Auto")
                }
                .pickerStyle(.segmented)
                Text("Auto follows the device appearance. Your color palette remains saved separately.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Color presets") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(presets, id: \.name) { preset in
                        Button {
                            selectedTheme = preset.name
                            accentHex = preset.accent
                            glowHex = preset.glow
                        } label: {
                            HStack(spacing: 6) {
                                Circle().fill(Color(hex: preset.accent)).frame(width: 15, height: 15)
                                Circle().fill(Color(hex: preset.glow)).frame(width: 15, height: 15)
                                Text(preset.name).font(.caption.weight(.semibold)).lineLimit(1)
                                Spacer(minLength: 0)
                                if selectedTheme == preset.name {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color(hex: preset.accent))
                                }
                            }
                            .padding(10)
                            .background(Color(hex: preset.glow).opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: preset.accent).opacity(0.45), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary)
                    }
                }
                .padding(.vertical, 5)
            }
            Section("Custom colors") {
                ColorPicker("Accent color", selection: accentBinding, supportsOpacity: false)
                ColorPicker("Glow / gradient color", selection: glowBinding, supportsOpacity: false)
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [glowColor, accentColor, .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(height: 60)
                    .overlay(alignment: .bottomLeading) {
                        Text("LIVE PREVIEW").font(.system(size: 9, weight: .black)).tracking(1.5).foregroundStyle(.white).padding(8)
                    }
            }
            Section("Selected theme") {
                LabeledContent("Palette", value: selectedTheme)
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .tint(accentColor)
    }

    private var playbackSettings: some View {
        Form {
            Section("Playback quality") {
                Picker("Default quality", selection: $playbackQuality) {
                    Text("Auto").tag("Auto")
                    Text("High").tag("High")
                    Text("Medium").tag("Medium")
                    Text("Low").tag("Low")
                }
                Text("Quality selection is a preference; the available quality depends on the stream provider.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Audio") {
                Toggle("Mix with other audio apps", isOn: $preferAudioMixing)
                Text("iOS and individual media sources can affect whether background music continues playing.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Subtitles") {
                Text("Subtitle and audio-track selection will be available when the selected stream exposes supported tracks.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Playback")
        .navigationBarTitleDisplayMode(.inline)
        .tint(accentColor)
    }

    private var downloadSettings: some View {
        Form {
            Section("Offline downloads") {
                Toggle("Enable downloads", isOn: $downloadsEnabled)
                Text("Offline saving depends on the source format, access permissions, and DRM restrictions.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Storage and cache") {
                LabeledContent("Download location", value: "App storage")
                Button("Clear temporary cache", role: .destructive) {}
                    .disabled(true)
                Text("Cache management becomes available when Shinji adds its local media cache.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Download")
        .navigationBarTitleDisplayMode(.inline)
        .tint(accentColor)
    }

    private var accountSettings: some View {
        Form {
            Section("Profiles") {
                LabeledContent("Current profile", value: "Default")
                Text("Multiple profile sign-in and cloud sync are not configured yet.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Parental controls") {
                Toggle("Enable parental controls", isOn: $parentalControls)
                Text("This setting records your preference; rating-based content restrictions still need to be connected to catalog metadata.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .tint(accentColor)
    }

    private var privacySettings: some View {
        Form {
            Section("Privacy") {
                Label("Add-on sources connect to their configured servers.", systemImage: "network")
                Label("Only install sources you trust.", systemImage: "checkmark.shield")
                Text("Shinji does not ask for an account in this starter build. Source providers may have their own privacy policies.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Local data") {
                Text("Settings and installed add-on metadata are stored on this device.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .tint(accentColor)
    }

    private var aboutSettings: some View {
        Form {
            Section("Shinji") {
                LabeledContent("Version", value: "0.1.0")
                LabeledContent("Build", value: "GitHub Actions")
                Text("A cinematic media library for authorized catalogs and streams.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .tint(accentColor)
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let value = UInt64(cleaned, radix: 16) ?? 0xB64DFF
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }

    var hexString: String {
        let components = UIColor(self).cgColor.components ?? [0.71, 0.30, 1.0, 1.0]
        let red = Int((components[0] * 255).rounded())
        let green = Int(((components.count > 1 ? components[1] : components[0]) * 255).rounded())
        let blue = Int(((components.count > 2 ? components[2] : components[0]) * 255).rounded())
        return String(format: "%02X%02X%02X", red, green, blue)
    }
}

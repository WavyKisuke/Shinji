import SwiftUI
import UIKit

struct SettingsView: View {
    @AppStorage("preferAudioMixing") private var preferAudioMixing = true
    @AppStorage("selectedTheme") private var selectedTheme = "Midnight Neon"
    @AppStorage("shinjiAccentHex") private var accentHex = "B64DFF"
    @AppStorage("shinjiGlowHex") private var glowHex = "4936FF"

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

    private var accentColor: Color {
        get { Color(hex: accentHex) }
    }

    private var glowColor: Color {
        get { Color(hex: glowHex) }
    }

    private var accentBinding: Binding<Color> {
        Binding(get: { accentColor }, set: { accentHex = $0.hexString })
    }

    private var glowBinding: Binding<Color> {
        Binding(get: { glowColor }, set: { glowHex = $0.hexString })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Playback") {
                    Toggle("Mix with other audio apps", isOn: $preferAudioMixing)
                    Text("iOS and individual media sources can affect whether background music continues playing.")
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
                                HStack(spacing: 9) {
                                    Circle().fill(Color(hex: preset.accent)).frame(width: 17, height: 17)
                                    Circle().fill(Color(hex: preset.glow)).frame(width: 17, height: 17).offset(x: -13)
                                    Text(preset.name)
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    Spacer(minLength: 0)
                                    if selectedTheme == preset.name {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color(hex: preset.accent))
                                    }
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(hex: preset.glow).opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: preset.accent).opacity(selectedTheme == preset.name ? 0.9 : 0.25), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.primary)
                        }
                    }
                    .padding(.vertical, 5)
                    Text("Choose a palette to change Shinji’s accent and cinematic glow colors.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("Custom colors") {
                    ColorPicker("Accent color", selection: accentBinding, supportsOpacity: false)
                        .onChange(of: accentHex) { _ in selectedTheme = "Custom" }
                    ColorPicker("Glow / gradient color", selection: glowBinding, supportsOpacity: false)
                        .onChange(of: glowHex) { _ in selectedTheme = "Custom" }
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(colors: [glowColor, accentColor, .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(height: 54)
                            .overlay(alignment: .bottomLeading) {
                                Text("LIVE PREVIEW")
                                    .font(.system(size: 9, weight: .black))
                                    .tracking(1.5)
                                    .foregroundStyle(.white)
                                    .padding(8)
                            }
                    }
                    .listRowBackground(Color.black)
                }

                Section("Appearance") {
                    LabeledContent("Current palette", value: selectedTheme)
                    Text("The selected colors are saved on this device and applied to Shinji’s navigation accents and featured banners.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("About") {
                    LabeledContent("Version", value: "0.1.0")
                    Text("Shinji is a starter app. Add authorized catalog sources through Add-ons.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .tint(accentColor)
        }
        .preferredColorScheme(.dark)
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

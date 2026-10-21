import SwiftUI

struct NuvioPlayerTrack: Identifiable, Hashable {
    let id: Int
    let title: String
    let language: String?
    let type: String

    var displayTitle: String {
        if !title.isEmpty { return title }
        if let language, !language.isEmpty, language != "und" { return language.uppercased() }
        return "Track \(id)"
    }
}

struct NuvioPlayerTrackPicker: View {
    let title: String
    let tracks: [NuvioPlayerTrack]
    let selectedID: Int?
    let offOption: Bool
    let onSelect: (Int?) -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.black.opacity(0.62)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.10), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .accessibilityLabel("Close \(title)")
                }

                ScrollView {
                    LazyVStack(spacing: 6) {
                        if offOption {
                            row(title: "Off", subtitle: nil, selected: selectedID == nil) {
                                onSelect(nil)
                            }
                        }

                        ForEach(tracks) { track in
                            row(
                                title: track.displayTitle,
                                subtitle: track.language,
                                selected: selectedID == track.id
                            ) {
                                onSelect(track.id)
                            }
                        }

                        if tracks.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: offOption ? "captions.bubble" : "waveform")
                                    .font(.system(size: 25, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.55))
                                Text(offOption ? "No subtitle tracks available" : "No audio tracks available")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.82))
                                Text(offOption ? "This stream did not provide subtitles." : "This stream did not provide alternate audio tracks.")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.55))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 34)
                        }
                    }
                }
                .frame(maxHeight: 420)
            }
            .padding(22)
            .frame(maxWidth: 460, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.leading, 24)
            .padding(.bottom, 28)
        }
    }

    @ViewBuilder
    private func row(title: String, subtitle: String?, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body.weight(selected ? .semibold : .regular))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let subtitle, !subtitle.isEmpty, subtitle != "und" {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.68))
                    }
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.white)
                        .font(.body.weight(.bold))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(selected ? Color.white.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

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
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)

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

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @AppStorage("shinjiAccentHex") private var accentHex = "B64DFF"

    private var accent: Color { Color(hex: accentHex) }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case 0: HomeLibraryView()
                case 1: SearchView()
                case 2: UnifiedLibraryView(kind: .all)
                default: ProfileHubView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            tabBar
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            tabButton("house.fill", "Home", 0)
            tabButton("magnifyingglass", "Search", 1)
            tabButton("rectangle.stack.fill", "Library", 2)
            tabButton("person.crop.circle.fill", "Profile", 3)
        }
        .padding(7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 20, y: 8)
    }

    private func tabButton(_ icon: String, _ title: String, _ index: Int) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.16)) { selectedTab = index }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(selectedTab == index ? .white : .white.opacity(0.55))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background {
                if selectedTab == index {
                    Capsule().fill(accent.opacity(0.22))
                        .overlay(Capsule().stroke(accent.opacity(0.32), lineWidth: 1))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

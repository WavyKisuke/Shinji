import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @AppStorage("shinjiAccentHex") private var accentHex = "B64DFF"

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case 0:
                    HomeLibraryView()
                case 1:
                    LibraryView(kind: .movies)
                case 2:
                    UnifiedLibraryView(kind: .movies)
                default:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            nuvioTabBar
                .padding(.horizontal, 18)
                .padding(.bottom, 8)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private var nuvioTabBar: some View {
        HStack(spacing: 0) {
            tabButton("house.fill", "Home", 0)
            tabButton("magnifyingglass", "Search", 1)
            tabButton("rectangle.stack.fill", "Library", 2)
            tabButton("person.crop.circle.fill", "Profile", 3)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 22, y: 8)
    }

    private func tabButton(_ icon: String, _ title: String, _ index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { selectedTab = index }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(selectedTab == index ? .white : .white.opacity(0.68))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background {
                if selectedTab == index {
                    Capsule().fill(Color.white.opacity(0.10))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

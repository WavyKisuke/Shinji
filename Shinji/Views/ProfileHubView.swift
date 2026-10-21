import SwiftUI

struct ProfileHubView: View {
    @AppStorage("shinjiAccountCreated") private var accountCreated = false
    @AppStorage("shinjiAccountName") private var accountName = ""

    private var accentColor: Color {
        Color(hex: UserDefaults.standard.string(forKey: "shinjiAccentHex") ?? "B64DFF")
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    profileCard
                    settingsCard
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 120)
            }
            .background(Color.black.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    private var profileCard: some View {
        NavigationLink { ProfileAccountView() } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(accentColor.opacity(0.18))
                    .frame(width: 58, height: 58)
                    .overlay {
                        if accountCreated && !accountName.isEmpty {
                            Text(String(accountName.prefix(1)).uppercased())
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(accentColor)
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(accentColor)
                        }
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(accountCreated ? accountName : "Create an account")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(accountCreated ? "Manage your profile" : "Set up your Shinji profile")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.52))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(18)
            .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var settingsCard: some View {
        NavigationLink { SettingsView() } label: {
            HStack(spacing: 14) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .frame(width: 42, height: 42)
                    .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Settings & Add-ons")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Sources, playback and app preferences")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.48))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(16)
            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.07), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

import SwiftUI

struct ProfileHubView: View {
    @AppStorage("shinjiAccountCreated") private var accountCreated = false
    @AppStorage("shinjiAccountName") private var accountName = ""

    private var accentColor: Color {
        Color(hex: UserDefaults.standard.string(forKey: "shinjiAccentHex") ?? "B64DFF")
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ProfileAccountView()
                    } label: {
                        HStack(spacing: 14) {
                            Circle()
                                .fill(accentColor.opacity(0.18))
                                .frame(width: 52, height: 52)
                                .overlay {
                                    if accountCreated && !accountName.isEmpty {
                                        Text(String(accountName.prefix(1)).uppercased())
                                            .font(.title3.bold())
                                            .foregroundStyle(accentColor)
                                    } else {
                                        Image(systemName: "person.fill")
                                            .foregroundStyle(accentColor)
                                    }
                                }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(accountCreated ? accountName : "Create an account")
                                    .font(.headline)
                                Text(accountCreated ? "Manage your profile" : "Set up your Shinji profile")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 5)
                    }
                }

                Section("Shinji") {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings & Add-ons", systemImage: "gearshape.fill")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Profile")
            .tint(accentColor)
        }
        .preferredColorScheme(.dark)
    }
}

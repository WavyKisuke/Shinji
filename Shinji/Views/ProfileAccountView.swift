import SwiftUI

struct ProfileAccountView: View {
    @AppStorage("shinjiAccountCreated") private var accountCreated = false
    @AppStorage("shinjiAccountName") private var accountName = ""
    @AppStorage("shinjiAccountEmail") private var accountEmail = ""
    @State private var name = ""
    @State private var email = ""
    @State private var showingDeleteConfirmation = false

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        email.contains("@") && email.contains(".")
    }

    var body: some View {
        Form {
            if accountCreated {
                Section("Profile") {
                    HStack(spacing: 14) {
                        Circle()
                            .fill(Color.accentColor.opacity(0.2))
                            .frame(width: 56, height: 56)
                            .overlay {
                                Text(String(accountName.prefix(1)).uppercased())
                                    .font(.title2.bold())
                                    .foregroundStyle(Color.accentColor)
                            }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(accountName).font(.headline)
                            Text(accountEmail).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Account") {
                    Button("Sign out", role: .destructive) {
                        accountCreated = false
                        accountName = ""
                        accountEmail = ""
                        name = ""
                        email = ""
                    }
                }

                Section {
                    Text("This is a local Shinji profile. Cloud account sync and server-side authentication are not connected yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Create your Shinji account") {
                    Text("Create a profile to keep your Shinji identity separate from the app settings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    TextField("Name", text: $name)
                        .textContentType(.name)
                        .autocorrectionDisabled()

                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section {
                    Button {
                        accountName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        accountEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        accountCreated = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Create Account").fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!canCreate)
                }
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            name = accountName
            email = accountEmail
        }
    }
}

import SwiftUI
import Foundation

private struct MediaLibrary: Identifiable, Decodable {
    let Id: String
    let Name: String
    var id: String { Id }
}

private struct LibraryResponse: Decodable {
    let Items: [MediaLibrary]?
}

struct MediaServerSettingsView: View {
    @AppStorage("shinji.mediaServer.url") private var savedServerURL = ""
    @AppStorage("shinji.mediaServer.kind") private var savedServerKind = "Jellyfin"
    @AppStorage("shinji.mediaServer.username") private var savedUsername = ""
    @AppStorage("shinji.mediaServer.token") private var savedToken = ""
    @AppStorage("shinji.mediaServer.userID") private var savedUserID = ""

    @State private var serverURL = ""
    @State private var serverKind = "Jellyfin"
    @State private var username = ""
    @State private var password = ""
    @State private var libraries: [MediaLibrary] = []
    @State private var isWorking = false
    @State private var message: String?
    @State private var isConnected = false

    var body: some View {
        Form {
            Section("Server") {
                Picker("Platform", selection: $serverKind) {
                    Text("Jellyfin").tag("Jellyfin")
                    Text("Emby").tag("Emby")
                }
                TextField("Server URL (e.g. https://media.example.com)", text: $serverURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
                Button {
                    Task { await connect() }
                } label: {
                    HStack {
                        if isWorking { ProgressView() }
                        Text(isWorking ? "Connecting…" : "Connect and load libraries")
                    }
                }
                .disabled(isWorking || serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || username.isEmpty || password.isEmpty)
            }

            if isConnected {
                Section("Libraries") {
                    if libraries.isEmpty {
                        Text("Connected, but no libraries were returned for this account.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(libraries) { library in
                            Label(library.Name, systemImage: "folder.fill")
                        }
                    }
                }
                Section {
                    Button("Disconnect", role: .destructive) {
                        savedToken = ""
                        savedUserID = ""
                        savedServerURL = ""
                        savedUsername = ""
                        libraries = []
                        isConnected = false
                        message = "Disconnected from the server."
                    }
                }
            }

            if let message {
                Section("Status") {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(message.lowercased().contains("failed") || message.lowercased().contains("invalid") ? .red : .secondary)
                }
            }

            Section("About connections") {
                Text("Enter your own Jellyfin or Emby server URL. Your password is used only for the sign-in request and is not saved by this screen. The server access token is stored locally on this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Use HTTPS when connecting over the internet. This first version verifies sign-in and lists libraries; library item browsing, resume sync, and playback integration are separate follow-up steps.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Media Servers")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            serverURL = savedServerURL
            serverKind = savedServerKind
            username = savedUsername
            isConnected = !savedToken.isEmpty && !savedUserID.isEmpty
            if isConnected { Task { await loadLibraries() } }
        }
    }

    @MainActor
    private func connect() async {
        guard let baseURL = normalizedBaseURL(serverURL) else {
            message = "Invalid server URL. Include http:// or https:// and a valid host."
            return
        }
        isWorking = true
        defer { isWorking = false }
        message = nil

        do {
            var request = URLRequest(url: baseURL.appendingPathComponent("Users/AuthenticateByName"))
            request.httpMethod = "POST"
            request.timeoutInterval = 20
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("MediaBrowser Client=\"Shinji\", Device=\"iPhone\", DeviceId=\"shinji-ios\", Version=\"0.1.0\"", forHTTPHeaderField: "X-Emby-Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["Username": username, "Pw": password])
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ServerConnectionError.invalidResponse }
            guard (200..<300).contains(http.statusCode) else {
                throw ServerConnectionError.httpStatus(http.statusCode)
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let user = json?["User"] as? [String: Any]
            guard let token = json?["AccessToken"] as? String,
                  let userID = user?["Id"] as? String else {
                throw ServerConnectionError.invalidResponse
            }

            savedServerURL = baseURL.absoluteString
            savedServerKind = serverKind
            savedUsername = username
            savedToken = token
            savedUserID = userID
            password = ""
            isConnected = true
            await loadLibraries()
        } catch {
            isConnected = false
            message = "Connection failed: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func loadLibraries() async {
        guard let baseURL = normalizedBaseURL(savedServerURL),
              !savedToken.isEmpty, !savedUserID.isEmpty else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            var components = URLComponents(url: baseURL.appendingPathComponent("Users/\(savedUserID)/Views"), resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "api_key", value: savedToken)]
            guard let url = components?.url else { throw ServerConnectionError.invalidResponse }
            var request = URLRequest(url: url)
            request.timeoutInterval = 20
            request.setValue("MediaBrowser Client=\"Shinji\", Device=\"iPhone\", DeviceId=\"shinji-ios\", Version=\"0.1.0\"", forHTTPHeaderField: "X-Emby-Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw ServerConnectionError.libraryRequestFailed
            }
            libraries = try JSONDecoder().decode(LibraryResponse.self, from: data).Items ?? []
            message = "Connected to \(savedServerKind). Loaded \(libraries.count) libraries."
        } catch {
            libraries = []
            message = "Signed in, but loading libraries failed: \(error.localizedDescription)"
        }
    }

    private func normalizedBaseURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["https", "http"].contains(scheme),
              url.host != nil else { return nil }
        return url
    }
}

private enum ServerConnectionError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case libraryRequestFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server returned an unexpected sign-in response."
        case .httpStatus(let code):
            return "The server returned HTTP \(code). Check the URL and credentials."
        case .libraryRequestFailed:
            return "The server rejected the library request. Try signing in again."
        }
    }
}

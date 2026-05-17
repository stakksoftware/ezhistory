import SwiftUI
import KeyboardShortcuts
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("refreshIntervalMinutes") private var refreshInterval = 10
    @State private var launchAtLogin = false
    @State private var profiles: [ProfileRecord] = []
    @State private var excludedProfiles: Set<String> = {
        let saved = UserDefaults.standard.stringArray(forKey: "excludedProfiles") ?? []
        return Set(saved)
    }()

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }

            profilesTab
                .tabItem { Label("Profiles", systemImage: "person.2") }

            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 500, height: 400)
        .task {
            profiles = (try? appState.indexStore.allProfiles()) ?? []
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private var generalTab: some View {
        Form {
            Section("Keyboard Shortcut") {
                KeyboardShortcuts.Recorder("Toggle Search Window:", name: .toggleSearch)
            }

            Section("Indexing") {
                Picker("Refresh Interval", selection: $refreshInterval) {
                    Text("5 minutes").tag(5)
                    Text("10 minutes").tag(10)
                    Text("30 minutes").tag(30)
                    Text("1 hour").tag(60)
                }
                .pickerStyle(.menu)

                LabeledContent("Status") {
                    if appState.isIndexing {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Indexing...")
                        }
                    } else {
                        Text("\(appState.profileCount) profiles, \(appState.itemCount) items")
                    }
                }

                Button("Reindex Now") {
                    Task { await appState.reindex() }
                }
                .disabled(appState.isIndexing)
            }

            Section("Startup") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            print("Failed to update login item: \(error)")
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var profilesTab: some View {
        VStack(alignment: .leading) {
            Text("Select which profiles to include in search:")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top)

            List {
                ForEach(Array(profiles.enumerated()), id: \.element.id) { _, profile in
                    let dirName = profile.dirName
                    HStack {
                        Toggle(isOn: Binding(
                            get: { !excludedProfiles.contains(dirName) },
                            set: { included in
                                if included {
                                    excludedProfiles.remove(dirName)
                                } else {
                                    excludedProfiles.insert(dirName)
                                }
                                UserDefaults.standard.set(Array(excludedProfiles), forKey: "excludedProfiles")
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.displayName)
                                    .font(.body)
                                if !profile.accountEmail.isEmpty {
                                    Text(profile.accountEmail)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text(profile.dirName)
                                    .font(.caption2)
                                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                            }
                        }
                    }
                }
            }
        }
    }

    private var aboutTab: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("EzHistory")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 1.0.0")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Search across all your Chrome profiles in one place.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }
}

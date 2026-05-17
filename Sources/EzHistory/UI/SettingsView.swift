import SwiftUI
import KeyboardShortcuts
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("refreshIntervalMinutes") private var refreshInterval = 10
    @AppStorage("safariEnabled") private var safariEnabled = false
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

            browsersTab
                .tabItem { Label("Browsers", systemImage: "globe") }

            profilesTab
                .tabItem { Label("Profiles", systemImage: "person.2") }

            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 450)
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

    private var browsersTab: some View {
        Form {
            Section {
                Text("EzHistory automatically detects and indexes all installed Chromium-based browsers and Firefox.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Detected Browsers") {
                let installedBrowsers = detectInstalledBrowsers()
                ForEach(installedBrowsers, id: \.name) { browser in
                    HStack {
                        Image(systemName: browser.icon)
                            .frame(width: 20)
                        Text(browser.name)
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }

                if installedBrowsers.isEmpty {
                    Text("No supported browsers found")
                        .foregroundColor(.secondary)
                }
            }

            Section("Safari") {
                Toggle(isOn: $safariEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Safari indexing")
                        Text("Requires Full Disk Access in System Settings > Privacy & Security")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: safariEnabled) { _ in
                    Task { await appState.reindex() }
                }

                Button("Open Privacy & Security Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                }
                .font(.caption)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func detectInstalledBrowsers() -> [BrowserDef] {
        let fm = FileManager.default
        let appSupport = BrowserScanner.appSupportBase
        return BrowserDef.chromiumBrowsers.filter { browser in
            fm.fileExists(atPath: appSupport.appendingPathComponent(browser.basePath).path)
        } + (fm.fileExists(atPath: appSupport.appendingPathComponent("Firefox/Profiles").path) ? [BrowserDef.firefox] : [])
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
                    let key = "\(profile.browser):\(profile.dirName)"
                    HStack {
                        Toggle(isOn: Binding(
                            get: { !excludedProfiles.contains(key) },
                            set: { included in
                                if included {
                                    excludedProfiles.remove(key)
                                } else {
                                    excludedProfiles.insert(key)
                                }
                                UserDefaults.standard.set(Array(excludedProfiles), forKey: "excludedProfiles")
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    let icon = BrowserDef.allBrowsers.first { $0.name == profile.browser }?.icon ?? "globe"
                                    Image(systemName: icon)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(profile.browser) / \(profile.displayName)")
                                        .font(.body)
                                }
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

            Text("Version \(AppVersion.current)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Search across all your browser profiles in one place.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if let update = appState.availableUpdate {
                Button {
                    appState.performUpdate()
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Update to v\(update.version)")
                    }
                }
                .disabled(appState.isUpdating)
            }

            Spacer()
        }
    }
}

import SwiftUI
import KeyboardShortcuts
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("refreshIntervalMinutes") private var refreshInterval = 10
    @AppStorage("safariEnabled") private var safariEnabled = false
    @State private var launchAtLogin = false
    @State private var profiles: [ProfileRecord] = []
    @State private var browserStats: [IndexStore.BrowserStats] = []
    @State private var kindStats: [IndexStore.KindStats] = []
    @State private var installedBrowsers: [BrowserDef] = []
    @State private var excludedProfiles: Set<String> = {
        let saved = UserDefaults.standard.stringArray(forKey: "excludedProfiles") ?? []
        return Set(saved)
    }()

    var body: some View {
        TabView {
            dashboardTab
                .tabItem { Label("Dashboard", systemImage: "chart.bar") }

            browsersTab
                .tabItem { Label("Browsers", systemImage: "globe") }

            profilesTab
                .tabItem { Label("Profiles", systemImage: "person.2") }

            generalTab
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .frame(width: 580, height: 520)
        .task { refreshData() }
    }

    private func refreshData() {
        profiles = (try? appState.indexStore.allProfiles()) ?? []
        browserStats = (try? appState.indexStore.browserStats()) ?? []
        kindStats = (try? appState.indexStore.kindStats()) ?? []
        launchAtLogin = SMAppService.mainApp.status == .enabled
        installedBrowsers = detectInstalledBrowsers()
    }

    // MARK: - Dashboard

    private var dashboardTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                overviewCard
                browserBreakdownCard
                dataBreakdownCard
            }
            .padding()
        }
    }

    private var overviewCard: some View {
        GroupBox {
            VStack(spacing: 12) {
                HStack(spacing: 20) {
                    statBox(
                        value: "\(appState.profileCount)",
                        label: "Profiles",
                        icon: "person.2.fill",
                        color: .blue
                    )
                    Divider().frame(height: 40)
                    statBox(
                        value: formatNumber(appState.itemCount),
                        label: "Items Indexed",
                        icon: "doc.text.fill",
                        color: .purple
                    )
                    Divider().frame(height: 40)
                    statBox(
                        value: "\(browserStats.count)",
                        label: "Browsers",
                        icon: "globe",
                        color: .green
                    )
                }
                .padding(.vertical, 8)

                if appState.isIndexing {
                    HStack(spacing: 8) {
                        ProgressView(value: appState.indexingProgress)
                            .progressViewStyle(.linear)
                        Text("\(Int(appState.indexingProgress * 100))%")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                } else if let lastDate = appState.lastIndexDate {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Last indexed \(lastDate.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Reindex Now") {
                            Task {
                                await appState.reindex()
                                refreshData()
                            }
                        }
                        .controlSize(.small)
                        .disabled(appState.isIndexing)
                    }
                }
            }
            .padding(4)
        } label: {
            Label("Overview", systemImage: "chart.bar.fill")
                .font(.headline)
        }
    }

    private var browserBreakdownCard: some View {
        GroupBox {
            if browserStats.isEmpty {
                Text("No data indexed yet. Click Reindex Now above.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(8)
            } else {
                VStack(spacing: 6) {
                    ForEach(browserStats, id: \.browser) { stat in
                        HStack(spacing: 10) {
                            let icon = BrowserDef.allBrowsers.first { $0.name == stat.browser }?.icon ?? "globe"
                            Image(systemName: icon)
                                .frame(width: 20)
                                .foregroundColor(.accentColor)

                            Text(stat.browser)
                                .frame(width: 80, alignment: .leading)

                            ProgressView(
                                value: Double(stat.itemCount),
                                total: Double(max(browserStats.map(\.itemCount).max() ?? 1, 1))
                            )
                            .progressViewStyle(.linear)
                            .tint(browserColor(stat.browser))

                            Text("\(stat.profileCount) profiles")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 70, alignment: .trailing)

                            Text(formatNumber(stat.itemCount))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                                .frame(width: 55, alignment: .trailing)
                        }
                    }
                }
                .padding(4)
            }
        } label: {
            Label("Browsers", systemImage: "globe")
                .font(.headline)
        }
    }

    private var dataBreakdownCard: some View {
        GroupBox {
            if kindStats.isEmpty {
                Text("No data indexed yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(8)
            } else {
                HStack(spacing: 16) {
                    ForEach(kindStats, id: \.kind) { stat in
                        VStack(spacing: 4) {
                            kindIconView(stat.kind)
                                .font(.title3)
                                .foregroundColor(kindColor(stat.kind))
                            Text(formatNumber(stat.count))
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                            Text(stat.kind.capitalized)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 8)
            }
        } label: {
            Label("Data Types", systemImage: "square.grid.2x2")
                .font(.headline)
        }
    }

    // MARK: - Browsers

    private var browsersTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                GroupBox {
                    VStack(spacing: 8) {
                        ForEach(BrowserDef.chromiumBrowsers + [BrowserDef.firefox], id: \.name) { browser in
                            let isInstalled = installedBrowsers.contains(where: { $0.name == browser.name })
                            let stat = browserStats.first { $0.browser == browser.name }

                            HStack(spacing: 10) {
                                Image(systemName: browser.icon)
                                    .font(.title3)
                                    .foregroundColor(isInstalled ? browserColor(browser.name) : .secondary)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(browser.name)
                                        .fontWeight(.medium)
                                    if isInstalled, let stat = stat {
                                        Text("\(stat.profileCount) profile\(stat.profileCount == 1 ? "" : "s"), \(formatNumber(stat.itemCount)) items")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else if isInstalled {
                                        Text("Installed — no data indexed yet")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("Not installed")
                                            .font(.caption)
                                            .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                                    }
                                }

                                Spacer()

                                if isInstalled {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "minus.circle")
                                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                                }
                            }
                            .padding(.vertical, 2)

                            if browser.name != BrowserDef.firefox.name {
                                Divider()
                            }
                        }
                    }
                    .padding(4)
                } label: {
                    Label("Auto-Detected Browsers", systemImage: "magnifyingglass")
                        .font(.headline)
                }

                safariCard

                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Chromium-based browsers (Chrome, Edge, Brave, Arc, Vivaldi, Opera, Chromium) and Firefox are automatically detected and indexed when installed.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Safari requires Full Disk Access — enable it above, then grant the permission in System Settings.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(4)
                } label: {
                    Label("How It Works", systemImage: "info.circle")
                        .font(.headline)
                }
            }
            .padding()
        }
    }

    private var safariCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "safari")
                        .font(.title3)
                        .foregroundColor(safariEnabled ? .blue : .secondary)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Safari")
                            .fontWeight(.medium)
                        if safariEnabled {
                            let stat = browserStats.first { $0.browser == "Safari" }
                            if let stat = stat {
                                Text("\(formatNumber(stat.itemCount)) items indexed")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Enabled — will index on next scan")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("Disabled — requires Full Disk Access")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Toggle("", isOn: $safariEnabled)
                        .labelsHidden()
                        .onChange(of: safariEnabled) { _ in
                            Task {
                                await appState.reindex()
                                refreshData()
                            }
                        }
                }

                if safariEnabled {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("EzHistory needs Full Disk Access to read Safari data.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                        } label: {
                            Text("Open Settings")
                                .font(.caption)
                        }
                        .controlSize(.small)
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            .padding(4)
        } label: {
            HStack {
                Label("Safari", systemImage: "safari")
                    .font(.headline)
                Spacer()
                if safariEnabled {
                    Text("Enabled")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Profiles

    private var profilesTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Manage which profiles are included in search results.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(profiles.count) total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            List {
                let grouped = Dictionary(grouping: profiles) { $0.browser }
                let sortedBrowsers = grouped.keys.sorted()

                ForEach(sortedBrowsers, id: \.self) { browser in
                    Section {
                        ForEach(grouped[browser] ?? [], id: \.id) { profile in
                            profileRow(profile)
                        }
                    } header: {
                        HStack(spacing: 6) {
                            let icon = BrowserDef.allBrowsers.first { $0.name == browser }?.icon ?? "globe"
                            Image(systemName: icon)
                                .foregroundColor(browserColor(browser))
                            Text(browser)
                                .fontWeight(.semibold)
                            Text("(\(grouped[browser]?.count ?? 0))")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }

    private func profileRow(_ profile: ProfileRecord) -> some View {
        let key = "\(profile.browser):\(profile.dirName)"
        return Toggle(isOn: Binding(
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
                Text(profile.displayName)
                    .fontWeight(.medium)
                HStack(spacing: 8) {
                    if !profile.accountEmail.isEmpty {
                        Label(profile.accountEmail, systemImage: "envelope")
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

    // MARK: - General Settings

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

            Section("About") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("EzHistory")
                            .font(.headline)
                        Text("Version \(AppVersion.current)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Search across all your browser profiles in one place.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32))
                        .foregroundColor(.accentColor)
                }

                if let update = appState.availableUpdate {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.accentColor)
                        Text("Version \(update.version) available")
                        Spacer()
                        Button("Update Now") {
                            appState.performUpdate()
                        }
                        .disabled(appState.isUpdating)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Helpers

    private func detectInstalledBrowsers() -> [BrowserDef] {
        let fm = FileManager.default
        let appSupport = BrowserScanner.appSupportBase
        var result = BrowserDef.chromiumBrowsers.filter { browser in
            fm.fileExists(atPath: appSupport.appendingPathComponent(browser.basePath).path)
        }
        if fm.fileExists(atPath: appSupport.appendingPathComponent("Firefox/Profiles").path) {
            result.append(BrowserDef.firefox)
        }
        return result
    }

    private func statBox(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }

    private func browserColor(_ name: String) -> Color {
        switch name {
        case "Chrome": return .blue
        case "Edge": return .cyan
        case "Brave": return .orange
        case "Arc": return .purple
        case "Vivaldi": return .red
        case "Opera": return .red
        case "Firefox": return .orange
        case "Safari": return .blue
        default: return .gray
        }
    }

    private func kindColor(_ kind: String) -> Color {
        switch kind {
        case "history": return .blue
        case "bookmark": return .orange
        case "download": return .green
        case "login": return .red
        case "autofill": return .purple
        default: return .gray
        }
    }

    @ViewBuilder
    private func kindIconView(_ kind: String) -> some View {
        switch kind {
        case "history": Image(systemName: "clock.fill")
        case "bookmark": Image(systemName: "bookmark.fill")
        case "download": Image(systemName: "arrow.down.circle.fill")
        case "login": Image(systemName: "key.fill")
        case "autofill": Image(systemName: "person.text.rectangle.fill")
        default: Image(systemName: "doc.fill")
        }
    }
}

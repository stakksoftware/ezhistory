import Foundation

struct BrowserDef {
    let name: String
    let basePath: String
    let icon: String
    let bundleId: String
    let isChromium: Bool

    static let allBrowsers: [BrowserDef] = chromiumBrowsers + [firefox, safari]

    static let chromiumBrowsers: [BrowserDef] = [
        .init(name: "Chrome", basePath: "Google/Chrome", icon: "globe", bundleId: "com.google.Chrome", isChromium: true),
        .init(name: "Edge", basePath: "Microsoft Edge", icon: "globe.americas", bundleId: "com.microsoft.edgemac", isChromium: true),
        .init(name: "Brave", basePath: "BraveSoftware/Brave-Browser", icon: "shield.lefthalf.filled", bundleId: "com.brave.Browser", isChromium: true),
        .init(name: "Arc", basePath: "Arc/User Data", icon: "circle.hexagongrid", bundleId: "company.thebrowser.Browser", isChromium: true),
        .init(name: "Vivaldi", basePath: "Vivaldi", icon: "paintpalette", bundleId: "com.vivaldi.Vivaldi", isChromium: true),
        .init(name: "Opera", basePath: "com.operasoftware.Opera", icon: "theatermasks", bundleId: "com.operasoftware.Opera", isChromium: true),
        .init(name: "Chromium", basePath: "Chromium", icon: "globe", bundleId: "org.chromium.Chromium", isChromium: true),
    ]

    static let firefox = BrowserDef(name: "Firefox", basePath: "Firefox", icon: "flame", bundleId: "org.mozilla.firefox", isChromium: false)
    static let safari = BrowserDef(name: "Safari", basePath: "../Safari", icon: "safari", bundleId: "com.apple.Safari", isChromium: false)
}

struct BrowserProfile {
    let browser: String
    let browserDef: BrowserDef
    let dirName: String
    let displayName: String
    let accountEmail: String
    let avatarIcon: String
    let themeColor: Int
    let path: URL
}

// Keep typealias for backward compatibility with importers
typealias ChromeProfile = BrowserProfile

struct BrowserScanner {
    static let appSupportBase: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support")
    }()

    static let safariBase: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Safari")
    }()

    func scan() -> [BrowserProfile] {
        var allProfiles: [BrowserProfile] = []

        for browserDef in BrowserDef.chromiumBrowsers {
            let basePath = Self.appSupportBase.appendingPathComponent(browserDef.basePath)
            allProfiles.append(contentsOf: scanChromiumBrowser(browserDef: browserDef, basePath: basePath))
        }

        allProfiles.append(contentsOf: scanFirefox())
        allProfiles.append(contentsOf: scanSafari())

        return allProfiles
    }

    // MARK: - Chromium browsers

    private func scanChromiumBrowser(browserDef: BrowserDef, basePath: URL) -> [BrowserProfile] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: basePath.path) else { return [] }

        let localStateInfo = parseLocalState(at: basePath.appendingPathComponent("Local State"))
        var profiles: [BrowserProfile] = []

        guard let contents = try? fm.contentsOfDirectory(at: basePath, includingPropertiesForKeys: nil) else {
            return []
        }

        for item in contents {
            let dirName = item.lastPathComponent
            guard dirName == "Default" || dirName.hasPrefix("Profile ") else { continue }

            let historyFile = item.appendingPathComponent("History")
            guard fm.fileExists(atPath: historyFile.path) else { continue }

            let cached = localStateInfo[dirName]
            let prefs = parsePreferences(at: item.appendingPathComponent("Preferences"))

            profiles.append(BrowserProfile(
                browser: browserDef.name,
                browserDef: browserDef,
                dirName: dirName,
                displayName: cached?.name ?? prefs.name ?? dirName,
                accountEmail: cached?.email ?? prefs.email ?? "",
                avatarIcon: cached?.avatarIcon ?? "",
                themeColor: prefs.themeColor,
                path: item
            ))
        }

        if profiles.isEmpty {
            let defaultHistory = basePath.appendingPathComponent("History")
            if fm.fileExists(atPath: defaultHistory.path) {
                profiles.append(BrowserProfile(
                    browser: browserDef.name,
                    browserDef: browserDef,
                    dirName: "Default",
                    displayName: "Default",
                    accountEmail: "",
                    avatarIcon: "",
                    themeColor: 0,
                    path: basePath
                ))
            }
        }

        return profiles.sorted { $0.dirName.localizedStandardCompare($1.dirName) == .orderedAscending }
    }

    // MARK: - Firefox

    func scanFirefox() -> [BrowserProfile] {
        let fm = FileManager.default
        let firefoxBase = Self.appSupportBase.appendingPathComponent("Firefox")
        let profilesDir = firefoxBase.appendingPathComponent("Profiles")

        guard fm.fileExists(atPath: profilesDir.path) else { return [] }

        let profileNames = parseFirefoxProfilesIni(at: firefoxBase.appendingPathComponent("profiles.ini"))

        var profiles: [BrowserProfile] = []

        guard let contents = try? fm.contentsOfDirectory(at: profilesDir, includingPropertiesForKeys: nil) else {
            return []
        }

        for item in contents {
            let dirName = item.lastPathComponent
            let placesFile = item.appendingPathComponent("places.sqlite")
            guard fm.fileExists(atPath: placesFile.path) else { continue }

            let displayName = profileNames[dirName] ?? dirName

            profiles.append(BrowserProfile(
                browser: "Firefox",
                browserDef: BrowserDef.firefox,
                dirName: dirName,
                displayName: displayName,
                accountEmail: "",
                avatarIcon: "",
                themeColor: 0,
                path: item
            ))
        }

        return profiles
    }

    private func parseFirefoxProfilesIni(at url: URL) -> [String: String] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [:] }

        var result: [String: String] = [:]
        var currentName: String?
        var currentPath: String?

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") {
                if let path = currentPath, let name = currentName {
                    let dirName = (path as NSString).lastPathComponent
                    result[dirName] = name
                }
                currentName = nil
                currentPath = nil
            } else if trimmed.hasPrefix("Name=") {
                currentName = String(trimmed.dropFirst(5))
            } else if trimmed.hasPrefix("Path=") {
                currentPath = String(trimmed.dropFirst(5))
            }
        }
        if let path = currentPath, let name = currentName {
            let dirName = (path as NSString).lastPathComponent
            result[dirName] = name
        }
        return result
    }

    // MARK: - Safari

    func scanSafari() -> [BrowserProfile] {
        let fm = FileManager.default
        let safariDir = Self.safariBase
        let historyFile = safariDir.appendingPathComponent("History.db")

        guard fm.fileExists(atPath: historyFile.path) else { return [] }

        let enabled = UserDefaults.standard.bool(forKey: "safariEnabled")
        guard enabled else { return [] }

        return [BrowserProfile(
            browser: "Safari",
            browserDef: BrowserDef.safari,
            dirName: "Default",
            displayName: "Safari",
            accountEmail: "",
            avatarIcon: "",
            themeColor: 0,
            path: safariDir
        )]
    }

    // MARK: - Chromium Local State / Preferences parsing

    private struct CachedProfileInfo {
        let name: String
        let email: String
        let avatarIcon: String
    }

    private func parseLocalState(at url: URL) -> [String: CachedProfileInfo] {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profile = json["profile"] as? [String: Any],
              let infoCache = profile["info_cache"] as? [String: Any] else {
            return [:]
        }

        var result: [String: CachedProfileInfo] = [:]
        for (dirName, value) in infoCache {
            guard let info = value as? [String: Any] else { continue }
            let name = info["name"] as? String ?? dirName
            let email = info["user_name"] as? String ?? ""
            let avatar = info["avatar_icon"] as? String ?? ""
            result[dirName] = CachedProfileInfo(name: name, email: email, avatarIcon: avatar)
        }
        return result
    }

    private struct PrefsInfo {
        let name: String?
        let email: String?
        let themeColor: Int
    }

    private func parsePreferences(at url: URL) -> PrefsInfo {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return PrefsInfo(name: nil, email: nil, themeColor: 0)
        }

        let profileSection = json["profile"] as? [String: Any]
        let name = profileSection?["name"] as? String

        let accountInfo = json["account_info"] as? [[String: Any]]
        let email = accountInfo?.first?["email"] as? String

        var themeColor = 0
        if let themeSection = json["browser"] as? [String: Any],
           let colorMixer = themeSection["colour_mixer_model"] as? [String: Any],
           let color = colorMixer["colour"] as? Int {
            themeColor = color
        } else if let profileColor = profileSection?["avatar_bubble_color"] as? Int {
            themeColor = profileColor
        }

        return PrefsInfo(name: name, email: email, themeColor: themeColor)
    }
}

// Keep old name as typealias for backward compatibility
typealias ChromeProfileScanner = BrowserScanner

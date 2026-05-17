import Foundation

struct ChromeProfile {
    let dirName: String
    let displayName: String
    let accountEmail: String
    let avatarIcon: String
    let themeColor: Int
    let path: URL
}

struct ChromeProfileScanner {
    static let chromeBasePath: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Google/Chrome")
    }()

    func scan() -> [ChromeProfile] {
        let fm = FileManager.default
        let basePath = Self.chromeBasePath

        guard fm.fileExists(atPath: basePath.path) else { return [] }

        let localStateInfo = parseLocalState(at: basePath.appendingPathComponent("Local State"))

        var profiles: [ChromeProfile] = []

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

            let profile = ChromeProfile(
                dirName: dirName,
                displayName: cached?.name ?? prefs.name ?? dirName,
                accountEmail: cached?.email ?? prefs.email ?? "",
                avatarIcon: cached?.avatarIcon ?? "",
                themeColor: prefs.themeColor,
                path: item
            )
            profiles.append(profile)
        }

        return profiles.sorted { $0.dirName.localizedStandardCompare($1.dirName) == .orderedAscending }
    }

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

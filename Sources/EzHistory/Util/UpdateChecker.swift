import Foundation
import AppKit

struct AppVersion {
    static let current = "1.1.0"
    static let repo = "stakksoftware/ezhistory"
}

struct UpdateInfo {
    let version: String
    let downloadURL: String
}

final class UpdateChecker {
    private static let lastCheckKey = "lastUpdateCheckDate"
    private static let checkInterval: TimeInterval = 86400

    static func checkForUpdate() async -> UpdateInfo? {
        let now = Date()
        let lastCheck = UserDefaults.standard.object(forKey: lastCheckKey) as? Date ?? .distantPast
        if now.timeIntervalSince(lastCheck) < checkInterval { return nil }

        UserDefaults.standard.set(now, forKey: lastCheckKey)

        let urlString = "https://api.github.com/repos/\(AppVersion.repo)/releases/latest"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String,
                  let assets = json["assets"] as? [[String: Any]] else { return nil }

            let remoteVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

            guard isNewer(remote: remoteVersion, current: AppVersion.current) else { return nil }

            let downloadURL = assets.first.flatMap { $0["browser_download_url"] as? String } ?? ""
            guard !downloadURL.isEmpty else { return nil }

            return UpdateInfo(version: remoteVersion, downloadURL: downloadURL)
        } catch {
            return nil
        }
    }

    static func performUpdate(from downloadURL: String) async -> Bool {
        guard let url = URL(string: downloadURL) else { return false }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return false }

            let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("ezhistory-update-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tmpDir) }

            let zipPath = tmpDir.appendingPathComponent("EzHistory.zip")
            try data.write(to: zipPath)

            let unzipTask = Process()
            unzipTask.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            unzipTask.arguments = ["-x", "-k", zipPath.path, tmpDir.path]
            try unzipTask.run()
            unzipTask.waitUntilExit()
            guard unzipTask.terminationStatus == 0 else { return false }

            let sourceApp = tmpDir.appendingPathComponent("EzHistory.app")
            guard FileManager.default.fileExists(atPath: sourceApp.path) else { return false }

            let destApp = URL(fileURLWithPath: "/Applications/EzHistory.app")
            try? FileManager.default.removeItem(at: destApp)
            try FileManager.default.copyItem(at: sourceApp, to: destApp)

            let codesign = Process()
            codesign.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
            codesign.arguments = ["--force", "--deep", "--sign", "-", destApp.path]
            try codesign.run()
            codesign.waitUntilExit()

            let xattr = Process()
            xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
            xattr.arguments = ["-dr", "com.apple.quarantine", destApp.path]
            try? xattr.run()
            xattr.waitUntilExit()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let relaunch = Process()
                relaunch.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                relaunch.arguments = [destApp.path]
                try? relaunch.run()
                NSApp.terminate(nil)
            }

            return true
        } catch {
            print("Update failed: \(error)")
            return false
        }
    }

    private static func isNewer(remote: String, current: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(remoteParts.count, currentParts.count) {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if r > c { return true }
            if r < c { return false }
        }
        return false
    }
}

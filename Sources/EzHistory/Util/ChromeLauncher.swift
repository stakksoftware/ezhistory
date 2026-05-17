import Foundation
import AppKit

enum ChromeLauncher {
    /// Opens a URL in a specific browser profile.
    static func openURL(_ urlString: String, inProfile profileDirName: String, browser: String = "Chrome") {
        let browserDef = BrowserDef.allBrowsers.first { $0.name == browser }

        if let browserDef = browserDef, browserDef.isChromium {
            openChromiumURL(urlString, profileDir: profileDirName, bundleId: browserDef.bundleId)
        } else if browser == "Firefox" {
            openFirefoxURL(urlString, profileName: profileDirName)
        } else {
            openGenericURL(urlString)
        }
    }

    private static func openChromiumURL(_ urlString: String, profileDir: String, bundleId: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = [
            "-b", bundleId,
            "--args",
            "--profile-directory=\(profileDir)",
            urlString
        ]
        try? task.run()
    }

    private static func openFirefoxURL(_ urlString: String, profileName: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = [
            "-b", BrowserDef.firefox.bundleId,
            "--args",
            "-P", profileName,
            "-url", urlString
        ]
        try? task.run()
    }

    private static func openGenericURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    /// Opens a URL in the default browser.
    static func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    static func copyURL(_ urlString: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(urlString, forType: .string)
    }

    static func revealInFinder(_ path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

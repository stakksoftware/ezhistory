import Foundation
import AppKit

enum ChromeLauncher {
    /// Opens a URL in a specific Chrome profile.
    /// `profileDirName` must be the directory name like "Profile 11", not the display name.
    static func openURL(_ urlString: String, inProfile profileDirName: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = [
            "-na", "Google Chrome",
            "--args",
            "--profile-directory=\(profileDirName)",
            urlString
        ]

        try? task.run()
    }

    /// Opens a URL in the default Chrome profile.
    static func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    /// Copies a URL string to the clipboard.
    static func copyURL(_ urlString: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(urlString, forType: .string)
    }

    /// Reveals a file at the given path in Finder.
    static func revealInFinder(_ path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

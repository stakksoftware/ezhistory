import Foundation

enum SafeFileCopy {
    private static let tempRoot: URL = {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ezhistory-copies")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    /// Copies a Chrome SQLite file to a temp location so we can read it
    /// while Chrome holds the WAL lock on the original.
    static func copy(source: URL) throws -> URL {
        let fm = FileManager.default
        let uuid = UUID().uuidString
        let destDir = tempRoot.appendingPathComponent(uuid)
        try fm.createDirectory(at: destDir, withIntermediateDirectories: true)

        let dest = destDir.appendingPathComponent(source.lastPathComponent)
        try fm.copyItem(at: source, to: dest)
        return dest
    }

    static func cleanup(tempFile: URL) {
        let dir = tempFile.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: dir)
    }

    /// Returns the modification date of a file, or nil if it doesn't exist.
    static func modificationDate(of url: URL) -> Date? {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attrs?[.modificationDate] as? Date
    }
}

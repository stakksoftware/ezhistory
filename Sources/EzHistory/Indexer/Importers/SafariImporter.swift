import Foundation
import GRDB

struct SafariImporter {
    let store: IndexStore

    /// Core Data epoch: seconds since 2001-01-01 00:00:00 UTC
    private static let coreDataEpochOffset: TimeInterval = 978307200

    static func coreDataTimestampToUnix(_ coreDataTs: Double) -> Int64 {
        Int64(coreDataTs + coreDataEpochOffset)
    }

    func importHistory(profile: BrowserProfile, profileId: Int64) throws {
        let historyPath = profile.path.appendingPathComponent("History.db")
        guard FileManager.default.fileExists(atPath: historyPath.path) else { return }

        let meta = try store.getMeta(profileDir: "Safari-Default", sourceFile: "safari-history")
        let sourceMod = SafeFileCopy.modificationDate(of: historyPath)?.timeIntervalSince1970 ?? 0
        if let meta = meta, meta.lastModified >= sourceMod { return }

        let tempFile = try SafeFileCopy.copy(source: historyPath)
        defer { SafeFileCopy.cleanup(tempFile: tempFile) }

        var config = GRDB.Configuration()
        config.readonly = true

        let sourceDb: DatabaseQueue
        do {
            sourceDb = try DatabaseQueue(path: tempFile.path, configuration: config)
        } catch {
            print("Safari History.db requires Full Disk Access: \(error)")
            return
        }

        var items: [ItemRecord] = []

        try sourceDb.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT hi.url, hv.title, hi.visit_count, hv.visit_time
                FROM history_items hi
                JOIN history_visits hv ON hv.history_item = hi.id
                WHERE hv.visit_time IS NOT NULL
                ORDER BY hv.visit_time DESC
                LIMIT 50000
            """)

            for row in rows {
                let visitTime: Double = row["visit_time"] ?? 0
                let unixTs = Self.coreDataTimestampToUnix(visitTime)

                items.append(ItemRecord(
                    profileId: profileId,
                    kind: "history",
                    url: row["url"] ?? "",
                    title: row["title"] ?? "",
                    timestamp: unixTs,
                    visitCount: row["visit_count"]
                ))
            }
        }

        if !items.isEmpty { try store.upsertItems(items) }

        try store.setMeta(IndexMeta(
            profileDirName: "Safari-Default",
            sourceFile: "safari-history",
            lastModified: sourceMod,
            lastVisitTime: 0
        ))
    }

    func importBookmarks(profile: BrowserProfile, profileId: Int64) throws {
        let bookmarksPath = profile.path.appendingPathComponent("Bookmarks.plist")
        guard FileManager.default.fileExists(atPath: bookmarksPath.path) else { return }

        let meta = try store.getMeta(profileDir: "Safari-Default", sourceFile: "safari-bookmarks")
        let sourceMod = SafeFileCopy.modificationDate(of: bookmarksPath)?.timeIntervalSince1970 ?? 0
        if let meta = meta, meta.lastModified >= sourceMod { return }

        guard let data = try? Data(contentsOf: bookmarksPath),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return
        }

        var items: [ItemRecord] = []
        flattenSafariBookmarks(node: plist, path: "", profileId: profileId, items: &items)

        if !items.isEmpty { try store.upsertItems(items) }

        try store.setMeta(IndexMeta(
            profileDirName: "Safari-Default",
            sourceFile: "safari-bookmarks",
            lastModified: sourceMod,
            lastVisitTime: 0
        ))
    }

    private func flattenSafariBookmarks(node: [String: Any], path: String, profileId: Int64, items: inout [ItemRecord]) {
        let type = node["WebBookmarkType"] as? String ?? ""

        if type == "WebBookmarkTypeLeaf",
           let urlString = node["URLString"] as? String {
            let title = (node["URIDictionary"] as? [String: Any])?["title"] as? String ?? urlString

            items.append(ItemRecord(
                profileId: profileId,
                kind: "bookmark",
                url: urlString,
                title: title,
                timestamp: Int64(Date().timeIntervalSince1970)
            ))
        }

        if let children = node["Children"] as? [[String: Any]] {
            let folderTitle = node["Title"] as? String ?? ""
            let childPath = path.isEmpty ? folderTitle : "\(path)/\(folderTitle)"
            for child in children {
                flattenSafariBookmarks(node: child, path: childPath, profileId: profileId, items: &items)
            }
        }
    }
}

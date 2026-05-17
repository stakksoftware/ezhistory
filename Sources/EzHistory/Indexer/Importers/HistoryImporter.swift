import Foundation
import GRDB

struct HistoryImporter {
    let store: IndexStore

    /// Chrome timestamps: microseconds since 1601-01-01 UTC
    private static let chromeEpochOffset: Int64 = 11_644_473_600

    static func chromeTimestampToUnix(_ chromeTs: Int64) -> Int64 {
        (chromeTs / 1_000_000) - chromeEpochOffset
    }

    func importHistory(profile: ChromeProfile, profileId: Int64) throws {
        let historyPath = profile.path.appendingPathComponent("History")
        guard FileManager.default.fileExists(atPath: historyPath.path) else { return }

        let meta = try store.getMeta(profileDir: profile.dirName, sourceFile: "History")
        let sourceMod = SafeFileCopy.modificationDate(of: historyPath)?.timeIntervalSince1970 ?? 0

        if let meta = meta, meta.lastModified >= sourceMod {
            return
        }

        let tempFile = try SafeFileCopy.copy(source: historyPath)
        defer { SafeFileCopy.cleanup(tempFile: tempFile) }

        let lastVisitTime = meta?.lastVisitTime ?? 0

        var config = GRDB.Configuration()
        config.readonly = true
        let sourceDb = try DatabaseQueue(path: tempFile.path, configuration: config)

        var maxVisitTime: Int64 = lastVisitTime
        var items: [ItemRecord] = []

        try sourceDb.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT u.url, u.title, u.visit_count, u.last_visit_time
                FROM urls u
                WHERE u.last_visit_time > ?
                ORDER BY u.last_visit_time DESC
            """, arguments: [lastVisitTime])

            for row in rows {
                let chromeTs: Int64 = row["last_visit_time"]
                let unixTs = Self.chromeTimestampToUnix(chromeTs)

                items.append(ItemRecord(
                    profileId: profileId,
                    kind: "history",
                    url: row["url"],
                    title: row["title"] ?? "",
                    timestamp: unixTs,
                    visitCount: row["visit_count"]
                ))

                maxVisitTime = max(maxVisitTime, chromeTs)
            }
        }

        if !items.isEmpty {
            try store.upsertItems(items)
        }

        try store.setMeta(IndexMeta(
            profileDirName: profile.dirName,
            sourceFile: "History",
            lastModified: sourceMod,
            lastVisitTime: maxVisitTime
        ))
    }

    func importDownloads(profile: ChromeProfile, profileId: Int64) throws {
        let historyPath = profile.path.appendingPathComponent("History")
        guard FileManager.default.fileExists(atPath: historyPath.path) else { return }

        let meta = try store.getMeta(profileDir: profile.dirName, sourceFile: "Downloads")
        let sourceMod = SafeFileCopy.modificationDate(of: historyPath)?.timeIntervalSince1970 ?? 0

        if let meta = meta, meta.lastModified >= sourceMod {
            return
        }

        let tempFile = try SafeFileCopy.copy(source: historyPath)
        defer { SafeFileCopy.cleanup(tempFile: tempFile) }

        var config = GRDB.Configuration()
        config.readonly = true
        let sourceDb = try DatabaseQueue(path: tempFile.path, configuration: config)

        var items: [ItemRecord] = []

        try sourceDb.read { db in
            let tableExists = try Bool.fetchOne(db, sql: """
                SELECT COUNT(*) > 0 FROM sqlite_master WHERE type='table' AND name='downloads'
            """) ?? false

            guard tableExists else { return }

            let rows = try Row.fetchAll(db, sql: """
                SELECT d.id, d.target_path, d.start_time, d.total_bytes, d.tab_url,
                       duc.url as source_url
                FROM downloads d
                LEFT JOIN downloads_url_chains duc ON duc.id = d.id AND duc.chain_index = 0
                ORDER BY d.start_time DESC
            """)

            for row in rows {
                let chromeTs: Int64 = row["start_time"]
                let unixTs = Self.chromeTimestampToUnix(chromeTs)
                let targetPath: String = row["target_path"] ?? ""
                let sourceURL: String = row["source_url"] ?? row["tab_url"] ?? ""
                let filename = (targetPath as NSString).lastPathComponent
                let totalBytes: Int64? = row["total_bytes"]

                let extra: [String: Any] = [
                    "filename": filename,
                    "targetPath": targetPath,
                    "totalBytes": totalBytes ?? 0
                ]
                let extraJson: String? = (try? JSONSerialization.data(withJSONObject: extra))
                    .flatMap { String(data: $0, encoding: .utf8) }

                items.append(ItemRecord(
                    profileId: profileId,
                    kind: "download",
                    url: sourceURL,
                    title: filename,
                    timestamp: unixTs,
                    extraJson: extraJson
                ))
            }
        }

        if !items.isEmpty {
            try store.upsertItems(items)
        }

        try store.setMeta(IndexMeta(
            profileDirName: profile.dirName,
            sourceFile: "Downloads",
            lastModified: sourceMod,
            lastVisitTime: 0
        ))
    }
}

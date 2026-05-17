import Foundation
import GRDB

struct LoginsImporter {
    let store: IndexStore

    func importLogins(profile: ChromeProfile, profileId: Int64) throws {
        let loginDataPath = profile.path.appendingPathComponent("Login Data")
        guard FileManager.default.fileExists(atPath: loginDataPath.path) else { return }

        let meta = try store.getMeta(profileDir: profile.dirName, sourceFile: "LoginData")
        let sourceMod = SafeFileCopy.modificationDate(of: loginDataPath)?.timeIntervalSince1970 ?? 0

        if let meta = meta, meta.lastModified >= sourceMod {
            return
        }

        let tempFile = try SafeFileCopy.copy(source: loginDataPath)
        defer { SafeFileCopy.cleanup(tempFile: tempFile) }

        var config = GRDB.Configuration()
        config.readonly = true
        let sourceDb = try DatabaseQueue(path: tempFile.path, configuration: config)

        var items: [ItemRecord] = []

        try sourceDb.read { db in
            let tableExists = try Bool.fetchOne(db, sql: """
                SELECT COUNT(*) > 0 FROM sqlite_master WHERE type='table' AND name='logins'
            """) ?? false

            guard tableExists else { return }

            let rows = try Row.fetchAll(db, sql: """
                SELECT origin_url, username_value, date_created, date_last_used,
                       signon_realm, times_used
                FROM logins
                WHERE blacklisted_by_user = 0
                ORDER BY date_last_used DESC
            """)

            for row in rows {
                let originURL: String = row["origin_url"] ?? ""
                let username: String = row["username_value"] ?? ""
                let dateCreated: Int64 = row["date_created"] ?? 0
                let dateLastUsed: Int64 = row["date_last_used"] ?? 0
                let signonRealm: String = row["signon_realm"] ?? ""
                let timesUsed: Int = row["times_used"] ?? 0

                let ts = HistoryImporter.chromeTimestampToUnix(
                    dateLastUsed > 0 ? dateLastUsed : dateCreated
                )

                let extra: [String: Any] = [
                    "signonRealm": signonRealm,
                    "timesUsed": timesUsed,
                    "dateCreated": HistoryImporter.chromeTimestampToUnix(dateCreated)
                ]
                let extraJson: String? = (try? JSONSerialization.data(withJSONObject: extra))
                    .flatMap { String(data: $0, encoding: .utf8) }

                items.append(ItemRecord(
                    profileId: profileId,
                    kind: "login",
                    url: originURL,
                    title: signonRealm,
                    username: username.isEmpty ? nil : username,
                    timestamp: ts,
                    extraJson: extraJson
                ))
            }
        }

        if !items.isEmpty {
            try store.upsertItems(items)
        }

        try store.setMeta(IndexMeta(
            profileDirName: profile.dirName,
            sourceFile: "LoginData",
            lastModified: sourceMod,
            lastVisitTime: 0
        ))
    }
}

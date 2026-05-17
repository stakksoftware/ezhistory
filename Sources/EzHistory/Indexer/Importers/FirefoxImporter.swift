import Foundation
import GRDB

struct FirefoxImporter {
    let store: IndexStore

    func importHistory(profile: BrowserProfile, profileId: Int64) throws {
        let placesPath = profile.path.appendingPathComponent("places.sqlite")
        guard FileManager.default.fileExists(atPath: placesPath.path) else { return }

        let meta = try store.getMeta(profileDir: profile.dirName, sourceFile: "firefox-places")
        let sourceMod = SafeFileCopy.modificationDate(of: placesPath)?.timeIntervalSince1970 ?? 0
        if let meta = meta, meta.lastModified >= sourceMod { return }

        let tempFile = try SafeFileCopy.copy(source: placesPath)
        defer { SafeFileCopy.cleanup(tempFile: tempFile) }

        var config = GRDB.Configuration()
        config.readonly = true
        let sourceDb = try DatabaseQueue(path: tempFile.path, configuration: config)

        let lastVisitTime = meta?.lastVisitTime ?? 0
        var maxVisitTime: Int64 = lastVisitTime
        var items: [ItemRecord] = []

        try sourceDb.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT p.url, p.title, p.visit_count, p.last_visit_date
                FROM moz_places p
                WHERE p.last_visit_date > ? AND p.hidden = 0
                ORDER BY p.last_visit_date DESC
            """, arguments: [lastVisitTime])

            for row in rows {
                let mozTs: Int64 = row["last_visit_date"] ?? 0
                let unixTs = mozTs / 1_000_000

                items.append(ItemRecord(
                    profileId: profileId,
                    kind: "history",
                    url: row["url"] ?? "",
                    title: row["title"] ?? "",
                    timestamp: unixTs,
                    visitCount: row["visit_count"]
                ))
                maxVisitTime = max(maxVisitTime, mozTs)
            }
        }

        if !items.isEmpty { try store.upsertItems(items) }

        try store.setMeta(IndexMeta(
            profileDirName: profile.dirName,
            sourceFile: "firefox-places",
            lastModified: sourceMod,
            lastVisitTime: maxVisitTime
        ))
    }

    func importBookmarks(profile: BrowserProfile, profileId: Int64) throws {
        let placesPath = profile.path.appendingPathComponent("places.sqlite")
        guard FileManager.default.fileExists(atPath: placesPath.path) else { return }

        let meta = try store.getMeta(profileDir: profile.dirName, sourceFile: "firefox-bookmarks")
        let sourceMod = SafeFileCopy.modificationDate(of: placesPath)?.timeIntervalSince1970 ?? 0
        if let meta = meta, meta.lastModified >= sourceMod { return }

        let tempFile = try SafeFileCopy.copy(source: placesPath)
        defer { SafeFileCopy.cleanup(tempFile: tempFile) }

        var config = GRDB.Configuration()
        config.readonly = true
        let sourceDb = try DatabaseQueue(path: tempFile.path, configuration: config)

        var items: [ItemRecord] = []

        try sourceDb.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT b.title as btitle, p.url, b.dateAdded
                FROM moz_bookmarks b
                JOIN moz_places p ON b.fk = p.id
                WHERE b.type = 1 AND p.url NOT LIKE 'place:%'
            """)

            for row in rows {
                let dateAdded: Int64 = row["dateAdded"] ?? 0
                let unixTs = dateAdded / 1_000_000

                items.append(ItemRecord(
                    profileId: profileId,
                    kind: "bookmark",
                    url: row["url"] ?? "",
                    title: row["btitle"] ?? "",
                    timestamp: unixTs
                ))
            }
        }

        if !items.isEmpty { try store.upsertItems(items) }

        try store.setMeta(IndexMeta(
            profileDirName: profile.dirName,
            sourceFile: "firefox-bookmarks",
            lastModified: sourceMod,
            lastVisitTime: 0
        ))
    }

    func importLogins(profile: BrowserProfile, profileId: Int64) throws {
        let loginsPath = profile.path.appendingPathComponent("logins.json")
        guard FileManager.default.fileExists(atPath: loginsPath.path) else { return }

        let meta = try store.getMeta(profileDir: profile.dirName, sourceFile: "firefox-logins")
        let sourceMod = SafeFileCopy.modificationDate(of: loginsPath)?.timeIntervalSince1970 ?? 0
        if let meta = meta, meta.lastModified >= sourceMod { return }

        guard let data = try? Data(contentsOf: loginsPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let logins = json["logins"] as? [[String: Any]] else { return }

        var items: [ItemRecord] = []

        for login in logins {
            let hostname = login["hostname"] as? String ?? ""
            let username = login["encryptedUsername"] as? String
            let timeLastUsed = login["timeLastUsed"] as? Int64 ?? 0
            let timeCreated = login["timeCreated"] as? Int64 ?? 0
            let ts = (timeLastUsed > 0 ? timeLastUsed : timeCreated) / 1000

            items.append(ItemRecord(
                profileId: profileId,
                kind: "login",
                url: hostname,
                title: hostname,
                username: username,
                timestamp: ts
            ))
        }

        if !items.isEmpty { try store.upsertItems(items) }

        try store.setMeta(IndexMeta(
            profileDirName: profile.dirName,
            sourceFile: "firefox-logins",
            lastModified: sourceMod,
            lastVisitTime: 0
        ))
    }

    func importAutofill(profile: BrowserProfile, profileId: Int64) throws {
        let formHistoryPath = profile.path.appendingPathComponent("formhistory.sqlite")
        guard FileManager.default.fileExists(atPath: formHistoryPath.path) else { return }

        let meta = try store.getMeta(profileDir: profile.dirName, sourceFile: "firefox-formhistory")
        let sourceMod = SafeFileCopy.modificationDate(of: formHistoryPath)?.timeIntervalSince1970 ?? 0
        if let meta = meta, meta.lastModified >= sourceMod { return }

        let tempFile = try SafeFileCopy.copy(source: formHistoryPath)
        defer { SafeFileCopy.cleanup(tempFile: tempFile) }

        var config = GRDB.Configuration()
        config.readonly = true
        let sourceDb = try DatabaseQueue(path: tempFile.path, configuration: config)

        var items: [ItemRecord] = []

        try sourceDb.read { db in
            let tableExists = try Bool.fetchOne(db, sql: """
                SELECT COUNT(*) > 0 FROM sqlite_master WHERE type='table' AND name='moz_formhistory'
            """) ?? false
            guard tableExists else { return }

            let rows = try Row.fetchAll(db, sql: """
                SELECT fieldname, value, lastUsed FROM moz_formhistory
                WHERE fieldname IN ('email', 'Email', 'EMAIL', 'username', 'Username',
                                    'phone', 'Phone', 'name', 'Name', 'address', 'Address')
                ORDER BY lastUsed DESC
            """)

            for row in rows {
                let fieldname: String = row["fieldname"] ?? ""
                let value: String = row["value"] ?? ""
                let lastUsed: Int64 = row["lastUsed"] ?? 0
                let ts = lastUsed / 1_000_000

                guard !value.isEmpty else { continue }

                let isEmail = fieldname.lowercased().contains("email")

                items.append(ItemRecord(
                    profileId: profileId,
                    kind: "autofill",
                    url: "autofill://firefox/\(fieldname)",
                    title: "\(fieldname): \(value)",
                    username: isEmail ? value : nil,
                    timestamp: ts
                ))
            }
        }

        if !items.isEmpty { try store.upsertItems(items) }

        try store.setMeta(IndexMeta(
            profileDirName: profile.dirName,
            sourceFile: "firefox-formhistory",
            lastModified: sourceMod,
            lastVisitTime: 0
        ))
    }
}

import Foundation
import GRDB

struct ProfileRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "profiles"

    var id: Int64?
    var dirName: String
    var displayName: String
    var accountEmail: String
    var avatarIcon: String
    var color: Int

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

struct ItemRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "items"

    var id: Int64?
    var profileId: Int64
    var kind: String
    var url: String
    var title: String
    var username: String?
    var timestamp: Int64
    var visitCount: Int?
    var extraJson: String?

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

struct SearchResult: FetchableRecord, Decodable, Identifiable {
    var id: Int64
    var profileId: Int64
    var kind: String
    var url: String
    var title: String
    var username: String?
    var timestamp: Int64
    var visitCount: Int?
    var extraJson: String?
    var displayName: String
    var accountEmail: String
    var color: Int
    var dirName: String
}

struct IndexMeta: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "index_meta"

    var profileDirName: String
    var sourceFile: String
    var lastModified: Double
    var lastVisitTime: Int64
}

final class IndexStore {
    let dbQueue: DatabaseQueue

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbDir = appSupport.appendingPathComponent("ezhistory")
        try? FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let dbPath = dbDir.appendingPathComponent("index.db").path

        var config = Configuration()
        config.prepareDatabase { db in
            db.trace { _ in }
        }

        do {
            dbQueue = try DatabaseQueue(path: dbPath, configuration: config)
            try migrate()
        } catch {
            fatalError("Failed to open index database: \(error)")
        }
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "profiles", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("dirName", .text).notNull().unique()
                t.column("displayName", .text).notNull()
                t.column("accountEmail", .text).defaults(to: "")
                t.column("avatarIcon", .text).defaults(to: "")
                t.column("color", .integer).defaults(to: 0)
            }

            try db.create(table: "items", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("profileId", .integer).notNull().references("profiles", onDelete: .cascade)
                t.column("kind", .text).notNull()
                t.column("url", .text).notNull()
                t.column("title", .text).notNull().defaults(to: "")
                t.column("username", .text)
                t.column("timestamp", .integer).notNull()
                t.column("visitCount", .integer)
                t.column("extraJson", .text)
            }

            try db.execute(sql: """
                CREATE UNIQUE INDEX IF NOT EXISTS items_unique
                ON items(profileId, kind, url, COALESCE(username, ''))
            """)
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS items_url ON items(url)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS items_profile_kind ON items(profileId, kind)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS items_timestamp ON items(timestamp DESC)")

            try db.execute(sql: """
                CREATE VIRTUAL TABLE IF NOT EXISTS items_fts USING fts5(
                    title, url, username,
                    content='items',
                    content_rowid='id',
                    tokenize='unicode61 remove_diacritics 2'
                )
            """)

            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS items_ai AFTER INSERT ON items BEGIN
                    INSERT INTO items_fts(rowid, title, url, username)
                    VALUES (new.id, new.title, new.url, COALESCE(new.username, ''));
                END
            """)
            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS items_ad AFTER DELETE ON items BEGIN
                    INSERT INTO items_fts(items_fts, rowid, title, url, username)
                    VALUES ('delete', old.id, old.title, old.url, COALESCE(old.username, ''));
                END
            """)
            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS items_au AFTER UPDATE ON items BEGIN
                    INSERT INTO items_fts(items_fts, rowid, title, url, username)
                    VALUES ('delete', old.id, old.title, old.url, COALESCE(old.username, ''));
                    INSERT INTO items_fts(rowid, title, url, username)
                    VALUES (new.id, new.title, new.url, COALESCE(new.username, ''));
                END
            """)

            try db.create(table: "index_meta", ifNotExists: true) { t in
                t.column("profileDirName", .text).notNull()
                t.column("sourceFile", .text).notNull()
                t.column("lastModified", .double).notNull()
                t.column("lastVisitTime", .integer).notNull().defaults(to: 0)
                t.primaryKey(["profileDirName", "sourceFile"])
            }
        }

        try migrator.migrate(dbQueue)
    }

    // MARK: - Profile operations

    func upsertProfile(_ profile: ChromeProfile) throws -> Int64 {
        try dbQueue.write { db in
            if let existing = try ProfileRecord.filter(Column("dirName") == profile.dirName).fetchOne(db) {
                var updated = existing
                updated.displayName = profile.displayName
                updated.accountEmail = profile.accountEmail
                updated.avatarIcon = profile.avatarIcon
                updated.color = profile.themeColor
                try updated.update(db)
                return existing.id!
            } else {
                let record = ProfileRecord(
                    dirName: profile.dirName,
                    displayName: profile.displayName,
                    accountEmail: profile.accountEmail,
                    avatarIcon: profile.avatarIcon,
                    color: profile.themeColor
                )
                return try record.inserted(db).id!
            }
        }
    }

    // MARK: - Item operations

    func upsertItem(_ item: ItemRecord) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO items (profileId, kind, url, title, username, timestamp, visitCount, extraJson)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(profileId, kind, url, COALESCE(username, ''))
                    DO UPDATE SET
                        title = excluded.title,
                        timestamp = MAX(items.timestamp, excluded.timestamp),
                        visitCount = excluded.visitCount,
                        extraJson = excluded.extraJson
                """,
                arguments: [item.profileId, item.kind, item.url, item.title,
                            item.username, item.timestamp, item.visitCount, item.extraJson]
            )
        }
    }

    func upsertItems(_ items: [ItemRecord]) throws {
        try dbQueue.write { db in
            for item in items {
                try db.execute(
                    sql: """
                        INSERT INTO items (profileId, kind, url, title, username, timestamp, visitCount, extraJson)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                        ON CONFLICT(profileId, kind, url, COALESCE(username, ''))
                        DO UPDATE SET
                            title = excluded.title,
                            timestamp = MAX(items.timestamp, excluded.timestamp),
                            visitCount = excluded.visitCount,
                            extraJson = excluded.extraJson
                    """,
                    arguments: [item.profileId, item.kind, item.url, item.title,
                                item.username, item.timestamp, item.visitCount, item.extraJson]
                )
            }
        }
    }

    // MARK: - Search

    func search(query: String, kinds: Set<String>? = nil, profileIds: Set<Int64>? = nil,
                since: Date? = nil, limit: Int = 200) throws -> [SearchResult] {
        try dbQueue.read { db in
            let ftsQuery = query.split(separator: " ").map { "\($0)*" }.joined(separator: " ")

            var sql = """
                SELECT items.id, items.profileId, items.kind, items.url, items.title,
                       items.username, items.timestamp, items.visitCount, items.extraJson,
                       profiles.displayName, profiles.accountEmail, profiles.color, profiles.dirName
                FROM items_fts
                JOIN items ON items.id = items_fts.rowid
                JOIN profiles ON profiles.id = items.profileId
                WHERE items_fts MATCH ?
            """
            var arguments: [DatabaseValueConvertible] = [ftsQuery]

            if let kinds = kinds, !kinds.isEmpty {
                let placeholders = kinds.map { _ in "?" }.joined(separator: ",")
                sql += " AND items.kind IN (\(placeholders))"
                arguments.append(contentsOf: kinds.map { $0 as DatabaseValueConvertible })
            }

            if let profileIds = profileIds, !profileIds.isEmpty {
                let placeholders = profileIds.map { _ in "?" }.joined(separator: ",")
                sql += " AND items.profileId IN (\(placeholders))"
                arguments.append(contentsOf: profileIds.map { $0 as DatabaseValueConvertible })
            }

            if let since = since {
                let ts = Int64(since.timeIntervalSince1970 * 1000)
                sql += " AND items.timestamp >= ?"
                arguments.append(ts)
            }

            sql += " ORDER BY bm25(items_fts), items.timestamp DESC LIMIT ?"
            arguments.append(limit)

            return try SearchResult.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
        }
    }

    func profilesForURL(_ url: String) throws -> [SearchResult] {
        try dbQueue.read { db in
            try SearchResult.fetchAll(db, sql: """
                SELECT items.id, items.profileId, items.kind, items.url, items.title,
                       items.username, items.timestamp, items.visitCount, items.extraJson,
                       profiles.displayName, profiles.accountEmail, profiles.color, profiles.dirName
                FROM items
                JOIN profiles ON profiles.id = items.profileId
                WHERE items.url = ?
                ORDER BY items.timestamp DESC
            """, arguments: [url])
        }
    }

    func allProfiles() throws -> [ProfileRecord] {
        try dbQueue.read { db in
            try ProfileRecord.order(Column("displayName")).fetchAll(db)
        }
    }

    // MARK: - Meta

    func getMeta(profileDir: String, sourceFile: String) throws -> IndexMeta? {
        try dbQueue.read { db in
            try IndexMeta.filter(
                Column("profileDirName") == profileDir && Column("sourceFile") == sourceFile
            ).fetchOne(db)
        }
    }

    func setMeta(_ meta: IndexMeta) throws {
        try dbQueue.write { db in
            try meta.save(db, onConflict: .replace)
        }
    }

    func profileCount() throws -> Int {
        try dbQueue.read { db in
            try ProfileRecord.fetchCount(db)
        }
    }

    func itemCount() throws -> Int {
        try dbQueue.read { db in
            try ItemRecord.fetchCount(db)
        }
    }

    func rebuildFTS() throws {
        try dbQueue.write { db in
            try db.execute(sql: "INSERT INTO items_fts(items_fts) VALUES('rebuild')")
        }
    }
}

import Foundation
import GRDB

struct AutofillImporter {
    let store: IndexStore

    func importAutofill(profile: ChromeProfile, profileId: Int64) throws {
        let webDataPath = profile.path.appendingPathComponent("Web Data")
        guard FileManager.default.fileExists(atPath: webDataPath.path) else { return }

        let meta = try store.getMeta(profileDir: profile.dirName, sourceFile: "WebData")
        let sourceMod = SafeFileCopy.modificationDate(of: webDataPath)?.timeIntervalSince1970 ?? 0

        if let meta = meta, meta.lastModified >= sourceMod {
            return
        }

        let tempFile = try SafeFileCopy.copy(source: webDataPath)
        defer { SafeFileCopy.cleanup(tempFile: tempFile) }

        var config = GRDB.Configuration()
        config.readonly = true
        let sourceDb = try DatabaseQueue(path: tempFile.path, configuration: config)

        var items: [ItemRecord] = []

        try sourceDb.read { db in
            try importAutofillProfiles(db: db, profileId: profileId, items: &items)
            try importAutofillEmails(db: db, profileId: profileId, items: &items)
        }

        if !items.isEmpty {
            try store.upsertItems(items)
        }

        try store.setMeta(IndexMeta(
            profileDirName: profile.dirName,
            sourceFile: "WebData",
            lastModified: sourceMod,
            lastVisitTime: 0
        ))
    }

    private func importAutofillProfiles(db: Database, profileId: Int64, items: inout [ItemRecord]) throws {
        let tableExists = try Bool.fetchOne(db, sql: """
            SELECT COUNT(*) > 0 FROM sqlite_master WHERE type='table' AND name='autofill_profiles'
        """) ?? false

        guard tableExists else { return }

        let rows = try Row.fetchAll(db, sql: """
            SELECT guid, company_name, street_address, city, state, zipcode,
                   country_code, date_modified, use_count
            FROM autofill_profiles
        """)

        for row in rows {
            let guid: String = row["guid"] ?? ""
            let company: String = row["company_name"] ?? ""
            let street: String = row["street_address"] ?? ""
            let city: String = row["city"] ?? ""
            let state: String = row["state"] ?? ""
            let zip: String = row["zipcode"] ?? ""
            let country: String = row["country_code"] ?? ""
            let dateMod: Int64 = row["date_modified"] ?? 0

            let addressParts = [street, city, state, zip, country].filter { !$0.isEmpty }
            let title = company.isEmpty ? addressParts.joined(separator: ", ")
                                       : "\(company) - \(addressParts.joined(separator: ", "))"

            guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

            let extra: [String: Any] = [
                "guid": guid,
                "company": company,
                "street": street,
                "city": city,
                "state": state,
                "zipcode": zip,
                "country": country
            ]
            let extraJson: String? = (try? JSONSerialization.data(withJSONObject: extra))
                .flatMap { String(data: $0, encoding: .utf8) }

            items.append(ItemRecord(
                profileId: profileId,
                kind: "autofill",
                url: "autofill://address/\(guid)",
                title: title,
                timestamp: dateMod,
                extraJson: extraJson
            ))
        }
    }

    private func importAutofillEmails(db: Database, profileId: Int64, items: inout [ItemRecord]) throws {
        let tableExists = try Bool.fetchOne(db, sql: """
            SELECT COUNT(*) > 0 FROM sqlite_master WHERE type='table' AND name='autofill_profile_emails'
        """) ?? false

        guard tableExists else { return }

        let rows = try Row.fetchAll(db, sql: """
            SELECT guid, email FROM autofill_profile_emails
        """)

        for row in rows {
            let guid: String = row["guid"] ?? ""
            let email: String = row["email"] ?? ""
            guard !email.isEmpty else { continue }

            items.append(ItemRecord(
                profileId: profileId,
                kind: "autofill",
                url: "autofill://email/\(guid)",
                title: email,
                username: email,
                timestamp: Int64(Date().timeIntervalSince1970),
                extraJson: nil
            ))
        }
    }
}

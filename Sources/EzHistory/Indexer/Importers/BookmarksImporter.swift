import Foundation

struct BookmarksImporter {
    let store: IndexStore

    func importBookmarks(profile: ChromeProfile, profileId: Int64) throws {
        let bookmarksPath = profile.path.appendingPathComponent("Bookmarks")
        guard FileManager.default.fileExists(atPath: bookmarksPath.path) else { return }

        let meta = try store.getMeta(profileDir: profile.dirName, sourceFile: "Bookmarks")
        let sourceMod = SafeFileCopy.modificationDate(of: bookmarksPath)?.timeIntervalSince1970 ?? 0

        if let meta = meta, meta.lastModified >= sourceMod {
            return
        }

        guard let data = try? Data(contentsOf: bookmarksPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let roots = json["roots"] as? [String: Any] else {
            return
        }

        var items: [ItemRecord] = []

        for (_, rootValue) in roots {
            guard let rootNode = rootValue as? [String: Any] else { continue }
            flattenBookmarks(node: rootNode, path: "", profileId: profileId, items: &items)
        }

        if !items.isEmpty {
            try store.upsertItems(items)
        }

        try store.setMeta(IndexMeta(
            profileDirName: profile.dirName,
            sourceFile: "Bookmarks",
            lastModified: sourceMod,
            lastVisitTime: 0
        ))
    }

    private func flattenBookmarks(node: [String: Any], path: String, profileId: Int64, items: inout [ItemRecord]) {
        let name = node["name"] as? String ?? ""
        let type = node["type"] as? String ?? ""

        if type == "url", let url = node["url"] as? String {
            let dateAdded = node["date_added"] as? String ?? "0"
            let chromeTs = Int64(dateAdded) ?? 0
            let unixTs = HistoryImporter.chromeTimestampToUnix(chromeTs)

            let extra: [String: String] = ["folderPath": path]
            let extraJson: String? = (try? JSONSerialization.data(withJSONObject: extra))
                .flatMap { String(data: $0, encoding: .utf8) }

            items.append(ItemRecord(
                profileId: profileId,
                kind: "bookmark",
                url: url,
                title: name,
                timestamp: unixTs,
                extraJson: extraJson
            ))
        }

        if type == "folder", let children = node["children"] as? [[String: Any]] {
            let childPath = path.isEmpty ? name : "\(path)/\(name)"
            for child in children {
                flattenBookmarks(node: child, path: childPath, profileId: profileId, items: &items)
            }
        }
    }
}

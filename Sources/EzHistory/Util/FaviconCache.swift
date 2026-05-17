import Foundation
import AppKit

actor FaviconCache {
    static let shared = FaviconCache()

    private var cache: [String: NSImage] = [:]
    private var inFlight: Set<String> = []

    private let cacheDir: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ezhistory/favicons")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    func favicon(for urlString: String) async -> NSImage? {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return nil
        }

        let domain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host

        if let cached = cache[domain] {
            return cached
        }

        let diskPath = cacheDir.appendingPathComponent("\(domain).png")
        if let diskImage = NSImage(contentsOf: diskPath) {
            cache[domain] = diskImage
            return diskImage
        }

        guard !inFlight.contains(domain) else { return nil }
        inFlight.insert(domain)

        defer { inFlight.remove(domain) }

        let faviconURL = "https://www.google.com/s2/favicons?domain=\(domain)&sz=32"
        guard let fetchURL = URL(string: faviconURL) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: fetchURL)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = NSImage(data: data) else {
                return nil
            }

            try? data.write(to: diskPath)
            cache[domain] = image
            return image
        } catch {
            return nil
        }
    }
}

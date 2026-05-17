import SwiftUI

struct ResultRow: View {
    let result: SearchResult

    @State private var favicon: NSImage?

    var body: some View {
        HStack(spacing: 10) {
            faviconView
                .frame(width: 20, height: 20)

            kindIcon
                .frame(width: 16)
                .foregroundColor(kindColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.title.isEmpty ? displayURL : result.title)
                    .font(.system(.body, design: .default))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(displayURL)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    if let username = result.username, !username.isEmpty {
                        Label(username, systemImage: "person.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            ProfilePill(
                browserName: result.browser,
                profileName: result.displayName,
                color: pillColor,
                browserIcon: browserIcon
            )

            if let count = result.visitCount, count > 1 {
                Text("\(count)x")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            Text(relativeDate)
                .font(.caption2)
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 3)
        .task {
            favicon = await FaviconCache.shared.favicon(for: result.url)
        }
    }

    private var displayURL: String {
        guard let url = URL(string: result.url) else { return result.url }
        return url.host ?? result.url
    }

    private var faviconView: some View {
        Group {
            if let favicon = favicon {
                Image(nsImage: favicon)
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "globe")
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var kindIcon: some View {
        switch result.kind {
        case "history":
            Image(systemName: "clock")
        case "bookmark":
            Image(systemName: "bookmark.fill")
        case "download":
            Image(systemName: "arrow.down.circle")
        case "login":
            Image(systemName: "key.fill")
        case "autofill":
            Image(systemName: "person.text.rectangle")
        default:
            Image(systemName: "doc")
        }
    }

    private var kindColor: Color {
        switch result.kind {
        case "history": return .blue
        case "bookmark": return .orange
        case "download": return .green
        case "login": return .red
        case "autofill": return .purple
        default: return .gray
        }
    }

    private var pillColor: Color {
        let c = result.color
        guard c != 0 else { return .accentColor }
        let r = Double((c >> 16) & 0xFF) / 255.0
        let g = Double((c >> 8) & 0xFF) / 255.0
        let b = Double(c & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }

    private var browserIcon: String {
        BrowserDef.allBrowsers.first { $0.name == result.browser }?.icon ?? "globe"
    }

    private var relativeDate: String {
        let date = Date(timeIntervalSince1970: TimeInterval(result.timestamp))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ProfilePill: View {
    let browserName: String
    let profileName: String
    let color: Color
    let browserIcon: String

    init(browserName: String = "Chrome", profileName: String, color: Color, browserIcon: String = "globe") {
        self.browserName = browserName
        self.profileName = profileName
        self.color = color
        self.browserIcon = browserIcon
    }

    init(name: String, color: Color) {
        self.browserName = "Chrome"
        self.profileName = name
        self.color = color
        self.browserIcon = "globe"
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: browserIcon)
                .font(.caption2)
            Text(displayLabel)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .clipShape(Capsule())
        .lineLimit(1)
    }

    private var displayLabel: String {
        if browserName == profileName || profileName == "Default" || profileName == "Safari" {
            return browserName
        }
        return "\(browserName) / \(profileName)"
    }
}

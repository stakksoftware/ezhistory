import SwiftUI

struct ResultDetailView: View {
    let url: String
    let results: [SearchResult]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            profilesList
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let host = URL(string: url)?.host {
                Text(host)
                    .font(.headline)
                    .lineLimit(1)
            }

            Text(url)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .textSelection(.enabled)

            HStack(spacing: 12) {
                Button {
                    ChromeLauncher.copyURL(url)
                } label: {
                    Label("Copy URL", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Text("Found in \(profileCount) profile\(profileCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
    }

    private var profilesList: some View {
        List {
            ForEach(groupedByProfile, id: \.profileId) { group in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Circle()
                            .fill(profileColor(group.color))
                            .frame(width: 10, height: 10)

                        Text(group.displayName)
                            .font(.system(.body, weight: .medium))

                        Spacer()

                        Button {
                            ChromeLauncher.openURL(url, inProfile: group.dirName)
                        } label: {
                            Label("Open", systemImage: "arrow.up.right.square")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }

                    if !group.accountEmail.isEmpty {
                        Label(group.accountEmail, systemImage: "envelope")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 16) {
                        ForEach(group.items, id: \.id) { item in
                            kindBadge(item)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.plain)
    }

    private func kindBadge(_ item: SearchResult) -> some View {
        HStack(spacing: 4) {
            kindIcon(item.kind)
                .font(.caption2)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.kind.capitalized)
                    .font(.caption2)
                    .fontWeight(.medium)

                if let count = item.visitCount, count > 0, item.kind == "history" {
                    Text("\(count) visits")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if let username = item.username, !username.isEmpty {
                    Text(username)
                        .font(.caption2)
                        .foregroundColor(.orange)
                }

                Text(formatDate(item.timestamp))
                    .font(.caption2)
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            }
        }
        .padding(6)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }

    @ViewBuilder
    private func kindIcon(_ kind: String) -> some View {
        switch kind {
        case "history": Image(systemName: "clock")
        case "bookmark": Image(systemName: "bookmark.fill")
        case "download": Image(systemName: "arrow.down.circle")
        case "login": Image(systemName: "key.fill")
        case "autofill": Image(systemName: "person.text.rectangle")
        default: Image(systemName: "doc")
        }
    }

    private var profileCount: Int {
        Set(results.map(\.profileId)).count
    }

    private struct ProfileGroup {
        let profileId: Int64
        let displayName: String
        let accountEmail: String
        let color: Int
        let dirName: String
        let items: [SearchResult]
    }

    private var groupedByProfile: [ProfileGroup] {
        let grouped = Dictionary(grouping: results) { $0.profileId }
        return grouped.values.compactMap { items -> ProfileGroup? in
            guard let first = items.first else { return nil }
            return ProfileGroup(
                profileId: first.profileId,
                displayName: first.displayName,
                accountEmail: first.accountEmail,
                color: first.color,
                dirName: first.dirName,
                items: items
            )
        }
        .sorted { $0.displayName < $1.displayName }
    }

    private func profileColor(_ colorInt: Int) -> Color {
        guard colorInt != 0 else { return .accentColor }
        let r = Double((colorInt >> 16) & 0xFF) / 255.0
        let g = Double((colorInt >> 8) & 0xFF) / 255.0
        let b = Double(colorInt & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }

    private func formatDate(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

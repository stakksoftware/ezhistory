import SwiftUI

struct FilterBar: View {
    @ObservedObject var viewModel: SearchViewModel

    @State private var profiles: [ProfileRecord] = []

    private let kinds: [(String, String, Color)] = [
        ("history", "clock", .blue),
        ("bookmark", "bookmark.fill", .orange),
        ("download", "arrow.down.circle", .green),
        ("login", "key.fill", .red),
        ("autofill", "person.text.rectangle", .purple),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(kinds, id: \.0) { kind, icon, color in
                    FilterChip(
                        label: kind.capitalized,
                        icon: icon,
                        color: color,
                        isSelected: viewModel.selectedKinds.contains(kind)
                    ) {
                        if viewModel.selectedKinds.contains(kind) {
                            viewModel.selectedKinds.remove(kind)
                        } else {
                            viewModel.selectedKinds.insert(kind)
                        }
                    }
                }

                Divider()
                    .frame(height: 20)

                Picker("", selection: $viewModel.timeFilter) {
                    ForEach(SearchViewModel.TimeFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)

                if !profiles.isEmpty {
                    Divider()
                        .frame(height: 20)

                    Menu {
                        Button("All Profiles") {
                            viewModel.selectedProfileIds.removeAll()
                        }
                        Divider()
                        ForEach(profiles) { profile in
                            Button {
                                if let id = profile.id {
                                    if viewModel.selectedProfileIds.contains(id) {
                                        viewModel.selectedProfileIds.remove(id)
                                    } else {
                                        viewModel.selectedProfileIds.insert(id)
                                    }
                                }
                            } label: {
                                HStack {
                                    if let id = profile.id, viewModel.selectedProfileIds.contains(id) {
                                        Image(systemName: "checkmark")
                                    }
                                    Text(profile.displayName)
                                    if !profile.accountEmail.isEmpty {
                                        Text("(\(profile.accountEmail))")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2")
                            Text(profileLabel)
                                .lineLimit(1)
                        }
                        .font(.caption)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .task {
            profiles = (try? AppState.shared.indexStore.allProfiles()) ?? []
        }
    }

    private var profileLabel: String {
        if viewModel.selectedProfileIds.isEmpty {
            return "All Profiles"
        }
        return "\(viewModel.selectedProfileIds.count) selected"
    }
}

struct FilterChip: View {
    let label: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? color.opacity(0.2) : Color.gray.opacity(0.1))
            .foregroundColor(isSelected ? color : .secondary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

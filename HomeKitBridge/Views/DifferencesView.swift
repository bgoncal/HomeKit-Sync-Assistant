import SwiftUI

/// Where the Sync screen can push to.
enum SyncRoute: Hashable {
    case differences(homeId: String, serverId: UUID)
}

enum DifferencesState: Equatable {
    case loading
    case loaded(PairDifferences)
    case failed(String)
}

/// Both sides side by side, before choosing what to sync.
struct DifferencesView: View {
    @EnvironmentObject private var syncEngine: SyncEngine

    let homeId: String
    let serverId: UUID

    @State private var state: DifferencesState = .loading

    var body: some View {
        DifferencesContent(state: state, progress: syncEngine.progress)
            .task(id: "\(homeId)|\(serverId)") { await load() }
            .refreshable { await load() }
    }

    private func load() async {
        state = .loading
        do {
            state = .loaded(try await syncEngine.differences(homeId: homeId, serverId: serverId))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

struct DifferencesContent: View {
    let state: DifferencesState
    var progress: SyncProgress?

    var body: some View {
        Group {
            switch state {
            case .loading:
                ContentUnavailableView {
                    Label(progress?.title ?? "Comparing Both Sides…", systemImage: "arrow.left.arrow.right")
                } description: {
                    Text(progress?.detail ?? "Nothing is changed while comparing.")
                }
            case .failed(let message):
                ContentUnavailableView(
                    "Could Not Compare",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            case .loaded(let differences):
                list(differences)
            }
        }
        .navigationTitle("Differences")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func list(_ d: PairDifferences) -> some View {
        List {
            Section {
                LabeledContent("Already Matching", value: d.matchingCount.formatted())
                LabeledContent("Different Room", value: d.differentRoom.count.formatted())
                LabeledContent("Different Name", value: d.differentName.count.formatted())
                LabeledContent("Not Matched", value: d.unmatchedDevices.count.formatted())
            } header: {
                Text("\(d.homeName) and \(d.serverName)")
                    .textCase(nil)
            } footer: {
                Text(d.isEverythingInSync
                     ? "Every matched device has the same room and name on both sides."
                     : "Nothing has been changed. Pick what to sync on the Sync screen to line these up.")
            }

            if !d.differentRoom.isEmpty {
                Section("Different Room") {
                    ForEach(d.differentRoom) { comparison($0) }
                }
            }

            if !d.differentName.isEmpty {
                Section("Different Name") {
                    ForEach(d.differentName) { comparison($0) }
                }
            }

            if !d.roomsOnlyInAppleHome.isEmpty {
                names(d.roomsOnlyInAppleHome, title: "Rooms Only in Apple Home", systemImage: "house")
            }

            if !d.areasOnlyInHomeAssistant.isEmpty {
                names(d.areasOnlyInHomeAssistant, title: "Areas Only in Home Assistant", systemImage: "server.rack")
            }

            if !d.unmatchedDevices.isEmpty {
                Section {
                    ForEach(d.unmatchedDevices, id: \.self) { Text($0) }
                } header: {
                    Text("Not Matched")
                } footer: {
                    Text("These have no Home Assistant entity to compare with. Open one in the Apple Home list to choose its entity by hand.")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func comparison(_ difference: DeviceDifference) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(difference.deviceName)
            Group {
                Label(difference.appleHomeValue, systemImage: SyncPlatform.appleHome.symbolName)
                    .foregroundStyle(SyncPlatform.appleHome.tint)
                Label(difference.homeAssistantValue, systemImage: SyncPlatform.homeAssistant.symbolName)
                    .foregroundStyle(SyncPlatform.homeAssistant.tint)
            }
            .font(.footnote)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(difference.deviceName): \(difference.appleHomeValue) in Apple Home, \(difference.homeAssistantValue) in Home Assistant")
    }

    private func names(_ names: [String], title: String, systemImage: String) -> some View {
        Section(title) {
            ForEach(names, id: \.self) { name in
                Label(name, systemImage: systemImage)
            }
        }
    }
}

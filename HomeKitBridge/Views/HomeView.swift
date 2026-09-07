import SwiftUI

/// Where the app opens: both sides at a glance, the local API, and the small print.
struct HomeView: View {
    @EnvironmentObject private var homeKitManager: HomeKitManager
    @EnvironmentObject private var connections: ConnectionStore
    @EnvironmentObject private var server: HTTPServer
    @EnvironmentObject private var scheduledActionManager: ScheduledActionManager

    @AppStorage("onboardingComplete") private var onboardingComplete = false

    @State private var tipProduct: TipProduct?
    @State private var tipState: TipState = .idle

    private let tipService: TipService

    init(tipService: TipService? = nil) {
        self.tipService = tipService ?? StoreKitTipService()
    }

    @State private var path: [HomeRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            content
        }
        .task {
            tipProduct = await tipService.product()
        }
    }

    private var content: some View {
        HomeContent(
            homes: homeKitManager.homes,
            isHomeKitAuthorized: homeKitManager.isAuthorized,
            connections: connections.summaries,
            isServerRunning: server.isRunning,
            serverPort: server.port,
            scheduleCount: scheduledActionManager.schedules.count,
            tipProduct: tipProduct,
            tipState: tipState,
            onSelect: { path.append($0) },
            onRequestHomeKitAccess: { homeKitManager.requestAccess() },
            onTip: tip,
            onShowSetupAgain: { onboardingComplete = false }
        )
        .navigationDestination(for: HomeRoute.self) { route in
            switch route {
            case .appleHomes:
                AppleHomesContent(homes: homeKitManager.homes, isAuthorized: homeKitManager.isAuthorized)
            case .homeAssistants:
                ServersContent(
                    connections: connections.summaries,
                    onDelete: { connections.remove(serverId: $0.id) }
                )
            case .home(let homeId):
                HomeDevicesView(homeId: homeId)
            case .server(let serverId):
                EntitiesView(serverId: serverId)
            case .serverSettings(let serverId):
                ServerDetailView(serverId: serverId)
            case .newServer:
                ServerDetailView(serverId: nil)
            case .localAPI:
                LocalAPIView()
            case .scheduledActions:
                ActionsView()
            }
        }
    }

    private func tip() {
        tipState = .purchasing
        Task {
            do {
                tipState = try await tipService.tip() ? .thanks : .idle
            } catch {
                tipState = .failed(error.localizedDescription)
            }
        }
    }
}

/// Where the Home screen can push to.
enum HomeRoute: Hashable {
    case appleHomes
    case homeAssistants
    case home(String)
    case server(UUID)
    case serverSettings(UUID)
    case newServer
    case localAPI
    case scheduledActions
}

enum TipState: Equatable {
    case idle
    case purchasing
    case thanks
    case failed(String)
}

struct HomeContent: View {
    let homes: [HomeSummary]
    let isHomeKitAuthorized: Bool
    let connections: [ConnectionSummary]
    let isServerRunning: Bool
    let serverPort: Int
    var scheduleCount: Int = 0
    var supportsScheduledActions: Bool = ScheduledActionManager.isSupported
    var tipProduct: TipProduct?
    var tipState: TipState = .idle
    var onSelect: (HomeRoute) -> Void = { _ in }
    var onRequestHomeKitAccess: () -> Void = {}
    var onTip: () -> Void = {}
    var onShowSetupAgain: () -> Void = {}

    var body: some View {
        List {
            Section {
                HStack(alignment: .top, spacing: 12) {
                    box(
                        route: .appleHomes,
                        platform: .appleHome,
                        headline: appleHomeHeadline,
                        detail: appleHomeDetail
                    )
                    box(
                        route: .homeAssistants,
                        platform: .homeAssistant,
                        headline: homeAssistantHeadline,
                        detail: homeAssistantDetail
                    )
                }
                // Zero insets: the section is already inset, and adding to it pushed
                // this row further in than every card below it.
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowBackground(Color.clear)
            } footer: {
                Text("Tap either side to see what it holds. You pick which pair to sync on the Sync screen.")
            }

            if !isHomeKitAuthorized {
                Section {
                    Button("Allow Access to Apple Home", action: onRequestHomeKitAccess)
                } footer: {
                    Text("Without HomeKit access the app cannot read your rooms and devices.")
                }
            }

            Section {
                NavigationLink(value: HomeRoute.localAPI) {
                    LabeledContent {
                        BridgePill(
                            title: isServerRunning ? "Running" : "Stopped",
                            systemImage: isServerRunning ? "checkmark.circle.fill" : "pause.circle.fill",
                            tint: isServerRunning ? .green : .secondary
                        )
                    } label: {
                        Label("Local API", systemImage: "point.3.connected.trianglepath.dotted")
                    }
                }
            } footer: {
                Text(isServerRunning
                     ? "Serving Apple Home to your own scripts on port \(String(serverPort))."
                     : "Turn it on to drive Apple Home from your own scripts and automations.")
            }

            if supportsScheduledActions {
                Section {
                    NavigationLink(value: HomeRoute.scheduledActions) {
                        LabeledContent("Scheduled Syncs", value: scheduleCount == 0 ? "None" : scheduleCount.formatted())
                    }
                } footer: {
                    Text("Repeat a sync daily while this Mac is awake and the app is open.")
                }
            }

            setupSection
            supportSection
            aboutSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Home")
    }

    // MARK: Boxes

    /// A button rather than a `NavigationLink`: a list row containing a link is a
    /// single tap target, so two links in one row both open the first destination.
    private func box(route: HomeRoute, platform: SyncPlatform, headline: String, detail: String) -> some View {
        Button {
            onSelect(route)
        } label: {
            SideBox(
                title: platform.name,
                systemImage: platform.symbolName,
                tint: platform.tint,
                headline: headline,
                detail: detail
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
    }

    private var appleHomeHeadline: String {
        guard isHomeKitAuthorized else { return "No Access" }
        return homes.isEmpty ? "No Homes" : "\(homes.count) Home\(homes.count == 1 ? "" : "s")"
    }

    private var appleHomeDetail: String {
        guard isHomeKitAuthorized else { return "Allow access to continue" }
        guard !homes.isEmpty else { return "Open Apple Home once" }
        let devices = homes.reduce(0) { $0 + $1.accessories.count }
        return "\(devices) device\(devices == 1 ? "" : "s")"
    }

    private var homeAssistantHeadline: String {
        connections.isEmpty ? "None Yet" : "\(connections.count) Server\(connections.count == 1 ? "" : "s")"
    }

    private var homeAssistantDetail: String {
        guard !connections.isEmpty else { return "Add your first one" }
        let connected = connections.filter(\.state.isConnected).count
        return connected == connections.count ? "All connected" : "\(connected) of \(connections.count) connected"
    }

    // MARK: Setup

    private var setupSection: some View {
        Section {
            Button("Show Setup Guide Again", action: onShowSetupAgain)
        } header: {
            Text("Setup")
        } footer: {
            Text("Walks through how the two sides are paired, and where the address and token go.")
        }
    }

    // MARK: Support

    private var supportSection: some View {
        Section {
            Button(action: onTip) {
                HStack {
                    Label(tipTitle, systemImage: "heart.fill")
                        .foregroundStyle(.pink)
                    Spacer()
                    if tipState == .purchasing {
                        ProgressView()
                    } else if let tipProduct {
                        Text(tipProduct.displayPrice)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .disabled(tipState == .purchasing || tipProduct == nil)
        } header: {
            Text("Support")
        } footer: {
            switch tipState {
            case .thanks:
                Text("Thank you — that genuinely helps.")
            case .failed(let message):
                Text(message).foregroundStyle(.red)
            case .idle, .purchasing:
                Text(tipProduct == nil
                     ? "Tipping is unavailable right now."
                     : "A one-off thank you. Nothing unlocks — the app is the same either way.")
            }
        }
    }

    private var tipTitle: String {
        tipState == .thanks ? "Tip Sent" : "Tip the Developer"
    }

    private var aboutSection: some View {
        Section {
            Link(destination: URL(string: "https://github.com/bgoncal/HomeKit-Sync-Assistant")!) {
                LabeledContent {
                    Image(systemName: "arrow.up.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                } label: {
                    Label("Source on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }

            Link(destination: URL(string: "https://x.com/bgoncal2")!) {
                LabeledContent {
                    Image(systemName: "arrow.up.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                } label: {
                    Label("@bgoncal2 on X", systemImage: "at")
                }
            }
        } header: {
            Text("About")
        }
    }
}

/// One of the two tappable boxes at the top of the Home screen.
private struct SideBox: View {
    let title: String
    let systemImage: String
    let tint: Color
    let headline: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }

            Text(headline)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - The two lists behind the boxes

struct AppleHomesContent: View {
    let homes: [HomeSummary]
    var isAuthorized: Bool = true

    var body: some View {
        List {
            ForEach(homes) { home in
                NavigationLink(value: HomeRoute.home(home.id)) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(home.name)
                        Text("\(home.rooms.count) room\(home.rooms.count == 1 ? "" : "s") · \(home.accessories.count) device\(home.accessories.count == 1 ? "" : "s")")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if homes.isEmpty {
                ContentUnavailableView(
                    isAuthorized ? "No Homes Yet" : "No Access to Apple Home",
                    systemImage: "house",
                    description: Text(isAuthorized
                        ? "Open the Apple Home app once on this device, then come back."
                        : "Allow access on the Home tab, then come back.")
                )
            }
        }
        .navigationTitle(SyncPlatform.appleHome.name)
    }
}

struct ServersContent: View {
    let connections: [ConnectionSummary]
    var onDelete: (HomeAssistantServer) -> Void = { _ in }

    /// Set while the confirmation is up, so a long press cannot delete by accident.
    @State private var serverPendingDeletion: HomeAssistantServer?

    var body: some View {
        List {
            Section {
                ForEach(connections) { connection in
                    NavigationLink(value: HomeRoute.server(connection.server.id)) {
                        row(connection)
                    }
                    .contextMenu {
                        Button("Delete Server", systemImage: "trash", role: .destructive) {
                            serverPendingDeletion = connection.server
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            serverPendingDeletion = connection.server
                        }
                    }
                }

                NavigationLink(value: HomeRoute.newServer) {
                    Label("Add Home Assistant", systemImage: "plus")
                }
            } footer: {
                Text("Open a server to browse its entities, or to change its address and token. Press and hold one to remove it.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(SyncPlatform.homeAssistant.name)
        .confirmationDialog(
            serverPendingDeletion.map { "Delete “\($0.name)”?" } ?? "Delete this server?",
            isPresented: Binding(
                get: { serverPendingDeletion != nil },
                set: { if !$0 { serverPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Server", role: .destructive) {
                if let server = serverPendingDeletion {
                    onDelete(server)
                }
                serverPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { serverPendingDeletion = nil }
        } message: {
            Text("Its address and token are removed from this device and your other ones. Nothing changes in Home Assistant or in your home.")
        }
    }

    private func row(_ connection: ConnectionSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(connection.server.name)
                Spacer(minLength: 8)
                BridgePill(
                    title: connection.state.title,
                    systemImage: connection.state.isConnected ? "checkmark.circle.fill" : "circle.dashed",
                    tint: connection.state.isConnected ? .green : .secondary
                )
            }
            Text(connection.server.normalizedAddress.isEmpty ? "No address yet" : connection.server.normalizedAddress)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 2)
    }
}

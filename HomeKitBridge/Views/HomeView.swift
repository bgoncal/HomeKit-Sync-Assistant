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
            appVersion: Bundle.main.appVersionString,
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
    var appVersion: String = ""
    var onSelect: (HomeRoute) -> Void = { _ in }
    var onRequestHomeKitAccess: () -> Void = {}
    var onTip: () -> Void = {}
    var onShowSetupAgain: () -> Void = {}

    @State private var isShowingSettings = false

    private var needsSetup: Bool { !isHomeKitAuthorized || connections.isEmpty }

    var body: some View {
        List {
            if needsSetup {
                gettingStartedSection
            }
            sidesSection
            toolsSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .sheet(isPresented: $isShowingSettings) {
                    NavigationStack {
                        SettingsContent(
                            tipProduct: tipProduct,
                            tipState: tipState,
                            appVersion: appVersion,
                            onTip: onTip,
                            onShowSetupAgain: {
                                isShowingSettings = false
                                onShowSetupAgain()
                            }
                        )
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { isShowingSettings = false }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Getting started

    /// Only shown until both sides are there, so a first launch says what to do next
    /// instead of showing two empty summaries.
    private var gettingStartedSection: some View {
        Section {
            if isHomeKitAuthorized {
                BridgeChecklistRow(step: 1, title: "Apple Home Connected", isDone: true)
            } else {
                Button(action: onRequestHomeKitAccess) {
                    BridgeChecklistRow(step: 1, title: "Allow Access to Apple Home", isDone: false)
                }
            }

            if connections.isEmpty {
                Button { onSelect(.newServer) } label: {
                    BridgeChecklistRow(step: 2, title: "Add a Home Assistant Server", isDone: false)
                }
            } else {
                BridgeChecklistRow(step: 2, title: "Home Assistant Added", isDone: true)
            }
        } header: {
            Text("Get Started")
        } footer: {
            Text("Syncing needs both sides: access to your Apple Home, and the address and token of a Home Assistant server.")
        }
    }

    // MARK: The two sides

    private var sidesSection: some View {
        Section {
            NavigationLink(value: HomeRoute.appleHomes) {
                BridgeNavigationRow(
                    title: SyncPlatform.appleHome.name,
                    subtitle: appleHomeSummary,
                    systemImage: SyncPlatform.appleHome.symbolName,
                    tint: SyncPlatform.appleHome.tint
                )
            }
            NavigationLink(value: HomeRoute.homeAssistants) {
                BridgeNavigationRow(
                    title: SyncPlatform.homeAssistant.name,
                    subtitle: homeAssistantSummary,
                    systemImage: SyncPlatform.homeAssistant.symbolName,
                    tint: SyncPlatform.homeAssistant.tint,
                    warning: hasDisconnectedServer
                )
            }
        } header: {
            Text("Your Homes")
        } footer: {
            Text("Open either side to see what it holds. You choose which pair to sync on the Sync tab.")
        }
    }

    private var appleHomeSummary: String {
        guard isHomeKitAuthorized else { return "No access yet" }
        guard !homes.isEmpty else { return "No homes yet — open Apple Home once" }
        let devices = homes.reduce(0) { $0 + $1.accessories.count }
        return "\(homes.count) home\(homes.count == 1 ? "" : "s") · \(devices) device\(devices == 1 ? "" : "s")"
    }

    private var homeAssistantSummary: String {
        guard !connections.isEmpty else { return "No servers yet" }
        let connected = connections.filter(\.state.isConnected).count
        let servers = "\(connections.count) server\(connections.count == 1 ? "" : "s")"
        if connected == connections.count {
            return connections.count == 1 ? "\(servers) · connected" : "\(servers) · all connected"
        }
        return "\(servers) · \(connected) connected"
    }

    private var hasDisconnectedServer: Bool {
        connections.contains { !$0.state.isConnected }
    }

    // MARK: Tools

    private var toolsSection: some View {
        Section {
            NavigationLink(value: HomeRoute.localAPI) {
                LabeledContent {
                    Text(isServerRunning ? "On" : "Off")
                } label: {
                    BridgeNavigationRow(
                        title: "Local API",
                        subtitle: isServerRunning ? "Port \(String(serverPort))" : nil,
                        systemImage: "point.3.connected.trianglepath.dotted",
                        tint: .indigo
                    )
                }
            }

            if supportsScheduledActions {
                NavigationLink(value: HomeRoute.scheduledActions) {
                    LabeledContent {
                        Text(scheduleCount == 0 ? "None" : scheduleCount.formatted())
                    } label: {
                        BridgeNavigationRow(
                            title: "Scheduled Syncs",
                            systemImage: "clock.arrow.circlepath",
                            tint: .teal
                        )
                    }
                }
            }
        } header: {
            Text("Tools")
        } footer: {
            Text(supportsScheduledActions
                 ? "The local API drives Apple Home from your own scripts. Scheduled syncs repeat daily while this Mac is awake and the app is open."
                 : "The local API drives Apple Home from your own scripts and automations.")
        }
    }
}

// MARK: - Settings

/// The setup guide, the tip jar and the small print, behind the gear on Home.
struct SettingsContent: View {
    var tipProduct: TipProduct?
    var tipState: TipState = .idle
    var appVersion: String = ""
    var onTip: () -> Void = {}
    var onShowSetupAgain: () -> Void = {}

    var body: some View {
        List {
            Section {
                Button(action: onShowSetupAgain) {
                    Label("Show Setup Guide Again", systemImage: "list.number")
                }
            } footer: {
                Text("Walks through how the two sides are paired, and where the address and token go.")
            }

            supportSection
            aboutSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        #if !targetEnvironment(macCatalyst)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var supportSection: some View {
        Section {
            Button(action: onTip) {
                LabeledContent {
                    if tipState == .purchasing {
                        ProgressView()
                    } else if let tipProduct {
                        Text(tipProduct.displayPrice)
                    }
                } label: {
                    Label {
                        Text(tipState == .thanks ? "Tip Sent" : "Tip the Developer")
                    } icon: {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.pink)
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

    private var aboutSection: some View {
        Section {
            if !appVersion.isEmpty {
                LabeledContent("Version", value: appVersion)
            }

            Link(destination: URL(string: "https://github.com/bgoncal/HomeKit-Sync-Assistant")!) {
                Label("Source on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
            }

            Link(destination: URL(string: "https://x.com/bgoncal2")!) {
                Label("@bgoncal2 on X", systemImage: "at")
            }
        } header: {
            Text("About")
        } footer: {
            Text("Home Sync Assistant is open source.")
        }
    }
}

extension Bundle {
    /// "1.2 (21)", for the About section.
    var appVersionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = infoDictionary?["CFBundleVersion"] as? String ?? ""
        guard !version.isEmpty else { return "" }
        return build.isEmpty ? version : "\(version) (\(build))"
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

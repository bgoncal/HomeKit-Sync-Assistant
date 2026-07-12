import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var homeKitManager: HomeKitManager
    @EnvironmentObject private var syncEngine: SyncEngine
    @EnvironmentObject private var logStore: LogStore
    @EnvironmentObject private var wsClient: HAWebSocketClient
    @EnvironmentObject private var server: HTTPServer

    #if os(macOS) || targetEnvironment(macCatalyst)
    @State private var selectedSection: SidebarSection? = .dashboard
    @State private var isActivityPresented = true
    #endif

    var body: some View {
        #if os(macOS) || targetEnvironment(macCatalyst)
        NavigationSplitView {
            List(selection: $selectedSection) {
                ForEach(SidebarSection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .navigationTitle("HomeKit Bridge")
        } detail: {
            selectedSectionView
                .toolbar {
                    Button {
                        isActivityPresented.toggle()
                    } label: {
                        Label("Activity", systemImage: "clock")
                    }
                }
        }
        .inspector(isPresented: $isActivityPresented) {
            LogsView()
                .inspectorColumnWidth(min: 360, ideal: 420, max: 560)
        }
        #else
        TabView {
            primaryTabItems

            LogsView()
                .tabItem {
                    Label("Activity", systemImage: "clock")
                }
        }
        #endif
    }

    #if os(macOS) || targetEnvironment(macCatalyst)
    @ViewBuilder
    private var selectedSectionView: some View {
        switch selectedSection ?? .dashboard {
        case .dashboard:
            DashboardView()
        case .devices:
            DevicesView()
        case .sync:
            SyncView()
        case .actions:
            ActionsView()
        case .endpoints:
            EndpointsView()
        case .settings:
            SettingsView()
        }
    }
    #endif

    @ViewBuilder
    private var primaryTabItems: some View {
        DashboardView()
            .tabItem {
                Label("Dashboard", systemImage: "house")
            }

        DevicesView()
            .tabItem {
                Label("Devices", systemImage: "sensor.tag.radiowaves.forward")
            }

        SyncView()
            .tabItem {
                Label("Sync", systemImage: "arrow.triangle.2.circlepath")
            }

        ActionsView()
            .tabItem {
                Label("Actions", systemImage: "bolt.badge.clock")
            }

        EndpointsView()
            .tabItem {
                Label("Local API", systemImage: "point.3.connected.trianglepath.dotted")
            }

        SettingsView()
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
    }
}

#if os(macOS) || targetEnvironment(macCatalyst)
private enum SidebarSection: String, CaseIterable, Identifiable {
    case dashboard
    case devices
    case sync
    case actions
    case endpoints
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .devices: return "Devices"
        case .sync: return "Sync"
        case .actions: return "Actions"
        case .endpoints: return "Local API"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "house"
        case .devices: return "sensor.tag.radiowaves.forward"
        case .sync: return "arrow.triangle.2.circlepath"
        case .actions: return "bolt.badge.clock"
        case .endpoints: return "point.3.connected.trianglepath.dotted"
        case .settings: return "gearshape"
        }
    }
}
#endif

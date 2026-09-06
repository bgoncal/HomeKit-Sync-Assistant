import SwiftUI

struct MainTabView: View {
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
            .navigationTitle("Home Sync Assistant")
        } detail: {
            NavigationStack {
                selectedSectionView
            }
            .toolbar {
                Button {
                    isActivityPresented.toggle()
                } label: {
                    Label("Activity", systemImage: "clock")
                }
                .help("Show what the bridge has done")
            }
        }
        .inspector(isPresented: $isActivityPresented) {
            NavigationStack {
                LogsView()
            }
            .inspectorColumnWidth(min: 320, ideal: 380, max: 520)
        }
        #else
        TabView {
            NavigationStack { DashboardView() }
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }

            DevicesView()
                .tabItem { Label("Devices", systemImage: "sensor") }

            NavigationStack { SyncView() }
                .tabItem { Label("Sync", systemImage: "arrow.triangle.2.circlepath") }

            NavigationStack { LogsView() }
                .tabItem { Label("Activity", systemImage: "list.bullet.rectangle") }

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
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
        case .dashboard: return "square.grid.2x2"
        case .devices: return "sensor"
        case .sync: return "arrow.triangle.2.circlepath"
        case .actions: return "clock.arrow.circlepath"
        case .endpoints: return "point.3.connected.trianglepath.dotted"
        case .settings: return "gearshape"
        }
    }
}
#endif

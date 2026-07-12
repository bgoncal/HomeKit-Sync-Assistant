import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var homeKitManager: HomeKitManager
    @EnvironmentObject private var syncEngine: SyncEngine
    @EnvironmentObject private var logStore: LogStore
    @EnvironmentObject private var wsClient: HAWebSocketClient
    @EnvironmentObject private var server: HTTPServer

    var body: some View {
        #if os(macOS)
        HSplitView {
            TabView {
                primaryTabItems
            }
            .frame(minWidth: 420, idealWidth: 620)

            LogsView()
                .frame(minWidth: 360, idealWidth: 460)
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

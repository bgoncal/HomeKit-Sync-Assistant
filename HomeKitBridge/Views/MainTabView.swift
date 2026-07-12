import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var homeKitManager: HomeKitManager
    @EnvironmentObject private var syncEngine: SyncEngine
    @EnvironmentObject private var logStore: LogStore
    @EnvironmentObject private var wsClient: HAWebSocketClient
    @EnvironmentObject private var server: HTTPServer

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house")
                }

            SyncView()
                .tabItem {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                }

            LogsView()
                .tabItem {
                    Label("Logs", systemImage: "doc.text.magnifyingglass")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

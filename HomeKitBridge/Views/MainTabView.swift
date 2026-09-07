import SwiftUI

struct MainTabView: View {
    #if os(macOS) || targetEnvironment(macCatalyst)
    @State private var selectedSection: SidebarSection? = .home
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
            selectedSectionView
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
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }

            NavigationStack { SyncView() }
                .tabItem { Label("Sync", systemImage: "arrow.triangle.2.circlepath") }

            NavigationStack { LogsView() }
                .tabItem { Label("Activity", systemImage: "list.bullet.rectangle") }
        }
        #endif
    }

    #if os(macOS) || targetEnvironment(macCatalyst)
    @ViewBuilder
    private var selectedSectionView: some View {
        switch selectedSection ?? .home {
        case .home:
            // HomeView brings its own stack; the others need one for their titles.
            HomeView()
        case .sync:
            NavigationStack { SyncView() }
        case .actions:
            NavigationStack { ActionsView() }
        }
    }
    #endif
}

#if os(macOS) || targetEnvironment(macCatalyst)
private enum SidebarSection: String, CaseIterable, Identifiable {
    case home
    case sync
    case actions

    var id: Self { self }

    var title: String {
        switch self {
        case .home: return "Home"
        case .sync: return "Sync"
        case .actions: return "Scheduled Syncs"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house"
        case .sync: return "arrow.triangle.2.circlepath"
        case .actions: return "clock.arrow.circlepath"
        }
    }
}
#endif

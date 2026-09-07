import SwiftUI

struct ActionsView: View {
    @EnvironmentObject private var scheduledActionManager: ScheduledActionManager
    @EnvironmentObject private var homeKitManager: HomeKitManager
    @EnvironmentObject private var connections: ConnectionStore

    var body: some View {
        ActionsContent(
            schedules: scheduledActionManager.schedules,
            homes: homeKitManager.homes,
            servers: connections.servers,
            suggestedServerIds: Dictionary(
                uniqueKeysWithValues: homeKitManager.homes.map { home in
                    (home.id, connections.suggestedServer(forHomeId: home.id)?.id)
                }
            ),
            onAdd: { scheduledActionManager.addSchedule() },
            onUpdate: { scheduledActionManager.updateSchedule($0) },
            onDelete: { schedule in
                guard let index = scheduledActionManager.schedules.firstIndex(where: { $0.id == schedule.id }) else { return }
                scheduledActionManager.deleteSchedules(at: IndexSet(integer: index))
            }
        )
    }
}

/// Daily, unattended repeats of one sync direction — one grouped section each,
/// the way Settings shows a repeating rule.
struct ActionsContent: View {
    let schedules: [ScheduledAction]
    var homes: [HomeSummary] = []
    var servers: [HomeAssistantServer] = []
    /// The server last used with each home, offered when a schedule has no choice yet.
    var suggestedServerIds: [String: UUID?] = [:]
    var onAdd: () -> Void = {}
    var onUpdate: (ScheduledAction) -> Void = { _ in }
    var onDelete: (ScheduledAction) -> Void = { _ in }

    var body: some View {
        List {
            if !schedules.isEmpty {
                Section {
                    EmptyView()
                } footer: {
                    Text("A scheduled action applies its changes automatically, with no preview. Run the same direction on the Sync screen first, so you know what it will do.")
                }
            }

            ForEach(schedules) { schedule in
                section(for: schedule)
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if schedules.isEmpty {
                ContentUnavailableView {
                    Label("No Scheduled Actions", systemImage: "clock.badge.plus")
                } description: {
                    Text("Repeat a sync every day at a set time, while this Mac is awake and the app is open.")
                } actions: {
                    Button("Add Action", action: onAdd)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Actions")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Action", systemImage: "plus", action: onAdd)
            }
        }
    }

    private func section(for schedule: ScheduledAction) -> some View {
        let binding = binding(for: schedule)

        return Section {
            Toggle("Enabled", isOn: binding.isEnabled)

            Picker("Apple Home", selection: Binding(
                get: { resolvedHomeId(for: schedule) },
                set: { binding.wrappedValue.homeId = $0 }
            )) {
                if homes.isEmpty {
                    Text("None").tag("")
                }
                ForEach(homes) { home in
                    Text(home.name).tag(home.id)
                }
            }
            .disabled(!schedule.isEnabled || homes.isEmpty)

            Picker(SyncPlatform.homeAssistant.name, selection: Binding(
                get: { resolvedServerId(for: schedule) },
                set: { binding.wrappedValue.serverId = $0 }
            )) {
                if servers.isEmpty {
                    Text("None").tag(UUID?.none)
                }
                ForEach(servers) { server in
                    Text(server.name).tag(UUID?.some(server.id))
                }
            }
            .disabled(!schedule.isEnabled || servers.isEmpty)

            DatePicker(
                "Time",
                selection: timeBinding(for: binding),
                displayedComponents: .hourAndMinute
            )
            .disabled(!schedule.isEnabled)

            Picker("Sync", selection: binding.operationRawValue) {
                Section(SyncDirection.homeAssistantToAppleHome.label) {
                    ForEach(SyncOperation.allCases.filter { $0.direction == .homeAssistantToAppleHome }) { operation in
                        Text(operation.shortTitle).tag(operation.rawValue)
                    }
                }
                Section(SyncDirection.appleHomeToHomeAssistant.label) {
                    ForEach(SyncOperation.allCases.filter { $0.direction == .appleHomeToHomeAssistant }) { operation in
                        Text(operation.shortTitle).tag(operation.rawValue)
                    }
                }
            }
            .disabled(!schedule.isEnabled)

            if let operation = schedule.operation {
                LabeledContent {
                    BridgeDirectionBadge(direction: operation.direction)
                } label: {
                    Text("Direction")
                }
            }

            Button("Delete Action", role: .destructive) {
                onDelete(schedule)
            }
        } header: {
            Text(schedule.operation?.shortTitle ?? "Action Unavailable")
        } footer: {
            Text(summary(for: schedule))
        }
    }

    private func resolvedHomeId(for schedule: ScheduledAction) -> String {
        if !schedule.homeId.isEmpty, homes.contains(where: { $0.id == schedule.homeId }) {
            return schedule.homeId
        }
        return homes.first?.id ?? ""
    }

    private func homeName(for schedule: ScheduledAction) -> String? {
        homes.first { $0.id == resolvedHomeId(for: schedule) }?.name
    }

    private func resolvedServerId(for schedule: ScheduledAction) -> UUID? {
        if let chosen = schedule.serverId, servers.contains(where: { $0.id == chosen }) {
            return chosen
        }
        return (suggestedServerIds[resolvedHomeId(for: schedule)] ?? nil) ?? servers.first?.id
    }

    private func serverName(for schedule: ScheduledAction) -> String? {
        servers.first { $0.id == resolvedServerId(for: schedule) }?.name
    }

    private func summary(for schedule: ScheduledAction) -> String {
        let action = schedule.operation?.displayTitle ?? "Pick a direction before this action can run."
        let destination: String
        switch schedule.operation?.direction.destination {
        case .appleHome: destination = homeName(for: schedule) ?? SyncPlatform.appleHome.name
        case .homeAssistant: destination = serverName(for: schedule) ?? SyncPlatform.homeAssistant.name
        case nil: destination = "the other side"
        }
        let time = date(forMinutesAfterMidnight: schedule.timeMinutes)
            .formatted(date: .omitted, time: .shortened)

        guard schedule.isEnabled else {
            return "\(action). Paused — it was set to run daily at \(time)."
        }
        if serverName(for: schedule) == nil {
            return "\(action). It cannot run until a Home Assistant is chosen for it."
        }
        return "\(action). Every day at \(time), changes are applied in \(destination) while the app is open."
    }

    private func binding(for schedule: ScheduledAction) -> Binding<ScheduledAction> {
        Binding(
            get: { schedules.first(where: { $0.id == schedule.id }) ?? schedule },
            set: { onUpdate($0) }
        )
    }

    private func timeBinding(for schedule: Binding<ScheduledAction>) -> Binding<Date> {
        Binding(
            get: { date(forMinutesAfterMidnight: schedule.wrappedValue.timeMinutes) },
            set: { schedule.wrappedValue.timeMinutes = minutesAfterMidnight(for: $0) }
        )
    }

    private func date(forMinutesAfterMidnight minutes: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = minutes / 60
        components.minute = minutes % 60
        components.second = 0
        return calendar.date(from: components) ?? Date()
    }

    private func minutesAfterMidnight(for date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}

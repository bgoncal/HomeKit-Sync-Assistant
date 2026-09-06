import SwiftUI

struct ActionsView: View {
    @EnvironmentObject private var scheduledActionManager: ScheduledActionManager

    var body: some View {
        ActionsContent(
            schedules: scheduledActionManager.schedules,
            onAdd: { scheduledActionManager.addSchedule() },
            onUpdate: { scheduledActionManager.updateSchedule($0) },
            onDelete: { schedule in
                guard let index = scheduledActionManager.schedules.firstIndex(where: { $0.id == schedule.id }) else { return }
                scheduledActionManager.deleteSchedules(at: IndexSet(integer: index))
            }
        )
    }
}

/// Daily, unattended repeats of a sync direction.
struct ActionsContent: View {
    let schedules: [ScheduledAction]
    var onAdd: () -> Void = {}
    var onUpdate: (ScheduledAction) -> Void = { _ in }
    var onDelete: (ScheduledAction) -> Void = { _ in }

    var body: some View {
        BridgePage(
            title: "Actions",
            subtitle: "Repeat a sync every day at a set time, without opening the app."
        ) {
            overviewCard

            if schedules.isEmpty {
                BridgeCard {
                    ContentUnavailableView(
                        "No scheduled actions",
                        systemImage: "clock.badge.plus",
                        description: Text("Add an action, choose a time, and pick which direction it should sync.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(schedules) { schedule in
                        ScheduledActionCard(
                            schedule: binding(for: schedule),
                            onDelete: { onDelete(schedule) }
                        )
                    }
                }
            }
        }
    }

    private var overviewCard: some View {
        BridgeCard {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    overviewHeader
                    Spacer(minLength: 12)
                    addButton
                }
                VStack(alignment: .leading, spacing: 12) {
                    overviewHeader
                    addButton
                }
            }

            Label("A scheduled action applies its changes automatically — there is no preview step. Run the same direction manually on the Sync screen first, so you know what it will do.", systemImage: "exclamationmark.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var overviewHeader: some View {
        BridgeStatusHeader(
            title: "Runs without asking",
            message: overviewMessage,
            systemImage: "clock.arrow.circlepath",
            tint: .blue
        )
    }

    private var addButton: some View {
        Button(action: onAdd) {
            Label("Add Action", systemImage: "plus.circle")
        }
        .buttonStyle(.borderedProminent)
        .fixedSize()
    }

    private var overviewMessage: String {
        let enabledCount = schedules.filter(\.isEnabled).count
        let totalCount = schedules.count

        if totalCount == 0 {
            return "Nothing is scheduled yet. The app only syncs when you ask it to."
        }
        if enabledCount == totalCount {
            return "\(totalCount) scheduled action\(totalCount == 1 ? "" : "s") will run daily while the app is open."
        }
        return "\(enabledCount) of \(totalCount) scheduled actions will run daily while the app is open."
    }

    private func binding(for schedule: ScheduledAction) -> Binding<ScheduledAction> {
        Binding(
            get: { schedules.first(where: { $0.id == schedule.id }) ?? schedule },
            set: { onUpdate($0) }
        )
    }
}

private struct ScheduledActionCard: View {
    @Binding var schedule: ScheduledAction
    let onDelete: () -> Void

    private var operation: SyncOperation? { schedule.operation }

    var body: some View {
        BridgeCard {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: schedule.isEnabled ? "clock.badge.checkmark" : "clock.badge.xmark")
                    .font(.title3)
                    .foregroundStyle(schedule.isEnabled ? Color.green : Color.secondary)

                Text(operation?.displayTitle ?? "Action unavailable")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Toggle("Enabled", isOn: $schedule.isEnabled)
                    .labelsHidden()

                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
            }

            if let operation {
                BridgeDirectionBadge(direction: operation.direction)
            }

            Text(scheduleSummary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    Label("Runs at", systemImage: "clock")
                        .foregroundStyle(.secondary)
                    DatePicker("Runs at", selection: scheduledTimeBinding, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .disabled(!schedule.isEnabled)
                }

                GridRow(alignment: .firstTextBaseline) {
                    Label("Syncs", systemImage: "arrow.left.arrow.right")
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.leading)
                    VStack(alignment: .leading, spacing: 6) {
                        Picker("Syncs", selection: $schedule.operationRawValue) {
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
                        .labelsHidden()
                        .disabled(!schedule.isEnabled)

                        Text(operation?.description ?? "Pick a direction before this action can run.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .opacity(schedule.isEnabled ? 1 : 0.72)
    }

    private var scheduleSummary: String {
        let destination = operation?.direction.destination.name ?? "the other side"
        if schedule.isEnabled {
            return "Every day at \(timeText), changes are applied in \(destination)."
        }
        return "Paused. It was set to run daily at \(timeText)."
    }

    private var timeText: String {
        date(forMinutesAfterMidnight: schedule.timeMinutes)
            .formatted(date: .omitted, time: .shortened)
    }

    private var scheduledTimeBinding: Binding<Date> {
        Binding(
            get: { date(forMinutesAfterMidnight: schedule.timeMinutes) },
            set: { schedule.timeMinutes = minutesAfterMidnight(for: $0) }
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

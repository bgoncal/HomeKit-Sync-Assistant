import SwiftUI

struct ActionsView: View {
    @EnvironmentObject private var scheduledActionManager: ScheduledActionManager

    var body: some View {
        BridgePage(
            title: "Actions",
            subtitle: "Schedule sync actions to run automatically at specific times."
        ) {
            actionsOverview

            if scheduledActionManager.schedules.isEmpty {
                BridgeCard {
                    ContentUnavailableView(
                        "No Scheduled Actions",
                        systemImage: "clock.badge.plus",
                        description: Text("Add an action, choose when it runs, and select the sync operation to perform.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(scheduledActionManager.schedules) { schedule in
                        ScheduledActionCard(
                            schedule: binding(for: schedule),
                            operationTitle: operationTitle,
                            operationDescription: operationDescription,
                            onDelete: { deleteSchedule(schedule) }
                        )
                    }
                }
            }
        }
    }

    private var actionsOverview: some View {
        BridgeCard {
            HStack(alignment: .center, spacing: 12) {
                BridgeStatusHeader(
                    title: "Scheduled Actions",
                    message: overviewMessage,
                    systemImage: "clock.arrow.circlepath",
                    tint: .blue
                )

                Spacer(minLength: 12)

                Button {
                    scheduledActionManager.addSchedule()
                } label: {
                    Label("Add Action", systemImage: "plus.circle")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var overviewMessage: String {
        let enabledCount = scheduledActionManager.schedules.filter(\.isEnabled).count
        let totalCount = scheduledActionManager.schedules.count

        if totalCount == 0 {
            return "No actions are scheduled yet."
        }

        if enabledCount == totalCount {
            return "\(totalCount) scheduled action\(totalCount == 1 ? "" : "s") enabled."
        }

        return "\(enabledCount) of \(totalCount) scheduled actions enabled."
    }

    private func binding(for schedule: ScheduledAction) -> Binding<ScheduledAction> {
        Binding(
            get: {
                scheduledActionManager.schedules.first(where: { $0.id == schedule.id }) ?? schedule
            },
            set: { updatedSchedule in
                scheduledActionManager.updateSchedule(updatedSchedule)
            }
        )
    }

    private func deleteSchedule(_ schedule: ScheduledAction) {
        guard let index = scheduledActionManager.schedules.firstIndex(where: { $0.id == schedule.id }) else { return }
        scheduledActionManager.deleteSchedules(at: IndexSet(integer: index))
    }

    private func operationTitle(_ operation: SyncOperation) -> String {
        operation.displayTitle
    }

    private func operationDescription(_ operation: SyncOperation) -> String {
        operation.description
    }
}

private struct ScheduledActionCard: View {
    @Binding var schedule: ScheduledAction
    let operationTitle: (SyncOperation) -> String
    let operationDescription: (SyncOperation) -> String
    let onDelete: () -> Void

    private var selectedOperationTitle: String {
        schedule.operation.map(operationTitle) ?? "Unavailable action"
    }

    private var selectedOperationDescription: String {
        schedule.operation.map(operationDescription) ?? "Choose a valid action before this schedule can run."
    }

    var body: some View {
        BridgeCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: schedule.isEnabled ? "clock.badge.checkmark" : "clock.badge.xmark")
                    .font(.title3)
                    .foregroundStyle(schedule.isEnabled ? .green : .secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedOperationTitle)
                        .font(.headline)
                    Text(scheduleSummary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(selectedOperationDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Toggle("Enabled", isOn: $schedule.isEnabled)
                    .labelsHidden()

                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    Label("Time", systemImage: "clock")
                        .foregroundStyle(.secondary)
                    DatePicker("Time", selection: scheduledTimeBinding, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .disabled(!schedule.isEnabled)
                }

                GridRow {
                    Label("Action", systemImage: "bolt")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Picker("Action", selection: $schedule.operationRawValue) {
                            ForEach(SyncOperation.allCases) { operation in
                                Text(operationTitle(operation)).tag(operation.rawValue)
                            }
                        }
                        .disabled(!schedule.isEnabled)

                        Text(selectedOperationDescription)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .opacity(schedule.isEnabled ? 1 : 0.72)
    }

    private var scheduleSummary: String {
        if schedule.isEnabled {
            return "Runs daily at \(timeText)."
        }

        return "Disabled. Last configured for \(timeText)."
    }

    private var timeText: String {
        dateForScheduledAction(minutesAfterMidnight: schedule.timeMinutes)
            .formatted(date: .omitted, time: .shortened)
    }

    private var scheduledTimeBinding: Binding<Date> {
        Binding(
            get: {
                dateForScheduledAction(minutesAfterMidnight: schedule.timeMinutes)
            },
            set: { newDate in
                schedule.timeMinutes = minutesAfterMidnight(for: newDate)
            }
        )
    }

    private func dateForScheduledAction(minutesAfterMidnight: Int) -> Date {
        let calendar = Calendar.current
        let hour = minutesAfterMidnight / 60
        let minute = minutesAfterMidnight % 60
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? Date()
    }

    private func minutesAfterMidnight(for date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}

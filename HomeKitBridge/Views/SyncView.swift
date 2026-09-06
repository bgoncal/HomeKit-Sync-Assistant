import SwiftUI

struct SyncView: View {
    @EnvironmentObject private var homeKitManager: HomeKitManager
    @EnvironmentObject private var syncEngine: SyncEngine

    @State private var operation: SyncOperation = .devicePlacementHAToHome
    @State private var dryRunResult: DryRunResult?
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        SyncContent(
            homes: homeKitManager.homes,
            selectedHomeId: homeKitManager.selectedHome?.id,
            operation: $operation,
            dryRunResult: dryRunResult,
            progress: syncEngine.progress,
            errorMessage: errorMessage,
            isWorking: isWorking,
            onSelectHome: { homeId in
                homeKitManager.selectHome(id: homeId)
                dryRunResult = nil
            },
            onPreview: { Task { await runDryRun() } },
            onApply: { Task { await apply() } }
        )
        .onChange(of: operation) { _, _ in
            dryRunResult = nil
            errorMessage = nil
        }
    }

    private func runDryRun() async {
        isWorking = true
        errorMessage = nil
        dryRunResult = nil
        defer { isWorking = false }

        do {
            dryRunResult = try await syncEngine.dryRun(operation)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply() async {
        guard let dryRunResult else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await syncEngine.execute(dryRunResult)
            self.dryRunResult = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Picking a direction, previewing the plan, and applying it.
struct SyncContent: View {
    let homes: [HomeSummary]
    let selectedHomeId: String?
    @Binding var operation: SyncOperation
    let dryRunResult: DryRunResult?
    let progress: SyncProgress?
    let errorMessage: String?
    let isWorking: Bool
    var onSelectHome: (String) -> Void = { _ in }
    var onPreview: () -> Void = {}
    var onApply: () -> Void = {}

    private var hasHome: Bool { selectedHomeId != nil }

    var body: some View {
        BridgePage(
            title: "Sync",
            subtitle: "Choose which side to copy from. Nothing is written until you apply the preview."
        ) {
            planCard
            statusSection
            previewSection
        }
    }

    // MARK: Plan

    private var planCard: some View {
        BridgeCard {
            homePicker

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("What to sync")
                    .font(.headline)

                Picker("What to sync", selection: $operation) {
                    Section(SyncDirection.homeAssistantToAppleHome.label) {
                        ForEach(SyncOperation.allCases.filter { $0.direction == .homeAssistantToAppleHome }) { operation in
                            Text(operation.shortTitle).tag(operation)
                        }
                    }
                    Section(SyncDirection.appleHomeToHomeAssistant.label) {
                        ForEach(SyncOperation.allCases.filter { $0.direction == .appleHomeToHomeAssistant }) { operation in
                            Text(operation.shortTitle).tag(operation)
                        }
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .disabled(isWorking)
            }

            VStack(alignment: .leading, spacing: 10) {
                BridgeDirectionBadge(direction: operation.direction)

                Text(operation.displayTitle)
                    .font(.headline)

                Text(operation.description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Label(operation.direction.explanation, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack(spacing: 12) {
                Button(action: onPreview) {
                    Label("Preview Changes", systemImage: "list.bullet.clipboard")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isWorking || !hasHome)

                Button(action: onApply) {
                    Label(applyTitle, systemImage: "checkmark.circle")
                }
                .buttonStyle(.bordered)
                .disabled(isWorking || !hasApplicableChanges || !hasHome)
            }

            if !hasHome {
                Label("Pick an Apple Home first. If the list is empty, grant HomeKit access on the Dashboard.", systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var applyTitle: String {
        guard let dryRunResult, !dryRunResult.changes.isEmpty else {
            return "Apply to \(operation.direction.destination.name)"
        }
        let count = dryRunResult.changes.count
        return "Apply \(count) Change\(count == 1 ? "" : "s") to \(dryRunResult.operation.direction.destination.name)"
    }

    private var hasApplicableChanges: Bool {
        guard let dryRunResult else { return false }
        return !dryRunResult.changes.isEmpty
    }

    private var homePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Apple Home to sync")
                .font(.headline)

            Picker("Apple Home to sync", selection: Binding(
                get: { selectedHomeId ?? "" },
                set: { onSelectHome($0) }
            )) {
                if homes.isEmpty {
                    Text("No Apple homes found").tag("")
                } else {
                    ForEach(homes) { home in
                        Text(home.name).tag(home.id)
                    }
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .disabled(isWorking || homes.isEmpty)
        }
    }

    // MARK: Status

    @ViewBuilder
    private var statusSection: some View {
        if let progress {
            progressCard(progress)
        }

        if let errorMessage {
            BridgeCard {
                BridgeStatusHeader(
                    title: "Sync stopped",
                    message: errorMessage,
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .red
                )
            }
        }
    }

    private func progressCard(_ progress: SyncProgress) -> some View {
        BridgeCard {
            VStack(alignment: .leading, spacing: 2) {
                Text(progress.title)
                    .font(.headline)
                if let detail = progress.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if let fractionCompleted = progress.fractionCompleted {
                ProgressView(value: fractionCompleted)
                if let completed = progress.completed, let total = progress.total {
                    Text("\(completed) of \(total)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: Preview

    @ViewBuilder
    private var previewSection: some View {
        if let dryRunResult {
            BridgeCard {
                BridgeStatusHeader(
                    title: dryRunResult.changes.isEmpty ? "Already in sync" : "Preview of what will change",
                    message: dryRunResult.summary,
                    systemImage: dryRunResult.changes.isEmpty ? "checkmark.circle.fill" : "list.bullet.clipboard.fill",
                    tint: dryRunResult.changes.isEmpty ? .green : .orange
                )
                BridgeDirectionBadge(direction: dryRunResult.operation.direction)
            }

            if !dryRunResult.changes.isEmpty {
                LazyVStack(spacing: 12) {
                    ForEach(dryRunResult.changes) { change in
                        BridgeCard {
                            changeRow(change)
                        }
                    }
                }
            }
        } else {
            BridgeCard {
                ContentUnavailableView(
                    "No preview yet",
                    systemImage: "list.bullet.clipboard",
                    description: Text("Preview first to see every change the bridge would make in \(operation.direction.destination.name).")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
    }

    private func changeRow(_ change: SyncChange) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon(for: change.action))
                    .foregroundStyle(iconColor(for: change.action))
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 4) {
                    Text(change.title)
                        .font(.headline)
                    Text(change.details)
                        .foregroundStyle(.secondary)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            if hasTechnicalDetails(change) {
                DisclosureGroup("Technical details") {
                    VStack(spacing: 6) {
                        if let accessoryId = change.accessoryId {
                            BridgeInfoRow(label: "Device", value: accessoryId, selectable: true)
                        }
                        if let roomId = change.roomId {
                            BridgeInfoRow(label: "Room", value: roomId, selectable: true)
                        }
                        if let homeId = change.homeId {
                            BridgeInfoRow(label: "Home", value: homeId, selectable: true)
                        }
                        if let extraData = change.extraData {
                            ForEach(extraData.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                BridgeInfoRow(label: key, value: value, selectable: true)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .font(.callout)
            }
        }
    }

    private func hasTechnicalDetails(_ change: SyncChange) -> Bool {
        change.accessoryId != nil || change.roomId != nil || change.homeId != nil || change.extraData?.isEmpty == false
    }

    private func icon(for action: SyncActionType) -> String {
        switch action {
        case .createRoom: return "plus.square"
        case .renameRoom: return "text.cursor"
        case .moveAccessory: return "arrow.left.arrow.right"
        case .renameAccessory: return "pencil"
        case .unsupported: return "exclamationmark.triangle"
        }
    }

    private func iconColor(for action: SyncActionType) -> Color {
        switch action {
        case .createRoom: return .green
        case .renameRoom: return .orange
        case .moveAccessory: return .blue
        case .renameAccessory: return .purple
        case .unsupported: return .red
        }
    }
}

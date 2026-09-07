import SwiftUI

struct SyncView: View {
    @EnvironmentObject private var homeKitManager: HomeKitManager
    @EnvironmentObject private var syncEngine: SyncEngine
    @EnvironmentObject private var connections: ConnectionStore

    @State private var operation: SyncOperation = .devicePlacementHAToHome
    @State private var dryRunResult: DryRunResult?
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var selectedHome: HomeSummary? { homeKitManager.selectedHome }

    var body: some View {
        SyncContent(
            homes: homeKitManager.homes,
            selectedHomeId: selectedHome?.id,
            serverName: selectedHome.flatMap { connections.server(forHomeId: $0.id)?.name },
            serverState: selectedHome.flatMap { connections.state(forHomeId: $0.id) },
            operation: $operation,
            dryRunResult: dryRunResult,
            progress: syncEngine.progress,
            errorMessage: errorMessage,
            isWorking: isWorking,
            onSelectHome: { homeId in
                homeKitManager.selectHome(id: homeId)
                dryRunResult = nil
                errorMessage = nil
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
        guard let homeId = selectedHome?.id else { return }
        isWorking = true
        errorMessage = nil
        dryRunResult = nil
        defer { isWorking = false }

        do {
            dryRunResult = try await syncEngine.dryRun(operation, homeId: homeId)
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

/// Pick a direction, preview the plan, then apply it.
struct SyncContent: View {
    let homes: [HomeSummary]
    let selectedHomeId: String?
    /// The Home Assistant paired with the selected home, if there is one.
    var serverName: String?
    var serverState: ServerConnectionState?
    @Binding var operation: SyncOperation
    let dryRunResult: DryRunResult?
    let progress: SyncProgress?
    let errorMessage: String?
    let isWorking: Bool
    var onSelectHome: (String) -> Void = { _ in }
    var onPreview: () -> Void = {}
    var onApply: () -> Void = {}

    private var hasHome: Bool { selectedHomeId != nil || !homes.isEmpty }
    private var isLinked: Bool { serverName != nil }

    var body: some View {
        List {
            planSection
            actionsSection

            if let progress {
                progressSection(progress)
            }

            if let errorMessage {
                Section {
                    BridgeStatusRow(
                        title: "Sync Stopped",
                        message: errorMessage,
                        systemImage: "exclamationmark.triangle.fill",
                        tint: .red
                    )
                }
            }

            previewSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Sync")
    }

    // MARK: Plan

    private var planSection: some View {
        Section {
            Picker("Apple Home", selection: Binding(
                get: { selectedHomeId ?? "" },
                set: { onSelectHome($0) }
            )) {
                if homes.isEmpty {
                    Text("None").tag("")
                }
                ForEach(homes) { home in
                    Text(home.name).tag(home.id)
                }
            }
            .disabled(isWorking || homes.isEmpty)

            LabeledContent(SyncPlatform.homeAssistant.name) {
                if let serverName {
                    BridgePill(
                        title: serverName,
                        systemImage: serverState?.isConnected == true ? "checkmark.circle.fill" : SyncPlatform.homeAssistant.symbolName,
                        tint: serverState?.isConnected == true ? .green : SyncPlatform.homeAssistant.tint
                    )
                } else {
                    BridgePill(title: "Not Linked", systemImage: "link.badge.plus", tint: .orange)
                }
            }

            Picker("Sync", selection: $operation) {
                ForEach(SyncSubject.allCases) { subject in
                    Text(subject.title).tag(operation.direction.operation(for: subject))
                }
            }
            .disabled(isWorking)

            // One tap turns the sync around; the direction is the thing people get
            // wrong, so it is a control, not a label.
            Button {
                operation = operation.inverted
            } label: {
                LabeledContent {
                    HStack(spacing: 10) {
                        BridgeDirectionBadge(direction: operation.direction)
                        Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)
                    }
                } label: {
                    Text("Direction")
                        .foregroundStyle(.primary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isWorking)
            .accessibilityLabel("Direction: from \(operation.direction.source.name) to \(operation.direction.destination.name)")
            .accessibilityHint("Double tap to sync the other way")
            .accessibilityAddTraits(.isButton)

            Text(operation.displayTitle)
                .font(.subheadline.weight(.semibold))
        } header: {
            Text("Plan")
        } footer: {
            Text(operation.description)
        }
    }

    // MARK: Actions

    private var actionsSection: some View {
        Section {
            Button(action: onPreview) {
                HStack {
                    Label("Preview Changes", systemImage: "list.bullet.clipboard")
                    if isWorking {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isWorking || !hasHome || !isLinked)

            Button(action: onApply) {
                Label(applyTitle, systemImage: "checkmark.circle")
            }
            .disabled(isWorking || !hasApplicableChanges)
        } footer: {
            if !hasHome {
                Text("No Apple Home is available yet. Allow access on the Dashboard, then come back.")
            } else if !isLinked {
                Text("This home is not linked to a Home Assistant server yet. Link it in Settings, then come back.")
            } else {
                Text("Preview lists every change first. Nothing is written until you apply it.")
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

    // MARK: Progress

    private func progressSection(_ progress: SyncProgress) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text(progress.title)
                    .font(.subheadline.weight(.semibold))
                if let detail = progress.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
            .padding(.vertical, 2)
        } header: {
            Text("In Progress")
        }
    }

    // MARK: Preview

    @ViewBuilder
    private var previewSection: some View {
        if let dryRunResult {
            if dryRunResult.changes.isEmpty {
                Section {
                    BridgeStatusRow(
                        title: "Already in Sync",
                        message: dryRunResult.summary,
                        systemImage: "checkmark.circle.fill",
                        tint: .green
                    )
                } header: {
                    Text("Preview")
                }
            } else {
                Section {
                    ForEach(dryRunResult.changes) { change in
                        changeRow(change)
                    }
                } header: {
                    Text("Preview · \(dryRunResult.changes.count) Change\(dryRunResult.changes.count == 1 ? "" : "s")")
                } footer: {
                    Text(dryRunResult.summary)
                }
            }
        }
    }

    private func changeRow(_ change: SyncChange) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon(for: change.action))
                .font(.body)
                .foregroundStyle(iconColor(for: change.action))
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(change.title)
                    .font(.body.weight(.medium))
                Text(change.details)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private func icon(for action: SyncActionType) -> String {
        switch action {
        case .createRoom: return "plus.square"
        case .renameRoom: return "character.cursor.ibeam"
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

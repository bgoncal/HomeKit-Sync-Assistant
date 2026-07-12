import SwiftUI

struct SyncView: View {
    @EnvironmentObject private var homeKitManager: HomeKitManager
    @EnvironmentObject private var syncEngine: SyncEngine

    @State private var operation: SyncOperation = .devicePlacementHAToHome
    @State private var dryRunResult: DryRunResult?
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Sync")
                    .font(.largeTitle.bold())
                Text("Preview changes first, then apply them when the plan looks right.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            BridgeCard {
                homePicker

                Picker("What to sync", selection: $operation) {
                    ForEach(SyncOperation.allCases) { op in
                        Text(operationTitle(op)).tag(op)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: operation) { _, _ in
                    dryRunResult = nil
                }

                Text(operationDescription(operation))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button {
                        Task { await runDryRun() }
                    } label: {
                        Label("Preview Changes", systemImage: "list.bullet.clipboard")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isWorking || homeKitManager.primaryHome == nil)

                    Button {
                        Task { await execute() }
                    } label: {
                        Label("Apply", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isWorking || dryRunResult == nil || homeKitManager.primaryHome == nil)

                    if isWorking {
                        ProgressView()
                            .padding(.leading, 4)
                    }
                }
            }

            if let progress = syncEngine.progress {
                progressStatusView(progress)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            if let dryRunResult {
                resultSummary(dryRunResult)

                List(dryRunResult.changes) { change in
                    changeRow(change)
                        .padding(.vertical, 3)
                }
            } else {
                Spacer()
                ContentUnavailableView("No Preview Yet", systemImage: "list.bullet.clipboard", description: Text("Preview changes to see exactly what the bridge would update."))
                Spacer()
            }
        }
        .padding(20)
        .navigationTitle("Sync")
    }

    private var homePicker: some View {
        Picker("Apple Home", selection: Binding(
            get: { homeKitManager.primaryHome?.uniqueIdentifier.uuidString ?? "" },
            set: { newHomeId in
                homeKitManager.selectHome(id: newHomeId)
                dryRunResult = nil
            }
        )) {
            if homeKitManager.homes.isEmpty {
                Text("No Apple homes found").tag("")
            } else {
                ForEach(homeKitManager.homes, id: \.uniqueIdentifier) { home in
                    Text(home.name).tag(home.uniqueIdentifier.uuidString)
                }
            }
        }
        .pickerStyle(.menu)
        .disabled(isWorking || homeKitManager.homes.isEmpty)
    }

    private func resultSummary(_ result: DryRunResult) -> some View {
        BridgeCard {
            BridgeStatusHeader(
                title: result.changes.isEmpty ? "Nothing to Change" : "Preview Ready",
                message: result.summary,
                systemImage: result.changes.isEmpty ? "checkmark.circle.fill" : "exclamationmark.arrow.triangle.2.circlepath",
                tint: result.changes.isEmpty ? .green : .orange
            )
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
                }
            }

            if hasTechnicalDetails(change) {
                DisclosureGroup("Technical details") {
                    VStack(spacing: 6) {
                        if let accessoryId = change.accessoryId {
                            BridgeInfoRow(label: "Accessory", value: accessoryId, selectable: true)
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

    private func progressStatusView(_ progress: SyncProgress) -> some View {
        BridgeCard {
            HStack(spacing: 10) {
                if progress.fractionCompleted == nil {
                    ProgressView()
                        .controlSize(.small)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(progress.title)
                        .font(.headline)
                    if let detail = progress.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let fractionCompleted = progress.fractionCompleted {
                ProgressView(value: fractionCompleted)
                if let completed = progress.completed, let total = progress.total {
                    Text("\(completed) of \(total)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
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

    private func execute() async {
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

    private func operationTitle(_ operation: SyncOperation) -> String {
        operation.displayTitle
    }

    private func operationDescription(_ operation: SyncOperation) -> String {
        operation.description
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

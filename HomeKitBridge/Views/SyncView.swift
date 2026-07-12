import SwiftUI

struct SyncView: View {
    @EnvironmentObject private var syncEngine: SyncEngine

    @State private var operation: SyncOperation = .devicePlacementHAToHome
    @State private var dryRunResult: DryRunResult?
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Synchronization")
                .font(.largeTitle.bold())

            Picker("Operation", selection: $operation) {
                ForEach(SyncOperation.allCases) { op in
                    Text(op.rawValue).tag(op)
                }
            }
            .pickerStyle(.menu)

            HStack(spacing: 12) {
                Button("Dry Run") {
                    Task {
                        await runDryRun()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isWorking)

                Button("Execute") {
                    Task {
                        await execute()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isWorking || dryRunResult == nil)

                if isWorking {
                    ProgressView()
                        .padding(.leading, 4)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            if let dryRunResult {
                Text(dryRunResult.summary)
                    .font(.headline)

                List(dryRunResult.changes) { change in
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
                    .padding(.vertical, 2)
                }
            } else {
                Spacer()
                ContentUnavailableView("No dry run yet", systemImage: "list.bullet.clipboard", description: Text("Run a dry run to preview all changes before executing."))
                Spacer()
            }
        }
        .padding(20)
    }

    private func runDryRun() async {
        isWorking = true
        errorMessage = nil
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
        } catch {
            errorMessage = error.localizedDescription
        }
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

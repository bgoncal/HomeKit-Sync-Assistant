import SwiftUI

struct SyncView: View {
    @EnvironmentObject private var homeKitManager: HomeKitManager
    @EnvironmentObject private var syncEngine: SyncEngine
    @EnvironmentObject private var connections: ConnectionStore

    @State private var direction: SyncDirection = .homeAssistantToAppleHome
    @State private var subject: SyncSubject = .placement
    @State private var homeId: String = ""
    @State private var serverId: UUID?
    @State private var dryRunResult: DryRunResult?
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var operation: SyncOperation { direction.operation(for: subject) }

    var body: some View {
        SyncContent(
            homes: homeKitManager.homes,
            servers: connections.servers,
            homeId: $homeId,
            serverId: $serverId,
            direction: $direction,
            subject: $subject,
            dryRunResult: dryRunResult,
            progress: syncEngine.progress,
            errorMessage: errorMessage,
            isWorking: isWorking,
            onPreview: { Task { await runDryRun() } },
            onApply: { Task { await apply() } }
        )
        .onAppear(perform: restoreChoice)
        .onChange(of: operation) { _, _ in clearPlan() }
        .onChange(of: homeId) { _, newValue in
            // The app remembers which server was used with this home last time.
            serverId = connections.suggestedServer(forHomeId: newValue)?.id ?? serverId
            clearPlan()
        }
        .onChange(of: serverId) { _, _ in clearPlan() }
    }

    private func restoreChoice() {
        if homeId.isEmpty {
            homeId = homeKitManager.selectedHome?.id ?? homeKitManager.homes.first?.id ?? ""
        }
        if serverId == nil {
            serverId = connections.suggestedServer(forHomeId: homeId)?.id ?? connections.servers.first?.id
        }
    }

    private func clearPlan() {
        dryRunResult = nil
        errorMessage = nil
    }

    private func runDryRun() async {
        guard !homeId.isEmpty, let serverId else { return }
        isWorking = true
        errorMessage = nil
        dryRunResult = nil
        defer { isWorking = false }

        do {
            dryRunResult = try await syncEngine.dryRun(operation, homeId: homeId, serverId: serverId)
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

/// Sync in the order the decision is actually made: which way, what, preview, apply.
struct SyncContent: View {
    let homes: [HomeSummary]
    let servers: [HomeAssistantServer]
    @Binding var homeId: String
    @Binding var serverId: UUID?
    @Binding var direction: SyncDirection
    @Binding var subject: SyncSubject
    let dryRunResult: DryRunResult?
    let progress: SyncProgress?
    let errorMessage: String?
    let isWorking: Bool
    var onPreview: () -> Void = {}
    var onApply: () -> Void = {}

    @State private var isConfirmingApply = false

    private var operation: SyncOperation { direction.operation(for: subject) }
    private var home: HomeSummary? { homes.first { $0.id == homeId } ?? homes.first }
    private var server: HomeAssistantServer? { servers.first { $0.id == serverId } ?? servers.first }
    private var isReady: Bool { home != nil && server != nil }

    var body: some View {
        List {
            directionSection
            subjectSection
            previewButtonSection

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
            applySection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Sync")
        .confirmationDialog(
            confirmationTitle,
            isPresented: $isConfirmingApply,
            titleVisibility: .visible
        ) {
            Button(confirmationButton, role: .destructive, action: onApply)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(confirmationMessage)
        }
    }

    // MARK: 1 — which way

    private var directionSection: some View {
        Section {
            Picker("Read from", selection: $direction) {
                Text(SyncPlatform.homeAssistant.name).tag(SyncDirection.homeAssistantToAppleHome)
                Text(SyncPlatform.appleHome.name).tag(SyncDirection.appleHomeToHomeAssistant)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(isWorking)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            Button {
                direction = direction == .homeAssistantToAppleHome ? .appleHomeToHomeAssistant : .homeAssistantToAppleHome
            } label: {
                LabeledContent {
                    HStack(spacing: 10) {
                        BridgeDirectionBadge(direction: direction)
                        Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                } label: {
                    Text("Direction")
                        .foregroundStyle(.primary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isWorking)
            .accessibilityLabel("Direction: from \(direction.source.name) to \(direction.destination.name)")
            .accessibilityHint("Double tap to sync the other way")

            Picker(SyncPlatform.appleHome.name, selection: $homeId) {
                if homes.isEmpty {
                    Text("None").tag("")
                }
                ForEach(homes) { home in
                    Text(home.name).tag(home.id)
                }
            }
            .disabled(isWorking || homes.isEmpty)

            Picker(SyncPlatform.homeAssistant.name, selection: $serverId) {
                if servers.isEmpty {
                    Text("None").tag(UUID?.none)
                }
                ForEach(servers) { server in
                    Text(server.name).tag(UUID?.some(server.id))
                }
            }
            .disabled(isWorking || servers.isEmpty)
        } header: {
            Text("1 · Which Way")
        } footer: {
            Text(isReady
                 ? "Only \(destinationName) is changed. \(sourceName) is read and left alone."
                 : "Pick an Apple Home and a Home Assistant to sync between.")
        }
    }

    private var sourceName: String {
        direction.source == .appleHome ? (home?.name ?? SyncPlatform.appleHome.name) : (server?.name ?? SyncPlatform.homeAssistant.name)
    }

    private var destinationName: String {
        direction.destination == .appleHome ? (home?.name ?? SyncPlatform.appleHome.name) : (server?.name ?? SyncPlatform.homeAssistant.name)
    }

    // MARK: 2 — what

    private var subjectSection: some View {
        Section {
            Picker("What", selection: $subject) {
                ForEach(SyncSubject.allCases) { subject in
                    Text(subject.title).tag(subject)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            .disabled(isWorking)
        } header: {
            Text("2 · What to Sync")
        } footer: {
            Text(operation.description)
        }
    }

    // MARK: 3 — preview

    private var previewButtonSection: some View {
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
            .disabled(isWorking || !isReady)
        } header: {
            Text("3 · Preview")
        } footer: {
            Text("Nothing is written yet. The preview lists every change first.")
        }
    }

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
                }
            } else {
                Section {
                    ForEach(dryRunResult.changes) { change in
                        changeRow(change)
                    }
                } header: {
                    Text("\(dryRunResult.changes.count) Change\(dryRunResult.changes.count == 1 ? "" : "s")")
                } footer: {
                    Text(dryRunResult.summary)
                }
            }
        }
    }

    // MARK: 4 — apply

    @ViewBuilder
    private var applySection: some View {
        if let dryRunResult, !dryRunResult.changes.isEmpty {
            Section {
                Button {
                    isConfirmingApply = true
                } label: {
                    Label(applyTitle, systemImage: "checkmark.circle")
                }
                .disabled(isWorking)
            } header: {
                Text("4 · Apply")
            } footer: {
                Text("This writes to \(destinationName). It cannot be undone from here.")
            }
        }
    }

    private var applyTitle: String {
        let count = dryRunResult?.changes.count ?? 0
        return "Apply \(count) Change\(count == 1 ? "" : "s") to \(destinationName)"
    }

    private var confirmationTitle: String {
        "Apply to \(destinationName)?"
    }

    private var confirmationButton: String {
        let count = dryRunResult?.changes.count ?? 0
        return "Apply \(count) Change\(count == 1 ? "" : "s")"
    }

    private var confirmationMessage: String {
        let count = dryRunResult?.changes.count ?? 0
        return "\(count) change\(count == 1 ? "" : "s") will be written to \(destinationName). \(sourceName) is not touched."
    }

    // MARK: Pieces

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

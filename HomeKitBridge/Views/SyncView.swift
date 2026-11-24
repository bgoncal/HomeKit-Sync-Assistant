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
    @State private var skippedChangeIds: Set<UUID> = []
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
            skippedChangeIds: $skippedChangeIds,
            lastSync: syncEngine.lastUndo,
            progress: syncEngine.progress,
            errorMessage: errorMessage,
            isWorking: isWorking,
            onPreview: { Task { await runDryRun() } },
            onApply: { Task { await apply() } },
            onUndo: { Task { await undo() } }
        )
        .navigationDestination(for: SyncRoute.self) { route in
            switch route {
            case .differences(let homeId, let serverId):
                DifferencesView(homeId: homeId, serverId: serverId)
            }
        }
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
        skippedChangeIds = []
        errorMessage = nil
    }

    private func runDryRun() async {
        guard !homeId.isEmpty, let serverId else { return }
        isWorking = true
        errorMessage = nil
        dryRunResult = nil
        skippedChangeIds = []
        defer { isWorking = false }

        do {
            dryRunResult = try await syncEngine.dryRun(operation, homeId: homeId, serverId: serverId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func undo() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await syncEngine.undoLastSync()
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
            try await syncEngine.execute(dryRunResult.keeping { !skippedChangeIds.contains($0.id) })
            self.dryRunResult = nil
            skippedChangeIds = []
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
    /// Changes the person unticked in the preview; everything else is applied.
    var skippedChangeIds: Binding<Set<UUID>> = .constant([])
    /// The last sync that wrote anything, while it can still be undone.
    var lastSync: SyncUndoRecord?
    let progress: SyncProgress?
    let errorMessage: String?
    let isWorking: Bool
    var onPreview: () -> Void = {}
    var onApply: () -> Void = {}
    var onUndo: () -> Void = {}

    @State private var isConfirmingApply = false
    @State private var isConfirmingUndo = false

    private var operation: SyncOperation { direction.operation(for: subject) }
    private var home: HomeSummary? { homes.first { $0.id == homeId } ?? homes.first }
    private var server: HomeAssistantServer? { servers.first { $0.id == serverId } ?? servers.first }
    private var isReady: Bool { home != nil && server != nil }

    var body: some View {
        List {
            directionSection
            pairSection
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

            if dryRunResult == nil, let lastSync {
                lastSyncSection(lastSync)
            }
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
            Picker("Direction", selection: $direction) {
                ForEach(SyncDirection.allCases, id: \.self) { direction in
                    BridgeDirectionBadge(direction: direction)
                        .tag(direction)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            .disabled(isWorking)
        } header: {
            Text("1 · Which Way")
        } footer: {
            Text("The first side is only read. The second is the one that changes.")
        }
    }

    // MARK: 2 — between which two

    private var pairSection: some View {
        Section {
            Picker(selection: $homeId) {
                if homes.isEmpty {
                    Text("None").tag("")
                }
                ForEach(homes) { home in
                    Text(home.name).tag(home.id)
                }
            } label: {
                platformLabel(.appleHome)
            }
            .disabled(isWorking || homes.isEmpty)

            Picker(selection: $serverId) {
                if servers.isEmpty {
                    Text("None").tag(UUID?.none)
                }
                ForEach(servers) { server in
                    Text(server.name).tag(UUID?.some(server.id))
                }
            } label: {
                platformLabel(.homeAssistant)
            }
            .disabled(isWorking || servers.isEmpty)

            if let home, let server {
                NavigationLink(value: SyncRoute.differences(homeId: home.id, serverId: server.id)) {
                    Label("Compare Both Sides", systemImage: "arrow.left.arrow.right")
                }
                .disabled(isWorking)
            }
        } header: {
            Text("2 · Between")
        } footer: {
            Text(isReady
                 ? "Only \(destinationName) is changed. \(sourceName) is read and left alone."
                 : "Pick an Apple Home and a Home Assistant to sync between.")
        }
    }

    private func platformLabel(_ platform: SyncPlatform) -> some View {
        Label {
            Text(platform.name)
        } icon: {
            Image(systemName: platform.symbolName)
                .foregroundStyle(platform.tint)
        }
    }

    private var sourceName: String {
        direction.source == .appleHome ? (home?.name ?? SyncPlatform.appleHome.name) : (server?.name ?? SyncPlatform.homeAssistant.name)
    }

    private var destinationName: String {
        direction.destination == .appleHome ? (home?.name ?? SyncPlatform.appleHome.name) : (server?.name ?? SyncPlatform.homeAssistant.name)
    }

    // MARK: 3 — what

    private var subjectSection: some View {
        Section {
            Picker("What", selection: $subject) {
                ForEach(SyncSubject.allCases) { subject in
                    Label(subject.title, systemImage: subject.symbolName)
                        .tag(subject)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            .disabled(isWorking)
        } header: {
            Text("3 · What to Sync")
        } footer: {
            Text(operation.description)
        }
    }

    // MARK: 4 — preview

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
            Text("4 · Preview")
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
                    HStack {
                        Text(selectionHeader(for: dryRunResult))
                        Spacer()
                        Button(allSelected(in: dryRunResult) ? "Select None" : "Select All") {
                            skippedChangeIds.wrappedValue = allSelected(in: dryRunResult) ? Set(dryRunResult.changes.map(\.id)) : []
                        }
                        .font(.footnote)
                        .textCase(nil)
                        .disabled(isWorking)
                    }
                } footer: {
                    Text("\(dryRunResult.summary) Untick anything you would rather leave as it is.")
                }
            }
        }
    }

    private var selectedCount: Int {
        guard let dryRunResult else { return 0 }
        return dryRunResult.changes.filter { !skippedChangeIds.wrappedValue.contains($0.id) }.count
    }

    private func allSelected(in result: DryRunResult) -> Bool {
        skippedChangeIds.wrappedValue.isDisjoint(with: result.changes.map(\.id))
    }

    private func selectionHeader(for result: DryRunResult) -> String {
        let total = result.changes.count
        if selectedCount == total {
            return "\(total) Change\(total == 1 ? "" : "s")"
        }
        return "\(selectedCount) of \(total) Selected"
    }

    // MARK: 5 — apply

    @ViewBuilder
    private var applySection: some View {
        if let dryRunResult, !dryRunResult.changes.isEmpty {
            Section {
                Button {
                    isConfirmingApply = true
                } label: {
                    Label(applyTitle, systemImage: "checkmark.circle")
                }
                .disabled(isWorking || selectedCount == 0)
            } header: {
                Text("5 · Apply")
            } footer: {
                Text("This writes to \(destinationName). It cannot be undone from here.")
            }
        }
    }

    private var applyTitle: String {
        let count = selectedCount
        return "Apply \(count) Change\(count == 1 ? "" : "s") to \(destinationName)"
    }

    private var confirmationTitle: String {
        "Apply to \(destinationName)?"
    }

    private var confirmationButton: String {
        let count = selectedCount
        return "Apply \(count) Change\(count == 1 ? "" : "s")"
    }

    private var confirmationMessage: String {
        let count = selectedCount
        return "\(count) change\(count == 1 ? "" : "s") will be written to \(destinationName). \(sourceName) is not touched."
    }

    // MARK: Undo

    private func lastSyncSection(_ record: SyncUndoRecord) -> some View {
        Section {
            LabeledContent {
                Text(record.date.formatted(date: .abbreviated, time: .shortened))
            } label: {
                Text(record.operation.shortTitle)
                Text(record.operation.direction.label)
            }

            Button(role: .destructive) {
                isConfirmingUndo = true
            } label: {
                Label("Undo Changes in \(record.destinationName)", systemImage: "arrow.uturn.backward")
            }
            .disabled(isWorking)
            .confirmationDialog(
                "Undo the last sync?",
                isPresented: $isConfirmingUndo,
                titleVisibility: .visible
            ) {
                Button("Undo \(record.steps.count) Change\(record.steps.count == 1 ? "" : "s")", role: .destructive, action: onUndo)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("\(record.destinationName) goes back to how it was before. Rooms or areas the sync created are removed.")
            }
        } header: {
            Text("Last Sync")
        } footer: {
            Text("Puts back the \(record.steps.count) change\(record.steps.count == 1 ? "" : "s") it made in \(record.destinationName). Anything changed again since is left as it is. Only this device remembers them, for a day.")
        }
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

    /// A change as a Reminders-style row: the circle says whether it will be applied.
    private func changeRow(_ change: SyncChange) -> some View {
        let isSelected = !skippedChangeIds.wrappedValue.contains(change.id)
        return Button {
            if isSelected {
                skippedChangeIds.wrappedValue.insert(change.id)
            } else {
                skippedChangeIds.wrappedValue.remove(change.id)
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(change.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                    Label {
                        Text(change.details)
                    } icon: {
                        Image(systemName: icon(for: change.action))
                            .foregroundStyle(iconColor(for: change.action))
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func icon(for action: SyncActionType) -> String {
        switch action {
        case .createRoom: return "plus.square"
        case .renameRoom: return "character.cursor.ibeam"
        case .moveAccessory: return "arrow.left.arrow.right"
        case .renameAccessory: return "pencil"
        case .createZone: return "building.2"
        case .assignZone: return "square.stack.3d.up"
        case .createScene: return "sparkles"
        case .unsupported: return "exclamationmark.triangle"
        }
    }

    private func iconColor(for action: SyncActionType) -> Color {
        switch action {
        case .createRoom: return .green
        case .renameRoom: return .orange
        case .moveAccessory: return .blue
        case .renameAccessory: return .purple
        case .createZone: return .teal
        case .assignZone: return .indigo
        case .createScene: return .yellow
        case .unsupported: return .red
        }
    }
}

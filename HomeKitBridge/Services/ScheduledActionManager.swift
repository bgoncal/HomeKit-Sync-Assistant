import Foundation

struct ScheduledAction: Identifiable, Codable, Equatable {
    var id: UUID
    var isEnabled: Bool
    var timeMinutes: Int
    var operationRawValue: String
    /// The Apple Home this runs against, and with it the paired Home Assistant server.
    /// Empty means "the home selected in the app", which is what upgrades start as.
    var homeId: String
    var lastRunDay: String?

    init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        timeMinutes: Int = 8 * 60,
        operationRawValue: String = SyncOperation.devicePlacementHAToHome.rawValue,
        homeId: String = "",
        lastRunDay: String? = nil
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.timeMinutes = timeMinutes
        self.operationRawValue = operationRawValue
        self.homeId = homeId
        self.lastRunDay = lastRunDay
    }

    private enum CodingKeys: String, CodingKey {
        case id, isEnabled, timeMinutes, operationRawValue, homeId, lastRunDay
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        timeMinutes = try container.decode(Int.self, forKey: .timeMinutes)
        operationRawValue = try container.decode(String.self, forKey: .operationRawValue)
        homeId = try container.decodeIfPresent(String.self, forKey: .homeId) ?? ""
        lastRunDay = try container.decodeIfPresent(String.self, forKey: .lastRunDay)
    }

    var operation: SyncOperation? {
        SyncOperation.operation(forStoredRawValue: operationRawValue)
    }
}

@MainActor
final class ScheduledActionManager: ObservableObject {
    /// Scheduled syncs are a Mac feature. iPhone and iPad suspend the app within
    /// seconds of it leaving the screen, so a daily timer there would fire only if
    /// the app happened to be open — which is worse than not offering it at all.
    static var isSupported: Bool {
        #if targetEnvironment(macCatalyst) || os(macOS)
        return true
        #else
        return false
        #endif
    }

    private enum DefaultsKey {
        static let schedules = "scheduledActions"
        static let legacyIsEnabled = "scheduledActionEnabled"
        static let legacyTimeMinutes = "scheduledActionTimeMinutes"
        static let legacyOperation = "scheduledActionOperation"
        static let legacyLastRunDay = "scheduledActionLastRunDay"
        static let didMigrateLegacySchedule = "didMigrateLegacySchedule"
    }

    @Published private(set) var schedules: [ScheduledAction] = []

    private let syncEngine: SyncEngine
    private let logStore: LogStore
    private let homeKitManager: HomeKitManager
    private var timer: Timer?

    init(syncEngine: SyncEngine, logStore: LogStore, homeKitManager: HomeKitManager) {
        self.syncEngine = syncEngine
        self.logStore = logStore
        self.homeKitManager = homeKitManager
        loadSchedules()
    }

    deinit {
        timer?.invalidate()
    }

    func addSchedule() {
        schedules.append(ScheduledAction())
        saveSchedules()
        refreshSchedule()
    }

    func updateSchedule(_ schedule: ScheduledAction) {
        guard let index = schedules.firstIndex(where: { $0.id == schedule.id }) else { return }
        schedules[index] = schedule
        saveSchedules()
        refreshSchedule()
    }

    func deleteSchedules(at offsets: IndexSet) {
        schedules.remove(atOffsets: offsets)
        saveSchedules()
        refreshSchedule()
    }

    func refreshSchedule() {
        timer?.invalidate()
        timer = nil

        guard Self.isSupported else { return }

        let enabledSchedules = schedules.filter(\.isEnabled)
        guard !enabledSchedules.isEmpty else { return }

        let now = Date()
        guard let fireDate = enabledSchedules
            .map({ nextFireDate(for: $0, from: now) })
            .min() else { return }

        timer = Timer.scheduledTimer(withTimeInterval: max(1, fireDate.timeIntervalSinceNow), repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.runDueScheduledActions()
            }
        }
    }

    private func runDueScheduledActions() async {
        defer { refreshSchedule() }

        let now = Date()
        let todayKey = dayKey(for: now)
        let dueSchedules = schedules
            .filter { schedule in
                schedule.isEnabled
                    && schedule.lastRunDay != todayKey
                    && scheduledDate(for: schedule, on: now) <= now
            }
            .sorted { $0.timeMinutes < $1.timeMinutes }

        for schedule in dueSchedules {
            await runScheduledAction(schedule, todayKey: todayKey)
        }
    }

    private func runScheduledAction(_ schedule: ScheduledAction, todayKey: String) async {
        guard let currentSchedule = schedules.first(where: { $0.id == schedule.id }), currentSchedule.lastRunDay != todayKey else {
            return
        }

        guard !syncEngine.isBusy else {
            logStore.add(category: .sync, message: "Scheduled action skipped", details: "Another sync is already running.")
            markSchedule(schedule.id, lastRunDay: todayKey)
            return
        }

        guard let operation = currentSchedule.operation else {
            logStore.add(category: .error, message: "Scheduled action failed", details: "The selected action is no longer available.")
            markSchedule(schedule.id, lastRunDay: todayKey)
            return
        }

        let homeId = currentSchedule.homeId.isEmpty
            ? (homeKitManager.selectedHome?.id ?? "")
            : currentSchedule.homeId

        guard let home = homeKitManager.home(byId: homeId) else {
            logStore.add(category: .error, message: "Scheduled action failed", details: "Its Apple Home is no longer available.")
            markSchedule(schedule.id, lastRunDay: todayKey)
            return
        }

        markSchedule(schedule.id, lastRunDay: todayKey)
        logStore.add(
            category: .sync,
            message: "Scheduled action started",
            details: "\(operation.displayTitle) · \(home.name)"
        )

        do {
            let result = try await syncEngine.dryRun(operation, homeId: home.id)
            if result.changes.isEmpty {
                logStore.add(category: .sync, message: "Scheduled action finished", details: result.summary)
            } else {
                try await syncEngine.execute(result)
            }
        } catch {
            logStore.add(category: .error, message: "Scheduled action failed", details: error.localizedDescription)
        }
    }

    private func markSchedule(_ id: UUID, lastRunDay: String) {
        guard let index = schedules.firstIndex(where: { $0.id == id }) else { return }
        schedules[index].lastRunDay = lastRunDay
        saveSchedules()
    }

    private func loadSchedules() {
        migrateLegacyScheduleIfNeeded()

        guard let data = UserDefaults.standard.data(forKey: DefaultsKey.schedules),
              let decoded = try? JSONDecoder().decode([ScheduledAction].self, from: data) else {
            schedules = []
            return
        }

        // Operations used to be stored under their display strings; rewrite them to
        // the stable identifiers so pickers and lookups keep matching.
        schedules = decoded.map { schedule in
            guard let operation = SyncOperation.operation(forStoredRawValue: schedule.operationRawValue),
                  operation.rawValue != schedule.operationRawValue else {
                return schedule
            }
            var normalized = schedule
            normalized.operationRawValue = operation.rawValue
            return normalized
        }

        if schedules != decoded {
            saveSchedules()
        }
    }

    private func saveSchedules() {
        if let data = try? JSONEncoder().encode(schedules) {
            UserDefaults.standard.set(data, forKey: DefaultsKey.schedules)
        }
    }

    private func migrateLegacyScheduleIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: DefaultsKey.didMigrateLegacySchedule) else { return }
        defaults.set(true, forKey: DefaultsKey.didMigrateLegacySchedule)

        guard defaults.object(forKey: DefaultsKey.legacyIsEnabled) != nil else { return }

        let timeMinutes = defaults.object(forKey: DefaultsKey.legacyTimeMinutes) as? Int ?? 8 * 60
        let storedOperation = defaults.string(forKey: DefaultsKey.legacyOperation)
        let operationRawValue = storedOperation
            .flatMap(SyncOperation.operation(forStoredRawValue:))?.rawValue
            ?? SyncOperation.devicePlacementHAToHome.rawValue
        let schedule = ScheduledAction(
            isEnabled: defaults.bool(forKey: DefaultsKey.legacyIsEnabled),
            timeMinutes: timeMinutes,
            operationRawValue: operationRawValue,
            lastRunDay: defaults.string(forKey: DefaultsKey.legacyLastRunDay)
        )

        if let existingData = defaults.data(forKey: DefaultsKey.schedules),
           var existing = try? JSONDecoder().decode([ScheduledAction].self, from: existingData) {
            existing.append(schedule)
            if let data = try? JSONEncoder().encode(existing) {
                defaults.set(data, forKey: DefaultsKey.schedules)
            }
        } else if let data = try? JSONEncoder().encode([schedule]) {
            defaults.set(data, forKey: DefaultsKey.schedules)
        }
    }

    private func nextFireDate(for schedule: ScheduledAction, from now: Date = Date()) -> Date {
        let today = scheduledDate(for: schedule, on: now)
        if today > now {
            return today
        }

        return Calendar.current.date(byAdding: .day, value: 1, to: today) ?? now.addingTimeInterval(24 * 60 * 60)
    }

    private func scheduledDate(for schedule: ScheduledAction, on date: Date) -> Date {
        let calendar = Calendar.current
        let hour = schedule.timeMinutes / 60
        let minute = schedule.timeMinutes % 60

        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.second = 0

        return calendar.date(from: components) ?? date
    }

    private func dayKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}

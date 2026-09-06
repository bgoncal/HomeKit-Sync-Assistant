# AGENTS.md — HomeKitBridge

Guidance for AI agents (and humans) working in this repo. It documents the project
and the Swift / SwiftUI conventions this codebase already follows. **Match these
patterns** — consistency with existing code beats any personal preference.

## What this project is

A SwiftUI app that syncs devices/rooms between **Apple Home (HomeKit)** and
**Home Assistant**, and exposes a **local HTTP API** to drive HomeKit from other
tools. Single app target, no external package dependencies.

- **Platforms:** iOS 17.0+, macOS 14.0+ via **Mac Catalyst** (`SUPPORTS_MACCATALYST = YES`,
  device family `1,2,6`). Language mode: **Swift 5**.
- **Frameworks:** `SwiftUI`, `HomeKit`, `Network` (`NWListener` HTTP server),
  `Foundation` (`URLSessionWebSocketTask` for the HA WebSocket API).

### Layout

```
HomeKitBridge/
  HomeKitBridgeApp.swift     @main App — owns all services, injects via environment
  Models/                    Plain Codable/Identifiable value types
    HomeModels.swift           HomeSummary/RoomSummary/AccessorySummary/HomeAssistantMatch
    LogEntry.swift
  Services/                  @MainActor ObservableObject business logic
    HomeKitManager.swift       HomeKit access; publishes HomeSummary values
    HAWebSocketClient.swift     Home Assistant WebSocket client + HAConfiguration
    SyncEngine.swift            Sync operations, directions, dry runs
    HTTPServer.swift            Local HTTP API (Network framework) + BridgeError
    LogStore.swift              In-app log buffer
    ScheduledActionManager.swift
  Views/                     SwiftUI views
    BridgeUI.swift             Shared UI components (BridgePage, BridgeCard, …)
    MainTabView.swift, *View.swift
HomeKitBridgeTests/          Snapshot + logic tests (see "Tests")
  __Snapshots__/             Reference PNGs, one per screen per platform
```

## Architecture rules

- **Services are the source of truth.** Each is a
  `@MainActor final class Foo: ObservableObject` exposing `@Published` state.
  Prefer `@Published private(set)` for anything callers shouldn't mutate directly.
- **Ownership lives in the App.** `HomeKitBridgeApp` creates every service as a
  `@StateObject` and injects them with `.environmentObject(...)`. Views read them
  with `@EnvironmentObject private var name: Type`. Do **not** create a second
  instance of a service inside a view.
- **Dependencies are passed through initializers**, not looked up globally
  (e.g. `SyncEngine(homeKitManager:logStore:wsClient:)`). No singletons.
- **Persist small config in `UserDefaults`.** Register defaults once in
  `App.init()` (`UserDefaults.standard.register(defaults:)`); read user-facing
  toggles in views with `@AppStorage`. Keys are plain string literals today —
  reuse the exact existing key when touching persisted state.

## Concurrency

- Services and anything touching UI or HomeKit are **`@MainActor`**. Keep it that way.
- **Bridge completion-handler APIs to async** with `withCheckedThrowingContinuation`,
  resuming exactly once on every path. This is the established pattern for HomeKit
  calls (see `HomeKitManager.renameAccessory`, `createRoom`, etc.). For a `Void`
  result, annotate the continuation type:
  `withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in ... }`.
- **Delegate callbacks are `nonisolated`** and hop back to the main actor:
  ```swift
  nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
      Task { @MainActor in self.updateHomes(manager.homes) }
  }
  ```
- **Long-lived Tasks use `[weak self]`** and check `Task.isCancelled` in their loop;
  store the handle (e.g. `receiveTask`) and cancel it in `disconnect()`/teardown.
- Prefer `async`/`await` over nesting closures. Don't block the main thread.

## Error handling

- Model errors as **domain enums conforming to `LocalizedError`** with associated
  messages, next to the code that throws them (`BridgeError` in HTTPServer.swift,
  `HAWSError` in HAWebSocketClient.swift). Provide `errorDescription`.
- `throw` from `async` service methods; surface failures to the UI via a
  `@Published` string (`connectionError`) rather than crashing. Avoid
  `try!`/`fatalError` in app flow. Use `guard ... else { throw/return }` early.

## SwiftUI conventions

- **Every screen is split in two.** A connected view (`DashboardView`) reads the
  services from the environment and passes plain values into a content view
  (`DashboardContent`) that owns the layout. Content views take values, bindings,
  and closures only — never a service, an `HMHome`, or a `[String: Any]` payload.
  That split is what makes every screen snapshot-testable; keep it when adding one.
- **Name the direction in the UI.** Anything that mentions a sync shows
  `BridgeDirectionBadge` and says which side is written. Copy is plain language:
  "Apple Home", "Home Assistant", never "HA" or "HK".
- **Views are small `struct`s.** Break a `body` into `private var someCard: some View`
  computed properties or `private func row(...) -> some View` helpers (see
  `DashboardView`) instead of one giant view tree.
- **Reuse the shared components in `BridgeUI.swift`** — `BridgePage` (screen scaffold
  with title/subtitle, 900pt max width), `BridgeCard`, `BridgeStatusHeader`,
  `BridgeInfoRow`, `BridgeCodeBlock`. New screens should start from `BridgePage`.
  Generic container views take content via `@ViewBuilder`.
- **Styling idioms already in use:** SF Symbols via `Image(systemName:)`/`Label`;
  `.foregroundStyle(...)` (not `.foregroundColor`); `.regularMaterial` / `.quaternary`
  backgrounds; `RoundedRectangle(cornerRadius:style: .continuous)` clips; semantic
  fonts (`.headline`, `.callout`, `.title2.bold()`); `.secondary` for de-emphasis;
  `.textSelection(.enabled)` on copyable values; `value.formatted()` for numbers.
- Choose property wrappers correctly: `@StateObject` to *own*, `@EnvironmentObject`
  to *consume* injected services, `@State` for local view state, `@AppStorage` for
  persisted user prefs, `@Binding` to pass mutable state down.
- Keep side effects out of `body`. Kick off async work from `.onAppear`/`.task`/
  button actions with `Task { ... }`, guarding one-time launch work with a flag
  (see the `didStartLaunchServices` pattern in the App).

## Style

- `final class` for reference types; value types (`struct`/`enum`) by default for models.
- Models are `Identifiable` + `Codable` with a memberwise `init` providing sensible
  defaults (`id: UUID = UUID()`, `timestamp: Date = Date()`), as in `LogEntry`.
- Organize longer files with `// MARK: -` sections; document non-obvious types with
  `///` doc comments (as in `HAWebSocketClient`).
- Descriptive camelCase names; UI helper components use the `Bridge` prefix.
- No force-unwraps on external/optional data — unwrap with `guard`/`if let` and a
  fallback.

## Building & running

Use the **XcodeBuildMCP** tools rather than raw `xcodebuild` when available.
Before the first build/run in a session, call `session_show_defaults` to confirm the
project, scheme, and simulator; then `build_run_sim`. Use `discover_projs` only if
defaults are missing.

## Tests

`HomeKitBridgeTests` is a **non-hosted** unit-test bundle. The app's sources are
compiled into it directly (every file except `HomeKitBridgeApp.swift`), so there is
no `@testable import` and no app launch — which also means HomeKit is never touched
during a test run. Its only dependency is
[swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing).

It holds:

- **Snapshot tests for every screen**, rendered from `Fixtures` through the content
  views. New screen or new state ⇒ new snapshot test.
- **Logic tests** for credential validation and sync-operation copy/migration.

Run them on both platforms — references are stored per platform
(`…-iPhone.png` / `…-mac.png`) in `HomeKitBridgeTests/__Snapshots__/`:

```sh
Scripts/snapshot-tests.sh iphone            # iOS Simulator, default "iPhone 17"
Scripts/snapshot-tests.sh mac               # Mac Catalyst
```

Use the script rather than plain `xcodebuild test` for **mac**: a Mac Catalyst app is
always sandboxed and cannot read or write the reference images in the repository, so
the script copies them into the app container around the run. iPhone runs are a plain
`xcodebuild test` under the hood.

To re-record after an intentional UI change, delete the affected PNGs and run again
(missing references are recorded automatically, and the run fails once), then look at
the new images before committing them. `SnapshotTestCase` pins the time zone, the
locale, animations, the display scale, and the light appearance; keep new fixtures
free of `Date()`, random IDs, and anything else that changes between runs.

Two known, harmless differences in the Mac references: menu `Picker`s render as empty
popup buttons (they draw correctly in the running app — verified on Catalyst), and
`.regularMaterial` renders flat. Neither is an app bug; don't "fix" the UI because of
them.

The dependency is pinned to `swift-snapshot-testing` 1.18.x on purpose: 1.19 fails to
compile for Mac Catalyst (`UIImage` does not conform to `AttachableAsImage`).

## When making changes

1. Read the neighbouring file first and mirror its structure and naming.
2. Keep UI-facing state on `@MainActor` services; don't leak `[String: Any]` HA
   payloads into views — expose typed/derived state instead.
3. Don't add third-party dependencies without asking.
4. Reuse `BridgeUI` components and existing UserDefaults keys.
5. After non-trivial changes, build for the simulator to confirm it compiles, and
   run the tests for both iPhone and Mac Catalyst.

---
name: swift-style
description: Swift conventions for HomeKitBridge — services as @MainActor ObservableObjects owned by the App, dependencies through initializers, completion handlers bridged with continuations, domain errors as LocalizedError, and value types for anything a view renders. Use when writing or reviewing Swift in this repo.
---

# Swift style in HomeKitBridge

Consistency with the existing code beats personal preference. Read the neighbouring
file before adding one.

## Services

- One `@MainActor final class Foo: ObservableObject` per concern, exposing
  `@Published private(set)` state. Callers change state through methods, not properties.
- `HomeKitBridgeApp` owns every service as a `@StateObject` and injects it with
  `.environmentObject(...)`. Views consume with `@EnvironmentObject`. Never construct a
  second instance of a service inside a view.
- Declare the `@StateObject`s without a default value and assign them in `init()`;
  a default value builds a throwaway instance on every launch (and a throwaway
  `HMHomeManager` with it).
- Dependencies go through initializers — `SyncEngine(homeKitManager:logStore:wsClient:)`.
  No singletons, no global lookups.
- Small config lives in `UserDefaults`, registered once in `App.init()` and read in
  views with `@AppStorage`. Reuse the existing key when touching persisted state.

## Values, not framework objects

Views render plain `Codable`/`Equatable` structs (`HomeSummary`, `AccessorySummary`,
`HomeAssistantMatch`). `HomeKitManager` keeps `HMHome` internally and publishes
summaries; `SyncEngine` turns Home Assistant's `[String: Any]` payloads into typed
values, pre-rendering JSON to strings where a view needs to show raw data.

This is what makes every screen renderable from a fixture. A `[String: Any]` or an
`HMAccessory` reaching a view is a bug.

## Concurrency

- Anything touching UI or HomeKit is `@MainActor`.
- Bridge completion handlers with `withCheckedThrowingContinuation`, resuming exactly
  once on every path. For `Void`, annotate:
  `withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in … }`.
- Delegate callbacks are `nonisolated` and hop back:
  `Task { @MainActor in self.updateHomes(manager.homes) }`.
- Long-lived tasks capture `[weak self]`, check `Task.isCancelled`, and are stored so
  `disconnect()`/teardown can cancel them.
- Prefer `async`/`await` over nested closures. Never block the main thread.

## Errors

- Domain enums conforming to `LocalizedError`, declared next to the code that throws
  them (`BridgeError`, `HAWSError`), with `errorDescription` written for a person.
- `throw` from async service methods; surface failures through `@Published` state
  (`connectionError`) instead of crashing. No `try!`, no `fatalError` in app flow.
- Unwrap with `guard`/`if let` and a fallback. No force-unwraps on external data.

## Persistence

Raw values that are written to `UserDefaults` are API. `SyncOperation.rawValue` is
stored inside saved schedules, so renaming a case means adding its old string to
`SyncOperation.operation(forStoredRawValue:)` and normalising on load.

## Shape of a file

`// MARK: -` sections in anything long, `///` doc comments on non-obvious types that
say *why* rather than restating the name, `final class` for reference types, value types
by default, descriptive camelCase, and the `Bridge` prefix for shared UI components.

## Before you finish

Build for the simulator, and run the tests on both iPhone and Mac Catalyst
(see the `snapshot-tests` skill).

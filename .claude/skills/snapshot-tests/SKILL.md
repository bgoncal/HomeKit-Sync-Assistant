---
name: snapshot-tests
description: Run, record, and debug the HomeKitBridge snapshot tests on iPhone and Mac Catalyst, including the sandbox workaround, determinism rules, and the known Catalyst rendering quirks. Use when tests fail, when adding a screen, or after any UI change.
---

# Snapshot tests

`HomeKitBridgeTests` is an app-hosted bundle covering every screen on two platforms,
plus logic tests for credential validation and sync-operation migration. Its only
dependency is swift-snapshot-testing, pinned to 1.18.x (1.19 does not compile for
Mac Catalyst).

## Running

```sh
Scripts/snapshot-tests.sh iphone            # default simulator "iPhone 17"
Scripts/snapshot-tests.sh iphone "iPhone 17 Pro"
Scripts/snapshot-tests.sh mac               # Mac Catalyst
```

Use the script for **mac**: a Catalyst app is always sandboxed and cannot read or write
the references in the repository, so the script copies them into the app container
around the run. A plain `xcodebuild test` on Catalyst fails with permission errors.

The app skips its launch work (HomeKit access, the local server, the Home Assistant
connection) when `XCTestConfigurationFilePath` is set, so a test run never prompts for
permission or touches the network.

## Recording

References are recorded automatically when missing, and that run fails — that is
expected. So:

1. Delete the affected PNGs in `HomeKitBridgeTests/__Snapshots__/<TestClass>/`.
2. Run the platform once to record (fails).
3. **Read the new PNGs.** This is the point of the exercise.
4. Run again to prove they are stable.

Never commit a reference you have not looked at.

## Writing one

```swift
func testDeviceList() {
    assertScreen(
        NavigationStack {
            DevicesContent(homes: [Fixtures.home], selectedHomeId: Fixtures.home.id, search: .constant(""))
        },
        named: "devices-list"
    )
}
```

- Subclass `SnapshotTestCase`: it pins the time zone, disables animations, and forces
  light appearance and a 2x display scale.
- Render the **content** view, never the connected one, and wrap it in `NavigationStack`
  so titles and links appear.
- Data comes from `Fixtures`. Add to it rather than building values inline.
- Cover every state a screen has: populated, empty, failing, in progress.
- `assertScreen` picks the size and the reference name per platform
  (`…-iPhone.png` / `…-mac.png`), so one test covers both.

## Determinism

Anything that changes between runs will flap: `Date()`, `UUID()`, live data, and
indeterminate `ProgressView`s. Fixtures use fixed dates and fixed UUIDs; give a
determinate progress value when snapshotting an in-progress state.

## Known Catalyst quirks (not bugs)

- Menu `Picker`s render as empty popup buttons in Mac references. The running app draws
  them correctly — verified by launching the Catalyst build.
- `.regularMaterial` renders flat.

Do not change the UI to make these look different. Anything else that differs between
platforms is worth investigating.

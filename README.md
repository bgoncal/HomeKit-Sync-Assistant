# Home Sync Assistant

A SwiftUI app for iPhone, iPad, and Mac (via Mac Catalyst) that keeps **Apple Home** and
**Home Assistant** telling the same story: rooms and areas, which room each device sits
in, and device names. It also serves a small local HTTP API so your own scripts can read
and change Apple Home.

Every sync runs in one direction that you choose, and always starts as a preview —
nothing is written until you apply it.

## Requirements

Devices must reach Apple Home through Home Assistant's **HomeKit Bridge** integration.
That integration writes the Home Assistant entity ID into the HomeKit serial number,
which is how the two sides are paired. Native HomeKit accessories and devices from other
bridges are listed, skipped, and left untouched.

## Setup

The setup guide walks through it: what the app syncs, how devices are paired, the
HomeKit Bridge requirement, HomeKit permission, and your Home Assistant address plus a
long-lived access token. You can run it again from Settings.

## Licensing

The code is under the [PolyForm Noncommercial License 1.0.0](LICENSE.md). In short: use it,
change it and share it for any **noncommercial** purpose — personal use, study, hobby projects,
and noncommercial organisations. Selling it, or using it as part of something commercial, is not
covered. If you need commercial terms, ask.

Two things are **not** covered by that licence, so a fork stays clearly a fork:

- The app name, **Home Sync Assistant**.
- The app icon and artwork in `HomeKitBridge/AppIcon.icon`, and the store material under
  `Metadata/` and `Screenshots/`.

Contributions are welcome under the same licence: by opening a pull request you licence your
contribution to the project owner under these terms, and agree it may be released under a
different licence in future.

## Development

- [AGENTS.md](AGENTS.md) — architecture, conventions, and how to run things.
- `.claude/skills/` — `swift-style`, `swiftui-native-design`, `snapshot-tests`.
- `.claude/agents/` — subagents for building screens, recording snapshots, and copy.
- `Scripts/snapshot-tests.sh iphone|mac` — the test suite, including a snapshot of every
  screen on both platforms.

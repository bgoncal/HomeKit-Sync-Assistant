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

## Development

- [AGENTS.md](AGENTS.md) — architecture, conventions, and how to run things.
- `.claude/skills/` — `swift-style`, `swiftui-native-design`, `snapshot-tests`.
- `.claude/agents/` — subagents for building screens, recording snapshots, and copy.
- `Scripts/snapshot-tests.sh iphone|mac` — the test suite, including a snapshot of every
  screen on both platforms.

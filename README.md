# HomeKit Sync Assistant

A SwiftUI app (iPhone, iPad, and Mac via Mac Catalyst) that keeps **Apple Home** and
**Home Assistant** in sync: rooms and areas, which room each device sits in, and
device names. It also exposes a small local HTTP API so your own scripts can read and
change Apple Home.

Every sync runs in one direction that you choose, and always starts as a preview —
nothing is written until you apply it.

## Requirements

Devices must be exposed to Apple Home through Home Assistant's **HomeKit Bridge**
integration. That integration writes the Home Assistant entity ID into the HomeKit
serial number, which is how the two sides are paired. Native HomeKit accessories and
devices from other bridges are skipped and left untouched.

## Setup

The app's setup guide walks through it: what it syncs, how devices are matched,
the HomeKit Bridge requirement, HomeKit permission, and your Home Assistant address
plus a long-lived access token. You can run the guide again from Settings.

## Development

See [AGENTS.md](AGENTS.md) for the architecture, conventions, and how to run the
snapshot tests for iPhone and Mac.

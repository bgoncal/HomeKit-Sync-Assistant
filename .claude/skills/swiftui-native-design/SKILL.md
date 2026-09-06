---
name: swiftui-native-design
description: How screens in HomeKitBridge are built so they look like Apple's built-in iOS apps — grouped List/Form sections, explanatory footers, LabeledContent rows, ContentUnavailableView, the connected/content split, and the copy rules. Use when creating, restyling, or reviewing any SwiftUI screen.
---

# Screens that look built-in

The target is the Settings app, not a dashboard. If a screen needs a custom card,
a gradient, or a hand-drawn container to look finished, it is the wrong shape.

## The split every screen has

```swift
struct DashboardView: View {            // connected: reads services, passes values
    @EnvironmentObject private var homeKitManager: HomeKitManager
    var body: some View { DashboardContent(home: homeKitManager.selectedHome, …) }
}

struct DashboardContent: View {         // pure: values, bindings, closures
    let home: HomeSummary?
    var onConnect: () -> Void = {}
    var body: some View { List { … }.listStyle(.insetGrouped).navigationTitle("Dashboard") }
}
```

The content view is what the snapshot tests render. Anything it cannot be handed as a
value belongs in the connected view.

## Structure

- `List` (or `Form` for settings-like input) with `.listStyle(.insetGrouped)`.
- `Section { rows } header: { Text("Home Assistant") } footer: { Text("why this matters") }`.
  **Footers carry the explanation.** Never a paragraph floating between cards.
- `LabeledContent("Rooms", value: …)` for a fact, `Toggle`/`Picker`/`Stepper`/`DatePicker`
  for a setting, `Button` for an action, `NavigationLink` to go deeper.
- Drill down instead of nesting: a long list of services or a JSON payload is its own
  screen, not a `DisclosureGroup` inside a card.
- `.navigationTitle` on the content view, `NavigationStack` supplied by the host
  (`MainTabView` wraps each tab; `DevicesView` owns its own because it has a path).
- Empty and failed states are `ContentUnavailableView`, in an `.overlay`, with an action
  button when there is an obvious next step. Use `ContentUnavailableView.search(text:)`
  when a search comes up empty.
- `.searchable` for any list that can grow past a screenful.
- Secondary actions go in `.toolbar { ToolbarItem(placement: .primaryAction) { … } }`,
  usually a `Menu` when there is more than one.
- Five tabs at most on iPhone. Anything else is a row inside one of them.

## Group per item

Anything the person can have more than one of — a Home Assistant server, an Apple
Home — gets **its own section** (Dashboard) or **its own row with a detail screen**
(Settings), with that item's name as the section header. Never a single "Connection"
section with fields for whichever one happens to be selected. Pairings between two
kinds of item are a `Picker` on the row of the thing being paired.

## Rows

The shared pieces live in `HomeKitBridge/Views/BridgeUI.swift`:

- `BridgeStatusRow` — glyph, name, one line saying what the state means.
- `BridgeFeatureRow` — 44pt icon, headline, one explaining line. Onboarding and empty
  states, in the shape of Apple's own welcome screens.
- `BridgePill` / `BridgeDirectionBadge` — a status word or a direction, in a tinted capsule.
- `BridgeCodeBlock` — the only place a monospaced font appears.

Build the row from these before writing another `HStack`.

## Colour and type

- System colours only: `.secondary`, `.tint`, `Color(uiColor: .systemGroupedBackground)`.
  No hand-picked hex, no `.regularMaterial` over an opaque background (it renders flat
  in snapshots and buys nothing on device).
- Semantic fonts: `.body`, `.subheadline`, `.footnote`, `.caption`. Weight, not size.
- SF Symbols via `Image(systemName:)`/`Label`. Verify the symbol exists — an invalid
  name renders as nothing, and that is how a blank row happens.
- `.fixedSize(horizontal: false, vertical: true)` on any multi-line text in an `HStack`,
  and `ViewThatFits` when a row has to survive a narrow width.

## Words

- "Apple Home" and "Home Assistant", always in full.
- Name the side that changes: "2 changes will be made in Apple Home. Home Assistant will
  not change."
- Titles Title Case, sentences sentence case, buttons are verbs.
- Errors say what to do next, and quote other systems verbatim.

## Reference

Bruno's other apps are the house style; read them when unsure:
`../Muni/MuniKit/Sources/MuniFeature/` (welcome screen, settings, feed list),
`../XFinanceToGo/Sources/Phone/` (list-driven dashboard, rows, empty states),
`../XToGo/Sources/XToGoDesign/` (status chips, empty states).

## Check it

Every screen ships with snapshot tests for each of its states, recorded for iPhone and
Mac. Look at the images: an off-platform screen is obvious in a PNG and invisible in a
diff.

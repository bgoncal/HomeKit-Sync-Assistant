# Store screenshot copy — Home Sync Assistant

Six screens, in the order they tell the story. Headlines are five words or fewer; the copy
rules from `RELEASE_PLAYBOOK.md` apply here as they do to the listing: no Apple terms, no
platform or device names ("your home app", never the product's name), keep it short.

Raw captures come from `Scripts/capture-screenshots.sh` (`iphone/` 1320×2868, `ipad/`
2064×2752). Framed sets are rendered by Vitrine into `framed/` with the same palette on
every screen: `backgroundTop #0A84FF` (the app's blue tint), `backgroundBottom #31209C`
(the icon's indigo); the badge, centered and full-bleed screens use the solid `#31209C` with
`accent #0A84FF`.

The `*-title-below` layouts show the bottom of the device and crop the top tenth of the screen,
which is where every screen here keeps its title bar — so they are not used. The phone set uses
`iphone-centered` (title only, whole device visible) for the entities screen instead; the tablet
has no centered layout, so it stays on `ipad-title-above`.

| # | Capture | Template | Headline | Line |
|---|---|---|---|---|
| 1 | `01-home` | tilted | Both sides, one place | Your home app and Home Assistant, side by side, with every connection's status. |
| 2 | `02-sync` | badge ("Preview") | Nothing is written unseen | Every sync starts as a list of exact changes. Apply it only when it looks right. |
| 3 | `03-devices` | title-above | Devices grouped by room | Every home you can reach, room by room, with the devices that are bridged. |
| 4 | `04-entities` | centered (phone) / title-above (tablet) | Entities grouped by area | Each server's entities, with their IDs and states, searchable by name. |
| 5 | `05-device` | title-above | Paired by entity ID | See where a device lives on both sides, and the raw data behind the match. |
| 6 | `06-activity` | full-bleed | Every change on record | What ran, what it touched and what failed, with filters and export. |

The same six captions frame the phone and the tablet sets; the centered layout carries the headline only.

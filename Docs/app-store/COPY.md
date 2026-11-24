# Store screenshot copy — Home Sync Assistant

Six screens, in the order they tell the story. Headlines are five words or fewer; the copy
rules from `RELEASE_PLAYBOOK.md` apply here as they do to the listing: no Apple terms, no
platform or device names ("your home app", never the product's name), keep it short.

Raw captures come from `Scripts/capture-screenshots.sh` (`iphone/` 1320×2868, `ipad/`
2064×2752). Framed sets are rendered by Vitrine into `framed/` in the icon's palette since 1.2:
`backgroundTop #2B3354`, `backgroundBottom #0A0E1F` (the icon's midnight gradient); the badge and
full-bleed screens use the solid `#141A33` with `accent #0A84FF`.

The phone's Sync capture shows the top of the screen (direction and subjects): a store capture
cannot scroll the list, so on the phone it is captioned for the direction, and on the tablet,
where the preview fits, for the preview.

| # | Capture | Template | Headline | Line |
|---|---|---|---|---|
| 1 | `01-home` | tilted | Both sides, one place | Your home app and Home Assistant side by side, with each connection's status. |
| 2 | `02-sync` | title-above (phone) / badge "Preview" (tablet) | You pick the direction / Nothing is written unseen | Choose which side changes, and what: rooms, placement, names, floors or scenes. / Every sync starts as a list of exact changes. Untick any you would rather keep. |
| 3 | `03-differences` | title-above | See every difference | Rooms, areas and names that disagree, before anything changes. |
| 4 | `04-devices` | title-above | Leave anything out | Exclude an accessory or a whole room, and every sync leaves it alone. |
| 5 | `05-device` | title-above | Paired by entity ID | See an accessory on both sides, or choose its entity by hand. |
| 6 | `06-activity` | full-bleed | Every change on record | What ran, what it touched and what failed, with filters and export. |

Uploaded for 1.2 with `Scripts/upload_framed_sets.py` (the listing holds 1290×2796 and 2048×2732).

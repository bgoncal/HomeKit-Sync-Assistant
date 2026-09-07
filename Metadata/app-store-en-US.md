# App Store listing — Home Sync Assistant (en-US)

App id 6790157317 · bundle `com.panta.homekitsync` · iOS and macOS version records, both 1.0.
Filled 2026-09-07 through `Scripts/asc_write.py`. Copy follows the rules in
`../../RELEASE_PLAYBOOK.md`: no Apple terms, no platform or device names, no language lists —
which is why the listing says "your home app" rather than naming it.

## Filled

| Field | Value |
|---|---|
| Name | Home Sync Assistant |
| Subtitle | Sync rooms, names and areas |
| Categories | Utilities (primary), Lifestyle (secondary) |
| Keywords | home assistant,sync,rooms,areas,entities,accessories,smart home,automation,bridge,names |
| Support URL | https://x.com/bgoncal2 |
| Marketing URL | https://github.com/bgoncal/HomeKit-Sync-Assistant |
| Copyright | 2026, Bruno Goncalves |
| Age rating | 4+, everything declared as none |
| Content rights | Does not use third-party content |
| Price | Free |
| Availability | 175 territories |
| Screenshots | Four 6.7" iPhone shots, delivery COMPLETE |
| In-app purchase | `com.hasync.tip`, consumable — name, description and review note set |

### Promotional text

> Compare both sides, preview every change, and write it only when the list looks right.

### Description

Held verbatim in App Store Connect; 1390 characters. It covers what the app syncs, that the
direction is chosen per sync and previewed first, several homes and several servers, the local
API, and the requirement that accessories arrive through the Home Assistant bridge integration.

## Still open

1. **Privacy policy URL** — required before submission. Bruno is sharing a publicly editable
   document; the text to paste is in `privacy-policy.md` beside this file.
2. **Tip price** — `com.hasync.tip` stays `MISSING_METADATA` until a price tier is chosen. That
   is a business decision, so it was left alone.
3. **macOS screenshots** — the Mac version record has none. `Scripts/capture-screenshots.sh`
   only renders the phone sizes; a Catalyst capture needs a Retina display.
4. **Never submit for review from here.** That stays a human action.

## Regenerating the screenshots

`Scripts/capture-screenshots.sh` renders the real screens with the test fixtures at 1290×2796
into `../Screenshots/`, then `asc_write.upload_screenshots(..., 'IOS', 'APP_IPHONE_67', files,
replace=True)` uploads them in order.

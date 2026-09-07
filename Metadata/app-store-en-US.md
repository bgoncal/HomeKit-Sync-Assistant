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
| In-app purchase | `com.hasync.tip`, consumable — `READY_TO_SUBMIT`: name, description, review note, price (0.99) and review screenshot |
| Privacy policy | https://docs.google.com/document/d/1-p0J8RKmV6EXyJNK6Bo0dR4PyoYJMj2oRcBkc8QXY5M/preview |

### Promotional text

> Compare both sides, preview every change, and write it only when the list looks right.

### Description

Held verbatim in App Store Connect; 1390 characters. It covers what the app syncs, that the
direction is chosen per sync and previewed first, several homes and several servers, the local
API, and the requirement that accessories arrive through the Home Assistant bridge integration.

## Still open

1. **Nothing but the submit button, for iOS.** Text, screenshots, age rating, content rights,
   price, availability, privacy policy and the tip product are all in place, and build 21 is
   attached. Submitting stays a human action — never do it from here.
2. **macOS is deferred.** Bruno is not releasing the Mac version for now, so its version record
   is left in Prepare for Submission with no screenshots. Nothing to do until that changes.

## The tip product

`com.hasync.tip` is a consumable. It sat at `MISSING_METADATA` even after the price was set,
because a first submission also needs a review screenshot; `Screenshots/01-home.png` was uploaded
as that, since it shows the tip row and its price. It reads `READY_TO_SUBMIT` now.

## The privacy policy

`privacy-policy.md` beside this file is the source. It was pasted into Bruno's Google Doc
through the browser (the recipe in `../../RELEASE_PLAYBOOK.md`) and read back paragraph by
paragraph; the store points at the document's `/preview` URL, which resolves without a Google
account. Edit the markdown first, then repeat the paste, so the two do not drift.

## Regenerating the screenshots

`Scripts/capture-screenshots.sh` renders the real screens with the test fixtures at 1290×2796
into `../Screenshots/`, then `asc_write.upload_screenshots(..., 'IOS', 'APP_IPHONE_67', files,
replace=True)` uploads them in order.

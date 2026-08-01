# UI005 — TP-Member dashboard with full member parity (fallback version)

Saved: 2026-06-27

This is the most recent known-good version to fall back on.

## What this snapshot contains
- `lib/features/auth/trusted_partner_home_page.dart` — current working Trusted Partner home page.

## State captured in this version
- Redesigned TP business dashboard ("command center" layout) with header left untouched.
- QR scanner card height reduced (~half).
- New custom **TP-Member dashboard** shown when the TP toggles to Member mode (not raw `MembersHomePage`):
  - Editable member profile picture + name header above the savings card.
  - Savings summary card with a small QR symbol in its top-right corner.
  - Tapping the QR symbol expands the full membership QR card above the savings card.
  - Surname de-duplication on the member name.
- Three responsive layouts selected by form factor:
  - Wide/desktop (>= 1000): centered two-column.
  - Landscape (>= 600): compact two-column.
  - Portrait/narrow: single column.
- **Full member functional parity** (kept in the new UI):
  - Action tiles: Find Deals, Trusted Partners, My Receipts & History, My Profile, Pending Payments, Back to Business Mode.
  - Today stats (partners nearby + active deals counts).
  - Pending payments urgent card (when count > 0).
  - Eligible promotions banners.
  - Member city flows into deals/partners browsing as `cityFilter`.

## How to restore
Copy the file back over the working tree:

```powershell
Copy-Item "ui_snapshots\UI005\lib\features\auth\trusted_partner_home_page.dart" "lib\features\auth\trusted_partner_home_page.dart" -Force
```

Then hot-restart the running `flutter run` web server (press `R`) so the web build recompiles.

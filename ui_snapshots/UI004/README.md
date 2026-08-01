# UI004 Android Portrait Proposal

- Date: 2026-06-27
- Purpose: TP home screen portrait mockup with card content positioned higher up.
- Scope: Proposal snapshot only. No production file changed.
- Source baseline: `lib/features/auth/trusted_partner_home_page.dart`
- Proposal file: `ui_snapshots/UI004/lib/features/auth/trusted_partner_home_page.dart`

## What Changed In This Mockup

1. Reduced portrait compact identity panel padding.
- Before: 14
- After: 10

2. Reduced portrait compact logo size.
- Before: 90
- After: 82

3. Reduced compact portrait gap between identity panel and scanner panel.
- Before: 14
- After: 8

Estimated vertical lift of primary card content in portrait: about 18 px.

## Approval Focus

- Does the card feel visually higher and tighter in Android portrait?
- Is readability still good for business name and CTA?
- Should we keep the current scanner panel size or tighten it further in portrait?

## Next Step After Approval

- Apply the same 3 changes to `lib/features/auth/trusted_partner_home_page.dart`.
- Run a quick portrait validation pass in emulator/device.

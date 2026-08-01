# TP Home Android Portrait Mockup Notes

This proposal targets one request only: move card items higher up in portrait.

## Proposed Portrait Layout Intent

- Keep top card shell anchored near the top.
- Compress vertical whitespace inside the identity panel.
- Keep action hierarchy unchanged (name, profile CTA, banking CTA, scanner card).

## Simple Wireframe (Portrait)

```
[AppBar]
[Hero Card Shell]
  [Logo][Business Name]
  [Edit Profile CTA]
  [Banking Status CTA]
  [Scanner Card]
[Deal Authorizations]
[Analytics]
[Shutter Scanner]
```

Compared with current baseline, this mockup reduces empty vertical gaps before the scanner section so key items appear sooner on screen.

## Safety

- No route changes.
- No business logic changes.
- No backend/RPC changes.
- No production file changes yet.

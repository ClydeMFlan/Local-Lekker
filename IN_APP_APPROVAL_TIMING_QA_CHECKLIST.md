# In-App Approval Timing QA Checklist

Purpose: Validate that a member receives the in-app payment popup immediately after trusted partner approval, including app resume recovery, without sign-out/sign-in.

## Scope

- In scope: In-app payment request lifecycle and popup timing/reliability.
- In scope: Resume recovery when app was backgrounded.
- In scope: Duplicate-popup prevention behavior.
- In scope: POS flow regression check.
- Out of scope: Database schema migrations and payment gateway credential setup.

## Preconditions

- Member test account with active subscription.
- Trusted partner test account with at least one active deal.
- Two devices (or two emulators): one signed in as member, one as trusted partner.
- App build includes lifecycle reconnect change in MembersHomePage.
- Supabase SQL editor access for verification queries.

## Test Data

- Payment method for primary test: in_app
- Payment method for regression test: pos
- Deal name: __________________
- Member user_id: __________________
- Trusted partner user_id: __________________

## Scenario A: Foreground immediate popup (in_app)

1. Member opens home screen and stays active.
2. Member requests a deal with payment method in_app.
3. TP opens pending requests and approves the same deal.
4. Observe member app.

Expected:

- Popup appears without navigation refresh.
- Member does not need sign-out/sign-in.
- Popup shows approved deal details and authorize payment action.

Record:

- Result: Pass / Fail
- Popup delay seconds: ______
- Notes: ________________________________

## Scenario B: Background then resume recovery (in_app)

1. Member opens home screen.
2. Send app to background.
3. TP approves a pending in_app request while member app is backgrounded.
4. Bring member app to foreground.

Expected:

- App resumes and re-subscribes approval stream.
- Fallback unread-check runs on resume.
- Popup appears without sign-out/sign-in.

Record:

- Result: Pass / Fail
- Popup delay after resume seconds: ______
- Notes: ________________________________

## Scenario C: Realtime interruption fallback (in_app)

1. Member on home screen.
2. Briefly disable member network.
3. TP approves in_app request while member is offline.
4. Re-enable member network.
5. Resume or foreground app if needed.

Expected:

- Stream reconnect and/or fallback unread-check surfaces popup.
- No forced logout needed.

Record:

- Result: Pass / Fail
- Recovery path observed: Stream / Fallback / Both
- Notes: ________________________________

## Scenario D: No duplicate popup

1. Trigger one approval event.
2. Keep app on home screen for 20-30 seconds.
3. Background and resume once.

Expected:

- Same approval popup does not loop repeatedly.
- Notification read state prevents duplicate prompts.

Record:

- Result: Pass / Fail
- Duplicate count observed: ______
- Notes: ________________________________

## Scenario E: POS regression check

1. Member requests deal with payment method pos.
2. TP approves.
3. Member receives store-visit style approval notification.
4. TP confirms payment from dashboard.
5. Receipt is generated and appears in member receipts.

Expected:

- No in-app Paystack popup for POS.
- POS completion and receipt path remains functional.

Record:

- Result: Pass / Fail
- Notes: ________________________________

## Suggested verification SQL

```sql
-- Replace with member id
select id, type, title, is_read, created_at
from notifications
where user_id = 'MEMBER_USER_ID'
  and type in ('deal_approved', 'pos_deal_approved')
order by created_at desc
limit 20;
```

```sql
-- Replace with deal authorization id
select id, status, payment_method, approved_at, completed_at, payment_completed_at
from deal_authorizations
where id = 'DEAL_AUTHORIZATION_ID';
```

```sql
-- POS receipt verification
select id, deal_authorization_id, payment_method, receipt_number, created_at
from deal_receipts
where member_id = 'MEMBER_USER_ID'
order by created_at desc
limit 10;
```

## Release Gate

Mark this test set as passing only if all conditions are true:

- Scenario A Pass
- Scenario B Pass
- Scenario C Pass
- Scenario D Pass
- Scenario E Pass

Tester signoff:

- Tester: __________________
- Date: __________________
- Build: __________________
- Final verdict: Pass / Fail

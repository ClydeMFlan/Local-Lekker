# Firebase Push Notification Setup Guide

This guide explains how to complete the setup for **true push notifications** that reach the trusted partner's device even when the app is completely closed.

## How It Works

1. **Member requests a deal** → `DealAuthorizationService` creates the deal authorization
2. **In-app notification created** → `NotificationService.notifyTrustedPartnerOfDealRequest()` inserts a row into `notifications` table
3. **Database webhook fires** → Supabase calls the `send-push-notification` Edge Function
4. **Edge Function sends FCM push** → Looks up the TP's FCM token from `profiles.fcm_token`, sends a push via Firebase Cloud Messaging HTTP v1 API
5. **Device receives push** → Android/iOS system tray shows the notification even if the app is killed

## Setup Steps

### Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **Add project** → name it `local-lekker` (or similar)
3. Disable Google Analytics (optional) → **Create project**

### Step 2: Add Android App to Firebase

1. In Firebase Console → **Project settings** → **Add app** → **Android**
2. Android package name: `com.locallekker.app`
3. App nickname: `Local Lekker`
4. Download `google-services.json`
5. Place it at: `android/app/google-services.json`

### Step 3: Run Database Migration

Run this SQL in the Supabase SQL Editor:

```sql
-- From: add_fcm_token_to_profiles.sql
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS fcm_token TEXT;
CREATE INDEX IF NOT EXISTS idx_profiles_fcm_token ON profiles (id) WHERE fcm_token IS NOT NULL;
```

### Step 4: Deploy the Edge Function

```bash
supabase functions deploy send-push-notification
```

### Step 5: Set FCM Service Account Secret

1. In Firebase Console → **Project settings** → **Service accounts**
2. Click **Generate new private key** → download the JSON file
3. Set it as a Supabase secret:

```bash
supabase secrets set FCM_SERVICE_ACCOUNT_KEY='<paste entire JSON content here>'
```

### Step 6: Create Database Webhook

1. Go to Supabase Dashboard → **Database** → **Webhooks**
2. Click **Create a new webhook**
3. Configure:
   - **Name**: `send_push_notification_on_insert`
   - **Table**: `notifications`
   - **Events**: `INSERT`
   - **Type**: Supabase Edge Functions
   - **Edge Function**: `send-push-notification`
   - **HTTP Headers**:
     - Key: `Authorization`
     - Value: `Bearer <your SUPABASE_SERVICE_ROLE_KEY>`

### Step 7: Build & Test

```bash
flutter pub get
flutter run
```

1. Log in as a trusted partner on one device → the app will register the FCM token
2. Close the app completely (swipe away / force stop)
3. On another device, log in as a member and request a deal from that TP
4. The TP's phone should show a push notification in the system tray

## Files Changed

| File | Change |
|------|--------|
| `pubspec.yaml` | Added `firebase_core` and `firebase_messaging` dependencies |
| `lib/main.dart` | Added Firebase initialization and background message handler registration |
| `lib/services/push_notification_service.dart` | Added FCM token management, foreground message handling, and `firebaseMessagingBackgroundHandler` |
| `android/app/build.gradle.kts` | Added `com.google.gms.google-services` plugin |
| `android/settings.gradle.kts` | Added Google services plugin dependency |
| `android/app/src/main/AndroidManifest.xml` | Added `POST_NOTIFICATIONS` permission |
| `supabase/functions/send-push-notification/index.ts` | New Edge Function that sends FCM pushes |
| `add_fcm_token_to_profiles.sql` | Migration to add `fcm_token` column to profiles |
| `add_push_notification_webhook_trigger.sql` | Documentation for the database webhook setup |

## Troubleshooting

- **No push when app is closed**: Check that `google-services.json` is in `android/app/` and the FCM secret is set correctly
- **Token not stored**: Check Supabase logs for RLS errors on `profiles` update. The user must be authenticated.
- **Edge function errors**: Check Supabase Edge Function logs in the dashboard
- **Stale tokens**: The edge function automatically clears invalid FCM tokens from profiles

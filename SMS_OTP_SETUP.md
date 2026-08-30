# SMS OTP Setup

The app sends SMS OTPs through Supabase Auth. SMS provider credentials stay in Supabase and must never be added to the Flutter `.env` file.

## Supabase Configuration

1. In the Supabase dashboard, open **Authentication** > **Providers** > **Phone**.
2. Enable the Phone provider and configure a supported SMS provider using its credentials.
3. Set the SMS message template to include the `{{ .Code }}` variable.
4. Configure SMS rate limits appropriate for production and test delivery with a real mobile number.

## App Behavior

- Signup verification presents Email and SMS when a contact number was entered.
- SMS uses an E.164 number. South African local mobile numbers such as `0821234567` are normalized to `+27821234567`.
- Existing email-only Supabase Auth users cannot receive a phone sign-in OTP until a verified phone identity has been enrolled in Supabase Auth. A `profiles.contact` value alone is not an Auth phone identity.
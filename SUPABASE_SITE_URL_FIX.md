-- Supabase Configuration Check for Password Reset

The password reset URL shows:
https://qdrotavcmmevhgveodcp.supabase.co/auth/v1/verify?token=...&type=recovery&redirect_to=locallekker://auth/callback

Issues to fix:

1. **Site URL Configuration** - In Supabase dashboard:
   - Go to Authentication → Settings → Site URL
   - Change from current URL to: locallekker://auth/callback
   - This tells Supabase to redirect with tokens in the fragment

2. **Redirect URLs** - In Supabase dashboard:
   - Go to Authentication → Settings → Redirect URLs
   - Add: locallekker://auth/callback
   - This allows deep links from that scheme

3. **Verify the redirect works** - After changing Site URL to locallekker://auth/callback:
   - The verify endpoint will redirect with the access_token in the fragment
   - URL should become: locallekker://auth/callback#access_token=...&type=recovery

Without this configuration, Supabase won't include the tokens in the redirect, so the app won't have the credentials to complete password reset.

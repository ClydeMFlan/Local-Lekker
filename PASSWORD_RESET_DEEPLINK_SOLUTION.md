# Password Reset Deep Link Flow Fix

## Current Problem
- Site URL set to Supabase domain
- Supabase verify endpoint can't redirect to `locallekker://` deep link properly
- Email link goes to Supabase verify endpoint which then errors

## Solution: Use Web Redirect Intermediary

Instead of trying to make Supabase redirect directly to deep link, we use a web page that does the redirect:

1. **Update Site URL** in Supabase Dashboard → URL Configuration:
   - Set to: `https://yourdomain.com/auth/callback` (or create a simple redirect page)
   
2. **Redirect URLs** should still include:
   - `locallekker://auth/callback`

3. **Create a simple HTML redirect page** at `https://yourdomain.com/auth/callback` that:
   - Reads the token from query parameters
   - Extracts type (recovery, signup, etc)
   - Redirects to: `locallekker://auth/callback#access_token=TOKEN&type=TYPE&refresh_token=REFRESH`

## Quick Alternative
Set Site URL to any valid https URL (like `https://locallekker.com` or `https://localhost`), and ensure the redirect parameters are properly configured in Supabase's email template.

The key is that Supabase needs a valid https URL to process, but it will append the `redirect_to` parameter which points to your deep link.

Let me know if you have a website domain we can use for the Site URL instead.

-- Test admin deletion in the Flutter app
-- This should now work since we fixed the Edge Function

// In your Flutter app, try deleting a trusted partner again.
// The AdminService.deleteTrustedPartner() method should now:

1. ✅ Delete all user data (profiles, trusted_partners, etc.)
2. ✅ Call the Edge Function to delete the auth user
3. ✅ The Edge Function now properly checks admin permissions

// Test with a real trusted partner deletion in the app UI.
// The auth user should now be completely removed.
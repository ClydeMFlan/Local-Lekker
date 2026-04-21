# Google Play Store Internal Testing Upload Guide

## ✅ AAB Build Complete
**File Location:** `build\app\outputs\bundle\release\app-release.aab` (62.8MB)
**Version:** 1.0.0+2

## 📋 Upload Steps for Internal Testing

### 1. Access Google Play Console
1. Go to [Google Play Console](https://play.google.com/console)
2. Sign in with your developer account
3. Select your app (Local Lekker) or create a new app if this is the first upload

### 2. Set Up Internal Testing Track
1. In the left sidebar, go to **Testing → Internal testing**
2. Click **Create new release**

### 3. Upload the AAB
1. Click **Upload** in the "App bundles" section
2. Select the file: `build\app\outputs\bundle\release\app-release.aab`
3. Wait for the upload to complete (may take a few minutes for 62.8MB)
4. Google Play will automatically process and analyze the AAB

### 4. Configure Release Details
1. **Release name:** Enter a name (e.g., "v1.0.0 - Internal Test Build 2")
2. **Release notes:** Add what's new or being tested:
   ```
   Internal testing release for Local Lekker
   - Payment integration with Paystack
   - Receipt scanning with OCR
   - QR code payment system
   - Business partner management
   ```

### 5. Review and Rollout
1. Review the release summary
2. Click **Review release**
3. Confirm there are no errors or warnings
4. Click **Start rollout to Internal testing**

### 6. Add Testers
1. Go to **Testing → Internal testing → Testers tab**
2. Create an email list or use an existing one
3. Add tester email addresses (up to 100 for internal testing)
4. Save the tester list

### 7. Share Testing Link
1. After rollout, you'll get a testing link
2. Share this link with your testers
3. Testers need to:
   - Open the link on their Android device
   - Accept the invitation
   - Download the app from Play Store

## 🔍 Important Pre-Upload Checklist

### App Information Required (First-Time Setup)
If this is your first upload, ensure you have completed:

- [ ] **App details**
  - App name: Local Lekker
  - Short description (80 chars max)
  - Full description (4000 chars max)
  - App category: Business / Finance
  - Contact email and website

- [ ] **Store listing**
  - Screenshots (at least 2, up to 8)
    - Minimum dimension: 320px
    - Maximum dimension: 3840px
    - Recommended: 1080x1920 (phone screenshots)
  - Feature graphic (1024x500px)
  - App icon (512x512px, 32-bit PNG with alpha)

- [ ] **Content rating**
  - Complete the content rating questionnaire
  - Select appropriate age ratings

- [ ] **Privacy policy**
  - Add privacy policy URL
  - Required for apps that handle user data

- [ ] **App content**
  - Data safety section (describe data collection)
  - Target audience and content
  - News apps declaration (if applicable)

### Technical Requirements
- [x] AAB file signed with upload keystore
- [x] Version code incremented (currently: 2)
- [x] Release build configuration
- [ ] Test on physical devices before wide release

## 🚀 After Upload - Testing Process

### Internal Testing Best Practices
1. **Install and Launch Testing**
   - Verify app installs correctly
   - Check app doesn't crash on startup
   - Test on different Android versions

2. **Core Feature Testing**
   - Member signup and payment flow
   - QR code generation and scanning
   - Receipt upload and OCR processing
   - Business partner dashboard
   - Admin functions

3. **Payment Testing**
   - Test Paystack integration
   - Verify subscription creation
   - Check payment status updates
   - Test renewal flows

4. **Offline/Online Testing**
   - Test offline payment handling
   - Verify sync after reconnection
   - Check SharedPreferences caching

### Collecting Feedback
1. Monitor Play Console for crash reports
2. Check pre-launch reports (automatic testing by Google)
3. Gather tester feedback
4. Review Firebase Crashlytics (if configured)

## 📊 Moving to Production

Once internal testing is successful:

1. **Promote to Closed Testing** (Optional)
   - Testing → Closed testing
   - Larger group (up to 1000+ users)
   - More extensive testing period

2. **Promote to Open Testing** (Optional)
   - Testing → Open testing
   - Anyone can join and test
   - Good for public beta

3. **Production Release**
   - Release → Production
   - Review full release checklist
   - Submit for review
   - Google typically reviews within 24-48 hours

## ⚠️ Common Issues and Solutions

### Upload Errors

**Issue:** "You need to use a different version code"
- **Solution:** Increment version in pubspec.yaml (currently 1.0.0+2)

**Issue:** "APK or Android App Bundle is not zip aligned"
- **Solution:** Rebuild with `flutter build appbundle --release`

**Issue:** "Upload certificate has fingerprint... but needs..."
- **Solution:** Ensure using correct keystore (upload-keystore.jks)

### Review Rejections

**Issue:** "Missing privacy policy"
- **Solution:** Add privacy policy URL in App content section

**Issue:** "Inappropriate content rating"
- **Solution:** Complete content rating questionnaire accurately

**Issue:** "Permissions not justified"
- **Solution:** Explain why each permission is needed in description

## 🔐 Security Reminders

- ✅ AAB is signed with upload keystore (upload-keystore.jks)
- ✅ Never commit keystore files to git
- ✅ Keep keystore password secure
- ✅ Production environment variables in .env
- ⚠️ Verify PAYSTACK_SANDBOX=false for live payments

## 📞 Support

- Play Console Help: https://support.google.com/googleplay/android-developer
- Flutter Documentation: https://docs.flutter.dev/deployment/android
- Supabase Setup: Ensure RLS policies are production-ready

---

**Built on:** January 19, 2026
**Build Script:** `build_production.sh` (Windows: run in Git Bash or WSL)
**Manual Build:** `flutter build appbundle --release`

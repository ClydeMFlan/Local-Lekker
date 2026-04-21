# 🚀 Local Lekker Production Launch Checklist

## **Pre-Launch Requirements (Complete Before App Store Submission)**

### **1. Legal & Regulatory Compliance**
- [ ] **Business Registration**: Register as a Payment Service Provider (PSP) with SARB
- [ ] **FSP License**: Apply for Financial Services Provider license
- [ ] **POPIA Compliance**: Data protection policy and consent forms
- [ ] **Terms of Service**: User agreement and merchant terms
- [ ] **Privacy Policy**: GDPR/POPIA compliant privacy policy
- [ ] **PCI DSS**: PayFast handles compliance (document confirmation)

### **2. PayFast Live Account Setup**
- [ ] **Live Merchant Account**: Create production PayFast account at https://www.payfast.co.za
- [ ] **Bank Account Verification**: Verify business bank account with PayFast
- [ ] **Merchant Credentials**: Obtain live merchant ID, key, and passphrase
- [ ] **Webhook URL**: Configure `https://your-project.supabase.co/functions/v1/payfast-webhook`
- [ ] **IP Whitelisting**: Whitelist Supabase server IPs (contact PayFast support)

### **3. Supabase Production Setup**
- [ ] **Edge Function Deployment**:
  ```bash
  supabase functions deploy payfast-webhook
  ```
- [ ] **Environment Variables**: Set production secrets in Supabase dashboard
- [ ] **Database Backup**: Create full production backup
- [ ] **Monitoring**: Enable Supabase monitoring and alerts

### **4. App Configuration Updates**

#### **Update `.env` file with production values:**
```env
# PayFast Production Credentials
PAYFAST_MERCHANT_ID=YOUR_LIVE_MERCHANT_ID
PAYFAST_MERCHANT_KEY=YOUR_LIVE_MERCHANT_KEY
PAYFAST_PASSPHRASE=YOUR_LIVE_PASSPHRASE
PAYFAST_SANDBOX=false

# Production Settings
PAYFAST_DEVELOPMENT_MODE=false
FORCE_WELCOME_PAGE=false

# OCR Production API (if using)
VERYFI_CLIENT_ID=YOUR_PRODUCTION_CLIENT_ID
VERYFI_CLIENT_SECRET=YOUR_PRODUCTION_CLIENT_SECRET
```

#### **Update `pubspec.yaml`:**
```yaml
name: local_lekker
description: "Local Lekker - Smart receipt scanning and local business payments. Get instant discounts and pay digitally at your favorite local businesses."
version: 1.0.0+1
```

### **5. Android Production Build**

#### **Create signing keystore:**
```bash
keytool -genkey -v -keystore local_lekker.jks -keyalg RSA -keysize 2048 -validity 10000 -alias local_lekker
```

#### **Update `android/app/build.gradle.kts`:**
```kotlin
android {
    defaultConfig {
        applicationId = "com.locallekker.app" // Change from example
    }

    signingConfigs {
        create("release") {
            storeFile = file('local_lekker.jks')
            storePassword = System.getenv('STORE_PASSWORD')
            keyAlias = 'local_lekker'
            keyPassword = System.getenv('KEY_PASSWORD')
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}
```

#### **Build production APK and Bundle:**
```bash
# Set environment variables
export STORE_PASSWORD=your_store_password
export KEY_PASSWORD=your_key_password

# Build APK for testing
flutter build apk --release

# Build AAB for Play Store
flutter build appbundle --release
```

### **6. iOS Production Build (if targeting iOS)**

#### **Requirements:**
- [ ] **Apple Developer Account**: $99/year paid account
- [ ] **App Store Connect**: Create app record
- [ ] **Distribution Certificate**: Create production certificate
- [ ] **Provisioning Profile**: Create distribution provisioning profile

#### **Update iOS configuration:**
```bash
# Update bundle identifier in Xcode
# Product > Scheme > Edit Scheme > Run > Arguments > Environment Variables
# Add: SUPABASE_URL, SUPABASE_ANON_KEY, PAYFAST_MERCHANT_ID, etc.
```

#### **Build for iOS:**
```bash
flutter build ios --release
```

### **7. App Store Preparation**

#### **Required Assets:**

**Android (Google Play):**
- [ ] **App Icon**: 512x512 PNG
- [ ] **Feature Graphic**: 1024x500 PNG
- [ ] **Screenshots**: 2-8 screenshots (1080x1920)
- [ ] **Promo Graphic**: 1800x1200 PNG (optional)

**iOS (App Store):**
- [ ] **App Icon**: 1024x1024 PNG
- [ ] **Screenshots**: 3-10 screenshots (various sizes)
- [ ] **App Preview Video**: 30-second video (optional)

#### **Store Listing Content:**
- **App Name**: Local Lekker (30 chars max)
- **Short Description**: Smart receipt scanning for local discounts
- **Full Description**: 4000 characters max
- **Keywords**: receipt, scan, discount, local, payment, business
- **Privacy Policy URL**: Link to hosted privacy policy
- **Support URL**: Link to support website/email

### **8. Testing & Validation**

#### **Pre-Launch Testing:**
- [ ] **Payment Testing**: Test live PayFast payments with small amounts
- [ ] **Webhook Testing**: Verify payment notifications work
- [ ] **Database Testing**: Test with production Supabase instance
- [ ] **Performance Testing**: Test on various devices and networks
- [ ] **Security Testing**: Basic security audit

#### **Beta Testing:**
- [ ] **Internal Testing**: Test with team members
- [ ] **Closed Beta**: Limited user testing (Android)
- [ ] **TestFlight**: iOS beta testing
- [ ] **Feedback Collection**: Gather and implement feedback

### **9. Launch Execution**

#### **Day Before Launch:**
- [ ] **Final Build**: Create production builds with correct version numbers
- [ ] **Environment Switch**: Update all systems to production
- [ ] **Team Communication**: Notify all stakeholders
- [ ] **Monitoring Setup**: Enable error tracking and analytics

#### **Launch Day:**
- [ ] **App Store Submission**: Submit apps for review
- [ ] **Payment Verification**: Test live payment flow
- [ ] **Database Monitoring**: Monitor for issues
- [ ] **User Communication**: Prepare launch announcement

#### **Post-Launch:**
- [ ] **App Review Response**: Respond to any app store rejections
- [ ] **User Support**: Set up customer support channels
- [ ] **Performance Monitoring**: Track app performance and crashes
- [ ] **Payment Reconciliation**: Daily payment verification

### **10. Critical Success Factors**

#### **Payment Processing:**
- [ ] **99.9% Uptime**: Ensure reliable payment processing
- [ ] **Transaction Monitoring**: Real-time failure alerts
- [ ] **Chargeback Process**: Handle disputes professionally
- [ ] **Currency Support**: ZAR only (South Africa)

#### **User Experience:**
- [ ] **Fast Onboarding**: <5 minutes to first scan
- [ ] **Reliable Scanning**: >90% success rate
- [ ] **Clear Communication**: Transparent fees and processes
- [ ] **24/7 Support**: Customer support availability

#### **Business Operations:**
- [ ] **Partner Onboarding**: Streamlined business signup
- [ ] **Discount Management**: Easy discount configuration
- [ ] **Reporting Dashboard**: Real-time business insights
- [ ] **Compliance Monitoring**: Regular audits

### **11. Emergency Procedures**

#### **Payment Issues:**
1. Switch to sandbox mode temporarily
2. Enable manual payment processing
3. Communicate transparently with users

#### **App Issues:**
1. Rollback to previous version capability
2. Hotfix deployment process
3. User communication channels

#### **Business Continuity:**
1. Backup payment processing methods
2. Direct business communication
3. Database recovery procedures

---

## **📞 Support & Resources**

- **PayFast Support**: support@payfast.co.za
- **Supabase Support**: support@supabase.com
- **Google Play Console**: play.google.com/console
- **App Store Connect**: appstoreconnect.apple.com
- **Flutter Support**: docs.flutter.dev

## **🎯 Launch Metrics Targets**

- **Day 1**: 100 downloads, 50 scans, 10 payments
- **Week 1**: 1,000 downloads, 500 scans, 100 payments
- **Month 1**: 5,000 downloads, 2,000 scans, 500 payments
- **Conversion**: 40% scan-to-payment rate
- **Retention**: 60% Day 1, 30% Day 7, 20% Day 30

---

**Remember**: Start small, test everything, monitor closely, and scale gradually. Your first production users are your best testers!</content>
<parameter name="filePath">c:\Users\clyde\local_lekker\PRODUCTION_LAUNCH_CHECKLIST.md
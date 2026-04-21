# Visual Comparison: Admin Image Display Issue

## Problem: Admin Images Not Displaying

```
┌─────────────────────────────────────────────────────────────┐
│ CURRENT STATE (BROKEN)                                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ Trusted Partner Uploads Image:                            │
│ ┌──────────────────────────┐                              │
│ │ Upload to Storage        │ ✓ Works                      │
│ │ Save URL to Database     │ ✓ Works                      │
│ │ Admin View               │ ✓ Works (via Member policy) │
│ │ Member View              │ ✓ Works                      │
│ └──────────────────────────┘                              │
│                                                             │
│ Admin Uploads Image:                                       │
│ ┌──────────────────────────┐                              │
│ │ Upload to Storage        │ ✓ Works                      │
│ │ Save URL to Database     │ ✓ Works                      │
│ │ Admin View               │ ❌ FAILS (restrictive policy)│
│ │ Member View              │ ✓ Works                      │
│ │ TP View                  │ ✓ Works (via Member policy) │
│ └──────────────────────────┘                              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Root Cause: RLS Policy Logic

```
CURRENT ADMIN SELECT POLICY:
┌─────────────────────────────────────────────────────────────┐
│ IF (bucket = 'business-bills')                             │
│   AND (path LIKE 'deal_images/%')                          │
│   AND (user IS admin)          ─────┐                      │
│   AND (business.allow_admin_deal_creation = true)  ─┐ ← PROBLEM!
│ THEN allow SELECT                                    │     
└─────────────────────────────────────────────────────┘     
                                                             
When allow_admin_deal_creation = false:
  ❌ Admin policy FAILS
  ✓ But Member policy succeeds
  ⚠️ Browser can load image but admin sees nothing in thumbnail
```

## Solution: Remove Restrictive Check

```
NEW ADMIN SELECT POLICY:
┌─────────────────────────────────────────────────────────────┐
│ IF (bucket = 'business-bills')                             │
│   AND (path LIKE 'deal_images/%')                          │
│   AND (user IS admin)          ───────┐                    │
│ THEN allow SELECT              ← Simpler, no restriction  │
└─────────────────────────────────────────────────────────────┘

Result:
  ✓ Admin policy succeeds
  ✓ Member policy still works
  ✓ Everyone can view images correctly
```

## Policy Comparison Table

```
┌──────────────┬──────────────────────┬──────────────────────┐
│ Who          │ TP Policy            │ Admin Policy         │
├──────────────┼──────────────────────┼──────────────────────┤
│ Upload       │ Owner check only     │ Admin + permission   │
│ (INSERT)     │ ✓ Simple             │ ✓ Requires approval  │
├──────────────┼──────────────────────┼──────────────────────┤
│ View         │ Owner check only     │ Admin role only      │
│ (SELECT)     │ ✓ Simple             │ ✓ Fixed (was complex)│
├──────────────┼──────────────────────┼──────────────────────┤
│ Edit/Delete  │ Owner check only     │ Admin + permission   │
│ (UPDATE)     │ ✓ Simple             │ ✓ Restricted        │
└──────────────┴──────────────────────┴──────────────────────┘
```

## Policy Priority Order (Supabase OR Logic)

```
When browser requests image:
┌─────────────────────────────────────────────────────────────┐
│ Supabase checks EACH SELECT policy in order                │
│                                                             │
│ 1. "Admin can view..." → YES if admin? → ALLOW (if fixed) │
│ 2. "Members can view..." → YES if authenticated? → ALLOW   │
│ 3. "TP can view..." → YES if owner? → ALLOW               │
│                                                             │
│ If ANY policy says YES → Request succeeds                  │
│ If ALL say NO → Request blocked (403)                      │
└─────────────────────────────────────────────────────────────┘

BEFORE FIX:
  Request from ADMIN:
    1. Admin policy → NO (business permission missing) ✗
    2. Member policy → YES ✓ → Allow (but Image.network shows nothing?)
    3. (Never reached)

AFTER FIX:
  Request from ADMIN:
    1. Admin policy → YES ✓ → Allow (works!)
    2. (Never reached)
```

## Database vs Storage Flow

```
UPLOAD PROCESS:
┌───────────────────┐       ┌──────────────────┐       ┌────────────┐
│ Flutter App       │       │ Supabase Storage │       │ PostgreSQL │
├───────────────────┤       ├──────────────────┤       ├────────────┤
│ 1. Pick image     │       │                  │       │            │
│ 2. Upload binary  │──────→│ Check RLS        │       │            │
│    to storage     │       │ INSERT policy    │       │            │
│                   │       │ ✓ Allows         │       │            │
│                   │←──────│ Return URL       │       │            │
│ 3. Save URL to    │       │                  │───────→ INSERT     │
│    database       │       │                  │       │ image_url  │
│ 4. Display image  │←──────┤ Check RLS        │←──────│ ✓ Success  │
│    Image.network()│       │ SELECT policy    │       │            │
│                   │       │ (BROKEN for admin)       │            │
└───────────────────┘       └──────────────────┘       └────────────┘

FIX: Make SELECT policy less restrictive for admins
```

## The Three Storage Policies

```
FOR DEAL IMAGES IN 'business-bills' BUCKET:

┌─────────────────────────────────────┐
│ 1. MEMBERS CAN VIEW (Unrestricted) │
├─────────────────────────────────────┤
│ IF bucket = 'business-bills'        │
│   AND path LIKE 'deal_images/%'     │
│ THEN SELECT (view)                  │
│                                     │
│ Used by: All authenticated users    │
│ Purpose: Browse deals               │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ 2. TRUSTED PARTNER (Owner check)   │
├─────────────────────────────────────┤
│ IF bucket = 'business-bills'        │
│   AND path LIKE 'deal_images/%'     │
│   AND path owner = current user     │
│ THEN SELECT/INSERT/UPDATE/DELETE    │
│                                     │
│ Used by: Uploading TP               │
│ Purpose: Manage own images          │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ 3. ADMIN (Fixed version)            │
├─────────────────────────────────────┤
│ IF bucket = 'business-bills'        │
│   AND path LIKE 'deal_images/%'     │
│   AND user.role = 'admin'           │
│ THEN SELECT (view)                  │
│                                     │
│ Upload still checks: permission flag│
│                                     │
│ Used by: Admin viewing any image    │
│ Purpose: See images on admin screens│
└─────────────────────────────────────┘
```

## Testing Scenarios

```
SCENARIO 1: TP Uploads Image
┌──────┐     ┌────────┐     ┌───────────┐     ┌──────────┐
│  TP  │────→│Upload  │────→│ Storage   │────→│ Database │
└──────┘     │Check   │     │ RLS:      │     │ UPDATE   │
             │OwnerOK │     │ TP policy │     │image_url │
             └────────┘     └───────────┘     └──────────┘
                  ✓ Works

SCENARIO 2: Admin Uploads Image (BROKEN BEFORE)
┌───────┐     ┌────────┐     ┌───────────┐     ┌──────────┐
│ Admin │────→│Upload  │────→│ Storage   │────→│ Database │
└───────┘     │Check   │     │ RLS:      │     │ UPDATE   │
              │ PermsOK│     │ Admin     │     │image_url │
              └────────┘     │ policy    │     │ ✓ Saved  │
                             │ ✓ Allows  │     └──────────┘
                             └───────────┘
              When viewing Image.network(url):
              ┌───────────────────────────────┐
              │ Browser fetches image        │
              │ Storage checks SELECT policy │
              │ Admin policy: FAILS          │
              │ (missing business perm)      │
              │                             │
              │ ❌ Browser can't load image  │
              └───────────────────────────────┘

SCENARIO 3: Admin Uploads Image (FIXED VERSION)
              When viewing Image.network(url):
              ┌───────────────────────────────┐
              │ Browser fetches image        │
              │ Storage checks SELECT policy │
              │ Admin policy: PASSES         │
              │ (user is admin)              │
              │                             │
              │ ✓ Browser loads image        │
              └───────────────────────────────┘
```

---

**Key Insight**: The issue is NOT with upload or database storage. It's purely a storage SELECT policy being too restrictive for admins viewing images via Image.network() in Flutter.

# Session Context — Last Updated 2026-07-31 17:31:00

## Completed This Session (2026-07-31 17:31:00) — Blank Dropdowns Fix (Firestore Composite Indexes)

### Root Cause
- User reported the Language dropdown renders blank in both Flutter apps. Both apps query `collection('languages').where('isActive', isEqualTo: true).orderBy('name')` — a composite-index query. The deployed Firestore project had **ZERO composite indexes** (verified via REST `/collectionGroups/-/indexes`: `fareConfigs` count 0 — the 2 indexes declared in `firestore.indexes.json` were never deployed), so every `.where()+orderBy()` query threw `FAILED_PRECONDITION: query requires an index` → empty dropdowns/lists everywhere (languages, cancellation reasons, FAQ, promo banners, onboarding slides, subscription plans, trip history, notifications, saved addresses, payments, chats, pool trips, demand predictions, payouts, fare configs).

### Fix
- Expanded `admin-panel/firestore.indexes.json` from 2 → **24 composite indexes** covering every `.where()+orderBy()` chain in both Flutter apps:
  - Dropdown/data queries: `languages` (isActive,name), `cancellationReasons` (isActive,sortOrder), `faq` (isActive,order), `promoBanners` (isActive,order), `onboardingSlides` (isActive,sortOrder), `subscriptionPlans` (isActive,price)
  - Subscriptions: `user_subscriptions` (userId,isActive,endDate DESC), `driver_subscriptions` (driverId,isActive,endDate DESC)
  - Trips: `trips` (userId,status,createdAt DESC) + (driverId,status,createdAt DESC), `pool_trips` (driverId,status,createdAt DESC) + (passengers,status,completedAt DESC), `pool_requests` (poolId,status,requestedAt)
  - User scoped: `notifications` (userId,createdAt DESC), `saved_addresses` (userId,createdAt DESC) + (type,createdAt DESC), `wallet_transactions` (userId,createdAt DESC), `payments` (userId,createdAt DESC) + (userId,method,createdAt DESC), `chats` (userId,lastMessageTime DESC), `payout_requests` (driverId,requestedAt DESC), `demand_predictions` (zoneId,timestamp DESC)
  - Fare configs (were declared but never deployed): `fareConfigs` (isActive,zoneName,vehicleType) + (isActive,zoneId)
- Deployed: `firebase deploy --only firestore:indexes --project dadacabs-099`

### Verification
- All 24 indexes reached `READY` (polled via REST until `{"READY":24}`)
- Verified live: every query shape passes via raw Firestore REST `runQuery` (200 OK, all 6 sampled) and via firebase-admin individually (15x loop all OK)
- `languages` query now returns all 23 active languages (Assamese…English, etc.) — Language dropdown will render
- Note: firebase-admin SDK batch runs showed transient `requires index` errors for ~10 min after READY — Firestore index serving is eventually consistent across backend replicas; settled within minutes. REST + looped individual runs consistently OK.
- `firestore.indexes.json` is currently an **untracked git file** — commit alongside `firestore.rules` if desired.

## Completed This Session (2026-07-31 16:45:00) — Login "Asks to Register Again" Fix (Rules Permissive Again)

### Root Cause
- After the 16:30 fix, login still fell to Register in BOTH apps: `ensureDevAuthSession()` (anonymous sign-in) was the dependency, but **Anonymous Auth is DISABLED in this Firebase project** — verified via Identity Toolkit REST: `accounts:signUp` with empty body → `ADMIN_ONLY_OPERATION` (email/password signUp works fine)
- So the app never had an Auth session → every post-login Firestore read (`users`, `drivers`, `vehicleTypes`, etc.) still required `request.auth != null` → denied → `getUserByPhone` returned null → Register

### Fix (rules — server-side, no app logic change)
- Rewrote `admin-panel/firestore.rules`: **all app-facing collections now `allow read, write: if true`** (restoring the documented permissive design the dev-bypass apps depend on)
- Admin-only sensitive collections stay authenticated: `adminUsers`, `roles`, `DailyStats`, `DemandZones`, `auth` (write:false) — admin panel uses real email/password auth so these still work
- Added missing Partner collections: `claimed_incentives`, `Daily`, `driver_subscriptions`, `incentives`, `reviews`
- Verified live via Firestore REST (no auth token): `users` + `drivers` readable (200), `adminUsers` still 403
- Deployed: `firebase deploy --only firestore:rules --project dadacabs-099`

### Code Cleanup (Customer app — annotated with signature comments)
- Removed `ensureDevAuthSession()` call sites from `phone_login_logics.dart`, `register_logics.dart` (both methods), `splash_logics.dart` — anonymous auth is disabled so they always failed; helper kept in `user_repo.dart` for future use
- Builds: Customer `flutter build apk --debug` ✅ · Partner `flutter build apk --release` ✅
- Both apps' collections verified fully covered by rules (0 missing)

## Completed This Session (2026-07-31 16:30:00) — Customer App Login Fix (Firestore Rules vs Dev-Bypass)

### Root Cause
- Dev-bypass OTP flow NEVER signs into Firebase Auth, but Firestore rules (since 2026-07-20) require `request.auth != null` → every `users` read during login (getUserByPhone) returned PERMISSION_DENIED → login always fell through to Register; registration writes were also denied (`request.auth.uid == userId` mismatch)
- Additionally the Customer app reads 10+ collections not present in rules (chats, messages, wallets, referrals, scheduled_rides, user_subscriptions, promo_usage, wallet_transactions, referral_invites, Drivers legacy)

### Code Fixes (Customer app — all annotated with signature comments)
- `user_repo.dart`: new `ensureDevAuthSession()` — signs in anonymously (idempotent) so Firestore rules pass while keeping dev-bypass flow
- `phone_login_logics.dart`: dev-bypass `verifyOTP` calls `ensureDevAuthSession()` before `getUserByPhone`
- `register_logics.dart`: `registerUserSimple` + `verifyAndRegister` sign in anonymously and use auth uid for new user docs
- `splash_logics.dart`: signs in anonymously before restoring `dev_bypass_phone` session
- Verify: `flutter analyze` 0 errors, `flutter build apk --debug` ✅

### Rules Deployed (`firebase deploy --only firestore:rules`)
- `users` write relaxed from `uid == userId` to `request.auth != null` (dev uids ≠ auth uids; admin panel user writes also blocked before)
- Added blocks: chats, messages, promo_usage, referral_invites, referrals, scheduled_rides, user_subscriptions, wallets (+subcollections), wallet_transactions, Drivers (legacy)
- Note: also fixed Fare Fix Routes (fareFixRoutes + driverLevels missing) and Backup & Restore (dead REST endpoint → Firestore export/import) earlier this day

## Completed This Session (2026-07-31 14:30:00) — Admin Panel Firestore Fixes + Partner Heatmap

### Root Cause
- Deployed `firestore.rules` only matched ~20 collections → reads to `states`, `cities`, `roles`, `cancellationReasons`, `subscriptionPlans`, `onboardingSlides`, `etaConfig`, `partnerHomeConfig`, `appSettings/referral`, `faq` all returned `permission-denied` (verified via web-SDK sim in `check-web.js`)
- Several Admin Panel pages (States, Cities, Roles, FAQ, Settings, ServiceLocations, BusinessSettings, Zones) used raw `fetch` → `API_BASE_URL` is empty (`process.env.REACT_APP_API_URL || ''`) so they silently failed / showed empty tables

### Rules Deployed
- `firebase deploy --only firestore:rules --project dadacabs-099` — added match blocks for states, cities, countries, companies, languages, currencies, adminUsers, roles, faq, settings, appSettings, cancellationReasons, subscriptionPlans, onboardingSlides, etaConfig, partnerHomeConfig, serviceLocations, vehicles, fuelTypes, goodsTypes, owners, locations, master, promoCodes, bannerImages — all `allow read/write if request.auth != null`

### Admin Panel Code Fixes (firebase hosting deployed @ https://dadacabs-099.web.app)
- `api.js`: `states.create(data, id)`; `authUsers.*` + `roles.*` → Firestore `adminUsers` (REST `/auth/users` dead); added `faq` + `support.faq` CRUD (Firestore `faq`)
- `States.js`: `api.states.*` (removed raw fetch/ENDPOINTS/API_BASE_URL); client-side country/search filter
- `Roles.js`: handles synthetic `${roleKey}_group` ids (bulk-update/delete adminUsers by role key); create via `api.authUsers.create` without password
- `FAQ.js`: persists via `api.support.faq.*`; `group` field
- `Settings.js`, `ServiceLocations.js`, `BusinessSettings.js`, `Zones.js`: raw fetch → `api.*.getAll()`
- `Layout.js`: added "FAQ Management" → `/support/faq` menu item
- `npm run build` ✅ + `firebase deploy --only hosting` ✅

### Seeds (ran, verified live)
- `scripts/seed-admin-config.js`: 14 cancellationReasons, 4 subscriptionPlans, 4 onboardingSlides, 8 etaConfig (auto/bike/hatchback/sedan/suv/luxury/small truck/van), `partnerHomeConfig/settings` (heatmapEnabled=false, heatmapRadiusKm=5, heatmapGridSize=0.01), `appSettings/referral` (bonus ₹50), activated all 30 IN cities
- `scripts/seed-heatmap.js`: 25 Mumbai/Navi-Mumbai demand zones → `heat_map_data` (hm_01..25, demandLevel 1-10)

### Partner App Heatmap Overlay
- `home_screen.dart`: added `homeHeatmapDataProvider` (FutureProvider reads `heat_map_data` → `(LatLng, int)` records); GoogleMap `circles:` built when `heatmapEnabledProvider` true — radius `heatmapRadiusKmProvider*1000`, colors demand≥7 error / ≥4 warning / else success (`withOpacity` to match file convention)
- `flutter analyze` on changed files: 0 errors
- NOTE: 16 pre-existing analyze errors in Partner `login_screen.dart` (`Components`) + `document_upload_screen.dart` (`Text` not a class) exist in committed HEAD — unrelated, need separate fix

## Completed This Session (2026-07-31 13:00:00)

## Goal
Complete rebranding of DCS Customer, Partner, and Admin Panel apps to "Dada Cabs Services" with logo-matching Orange/Blue/Black theme (Vintage Indian Car theme), removal of all hardcoded strings, DadaCabs references, and centralized configuration.

## Constraints
- Keep existing dev-bypass OTP flow (no real Firebase phone auth required)
- Must match Firestore `users` collection and field conventions
- All code changes annotated with signature comments (date, time, name: Jayant Pandit, reason)
- Keep `google_maps_flutter` import only for `LatLng` type (used by models/providers)
- Keep existing IndianHeritageColors theme, flutter_map OSM, online/offline toggle, service preference selector
- Brand: "Dada Cabs Services" (full), "DadaCabs" (short), support@dadacabs.com
- Logo colors: Orange background + Blue + Black text → theme: primaryNavy #F98A0A, blueSecondary #0E469B, charcoal #171617

## Completed This Session (2026-07-31 13:00:00)

### Issue 1 — Uber/Ola/Rapido-style Horizontal Vehicle Booking Selector
- **Change**: Rebuilt the where-to fare sheet (`where_to_screen_modern.dart`) into a ride-type selector:
  - New "Choose a ride" header row showing `${distanceKm} km • ${durationMinutes} min` with a close (`Icons.close_rounded`) button that clears `_showFareSheet`/`_fareTrip`
  - Vehicle cards now display passenger capacity (`vehicle.capacity`) with a person icon next to ETA
  - Added `_selectedFare()` helper (mirrors `_selectedVehicleName()` filtering logic) and the single Book button now reads `'Book ${_selectedVehicleName()} • ₹${_selectedFare().toStringAsFixed(0)}'`
- **File**: `DCS_Customer/lib/View/Screens/Main_Screens/Sub_Screens/Where_To_Screen/where_to_screen_modern.dart`
- Home bottom vehicle panel (`home_screen_modern.dart` `_showRideOptions`) intentionally left unchanged — fare sheet is the single selector path

### Issue 2 — Grey / No-Next-Step Screens After Selection
- **Change**: Where-To GoogleMap `initialCameraPosition` no longer sits at (0,0) ocean before GPS resolves — falls back to `_pickupLocation ?? LatLng(19.0760, 72.8777)` (Mumbai)
- `_getCurrentLocation` now `_mapController?.animateCamera(newLatLngZoom(pos, 15))` after resolving GPS so the map centers on the user
- `myLocationEnabled: true` on both Home and Where-To maps (blue GPS dot)
- **Files**: `where_to_screen_modern.dart`, `home_screen_modern.dart`

### Issue 3 — "GoException: no routes for location" Navigation Failures
- **Root cause**: `profile_screen.dart` pushed `/edit-profile` and `ride_history_screen.dart` pushed `/ride-history` + `/ride-detail` — none of these paths were registered in `app_routes.dart` → GoException on every navigation, leaving users stranded on a grey screen
- **Fix**: Registered missing kebab-case route aliases:
  - `/edit-profile` (name `editProfile-alias` → `EditProfileScreen`)
  - `/ride-history` (name `rideHistory-alias` → `HistoryScreen`)
  - `/ride-detail` (name `rideHistoryDetail` → `RideDetailScreen(trip: state.extra as TripModel)`)
- **Hardening**: Added `onException: (context, state, goRouter)` to the GoRouter — it logs the error then safely `goNamed(Routes().home)` via a post-frame callback, so any future unknown location never strands the user (go_router 9.x signature is `void Function(BuildContext, GoRouterState, GoRouter)`)
- **FCM deep-link guard**: `firebase_messaging.dart` `handleNotificationClick` now validates the `screen` value against a known-screens allow-list; unknown names → log + `context.goNamed('home')` instead of crashing
- **Files**: `lib/View/Routes/app_routes.dart`, `lib/Container/utils/firebase_messaging.dart`

### Issue 4 — Remaining Black Backgrounds
- **Change**: `pool_matching_screen.dart` replaced all `Colors.grey[900]` (lines 112, 284, 538, 626, 746) with white/light surfaces: `disabledBackgroundColor` grey[800]→grey[300], passenger chip grey[800]→grey[400], circle avatar grey[800]→grey[300], stop chip grey[800]→grey[300]
- **File**: `lib/View/Screens/Main_Screens/Pooling_Screen/pool_matching_screen.dart`

### Issue 5 — Hardcoded Fields Bound to Firestore (verified)
- Audit confirmed user data already streams from Firestore: drawer (`customer_drawer.dart` `userProfileProvider`), home recent destinations (from `trips` collection), promo banners (`promoBannersStreamProvider`), vehicle types (`vehicleTypes`), fares (`fareConfigs` + surge rules). No new binding required.
- Dead-code file `modern_navigation.dart` (ModernDrawerNavigation/ModernAppShell/ModernBottomNavigation) still has sample 'John Doe' data but is **not referenced anywhere** in the app.

### Google Maps API Key Unified
- Both keys verified valid (Geocoding/Directions/Place Autocomplete → OK). Unified on `AIzaSyDU7qNKWIZZ4G0jnX_D8ZREwAQcs-r7lEs` (the manifest key) in `lib/Container/utils/keys.dart` `AppKeys.mapKey`.

### Build Fixes (pre-existing errors from earlier uncommitted sessions)
- `pool_matching_screen.dart`: added missing `indian_heritage_theme.dart` import (undefined `IndianHeritageCarColors`)
- `ride_detail_screen.dart`: added `flutter/foundation.dart` (for `Factory`) + `flutter/gestures.dart` (for `OneSequenceGestureRecognizer`) imports
- `Main_Screens/Settings_Screen/settings_screen.dart`: nested `orElse` closure returned nullable `Language?` → wrapped with `?? Language(...)` fallback
- `wallet_screen.dart`: `dateFormat` was out of scope at line 597 → inline `DateFormat('dd MMM yyyy, hh:mm a').format(txDate)`

### Verification
- `flutter analyze` on DCS_Customer: **0 errors**
- `flutter build apk --debug`: ✅ `build/app/outputs/flutter-apk/app-debug.apk`

## Completed This Session (2026-07-27)

### 60-Second Trip Expiry with Fare Boost Rebook

#### TripStatus.expired + surgeBonus Model
- **Change**: Added `TripStatus.expired` enum value and `surgeBonus` double field to both Customer and Partner `TripModel`
- **Files**: `DCS_Customer/lib/Model/trip_model.dart`, `DCS_Partner/lib/Model/Trip_Model/trip_model.dart`
- Updated `toJson()`, `fromJson()`, `statusText`, `statusColor` for both models

#### cancelTrip() Changed from Delete to Update
- **Change**: `cancelTrip()` in Customer `trip_repo.dart` no longer calls `delete()` for pending trips — it now always calls `update({status:'cancelled'})` so Admin Panel has audit trail
- **New method**: `expireTrip()` marks pending trips as `status:'expired'` with `expiredAt` timestamp
- History queries (`getUserTrips`, `getUserTripHistory`, `getDriverTrips`, `getDriverTripHistory`) now include `expired` status
- **Files**: `DCS_Customer/lib/Container/Repositories/trip_repo.dart:118-160`, `DCS_Partner/lib/Container/Repositories/trip_repo.dart:200-223`

#### Auto-Expire Timer: 120s → 60s from Firestore
- **Change**: `_startExpireTimer()` in `active_trip_screen_modern.dart` now reads `tripExpirySeconds` from Firestore `appSettings/general` (default 60s) instead of hardcoded 120s
- On expiry: calls `expireTrip()` (not `deleteTrip()`), passes `'trip_expired'` result via `Navigator.pop`
- `_subscribeToTrip()` also handles `TripStatus.expired` from Firestore real-time updates
- **File**: `DCS_Customer/lib/View/Screens/Main_Screens/Active_Trip_Screen/active_trip_screen_modern.dart:268-295`

#### Trip Expired → Fare Boost + Rebook Bottom Sheet
- **Change**: `_requestRide()` now `async`, captures navigation result from active trip screen
- When result is `'trip_expired'`, shows `_showTripExpiredSheet()` with:
  - **+₹10 / +₹20 / +₹50 Boost** buttons — re-creates trip with `surgeBonus` field and boosted `estimatedFare`
  - **Book Again (Same Fare)** — re-creates trip without boost
- Both options call `_rebookWithBoost()` which creates a new `TripModel` with `surgeBonus` and navigates to active trip screen
- **File**: `DCS_Customer/lib/View/Screens/Main_Screens/Home_Screen/home_screen_modern.dart:792-831, 832-940`

#### Partner Trip Request Card — Fare Boost Badge
- **Change**: Partner `trip_request_screen.dart` now shows a green "🔥 +₹X Boost" badge when `trip.surgeBonus > 0`
- **File**: `DCS_Partner/lib/View/Screens/Main_Screens/TripRequest_Screen/trip_request_screen.dart:693-712`

#### Admin Panel — Expired Status Support
- **Trips.js**: Added `'expired'` to `allowedStatuses`, `getStatusColor()` (warning), `statusOptions` fallback, and trip detail dialog (shows expired timestamp + surge bonus info)
- **api.js**: Added `expiredTrips` count in analytics, `dayExpired` in daily stats, `surgeBonus`/`expiredAt` passthrough in `_normalizeTrip()`
- **Files**: `admin-panel/src/pages/Trips.js:48,94,149-162,505-536`, `admin-panel/src/services/api.js:318-390,414-438`

### Booking Request Real-Time Sync — Gap Fixes

#### Decline/Accept Button Error Handling
- **Root cause**: `_declineTrip()` had no try-catch — if `_stopAlert()` threw, `setState` was never called and the trip card stayed on screen permanently. `_acceptTrip()` had no try-finally — if any code threw after `_isProcessing = true` (e.g. `_stopAlert`, `_notifyCustomerOfAcceptance`), `_isProcessing` stayed true permanently, disabling both ACCEPT and DECLINE buttons
- **Fix**: `_declineTrip()` rewritten with try-finally to guarantee `setState` always runs. `_acceptTrip()` rewritten with try-finally to guarantee `_isProcessing` reset. `_autoDecline()` also hardened with try-catch
- **File**: `DCS_Partner/lib/View/Screens/Main_Screens/TripRequest_Screen/trip_request_screen.dart:140-210`

#### FCM Token Multi-Device Support
- **Root cause**: `saveFCMToken()` wrote to single `fcmToken` field; UID path didn't match custom driver doc IDs (e.g. `nitin_arora_hatchback_1`) → only 1/23 drivers had tokens
- **Fix**: Rewrote `saveFCMToken()` to find driver by UID → phone → email, then append token to `deviceTokens` array (max 5, deduped) + keep `fcmToken` for backward compat
- **File**: `DCS_Partner/lib/Container/Repositories/firestore_repo.dart:183-252`

#### Location Cache for Cold Start
- **Root cause**: `homeScreenDriversLocationProvider` starts null on app restart → defaults to Bangalore (12.97, 77.59) → any real-city trip outside 10km radius silently filtered
- **Fix**: Save GPS to SharedPreferences on each fix; restore on HomeScreen startup before async GPS fix completes
- **Files**: `home_logics.dart` (save + `restoreLastKnownLocation()`), `home_screen.dart` (restore on init)

#### Webhook Server Verified
- Railway notification server at `dcs-notifications-production.up.railway.app` confirmed alive and responding `{"status":"ok"}`

#### Build Verified
- Partner APK: ✅ `flutter build apk --release --no-tree-shake-icons` — built successfully (66.6MB)

## Completed This Session (2026-07-20)

### Complete Rebranding — Dada Cabs Services

#### PHASE 1: Central Configuration
- Created `DCS_Customer/lib/Container/utils/app_config.dart` — single source of truth for all brand names, URLs, constants
- Created `DCS_Partner/lib/Container/utils/app_config.dart` — partner-specific config (dailyEarningsGoal, topUpAmounts, payoutAmounts, etc.)
- Created `admin-panel/src/config/appConfig.js` — admin panel brand config + theme colors

#### PHASE 2: Theme Color Overhaul
- Added `primaryYellow` alias → `primaryNavy` (fixes 100+ broken references across both apps)
- Added `deepGold` alias → `blueSecondary` (fixes 8+ broken references)
- Changed `goldAccent` from `#EAB308` (yellow) → `#1A356A` (logo blue)
- Changed `charcoal` from `#000000` → `#111827` (near-black, matching logo)
- Added `saffron` alias → `primaryNavy` (fixes heritage background references)
- Updated both Customer and Partner `DCSColors` classes

#### PHASE 3: Hardcoded Strings Removal (~30 files)
- Customer: main.dart, splash_screen.dart, splash_logics.dart, login_screen.dart, customer_drawer.dart, active_trip_screen_modern.dart, home_screen_modern.dart, support_screen.dart, refer_and_earn_screen.dart, firebase_messaging.dart, auth_repo.dart
- Partner: main.dart, splash_screen.dart, phone_login_screen.dart, driver_drawer.dart, home_screen.dart, document_upload_logics.dart, earnings_screen.dart, earnings_detail_screen.dart, wallet_payout_screen.dart, captain_navigation_screen.dart, firebase_messaging.dart

#### PHASE 4: DadaCabs References Removal
- Replaced "DadaCabs-style" → "DadaCabs-style" in 52 files (29 Dart Customer, 21 Dart Partner, 2 JS Admin)
- Updated AGENTS.md and CHANGELOG.md

#### PHASE 5: Admin Panel Rebranding
- Updated `App.js` dcsAdminColors: secondary/accent changed from gold #EAB308 to blue #2E5AB8/#1A356A
- Updated `Layout.js` with verified footer text
- Updated `manifest.json`: name → "DadaCabs Admin Panel", short_name → "DadaCabs"
- Updated `api.config.js`: company name → "Dada Cabs Services Pvt Ltd"

#### PHASE 6: Hardcoded Colors Removal (~20 files)
- home_screen_modern.dart: 7 replacements (primaryNavy, success, blueSecondary, platinum)
- where_to_screen_modern.dart: 4 replacements (primaryNavy, error, success)
- register_screen.dart: 3 replacements (platinum)
- document_upload_screen.dart: 6 replacements (textDark)

#### PHASE 7: Expiry Date Update
- Both apps: DateTime(2026, 7, 31) → AppConfig.appExpiryDate = DateTime(2026, 8, 14)
- Note: Changed from `const` to `final` (DateTime constructor not const in this SDK)

#### PHASE 9: Build Verification
- Customer APK: ✅ `flutter build apk --debug` — built successfully
- Partner APK: ✅ `flutter build apk --release --no-tree-shake-icons` — built successfully (66.2MB)

## Remaining Work / Known Issues
- PhonePe service still has placeholder callback URL (`webhook.site`) and sandbox salt key
- Debug OTP bypass still in auth flow (intentional for development)
- API keys still hardcoded in source (should move to --dart-define in production)
- Backend IP address exposed in admin-panel api.config.js
- `flutter_map` versions differ: Customer 4.0.0, Partner 7.0.2

## Completed This Session (2026-07-24)

### New Logo Color Theme — Vintage Indian Car Orange/Blue/Black

#### Color Scheme Update
| Role | Old | New |
|------|-----|-----|
| Primary | `#1A356A` (Navy Blue) | `#F98A0A` (Orange) |
| Secondary | `#2E5AB8` (Blue) | `#0E469B` (Blue) |
| Text/Lines | `#111827` (Near-black) | `#171617` (Black) |

#### Files Updated
- **Customer DCSColors**: `indian_heritage_theme.dart` — all brand + neutral colors
- **Partner DCSColors**: `app_theme.dart` — all brand + neutral colors
- **Admin Panel**: `App.js`, `appConfig.js`, `Chat.js`, `SOS.js`, `Support.js`, `Fleet.js`, `Onboarding.js`, `LandingPage.js`, `Settings.js`, `Roles.js`, `DriverEarnings.js`, `VehicleServiceAreaMap.js`
- **Hardcoded colors**: 98 replacements in Partner Dart files (12 screen files), all rgba values in admin JS
- **Logo files**: New `Dadacabs.png` copied to all 7 asset locations
- **Android launcher icons**: Regenerated for both Customer and Partner apps

#### Verification
- Old color `#1A356A`: **0 occurrences** across entire codebase
- Old color `#2E5AB8`: **0 occurrences** across entire codebase
- Old color `#111827`: **0 occurrences** across entire codebase
- Old `#1976d2`: **0 occurrences** across entire codebase
- Old `rgba(26,53,106,...)`: **0 occurrences** across entire codebase
- Customer APK: ✅ `flutter build apk --debug` — built successfully
- Partner APK: ✅ `flutter build apk --release --no-tree-shake-icons` — built successfully (63.9MB)

## Completed This Session (2026-07-19)

### DadaCabs-Style Partner Home Screen Enhancements
- **Earnings Dashboard Panel**: Expandable bottom card with today's total earnings, completed trips, online hours, weekly summary, and daily goal progress bar (₹2000 target). Uses `todayEarningsStreamProvider` streaming from `EarningsRepo.streamDailyEarnings()`. Slides in/out with `AnimatedSize` + `AnimationController`.
- **Auto-Accept Toggle**: Toggle switch in online status card (`autoAcceptProvider` StateProvider). When enabled, partner app auto-accepts ride requests. Styled with `IndianHeritageCarColors.success` theme.
- **Performance Metrics Chips**: Acceptance rate (92%), cancellation rate (3%), rating (X.X ⭐) — placeholder values in stat chips, positioned top-right when earnings panel is collapsed.
- **Notification Bell**: Bell icon in top bar with red badge count (`notificationBadgeCountProvider`). Tap clears badge. Badge count shows "99+" for >99.
- **Current Zone Display**: Shows `currentZoneNameProvider` value in top bar below menu icon. Falls back to "Detecting zone..." when no zone detected yet.
- **Earnings Stream Provider**: `todayEarningsStreamProvider` watches `driverDataProvider` and streams daily earnings from Firestore `driver_earnings` collection using existing `EarningsRepo`.
- **New Providers**: `autoAcceptProvider`, `notificationBadgeCountProvider`, `dailyEarningsGoalProvider` added as Riverpod StateProviders.
- **Build verified**: Partner APK `flutter build apk --release` ✅ (66.2MB)

### Signature Comments
- All changed lines annotated with `// Modified by Jayant Pandit on 2026-07-19 10:00:00 // Reason: ...`

## Completed This Session (2026-07-11)

## Constraints
- Keep existing dev-bypass OTP flow (no real Firebase phone auth required)
- Must match Firestore `users` collection and field conventions
- All code changes annotated with signature comments (date, time, name: Jayant Pandit, reason)
- Keep `google_maps_flutter` import only for `LatLng` type (used by models/providers)

## Completed This Session (2026-07-11)

### Issue 4 — Ride request flow (diagnostic logging added)
- **Investigation**: Traced the full ride request flow from Customer → Firestore → Partner GeoFlutterFire query
- **Flow confirmed**: `incomingTripRequestsProvider` (trip_request_screen.dart) watches `homeScreenDriversLocationProvider` + `driverDataProvider`, calls `getNearbyTripRequests(center, 10, preferences, driverCarType)`
- **IndexedStack confirmed**: `NavigationScreen` uses `IndexedStack` (line 75-78), so `TripRequestScreen` is ALWAYS mounted and provider is ALWAYS active. Auto-switch to Rides tab already implemented (line 26-33)
- **GeoFlutterFire query**: `geo.collection().within(center, radius, field: 'pickupLoc')` — queries `trips` collection by `pickupLoc` GeoFire point field
- **Customer writes**: `carType: vehicle.name` (e.g. "Hatchback"), `serviceType: 'ride'` (default), `pickupLoc` as GeoFire point, `status: 'pending'`
- **Filter logic**: Vehicle type contains-match (bike→bike only, auto→auto only, sedan→non-bike/non-auto), service preference match ("Passenger Rides"→serviceType=='ride')
- **Added diagnostic logging**: `trip_repo.dart` logs center, radius, driverCarType, preferences, raw doc count, each doc's status/carType/serviceType/pickupLoc, filter pass/fail for each doc
- **Added diagnostic logging**: `trip_request_screen.dart` logs uid, loc provider state, driver name/carType/prefs, center coordinates
- **Added diagnostic logging**: Customer `firestore_repo.dart` logs full tripJson keys, status/carType/serviceType/pickupLoc, pickupLat/pickupLng, selectedDriver state
- **Build verified**: Partner APK `flutter build apk --release` ✅ (66.3MB), Customer APK `flutter build apk --debug` ✅

### Issue 5 — Signature comments
- All changed lines annotated with `// Modified by Jayant Pandit on 2026-07-11 HH:MM:SS // Reason: ...`

## Completed This Session (2026-07-10)

### Issue 1 — Partner current location marker
- `home_screen.dart`: Added `_currentLocation` (latlong.LatLng?), `_locationMarkers` (List<flmap.Marker>), `_buildCurrentLocationMarker()` (blue dot with white border + shadow).
- `_loadInitialLocation()` now stores GPS as `_currentLocation`, clears/adds marker, calls `setState`.
- `_safeRecenter()` fetches GPS, updates `_currentLocation` + `_locationMarkers`, moves map to current position.
- FlutterMap `children` now include `flmap.MarkerLayer(markers: _locationMarkers)` when non-empty.

### Issue 2 — Customer vehicle images
- **Root cause**: Firestore `vehicleTypes` collection stores relative image paths (e.g. `/Auto.webp`), not absolute URLs. `Image.network(vehicle.imageUrl!)` tried to load a relative path which failed silently.
- **Fix**: Added `fullImageUrl` getter to `VehicleTypeModel` in `vehicle_type_model.dart` that prepends the Firebase Hosting base URL (`https://dadacabs-099.web.app/`) to relative paths.
- Added `static const String vehicleImageBaseUrl` to `AppKeys` in `keys.dart`.
- Updated both `home_screen_modern.dart` and `where_to_screen_modern.dart` to use `vehicle.fullImageUrl!` instead of `vehicle.imageUrl!`, with `errorBuilder` + `loadingBuilder`.

### Issue 3 — Online drivers not showing on Customer map
- **Root cause 1**: `_mergeAndProcessDrivers` was `void` calling `_processDriverDataList` (async) without `await`. If `MarkerIcons.getIconForVehicle` threw (e.g. cold start), unhandled promise rejection silently dropped driver list.
- **Fix 1**: Changed to `Future<void> + await _processDriverDataList` with try/catch at `firestore_repo.dart:107-122`.
- **Root cause 2**: `_parseDriverLocation` did not handle GeoFlutterFire's internal `_latitude`/`_longitude` keys. Two online drivers (`nitin_arora_hatchback_1`) had `geopoint: {_latitude: ..., _longitude: ...}` format which failed to parse → drivers excluded.
- **Fix 2**: Added `_latitude`/`_longitude` key detection in `_parseDriverLocation` at `firestore_repo.dart:320-323` and `driverLocData` level.

### Issue 4 — Ride request not reaching drivers
- **Root cause (race)**: Fire-and-forget `addUserRideRequestToDB()` then immediately `notifyDriversViaWebhook()` — webhook hit Firestore before write propagated → 404, no notification.
- **Fix**: `await` Firestore write first, then `await` webhook in `home_screen_modern.dart`, `where_to_screen_modern.dart`, `home_logics.dart`.
- **Root cause (UI block)**: `_requestRide` was `void`+`async`, blocking navigation until Firestore write + webhook completed. If either hung, the user saw no response.
- **Fix**: `_requestRide` now navigates to `activeTripModern` immediately, then does Firestore write + webhook in background (`.then().catchError()`).
- **Root cause (webhook retry)**: `notifyDriversViaWebhook` had no retry — any network blip permanently lost the notification.
- **Fix**: Added 3-attempt retry with exponential backoff in `home_logics.dart`.
- **Root cause (FCM tokens)**: Only 1/23 drivers had FCM tokens. `MessagingService.init()` used `doc(currentUser.uid)` but driver docs use custom IDs (e.g. `nitin_arora_hatchback_1`). `update()` silently failed.
- **Fix**: `firebase_messaging.dart` now queries `drivers` collection by `phone` field before falling back to uid.

### Issue 5 — Signature comments
- All changed lines annotated with `// Modified by Jayant Pandit on 2026-07-09 HH:MM:SS // Reason: ...`
- All new changes this session annotated with `// Modified by Jayant Pandit on 2026-07-10 HH:MM:SS // Reason: ...`

## Completed This Session (2026-07-10)

### Regressions Fixed
- **Restored missing files**: `pubspec.yaml` (both Customer & Partner), `home_providers.dart`, `trip_model.dart`, `driver_model.dart`, `direction_model.dart` were missing from disk. Restored from git commit `219a439`.
- **Fixed Android build**: Restored Android project files (`android/`) from git commit `219a439`. 

### Issue 3 — Online drivers not showing (re-fix)
- **Root cause (data)**: Firestore `drivers` collection had ALL 23 drivers with `isOnline: false` and NO `driverLoc` field. The `add-driver-locations.js` script was never executed against Firestore.
- **Fix**: Ran `add-driver-locations.js` → all 23 drivers now have `isOnline: true`, `driverLoc {latitude, longitude}`, and `driverStatus: 'online'`.
- **Root cause (selection screen)**: `where_to_screen_modern.dart` had NO driver markers on its OSM map.
- **Fix**: Added `_osmVehicleIcon()` and `_vehicleColor()` helper methods + `flmap.MarkerLayer` that renders colored vehicle markers from `homeScreenAvailableDriversProvider`.

### Issue 2 — Customer vehicle images (verified working)
- Verified all 10 vehicle type images exist at `https://dadacabs-099.web.app/` (HTTP 200 for all).
- `fullImageUrl` getter correctly prepends base URL to relative paths from Firestore `vehicleTypes` collection.
- Images render in both `home_screen_modern.dart` and `where_to_screen_modern.dart` with errorBuilder fallback.

### Issue 4 — Ride request flow (verified working)
- **Notification server**: `https://dcs-notifications-production.up.railway.app/` returns `{"status":"ok"}`.
- **Webhook parsing**: Trip `toJson()` now includes both `pickupLat`/`pickupLng` (legacy) and `pickupLoc` (GeoFlutterFire geo point format) for maximum compatibility.
- **Webhook nearby driver search**: `findNearbyDrivers()` checks `isOnline`, `carType`, location. All 23 drivers now have valid data.
- **FCM token issue**: Only `nitin_arora_hatchback_1` has FCM token (142 chars). Remaining drivers need Partner APK redeploy with the phone-based token registration fix.

### New Files Created/Restored
- `DCS_Customer/pubspec.yaml` — restored + added `flutter_map`, `latlong2`, `flutter_contacts`
- `DCS_Customer/lib/Model/driver_model.dart` — restored from git
- `DCS_Customer/lib/Model/trip_model.dart` — restored + added `userName`, `userPhone`, `userPhoto` fields + GeoFlutterFire points in `toJson()`
- `DCS_Customer/lib/Model/direction_model.dart` — restored from git
- `DCS_Customer/lib/View/Screens/Main_Screens/Home_Screen/home_providers.dart` — restored + added `homeScreenBookingPassengerProvider`
- `DCS_Customer/lib/Container/Providers/fare_config_providers.dart` — added `surgeRulesStreamProvider`

## Build Status
```bash
# Customer APK (builds successfully)
cd /data/DCSApp/DCS_Customer && flutter build apk --debug
# ✅ Built build/app/outputs/flutter-apk/app-debug.apk
```

## Verification
- Notification server (Railway) is alive: `GET /` → `{"status":"ok","service":"dcs-notification-server"}`

## Key Context
- Firebase project: `dadacabs-099`; rules permissive (`allow read, write: if true`)
- UserRepo._primaryCollection = `users`; driver collection = `drivers`; vehicle types collection = `vehicleTypes`
- Phone stored as `+91XXXXXXXXXX`; login input is raw 10-digit string
- `getUserByPhone()` does 4-step lookup: (1) exact 10-digit, (2) +91 prefix, (3) 91 prefix, (4) full scan
- Google Maps API key: `AIzaSyAnsK0I2lw7YP3qhUthMBtlsiJ31WVkPrY` (used only by Places/Directions APIs now, no map rendering)
- 23 drivers in Firestore `drivers` collection; only 2 have `isOnline: true`
- Driver model has NO `isOnline` field — online status determined by Firestore field
- `_getOnlineCount` uses substring matching on `carType` against vehicle type name from `vehicleTypes` collection
- 10 vehicle types: Auto Rickshaw, Bike, Hatchback, Luxury Car, Sedan, SUV, Tempo (inactive), Large Truck (inactive), Small Truck, Van

### Renamed All "Captain" → "Partner" (2026-07-31)
- **Files renamed (4):** `captain_navigation_screen.dart`→`partner_navigation_screen.dart`, `captain_trip_detail_screen.dart`→`partner_trip_detail_screen.dart`, `captain_support_screen.dart`→`partner_support_screen.dart`, `captain_rating_detail_screen.dart`→`partner_rating_detail_screen.dart`
- **Class/identifiers renamed:** `CaptainNavigationScreen`→`PartnerNavigationScreen`, `CaptainSupportScreen`→`PartnerSupportScreen`, `CaptainRatingDetailScreen`→`PartnerRatingDetailScreen`, `CaptainTripDetailArgs/Screen`→`PartnerTripDetailArgs/Screen`
- **Model fields:** `fare_config_model.dart` (both apps): `captainBaseFare`→`partnerBaseFare`, `captainPerKmRate`→`partnerPerKmRate`, `captainPerMinuteRate`→`partnerPerMinuteRate`, `calculateCaptainEarning`→`calculatePartnerEarning`
- **Providers:** `incentive_screen.dart`: `captainLevelProvider`→`partnerLevelProvider`, `CaptainLevel`→`PartnerLevel`
- **Routes:** `app_routes.dart`: All class references updated
- **Admin panel:** `SetPrices.js`: All field names (`captainBaseFare`→`partnerBaseFare`, etc.) and display text ("Captain"→"Partner") updated
- **Customer app:** `active_trip_screen_modern.dart`: "captain"→"partner" in PIN sharing text
- **Verification:** `flutter analyze` on both Customer & Partner: 0 errors from changes. `rg -l captain` on all source: 0 matches.

## Relevant Files
- `DCS_Customer/lib/View/Screens/Main_Screens/Home_Screen/home_screen_modern.dart` — OSM-only map, color rename `accentYellow`→`lemonYellow`/`darkYellow`, ride options filtering, vehicle icons
- `DCS_Customer/lib/View/Screens/Main_Screens/Active_Trip_Screen/active_trip_screen_modern.dart` — OSM map, inline marker icons, vehicle-type searching icon
- `DCS_Customer/lib/View/Screens/Main_Screens/Sub_Screens/Where_To_Screen/where_to_screen_modern.dart` — OSM map, color rename, ride request flow
- `DCS_Customer/lib/Container/Repositories/firestore_repo.dart` — driver stream merge, online status filtering, `addUserRideRequestToDB()`
- `DCS_Customer/lib/View/Screens/Main_Screens/Home_Screen/home_logics.dart` — webhook notify, no-op FCM methods
- `DCS_Partner/lib/View/Screens/Main_Screens/Home_Screen/home_screen.dart` — OSM map, post-frame driver fetch, `_loadInitialLocation()`
- `DCS_Partner/lib/View/Screens/Main_Screens/Home_Screen/home_logics.dart` — removed `GoogleMapController` params
- `DCS_Partner/lib/View/Screens/Main_Screens/TripRequest_Screen/trip_request_screen.dart` — OSM maps for request card and active trip
- `DCS_Partner/pubspec.yaml` — added `flutter_map: ^7.0.2`, `latlong2: ^0.9.0`; upgraded `image_cropper: ^12.2.1` (fixes pre-existing `PluginRegistry.Registrar` Java compile error)
- `DCS_Customer/pubspec.yaml` — already had `flutter_map: ^4.0.0`, `latlong2: ^0.8.2`
- `functions/src/notifications.ts` — Firestore collection/field fix, isOnline string handling, token pruning
- `notification-server/index.js` — Express webhook for Railway

## Build Commands
```bash
# Customer APK (builds successfully)
cd /data/DCSApp/DCS_Customer && flutter build apk --debug

# Partner APK (builds successfully)
cd /data/DCSApp/DCS_Partner && flutter build apk --release --no-tree-shake-icons
```

## Remaining Work / Known Issues
- Color theme files (`indian_heritage_theme.dart`, `app_theme.dart`) may still reference old `accentYellow` — verify and update if needed
- Some files may still import `set_blackmap.dart` (Customer legacy import) — already removed from `home_screen_modern.dart`
- `flutter_map` versions differ between Customer (4.0.0) and Partner (7.0.2) — unify if desired (both work independently)
- FCM token issue: only 1/23 drivers have tokens because `MessagingService.init()` used `doc(currentUser.uid)` but driver docs use custom IDs. Fixed by querying `phone` field now. Will need to test after redeploying Partner APK with fix and logging in as a driver.
- **Ride request diagnostic logging**: Added comprehensive logging to Customer firestore_repo.dart + Partner trip_repo.dart + trip_request_screen.dart. Next step: deploy both APKs, create a test trip from Customer, and check Partner app logs (TRIP_REPO / TRIP_PROVIDER / FIRESTORE_REPO prefixes) to identify where the flow breaks.

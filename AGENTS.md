# Session Context — Last Updated 2026-07-11 12:30:00

## Goal
Fix all 5 reported issues: (1) Partner current location marker, (2) Customer vehicle images, (3) online drivers not showing on Customer map, (4) ride request not reaching drivers, (5) signature comments missing on changed lines. (Re-fix after file regressions.)

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

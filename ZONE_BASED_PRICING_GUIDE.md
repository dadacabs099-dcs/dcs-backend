# Zone-Based Pricing System (Rapido-Style)

## Overview

This document describes the complete zone-based pricing system implemented across the DCS platform. The pricing follows Rapido's base fare model where:

1. **Each zone has different pricing** for each vehicle type
2. **Base fare covers a base distance** (e.g., first 2-3 km included)
3. **Per-km rate applies after base distance**
4. **Per-minute rate** for ride duration
5. **Waiting charges** after free waiting time
6. **Surge multiplier** for demand-based pricing

## Architecture

```
┌─────────────────┐     ┌──────────────────────────┐     ┌─────────────────┐
│   Admin Panel    │────▶│   Firestore DB            │◀────│  Backend API    │
│  (SetPrices.js)  │     │  (zones, vehicleTypes,    │     │  (/api/fares)   │
│                  │     │   fareConfigs)             │     │                 │
└─────────────────┘     └──────────────────────────┘     └─────────────────┘
                               ▲    │
                               │    ▼
┌─────────────────┐     ┌──────────────────────────┐
│  DCS_Customer    │     │  DCS_Partner             │
│  (Flutter App)   │     │  (Flutter App)           │
│  Zone auto-      │     │  Zone auto-detected      │
│  detected from   │     │  from driver GPS         │
│  customer GPS    │     │                          │
└─────────────────┘     └──────────────────────────┘
```

## How It Works

1. **Zones exist** in Firestore `zones` collection (created via Admin Panel → Zones)
2. **Vehicle types with pricing exist** in Firestore `vehicleTypes` collection (created via Admin Panel)
3. **Apps auto-detect the user's zone** based on GPS location matching against zone boundaries (lat/lng + radius)
4. **Fare is calculated using existing vehicle types pricing** from Firestore `vehicleTypes` collection
5. **Zone-specific overrides** from `fareConfigs` collection apply when configured (for different pricing per zone)

## Pricing Priority Order

1. **Zone-specific fare config** from `fareConfigs` collection (if configured for the detected zone + vehicle type) — uses Rapido-style base distance formula
2. **Vehicle type rates** from `vehicleTypes` collection (your existing admin panel configuration) — uses simple per-km formula
3. **Static defaults** in `VehicleTypeModel.defaults` (only as last resort if vehicleTypes collection is empty)

## Fare Calculation Formulas

### With Zone-Specific Fare Config (Rapido-Style)
```
fare = baseFare + max(0, distance - baseDistance) × perKmRate + duration × perMinuteRate + waitingFare
totalFare = max(fare × surge, minimumFare)
```

### With Vehicle Type Rates (Existing System)
```
fare = baseFare + distance × perKmRate + duration × perMinuteRate
totalFare = max(fare, minimumFare)
```

### Example: 7 km ride in South Mumbai (Sedan), 20 minutes

**With zone config:** ₹50 base (3km included) + (7-3)×₹14 + 20×₹1.8 = ₹142
**Without zone config:** ₹50 base + 7×₹14 + 20×₹1.8 = ₹186 (uses vehicleTypes rates)

## Files Modified/Created

### Backend
| File | Description |
|------|-------------|
| `backend/server.js` | Added `/api/fares/*` endpoints for CRUD + calculate |
| `backend/routes/fareRoutes.js` | Standalone route module (optional) |

### Admin Panel
| File | Description |
|------|-------------|
| `admin-panel/src/services/api.js` | Added `fareConfigs` and `pricing` API methods |
| `admin-panel/src/pages/pricing/SetPrices.js` | Updated to save zone-based fare configs |
| `admin-panel/scripts/seed-fare-configs.js` | Seed script for initial fare data |

### DCS_Customer
| File | Description |
|------|-------------|
| `DCS_Customer/lib/Model/fare_config_model.dart` | FareConfig model with calculateFare() |
| `DCS_Customer/lib/Container/Providers/fare_config_providers.dart` | Riverpod providers for fare configs |
| `DCS_Customer/lib/Container/Providers/zone_detection_provider.dart` | GPS-based zone detection |
| `DCS_Customer/lib/View/.../home_logics.dart` | Zone detection + dynamic fare calculation |

### DCS_Partner
| File | Description |
|------|-------------|
| `DCS_Partner/lib/Model/fare_config_model.dart` | FareConfig model with calculateFare() |
| `DCS_Partner/lib/Container/Providers/fare_config_providers.dart` | Riverpod providers + getStandardFare() |
| `DCS_Partner/lib/Container/Providers/zone_detection_provider.dart` | GPS-based zone detection |
| `DCS_Partner/lib/View/.../trip_request_screen.dart` | Updated fare display and trip completion |
| `DCS_Partner/lib/View/.../home_logics.dart` | Zone detection on driver location fetch |

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/fares` | Get all fare configs (optional filters: zoneId, vehicleType, isActive) |
| GET | `/api/fares/zone/:zoneId` | Get fares for a specific zone |
| GET | `/api/fares/zone-name/:zoneName` | Get fares by zone name |
| GET | `/api/fares/:id` | Get single fare config |
| POST | `/api/fares` | Create a fare config |
| POST | `/api/fares/bulk` | Bulk create fare configs |
| PUT | `/api/fares/:id` | Update a fare config |
| DELETE | `/api/fares/:id` | Delete a fare config |
| POST | `/api/fares/calculate` | Calculate fare estimate |

## Setup Instructions

### Step 1: Ensure Zones and Vehicle Types Exist
Your existing Firestore data is used directly:
- **`zones` collection** — Zone boundaries (lat, lng, radius) for GPS-based zone detection
- **`vehicleTypes` collection** — Base fare rates (baseFare, perKmRate, perMinuteRate, minimumFare)

### Step 2 (Optional): Add Zone-Specific Fare Overrides
If you want different pricing per zone (e.g., premium zones cost more):
1. Go to Admin Panel → Pricing → Add Pricing Rule
2. Select a Zone and Vehicle Type
3. Fill in the Rapido-style fare fields (base fare, base distance, per-km rate, etc.)
4. Save → This creates a `fareConfigs` document

### Step 3: Create Firestore Composite Index
The `fareConfigs` collection requires a composite index:
- Fields: `isActive` (Ascending) + `zoneName` (Ascending) + `vehicleType` (Ascending)

This will be auto-created when you first query the collection, or you can create it manually in Firebase Console → Firestore → Indexes.

### Step 4: Test in Apps
1. **Customer App**: Open app → zone is auto-detected from GPS → request a ride → fare uses vehicle type rates from Firestore
2. **Partner App**: Open app → zone is auto-detected from GPS → accept a trip → fare display uses vehicle type rates

## Zone Detection

Both apps automatically detect the user's zone when GPS location is obtained:

1. Reads all active zones from Firestore `zones` collection
2. Checks if the GPS point falls within any zone's radius (using Haversine distance)
3. If no exact match, finds the nearest zone within 2x radius as a soft boundary
4. Sets `currentZoneNameProvider` with the detected zone name
5. Fare calculation uses this zone name to find matching fare configs

## Adding New Zones

1. Create the zone in Admin Panel → Zones → Manage Zones (with lat/lng/radius)
2. The apps will auto-detect users in that zone based on GPS
3. Optionally add zone-specific fare overrides via Admin Panel → Pricing → Add Pricing Rule
4. If no zone-specific override exists, the global vehicle type rates apply

## Monitoring

- Check Firestore `fareConfigs` collection in Firebase Console
- Use `/api/fares` endpoint to view all configurations
- Monitor fare calculation via `/api/fares/calculate` endpoint
- Check app logs for "Zone detected:" messages to verify zone detection
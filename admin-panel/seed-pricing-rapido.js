/**
 * Rapido-Style Pricing Seed Script for DCS (Dada Cabs)
 * 
 * This script populates the Firestore database with Rapido-style pricing
 * for all vehicle types across all Mumbai zones. It creates:
 * 
 * 1. fareConfigs  – Zone-based pricing per vehicle type (Rapido-style)
 * 2. fareFixRoutes – Fixed fares for popular routes (airport, stations)
 * 3. surgeRules    – Time-based surge pricing rules
 * 
 * Usage:
 *   cd admin-panel && node seed-pricing-rapido.js
 * 
 * Prerequisites:
 *   - service-account.json in DCSApp/ directory (or ../service-account.json)
 *   - firebase-admin installed
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// ─── Firebase Init ────────────────────────────────────────────────
const PROJECT_ID = 'dadacabs-099';
const serviceAccountPath = path.join(__dirname, '..', 'service-account.json');

if (!fs.existsSync(serviceAccountPath)) {
  console.error('❌ service-account.json not found at:', serviceAccountPath);
  console.log('Place your Firebase service account key there.');
  process.exit(1);
}

const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: `https://${PROJECT_ID}-default-rtdb.firebaseio.com`
});

const db = admin.firestore();

// ─── Zone Definitions (Mumbai) ───────────────────────────────────
const zones = [
  { id: 'zone-mumbai-01', zoneName: 'Zone 1', from: 'Dahisar', to: 'Bandra', city: 'Mumbai' },
  { id: 'zone-mumbai-02', zoneName: 'Zone 2', from: 'Mahim', to: 'Churchgate', city: 'Mumbai' },
  { id: 'zone-mumbai-03', zoneName: 'Zone 3', from: 'Mulund', to: 'Kurla', city: 'Mumbai' },
  { id: 'zone-mumbai-04', zoneName: 'Zone 4', from: 'Kurla', to: 'CSTM', city: 'Mumbai' },
  { id: 'zone-mumbai-05', zoneName: 'Zone 5', from: 'Thane', to: '', city: 'Mumbai' },
  { id: 'zone-mumbai-06', zoneName: 'Zone 6', from: 'Navi Mumbai', to: '', city: 'Mumbai' },
  { id: 'zone-mumbai-07', zoneName: 'Zone 7', from: 'Bhyander', to: 'Virar', city: 'Mumbai' },
  { id: 'zone-mumbai-08', zoneName: 'Zone 8', from: 'Thane', to: 'Karjat', city: 'Mumbai' },
];

// ─── Rapido-Style Pricing per Vehicle Type ────────────────────────
// Rapido formula: baseFare covers baseDistance km, then perKmRate, perMinuteRate, minimumFare
// Captain earns slightly less (admin commission ~15-20%)
const vehiclePricing = {
  Bike: {
    baseFare: 15,
    baseDistance: 2,
    perKmRate: 4,
    perMinuteRate: 0.5,
    minimumFare: 25,
    waitingCharge: 0.5,
    freeWaitingTime: 3,
    // Captain earning (70-80% of customer fare)
    captainBaseFare: 12,
    captainPerKmRate: 3.2,
    captainPerMinuteRate: 0.4,
    // Commission
    adminCommission: 20,  // 20%
    adminCommissionType: 'Percentage',
    serviceTax: 5,
    // Surge
    surgeEnabled: true,
    surgeMultiplier: 1.0,
    maxSurgeMultiplier: 3.0,
    // Features
    enableAirportRide: false,
    enableOutstationRide: false,
  },
  Auto: {
    baseFare: 30,
    baseDistance: 1.5,
    perKmRate: 11,
    perMinuteRate: 1.5,
    minimumFare: 50,
    waitingCharge: 1.0,
    freeWaitingTime: 3,
    captainBaseFare: 24,
    captainPerKmRate: 9,
    captainPerMinuteRate: 1.2,
    adminCommission: 20,
    adminCommissionType: 'Percentage',
    serviceTax: 5,
    surgeEnabled: true,
    surgeMultiplier: 1.0,
    maxSurgeMultiplier: 3.0,
    enableAirportRide: true,
    enableOutstationRide: false,
  },
  Sedan: {
    baseFare: 60,
    baseDistance: 3,
    perKmRate: 14,
    perMinuteRate: 2,
    minimumFare: 100,
    waitingCharge: 1.5,
    freeWaitingTime: 5,
    captainBaseFare: 48,
    captainPerKmRate: 11,
    captainPerMinuteRate: 1.6,
    adminCommission: 20,
    adminCommissionType: 'Percentage',
    serviceTax: 5,
    surgeEnabled: true,
    surgeMultiplier: 1.0,
    maxSurgeMultiplier: 3.5,
    enableAirportRide: true,
    enableOutstationRide: true,
  },
  SUV: {
    baseFare: 90,
    baseDistance: 3,
    perKmRate: 18,
    perMinuteRate: 2.5,
    minimumFare: 150,
    waitingCharge: 2.0,
    freeWaitingTime: 5,
    captainBaseFare: 72,
    captainPerKmRate: 14.5,
    captainPerMinuteRate: 2.0,
    adminCommission: 20,
    adminCommissionType: 'Percentage',
    serviceTax: 5,
    surgeEnabled: true,
    surgeMultiplier: 1.0,
    maxSurgeMultiplier: 3.5,
    enableAirportRide: true,
    enableOutstationRide: true,
  },
  Premium: {
    baseFare: 120,
    baseDistance: 4,
    perKmRate: 22,
    perMinuteRate: 3,
    minimumFare: 200,
    waitingCharge: 2.5,
    freeWaitingTime: 5,
    captainBaseFare: 96,
    captainPerKmRate: 17.5,
    captainPerMinuteRate: 2.4,
    adminCommission: 20,
    adminCommissionType: 'Percentage',
    serviceTax: 5,
    surgeEnabled: true,
    surgeMultiplier: 1.0,
    maxSurgeMultiplier: 4.0,
    enableAirportRide: true,
    enableOutstationRide: true,
  },
  Van: {
    baseFare: 100,
    baseDistance: 3,
    perKmRate: 16,
    perMinuteRate: 2,
    minimumFare: 160,
    waitingCharge: 2.0,
    freeWaitingTime: 5,
    captainBaseFare: 80,
    captainPerKmRate: 13,
    captainPerMinuteRate: 1.6,
    adminCommission: 20,
    adminCommissionType: 'Percentage',
    serviceTax: 5,
    surgeEnabled: true,
    surgeMultiplier: 1.0,
    maxSurgeMultiplier: 3.0,
    enableAirportRide: true,
    enableOutstationRide: true,
  },
};

// ─── Fare Fix Routes (Airport & Station transfers) ───────────────
const fareFixRoutes = [
  // Airport routes
  {
    routeName: 'Airport to Andheri',
    pickupLocation: 'Chhatrapati Shivaji Maharaj International Airport',
    dropoffLocation: 'Andheri West',
    vehicleType: 'Sedan',
    fixedFare: 350,
    captainEarning: 280,
    distance: 12,
    isActive: true,
  },
  {
    routeName: 'Airport to Bandra',
    pickupLocation: 'Chhatrapati Shivaji Maharaj International Airport',
    dropoffLocation: 'Bandra West',
    vehicleType: 'Sedan',
    fixedFare: 300,
    captainEarning: 240,
    distance: 10,
    isActive: true,
  },
  {
    routeName: 'Airport to Dadar',
    pickupLocation: 'Chhatrapati Shivaji Maharaj International Airport',
    dropoffLocation: 'Dadar',
    vehicleType: 'Sedan',
    fixedFare: 400,
    captainEarning: 320,
    distance: 15,
    isActive: true,
  },
  {
    routeName: 'Airport to South Mumbai',
    pickupLocation: 'Chhatrapati Shivaji Maharaj International Airport',
    dropoffLocation: 'Nariman Point',
    vehicleType: 'Sedan',
    fixedFare: 500,
    captainEarning: 400,
    distance: 22,
    isActive: true,
  },
  {
    routeName: 'Airport to Thane',
    pickupLocation: 'Chhatrapati Shivaji Maharaj International Airport',
    dropoffLocation: 'Thane Station',
    vehicleType: 'Sedan',
    fixedFare: 550,
    captainEarning: 440,
    distance: 28,
    isActive: true,
  },
  // Bike routes (short distance)
  {
    routeName: 'Bandra to Andheri (Bike)',
    pickupLocation: 'Bandra Station',
    dropoffLocation: 'Andheri Station',
    vehicleType: 'Bike',
    fixedFare: 60,
    captainEarning: 48,
    distance: 8,
    isActive: true,
  },
  {
    routeName: 'Dadar to CSMT (Bike)',
    pickupLocation: 'Dadar Station',
    dropoffLocation: 'CSMT Station',
    vehicleType: 'Bike',
    fixedFare: 50,
    captainEarning: 40,
    distance: 6,
    isActive: true,
  },
  // Auto routes
  {
    routeName: 'Thane to Mulund (Auto)',
    pickupLocation: 'Thane Station',
    dropoffLocation: 'Mulund Station',
    vehicleType: 'Auto',
    fixedFare: 100,
    captainEarning: 80,
    distance: 7,
    isActive: true,
  },
  {
    routeName: 'Bandra to Juhu (Auto)',
    pickupLocation: 'Bandra West',
    dropoffLocation: 'Juhu Beach',
    vehicleType: 'Auto',
    fixedFare: 80,
    captainEarning: 64,
    distance: 5,
    isActive: true,
  },
  // Premium routes
  {
    routeName: 'Airport to South Mumbai (Premium)',
    pickupLocation: 'Chhatrapati Shivaji Maharaj International Airport',
    dropoffLocation: 'Taj Mahal Palace Hotel',
    vehicleType: 'Premium',
    fixedFare: 700,
    captainEarning: 560,
    distance: 22,
    isActive: true,
  },
  {
    routeName: 'Bandra to Navi Mumbai (SUV)',
    pickupLocation: 'Bandra Kurla Complex',
    dropoffLocation: 'Vashi Station',
    vehicleType: 'SUV',
    fixedFare: 450,
    captainEarning: 360,
    distance: 20,
    isActive: true,
  },
];

// ─── Surge Rules ─────────────────────────────────────────────────
const surgeRules = [
  // Evening peak (Rapido-style time-based surge)
  {
    zoneName: 'Zone 1',
    multiplier: 1.5,
    startTime: '17:00',
    endTime: '21:00',
    days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
    vehicleType: 'All',
    minFare: 50,
    maxFare: 500,
    isActive: true,
  },
  {
    zoneName: 'Zone 2',
    multiplier: 1.5,
    startTime: '17:00',
    endTime: '21:00',
    days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
    vehicleType: 'All',
    minFare: 50,
    maxFare: 500,
    isActive: true,
  },
  // Weekend night surge
  {
    zoneName: 'Zone 1',
    multiplier: 2.0,
    startTime: '22:00',
    endTime: '02:00',
    days: ['Fri', 'Sat'],
    vehicleType: 'All',
    minFare: 80,
    maxFare: 800,
    isActive: true,
  },
  {
    zoneName: 'Zone 2',
    multiplier: 2.0,
    startTime: '22:00',
    endTime: '02:00',
    days: ['Fri', 'Sat'],
    vehicleType: 'All',
    minFare: 80,
    maxFare: 800,
    isActive: true,
  },
  // Morning rush hour
  {
    zoneName: 'Zone 3',
    multiplier: 1.3,
    startTime: '07:00',
    endTime: '10:00',
    days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
    vehicleType: 'All',
    minFare: 40,
    maxFare: 400,
    isActive: true,
  },
  {
    zoneName: 'Zone 4',
    multiplier: 1.3,
    startTime: '07:00',
    endTime: '10:00',
    days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
    vehicleType: 'All',
    minFare: 40,
    maxFare: 400,
    isActive: true,
  },
  // Rainy season / monsoon surge (all zones, higher multiplier)
  {
    zoneName: 'Zone 5',
    multiplier: 1.8,
    startTime: '06:00',
    endTime: '23:00',
    days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    vehicleType: 'All',
    minFare: 60,
    maxFare: 600,
    isActive: false, // Enable during monsoon
  },
  // Airport area surge
  {
    zoneName: 'Zone 6',
    multiplier: 1.4,
    startTime: '05:00',
    endTime: '23:00',
    days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    vehicleType: 'All',
    minFare: 50,
    maxFare: 500,
    isActive: true,
  },
  // Late night extreme surge (Thane-Virar belt)
  {
    zoneName: 'Zone 7',
    multiplier: 2.5,
    startTime: '23:00',
    endTime: '04:00',
    days: ['Fri', 'Sat'],
    vehicleType: 'Sedan',
    minFare: 100,
    maxFare: 1000,
    isActive: true,
  },
];

// ─── Main Seed Function ──────────────────────────────────────────
async function seedPricing() {
  console.log('\n🚀 Starting Rapido-Style Pricing Seed...\n');

  // ─── 1. Seed fareConfigs (zone × vehicle type) ─────────────────
  console.log('📋 Seeding fareConfigs...');
  const fareConfigBatch = db.batch();
  let fareConfigCount = 0;

  for (const zone of zones) {
    for (const [vehicleType, pricing] of Object.entries(vehiclePricing)) {
      const docId = `${zone.id}_${vehicleType.toLowerCase()}`;
      const docRef = db.collection('fareConfigs').doc(docId);

      // Slight zone-based adjustments (outer zones slightly cheaper)
      const zoneMultiplier = zone.id.includes('07') || zone.id.includes('08') ? 0.9 :
                             zone.id.includes('05') || zone.id.includes('06') ? 0.95 : 1.0;

      const fareData = {
        zoneId: zone.id,
        zoneName: zone.zoneName,
        vehicleType: vehicleType,
        // Customer pricing
        baseFare: Math.round(pricing.baseFare * zoneMultiplier),
        baseDistance: pricing.baseDistance,
        perKmRate: Math.round(pricing.perKmRate * zoneMultiplier * 10) / 10,
        perMinuteRate: Math.round(pricing.perMinuteRate * 10) / 10,
        minimumFare: Math.round(pricing.minimumFare * zoneMultiplier),
        // Waiting
        waitingCharge: pricing.waitingCharge,
        freeWaitingTime: pricing.freeWaitingTime,
        // Surge
        surgeMultiplier: 1.0,
        maxSurgeMultiplier: pricing.maxSurgeMultiplier,
        surgeEnabled: pricing.surgeEnabled,
        // Captain earning
        captainBaseFare: Math.round(pricing.captainBaseFare * zoneMultiplier),
        captainPerKmRate: Math.round(pricing.captainPerKmRate * zoneMultiplier * 10) / 10,
        captainPerMinuteRate: Math.round(pricing.captainPerMinuteRate * 10) / 10,
        // Commission
        adminCommissionType: pricing.adminCommissionType,
        adminCommission: pricing.adminCommission,
        serviceTax: pricing.serviceTax,
        // Features
        enableAirportRide: pricing.enableAirportRide,
        enableOutstationRide: pricing.enableOutstationRide,
        isActive: true,
        // Metadata
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        seededBy: 'seed-pricing-rapido.js',
      };

      fareConfigBatch.set(docRef, fareData);
      fareConfigCount++;
    }
  }

  try {
    await fareConfigBatch.commit();
    console.log(`   ✅ Created ${fareConfigCount} fareConfigs (${zones.length} zones × ${Object.keys(vehiclePricing).length} vehicle types)`);
  } catch (error) {
    console.error('   ❌ Error seeding fareConfigs:', error.message);
    // Try individual writes if batch fails
    console.log('   🔄 Falling back to individual writes...');
    for (const zone of zones) {
      for (const [vehicleType, pricing] of Object.entries(vehiclePricing)) {
        const docId = `${zone.id}_${vehicleType.toLowerCase()}`;
        try {
          const zoneMultiplier = zone.id.includes('07') || zone.id.includes('08') ? 0.9 :
                                 zone.id.includes('05') || zone.id.includes('06') ? 0.95 : 1.0;
          await db.collection('fareConfigs').doc(docId).set({
            zoneId: zone.id,
            zoneName: zone.zoneName,
            vehicleType,
            baseFare: Math.round(pricing.baseFare * zoneMultiplier),
            baseDistance: pricing.baseDistance,
            perKmRate: Math.round(pricing.perKmRate * zoneMultiplier * 10) / 10,
            perMinuteRate: Math.round(pricing.perMinuteRate * 10) / 10,
            minimumFare: Math.round(pricing.minimumFare * zoneMultiplier),
            waitingCharge: pricing.waitingCharge,
            freeWaitingTime: pricing.freeWaitingTime,
            surgeMultiplier: 1.0,
            maxSurgeMultiplier: pricing.maxSurgeMultiplier,
            surgeEnabled: pricing.surgeEnabled,
            captainBaseFare: Math.round(pricing.captainBaseFare * zoneMultiplier),
            captainPerKmRate: Math.round(pricing.captainPerKmRate * zoneMultiplier * 10) / 10,
            captainPerMinuteRate: Math.round(pricing.captainPerMinuteRate * 10) / 10,
            adminCommissionType: pricing.adminCommissionType,
            adminCommission: pricing.adminCommission,
            serviceTax: pricing.serviceTax,
            enableAirportRide: pricing.enableAirportRide,
            enableOutstationRide: pricing.enableOutstationRide,
            isActive: true,
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
            seededBy: 'seed-pricing-rapido.js',
          });
        } catch (e) {
          console.error(`   ❌ Failed to write ${docId}:`, e.message);
        }
      }
    }
  }

  // ─── 2. Seed fareFixRoutes ─────────────────────────────────────
  console.log('\n📋 Seeding fareFixRoutes...');
  const routeBatch = db.batch();
  let routeCount = 0;

  fareFixRoutes.forEach((route, index) => {
    const docId = `fareroute-${String(index + 1).padStart(3, '0')}`;
    const docRef = db.collection('fareFixRoutes').doc(docId);
    routeBatch.set(docRef, {
      ...route,
      fixedFare: route.fixedFare,
      customerFare: route.fixedFare, // Both field names for compatibility
      captainEarning: route.captainEarning,
      isActive: route.isActive,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      seededBy: 'seed-pricing-rapido.js',
    });
    routeCount++;
  });

  try {
    await routeBatch.commit();
    console.log(`   ✅ Created ${routeCount} fareFixRoutes`);
  } catch (error) {
    console.error('   ❌ Error seeding fareFixRoutes:', error.message);
    console.log('   🔄 Falling back to individual writes...');
    for (let i = 0; i < fareFixRoutes.length; i++) {
      const route = fareFixRoutes[i];
      try {
        const docId = `fareroute-${String(i + 1).padStart(3, '0')}`;
        await db.collection('fareFixRoutes').doc(docId).set({
          ...route,
          fixedFare: route.fixedFare,
          customerFare: route.fixedFare,
          captainEarning: route.captainEarning,
          isActive: route.isActive,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          seededBy: 'seed-pricing-rapido.js',
        });
      } catch (e) {
        console.error(`   ❌ Failed to write fareFixRoute ${i + 1}:`, e.message);
      }
    }
  }

  // ─── 3. Seed surgeRules ────────────────────────────────────────
  console.log('\n📋 Seeding surgeRules...');
  const surgeBatch = db.batch();
  let surgeCount = 0;

  surgeRules.forEach((rule, index) => {
    const docId = `surge-${String(index + 1).padStart(3, '0')}`;
    const docRef = db.collection('surgeRules').doc(docId);
    surgeBatch.set(docRef, {
      ...rule,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      seededBy: 'seed-pricing-rapido.js',
    });
    surgeCount++;
  });

  try {
    await surgeBatch.commit();
    console.log(`   ✅ Created ${surgeCount} surgeRules`);
  } catch (error) {
    console.error('   ❌ Error seeding surgeRules:', error.message);
    console.log('   🔄 Falling back to individual writes...');
    for (let i = 0; i < surgeRules.length; i++) {
      const rule = surgeRules[i];
      try {
        const docId = `surge-${String(i + 1).padStart(3, '0')}`;
        await db.collection('surgeRules').doc(docId).set({
          ...rule,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          seededBy: 'seed-pricing-rapido.js',
        });
      } catch (e) {
        console.error(`   ❌ Failed to write surgeRule ${i + 1}:`, e.message);
      }
    }
  }

  // ─── Summary ───────────────────────────────────────────────────
  console.log('\n' + '═'.repeat(60));
  console.log('✅ Rapido-Style Pricing Seed Complete!');
  console.log('═'.repeat(60));
  console.log(`   📊 fareConfigs:   ${fareConfigCount} documents (zones × vehicle types)`);
  console.log(`   🗺️  fareFixRoutes: ${routeCount} fixed fare routes`);
  console.log(`   ⚡ surgeRules:    ${surgeCount} surge pricing rules`);
  console.log('═'.repeat(60));
  console.log('\n💡 Pricing Summary (Rapido-style):');
  console.log('   ┌──────────┬─────────┬─────────┬──────────┬─────────┐');
  console.log('   │ Vehicle  │ Base(₹) │ /km(₹)  │ /min(₹)  │ Min(₹)  │');
  console.log('   ├──────────┼─────────┼─────────┼──────────┼─────────┤');
  for (const [type, p] of Object.entries(vehiclePricing)) {
    console.log(`   │ ${type.padEnd(8)} │ ${String(p.baseFare).padStart(7)} │ ${String(p.perKmRate).padStart(7)} │ ${String(p.perMinuteRate).padStart(8)} │ ${String(p.minimumFare).padStart(7)} │`);
  }
  console.log('   └──────────┴─────────┴─────────┴──────────┴─────────┘');
  console.log('\n   Captain earns ~80% of customer fare (admin commission: 20%)');
  console.log('   Surge pricing: 1.0x - 4.0x based on demand/time\n');

  process.exit(0);
}

seedPricing().catch(err => {
  console.error('❌ Fatal error:', err);
  process.exit(1);
});
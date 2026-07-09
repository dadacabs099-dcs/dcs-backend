/**
 * Seed Fare Configurations for Firestore
 * 
 * This script creates zone-based pricing (Rapido-style) for all zones
 * and vehicle types in the Firestore fareConfigs collection.
 * 
 * Usage: node scripts/seed-fare-configs.js
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccount = require(path.join(__dirname, '../../dadacabs-099-firebase-adminsdk-fbsvc-5039419589.json'));

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

// Rapido-style fare configurations per zone
// Format: { baseFare, baseDistance (km), perKmRate, perMinuteRate, minimumFare, waitingCharge, freeWaitingTime }
const zoneFareTemplates = {
  // Premium zones (South Mumbai, Bandra, Powai)
  premium: {
    Bike:    { baseFare: 25, baseDistance: 2, perKmRate: 7, perMinuteRate: 1.0, minimumFare: 30, waitingCharge: 1.5, freeWaitingTime: 3 },
    Auto:    { baseFare: 35, baseDistance: 2, perKmRate: 11, perMinuteRate: 1.5, minimumFare: 45, waitingCharge: 2.0, freeWaitingTime: 3 },
    Sedan:   { baseFare: 50, baseDistance: 3, perKmRate: 14, perMinuteRate: 1.8, minimumFare: 70, waitingCharge: 2.5, freeWaitingTime: 3 },
    SUV:     { baseFare: 80, baseDistance: 3, perKmRate: 22, perMinuteRate: 2.5, minimumFare: 110, waitingCharge: 3.5, freeWaitingTime: 3 },
    Premium: { baseFare: 100, baseDistance: 3, perKmRate: 28, perMinuteRate: 3.0, minimumFare: 150, waitingCharge: 4.0, freeWaitingTime: 3 },
    Van:     { baseFare: 120, baseDistance: 3, perKmRate: 25, perMinuteRate: 2.5, minimumFare: 160, waitingCharge: 3.5, freeWaitingTime: 3 },
  },
  // Standard zones (Andheri, Borivali, Thane)
  standard: {
    Bike:    { baseFare: 20, baseDistance: 2, perKmRate: 6, perMinuteRate: 1.0, minimumFare: 25, waitingCharge: 1.0, freeWaitingTime: 3 },
    Auto:    { baseFare: 30, baseDistance: 2, perKmRate: 10, perMinuteRate: 1.2, minimumFare: 40, waitingCharge: 1.5, freeWaitingTime: 3 },
    Sedan:   { baseFare: 40, baseDistance: 2, perKmRate: 12, perMinuteRate: 1.5, minimumFare: 60, waitingCharge: 2.0, freeWaitingTime: 3 },
    SUV:     { baseFare: 70, baseDistance: 3, perKmRate: 20, perMinuteRate: 2.2, minimumFare: 100, waitingCharge: 3.0, freeWaitingTime: 3 },
    Premium: { baseFare: 90, baseDistance: 3, perKmRate: 25, perMinuteRate: 2.8, minimumFare: 130, waitingCharge: 3.5, freeWaitingTime: 3 },
    Van:     { baseFare: 100, baseDistance: 3, perKmRate: 22, perMinuteRate: 2.2, minimumFare: 140, waitingCharge: 3.0, freeWaitingTime: 3 },
  },
  // Emerging zones (Kalyan, Dombivli, Panvel)
  emerging: {
    Bike:    { baseFare: 18, baseDistance: 2, perKmRate: 5.5, perMinuteRate: 0.8, minimumFare: 22, waitingCharge: 1.0, freeWaitingTime: 3 },
    Auto:    { baseFare: 25, baseDistance: 2, perKmRate: 9, perMinuteRate: 1.0, minimumFare: 35, waitingCharge: 1.5, freeWaitingTime: 3 },
    Sedan:   { baseFare: 35, baseDistance: 2, perKmRate: 11, perMinuteRate: 1.2, minimumFare: 50, waitingCharge: 1.5, freeWaitingTime: 3 },
    SUV:     { baseFare: 60, baseDistance: 2, perKmRate: 18, perMinuteRate: 2.0, minimumFare: 85, waitingCharge: 2.5, freeWaitingTime: 3 },
    Premium: { baseFare: 80, baseDistance: 3, perKmRate: 22, perMinuteRate: 2.5, minimumFare: 120, waitingCharge: 3.0, freeWaitingTime: 3 },
    Van:     { baseFare: 90, baseDistance: 3, perKmRate: 20, perMinuteRate: 2.0, minimumFare: 125, waitingCharge: 2.5, freeWaitingTime: 3 },
  },
  // Navi Mumbai zones
  naviMumbai: {
    Bike:    { baseFare: 20, baseDistance: 2, perKmRate: 6, perMinuteRate: 0.9, minimumFare: 25, waitingCharge: 1.0, freeWaitingTime: 3 },
    Auto:    { baseFare: 28, baseDistance: 2, perKmRate: 9.5, perMinuteRate: 1.2, minimumFare: 38, waitingCharge: 1.5, freeWaitingTime: 3 },
    Sedan:   { baseFare: 38, baseDistance: 2, perKmRate: 11.5, perMinuteRate: 1.4, minimumFare: 55, waitingCharge: 2.0, freeWaitingTime: 3 },
    SUV:     { baseFare: 65, baseDistance: 2, perKmRate: 19, perMinuteRate: 2.1, minimumFare: 90, waitingCharge: 2.8, freeWaitingTime: 3 },
    Premium: { baseFare: 85, baseDistance: 3, perKmRate: 24, perMinuteRate: 2.6, minimumFare: 125, waitingCharge: 3.2, freeWaitingTime: 3 },
    Van:     { baseFare: 95, baseDistance: 3, perKmRate: 21, perMinuteRate: 2.1, minimumFare: 130, waitingCharge: 2.8, freeWaitingTime: 3 },
  }
};

// Zone name to template mapping
const zoneTemplateMap = {
  // Premium
  'South Mumbai': 'premium',
  'Bandra': 'premium',
  'Powai': 'premium',
  // Standard
  'Andheri': 'standard',
  'Borivali': 'standard',
  'Thane West': 'standard',
  'Thane East': 'standard',
  // Emerging
  'Kalyan': 'emerging',
  'Dombivli': 'emerging',
  'Panvel': 'emerging',
  // Navi Mumbai
  'Vashi': 'naviMumbai',
  'Nerul': 'naviMumbai',
  'Belapur': 'naviMumbai',
  'Kharghar': 'naviMumbai',
};

async function seedFareConfigs() {
  console.log('🚀 Starting Fare Config seeding...\n');

  // Step 1: Get all zones from Firestore
  const zonesSnapshot = await db.collection('zones').get();
  const zones = zonesSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

  if (zones.length === 0) {
    console.log('❌ No zones found in Firestore. Please create zones first.');
    process.exit(1);
  }

  console.log(`📋 Found ${zones.length} zones in Firestore`);

  // Step 2: Check existing fare configs
  const existingConfigs = await db.collection('fareConfigs').get();
  console.log(`📋 Found ${existingConfigs.size} existing fare configs`);

  // Step 3: Create fare configs for each zone + vehicle type
  let created = 0;
  let skipped = 0;
  const batch = db.batch();

  for (const zone of zones) {
    const zoneName = zone.zoneName;
    const templateKey = zoneTemplateMap[zoneName] || 'standard'; // Default to standard
    const template = zoneFareTemplates[templateKey];

    console.log(`\n📍 Processing zone: ${zoneName} (template: ${templateKey})`);

    for (const [vehicleType, rates] of Object.entries(template)) {
      // Check if config already exists for this zone + vehicle type
      const existing = existingConfigs.docs.find(doc => {
        const data = doc.data();
        return data.zoneId === zone.id && data.vehicleType === vehicleType;
      });

      if (existing) {
        console.log(`   ⏭️  ${vehicleType} config already exists, skipping`);
        skipped++;
        continue;
      }

      const fareConfig = {
        zoneId: zone.id,
        zoneName: zoneName,
        vehicleType: vehicleType,
        baseFare: rates.baseFare,
        baseDistance: rates.baseDistance,
        perKmRate: rates.perKmRate,
        perMinuteRate: rates.perMinuteRate,
        minimumFare: rates.minimumFare,
        waitingCharge: rates.waitingCharge,
        freeWaitingTime: rates.freeWaitingTime,
        surgeMultiplier: 1.0,
        isActive: true,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };

      const docRef = db.collection('fareConfigs').doc();
      batch.set(docRef, fareConfig);
      created++;
      console.log(`   ✅ ${vehicleType}: ₹${rates.baseFare} base, ${rates.baseDistance}km, ₹${rates.perKmRate}/km, ₹${rates.perMinuteRate}/min`);
    }
  }

  // Step 4: Commit batch
  if (created > 0) {
    await batch.commit();
    console.log(`\n✅ Batch committed: ${created} fare configs created`);
  }

  console.log(`\n📊 Summary:`);
  console.log(`   Zones processed: ${zones.length}`);
  console.log(`   Fare configs created: ${created}`);
  console.log(`   Fare configs skipped (existing): ${skipped}`);
  console.log(`   Total fare configs: ${existingConfigs.size + created}`);
  console.log('\n🎉 Seeding complete!');
  process.exit(0);
}

seedFareConfigs().catch(err => {
  console.error('❌ Error seeding fare configs:', err);
  process.exit(1);
});
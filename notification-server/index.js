const express = require('express');
const admin = require('firebase-admin');

// Initialize Firebase Admin from env var (Railway sets this securely)
const serviceAccountRaw = process.env.FIREBASE_SERVICE_ACCOUNT;
if (!serviceAccountRaw) {
  console.error('FIREBASE_SERVICE_ACCOUNT env var not set');
  process.exit(1);
}

let serviceAccount;
try {
  serviceAccount = JSON.parse(serviceAccountRaw);
} catch (e) {
  console.error('Invalid FIREBASE_SERVICE_ACCOUNT JSON:', e.message);
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();
const messaging = admin.messaging();

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3000;

function isDriverOnline(data) {
  if (data.isOnline !== undefined) {
    if (typeof data.isOnline === 'boolean') return data.isOnline;
    if (typeof data.isOnline === 'string') return data.isOnline.toLowerCase() === 'true';
    if (typeof data.isOnline === 'number') return data.isOnline === 1;
  }
  const status = (data.driverStatus || data.status || '').toString().toLowerCase();
  return ['online', 'idle', 'active', 'available'].includes(status);
}

function getDriverTokens(driver) {
  const tokens = [];
  if (driver.deviceTokens && Array.isArray(driver.deviceTokens)) {
    for (const t of driver.deviceTokens) {
      if (typeof t === 'string' && t.length > 0) tokens.push(t);
    }
  }
  if (tokens.length === 0 && driver.fcmToken) {
    tokens.push(driver.fcmToken);
  }
  return tokens;
}

function getUserTokens(userData) {
  const tokens = [];
  if (userData?.deviceTokens && Array.isArray(userData.deviceTokens)) {
    for (const t of userData.deviceTokens) {
      if (typeof t === 'string' && t.length > 0) tokens.push(t);
    }
  }
  if (tokens.length === 0 && userData?.fcmToken) {
    tokens.push(userData.fcmToken);
  }
  return tokens;
}

function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = (lat2 - lat1) * (Math.PI / 180);
  const dLon = (lon2 - lon1) * (Math.PI / 180);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * (Math.PI / 180)) *
      Math.cos(lat2 * (Math.PI / 180)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

async function findNearbyDrivers(latitude, longitude, radiusKm, carType) {
  const driversSnapshot = await db.collection('drivers').get();
  const driversSnapshotFallback = await db.collection('Drivers').get();

  const allDocs = [];
  driversSnapshot.forEach(doc => {
    const data = doc.data();
    data.__id = doc.id;
    allDocs.push(data);
  });
  driversSnapshotFallback.forEach(doc => {
    const data = doc.data();
    data.__id = doc.id;
    if (!allDocs.some(d => d.__id === doc.id)) {
      allDocs.push(data);
    }
  });

  const matchingDrivers = [];
  for (const driver of allDocs) {
    if (!isDriverOnline(driver)) continue;

    if (carType) {
      const driverCarType = (driver.carType || '').toString().toLowerCase();
      const requestedType = carType.toLowerCase();
      if (!driverCarType.includes(requestedType) && !requestedType.includes(driverCarType)) {
        continue;
      }
    }

    const driverLocation = driver.location || driver.driverLoc || driver.loc;
    if (driverLocation) {
      // Modified by Jayant Pandit on 2026-07-09 18:00:00
      // Reason: Handle nested geopoint._latitude/_longitude format. Driver nitin_arora_hatchback_1
      // stores location as driverLoc.geopoint._latitude, which the old code (driverLocation.latitude)
      // resolved to undefined → (0,0) → falsy check excluded the only driver with FCM token.
      // Try direct latitude/longitude first
      let lat = driverLocation.latitude;
      let lng = driverLocation.longitude;
      // Fallback: check geopoint sub-object (GeoFlutterFire format with _latitude/_longitude)
      if ((lat == null || lng == null) && driverLocation.geopoint) {
        lat = driverLocation.geopoint._latitude ?? driverLocation.geopoint.latitude;
        lng = driverLocation.geopoint._longitude ?? driverLocation.geopoint.longitude;
      }
      // Fallback: check _latitude/_longitude at top level
      if (lat == null || lng == null) {
        lat = driverLocation._latitude ?? driverLocation.lat;
        lng = driverLocation._longitude ?? driverLocation.lng ?? driverLocation.lon;
      }
      if (lat && lng) {
        const distance = calculateDistance(latitude, longitude, lat, lng);
        if (distance <= radiusKm) {
          matchingDrivers.push({ ...driver, distance });
        }
      }
    }
  }

  matchingDrivers.sort((a, b) => a.distance - b.distance);
  return matchingDrivers;
}

async function pruneInvalidTokens(drivers, invalidTokens) {
  if (invalidTokens.length === 0) return;
  const invalidSet = new Set(invalidTokens);
  for (const driver of drivers) {
    const docRef = db.collection('drivers').doc(driver.__id);
    const currentTokens = getDriverTokens(driver);
    const validTokens = currentTokens.filter(t => !invalidSet.has(t));
    if (validTokens.length !== currentTokens.length) {
      await docRef.update({ deviceTokens: validTokens });
      console.log(`Pruned ${currentTokens.length - validTokens.length} invalid tokens for driver ${driver.__id}`);
    }
  }
}

// Health check
app.get('/', (req, res) => {
  res.json({ status: 'ok', service: 'dcs-notification-server' });
});

// POST /notify-drivers — called after trip is created
app.post('/notify-drivers', async (req, res) => {
  try {
    const { tripId } = req.body;
    if (!tripId) {
      return res.status(400).json({ error: 'tripId required' });
    }

    const tripDoc = await db.collection('trips').doc(tripId).get();
    if (!tripDoc.exists) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    const trip = tripDoc.data();
    if (trip.status !== 'pending') {
      return res.json({ message: 'Trip not pending, skipping' });
    }

    const pickupLat = trip.pickupLat ?? trip.pickupLoc?.latitude ?? 0;
    const pickupLng = trip.pickupLng ?? trip.pickupLoc?.longitude ?? 0;
    if (!pickupLat || !pickupLng) {
      return res.status(400).json({ error: 'No pickup location on trip' });
    }

    const carType = trip.carType || '';
    const nearbyDrivers = await findNearbyDrivers(pickupLat, pickupLng, 5, carType);

    if (nearbyDrivers.length === 0) {
      return res.json({ message: 'No matching drivers found', driversFound: 0 });
    }

    const allTokens = [];
    for (const driver of nearbyDrivers) {
      allTokens.push(...getDriverTokens(driver));
    }

    if (allTokens.length === 0) {
      return res.json({ message: 'No FCM tokens available', driversFound: nearbyDrivers.length });
    }

    const estimatedFare = trip.estimatedFare || trip.fare || 0;

    const message = {
      notification: {
        title: 'New Ride Request!',
        body: `Pickup: ${(trip.pickupAddress || 'Nearby location').substring(0, 50)}... • ₹${estimatedFare.toFixed(0)}`,
      },
      data: {
        tripId: tripId,
        type: 'new_ride_request',
        pickupLat: pickupLat.toString(),
        pickupLng: pickupLng.toString(),
        dropoffLat: (trip.dropoffLat || trip.dropoffLoc?.latitude || '').toString(),
        dropoffLng: (trip.dropoffLng || trip.dropoffLoc?.longitude || '').toString(),
        fare: estimatedFare.toString(),
        distance: (trip.distanceKm || 0).toString(),
        carType: carType,
      },
      android: { priority: 'high' },
      apns: {
        payload: { aps: { sound: 'default', badge: 1 } },
      },
    };

    const response = await messaging.sendEachForMulticast({
      tokens: allTokens,
      ...message,
    });

    console.log(`Sent ${response.successCount}/${allTokens.length} driver notifications for trip ${tripId}`);

    if (response.failureCount > 0) {
      const invalidTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const code = resp.error?.code;
          if (code === 'messaging/invalid-registration-token' ||
              code === 'messaging/registration-token-not-registered') {
            invalidTokens.push(allTokens[idx]);
          }
        }
      });
      await pruneInvalidTokens(nearbyDrivers, invalidTokens);
    }

    res.json({
      success: true,
      notified: response.successCount,
      failed: response.failureCount,
      total: allTokens.length,
    });
  } catch (error) {
    console.error('Error in /notify-drivers:', error);
    res.status(500).json({ error: error.message });
  }
});

// POST /notify-arrival — called when driver arrives
app.post('/notify-arrival', async (req, res) => {
  try {
    const { tripId } = req.body;
    if (!tripId) {
      return res.status(400).json({ error: 'tripId required' });
    }

    const tripDoc = await db.collection('trips').doc(tripId).get();
    if (!tripDoc.exists) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    const trip = tripDoc.data();

    const userDoc = await db.collection('users').doc(trip.userId).get();
    const userData = userDoc.data();
    const tokens = getUserTokens(userData);

    if (tokens.length === 0) {
      return res.json({ message: 'No user FCM tokens' });
    }

    await messaging.sendEachForMulticast({
      tokens,
      notification: {
        title: 'Driver Has Arrived!',
        body: `${trip.driverName || 'Your driver'} is waiting at your pickup location`,
      },
      data: {
        tripId,
        type: 'driver_arrived',
      },
      android: { priority: 'high' },
    });

    console.log(`Arrival notification sent to user for trip ${tripId}`);
    res.json({ success: true, notified: tokens.length });
  } catch (error) {
    console.error('Error in /notify-arrival:', error);
    res.status(500).json({ error: error.message });
  }
});

// POST /notify-driver-accepted — called when driver accepts ride
app.post('/notify-driver-accepted', async (req, res) => {
  try {
    const { tripId } = req.body;
    if (!tripId) {
      return res.status(400).json({ error: 'tripId required' });
    }

    const tripDoc = await db.collection('trips').doc(tripId).get();
    if (!tripDoc.exists) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    const trip = tripDoc.data();

    const userDoc = await db.collection('users').doc(trip.userId).get();
    const userData = userDoc.data();
    const tokens = getUserTokens(userData);

    if (tokens.length === 0) {
      return res.json({ message: 'No user FCM tokens' });
    }

    await messaging.sendEachForMulticast({
      tokens,
      notification: {
        title: 'Driver Found!',
        body: `${trip.driverName || 'Your driver'} is on the way in a ${trip.carName || 'vehicle'}`,
      },
      data: {
        tripId,
        type: 'driver_assigned',
        driverName: trip.driverName || '',
        driverPhone: trip.driverPhone || '',
        carName: trip.carName || '',
        carPlate: trip.carPlateNum || '',
        eta: (trip.estimatedArrivalTime || 5).toString(),
      },
      android: { priority: 'high' },
    });

    console.log(`Assignment notification sent to user for trip ${tripId}`);
    res.json({ success: true, notified: tokens.length });
  } catch (error) {
    console.error('Error in /notify-driver-accepted:', error);
    res.status(500).json({ error: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`DCS Notification Server running on port ${PORT}`);
});

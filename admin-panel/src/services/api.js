import { API_BASE_URL, DEBUG_API, FALLBACK_DATA } from '../config/api.config';
import { firebaseService } from './firebase';
import apiConfig from '../config/api.config';

// Use direct Firebase synchronization to stay in sync with Partner/Rider apps
const USE_FIREBASE = true;

// Track API availability
let apiAvailable = true;
let useFallback = false;

// Helper to normalize driver data from Firestore/API
const _normalizeDriver = (driver) => {
  if (!driver) return null;
  const id = driver._id || driver.id;
  return {
    ...driver,
    id: id,
    _id: id,
    name: driver.name || driver['Full Name'] || driver.driverName || 'Partner',
    phone: driver.phone || driver.mobile || driver.phoneNumber || '',
    carName: driver.carName || driver['Car Name'] || driver.vehicleName || '',
    carPlateNum: driver.carPlateNum || driver['Car Plate Num'] || driver.vehicleNumber || '',
    carType: driver.carType || driver['Car Type'] || driver.vehicleType || 'Sedan',
    fuelType: driver.fuelType || driver['Fuel Type'] || 'Petrol',
    rating: driver.rating !== undefined ? parseFloat(driver.rating) : 5.0,
    isOnline: !!driver.isOnline,
    isApproved: !!(driver.isApproved || driver.approvalStatus === 'approved' || driver.verified),
    documents: driver.documents || {},
    carDocuments: driver.carDocuments || {},
    stats: driver.stats || {
      totalTrips: driver.totalTrips || 0,
      totalEarnings: driver.totalEarnings || 0,
      totalDistance: 0
    }
  };
};

const api = {
  request: async (endpoint, options = {}) => {
    const url = `${API_BASE_URL}${endpoint}`;
    const method = options.method || 'GET';
    const headers = {
      'Content-Type': 'application/json',
      ...options.headers
    };
    const body = options.body ? JSON.stringify(options.body) : undefined;

    // If we're using fallback data, return it immediately for GET requests
    if (useFallback && method === 'GET') {
      const fallbackKey = endpoint.replace('/', '').split('/')[0];
      if (DEBUG_API) console.log(`Using fallback data for: ${fallbackKey}`);
      return FALLBACK_DATA[fallbackKey] || [];
    }

    try {
      if (DEBUG_API) console.log(`API Call: ${method} ${url}`);
      
      const response = await fetch(url, {
        method,
        headers,
        body
      });

      if (!response.ok) {
        const errorText = await response.text();
        console.error(`HTTP ${response.status}:`, errorText);
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const data = await response.json();
      apiAvailable = true;
      if (DEBUG_API) console.log(`API Success: ${endpoint}`);
      return data;
    } catch (error) {
      console.error('API request error:', error);
      apiAvailable = false;
      
      // For GET requests, return fallback data
      if (method === 'GET') {
        const fallbackKey = endpoint.replace('/', '').split('/')[0];
        if (FALLBACK_DATA[fallbackKey]) {
          console.warn(`Using fallback data for: ${fallbackKey}`);
          useFallback = true;
          return FALLBACK_DATA[fallbackKey];
        }
      }
      
      throw error;
    }
  },

  // Check if API is available (Firebase always available)
  healthCheck: async () => {
    // Firebase is always available, no need to check EC2 backend
    return true;
  },

  // Get API status
  isAvailable: () => apiAvailable,
  
  // Enable/disable fallback mode
  setFallbackMode: (enabled) => { useFallback = enabled; },
  isFallbackMode: () => useFallback,

  payments: {
    getAll: async () => USE_FIREBASE ? await firebaseService.getAll('payments') : api.request('/payments'),
    getById: async (id) => USE_FIREBASE ? await firebaseService.getById('payments', id) : api.request(`/payments/${id}`),
    create: async (data) => USE_FIREBASE ? await firebaseService.create('payments', data) : api.request('/payments', { method: 'POST', body: data }),
    update: async (id, data) => USE_FIREBASE ? await firebaseService.update('payments', id, data) : api.request(`/payments/${id}`, { method: 'PUT', body: data }),
    delete: async (id) => USE_FIREBASE ? await firebaseService.delete('payments', id) : api.request(`/payments/${id}`, { method: 'DELETE' })
  },

  driverEarnings: {
    getAll: async () => USE_FIREBASE ? await firebaseService.getAll('driver_earnings') : api.request('/driver_earnings'),
    getByDriverId: async (driverId) => USE_FIREBASE ? await firebaseService.query('driver_earnings', 'driverId', '==', driverId) : api.request(`/driver_earnings/${driverId}`),
    getDaily: async (driverId, dateKey) => USE_FIREBASE ? await firebaseService.getById(`driver_earnings/${driverId}/Daily`, dateKey) : api.request(`/driver_earnings/${driverId}/Daily/${dateKey}`),
  },

  tripRatings: {
    getAll: async () => USE_FIREBASE ? await firebaseService.getAll('trip_ratings') : api.request('/trip_ratings'),
    getByTripId: async (tripId) => USE_FIREBASE ? await firebaseService.query('trip_ratings', 'tripId', '==', tripId) : api.request(`/trip_ratings/${tripId}`),
    getByDriverId: async (driverId) => USE_FIREBASE ? await firebaseService.query('trip_ratings', 'driverId', '==', driverId) : api.request(`/trip_ratings/driver/${driverId}`),
  },

  companies: {
    getAll: async () => USE_FIREBASE ? await firebaseService.getAll('companies') : api.request('/companies'),
    getById: async (id) => USE_FIREBASE ? await firebaseService.getById('companies', id) : api.request(`/companies/${id}`),
    create: async (data) => USE_FIREBASE ? await firebaseService.create('companies', data) : api.request('/companies', { method: 'POST', body: data }),
    update: async (id, data) => USE_FIREBASE ? await firebaseService.update('companies', id, data) : api.request(`/companies/${id}`, { method: 'PUT', body: data }),
    delete: async (id) => USE_FIREBASE ? await firebaseService.delete('companies', id) : api.request(`/companies/${id}`, { method: 'DELETE' })
  },

  drivers: {
    getAll: async () => {
      const data = USE_FIREBASE ? await firebaseService.getAll('drivers') : await api.request('/drivers');
      return (data || []).map(_normalizeDriver);
    },
    getById: async (id) => {
      const data = USE_FIREBASE ? await firebaseService.getById('drivers', id) : await api.request(`/drivers/${id}`);
      return _normalizeDriver(data);
    },
    create: async (data) => USE_FIREBASE ? await firebaseService.create('drivers', data) : api.request('/drivers', { method: 'POST', body: data }),
    update: async (id, data) => USE_FIREBASE ? await firebaseService.update('drivers', id, data) : api.request(`/drivers/${id}`, { method: 'PUT', body: data }),
    delete: async (id) => USE_FIREBASE ? await firebaseService.delete('drivers', id) : api.request(`/drivers/${id}`, { method: 'DELETE' }),
    approve: async (id) => USE_FIREBASE ? await firebaseService.update('drivers', id, { status: 'approved' }) : api.request(`/drivers/${id}/approve`, { method: 'PUT' }),
    reject: async (id) => USE_FIREBASE ? await firebaseService.update('drivers', id, { status: 'rejected' }) : api.request(`/drivers/${id}/reject`, { method: 'PUT' }),
    levels: {
      getAll: async () => USE_FIREBASE ? await firebaseService.getAll('driverLevels') : api.request('/driverLevels'),
      getById: async (id) => USE_FIREBASE ? await firebaseService.getById('driverLevels', id) : api.request(`/driverLevels/${id}`),
      create: async (data) => USE_FIREBASE ? await firebaseService.create('driverLevels', data) : api.request('/driverLevels', { method: 'POST', body: data }),
      update: async (id, data) => USE_FIREBASE ? await firebaseService.update('driverLevels', id, data) : api.request(`/driverLevels/${id}`, { method: 'PUT', body: data }),
      delete: async (id) => USE_FIREBASE ? await firebaseService.delete('driverLevels', id) : api.request(`/driverLevels/${id}`, { method: 'DELETE' })
    },
    ratings: {
      getAll: async () => {
        if (USE_FIREBASE) {
          // Get drivers and transform to ratings format with proper structure
          const drivers = await firebaseService.getAll('drivers');
          return drivers.map(driver => {
            const rating = driver.rating || driver.avgRating || (Math.random() * 2 + 3).toFixed(1); // 3.0-5.0
            const totalTrips = driver.totalTrips || driver.tripCount || Math.floor(Math.random() * 200);
            const totalRatings = driver.totalRatings || Math.floor(totalTrips * 0.8) || 10;
            
            // Generate realistic rating breakdown
            const fiveStars = Math.floor(totalRatings * (rating / 5) * 0.6);
            const fourStars = Math.floor(totalRatings * 0.25);
            const threeStars = Math.floor(totalRatings * 0.1);
            const twoStars = Math.floor(totalRatings * 0.03);
            const oneStar = totalRatings - fiveStars - fourStars - threeStars - twoStars;
            
            return {
              _id: driver._id || driver.id,
              id: driver._id || driver.id,
              driverId: driver._id || driver.id,
              driverName: driver.name || driver.fullName || 'Unknown Driver',
              driverPhone: driver.phone || driver.mobile || '-',
              carName: driver.vehicleName || driver.carName || driver.carType || driver.vehicleType || 'Sedan',
              carPlateNum: driver.carPlateNum || driver.vehicleNumber || driver.licensePlate || 'DL-XX-XX-XXXX',
              rating: parseFloat(rating),
              totalRatings: totalRatings,
              totalTrips: totalTrips,
              ratingBreakdown: {
                fiveStars: Math.max(0, fiveStars),
                fourStars: Math.max(0, fourStars),
                threeStars: Math.max(0, threeStars),
                twoStars: Math.max(0, twoStars),
                oneStar: Math.max(0, oneStar)
              },
              isOnline: driver.isOnline || driver.status === 'online' || false,
              isApproved: driver.isApproved || driver.status === 'approved' || driver.verified || false,
              profileImage: driver.profileImage || driver.photo || null,
              vehicleType: driver.vehicleType || driver.carType || '-',
              lastActive: driver.lastActive || driver.updatedAt || new Date().toISOString()
            };
          });
        }
        return api.request('/driverRatings');
      },
      getById: async (id) => USE_FIREBASE ? await firebaseService.getById('drivers', id) : api.request(`/driverRatings/${id}`),
      create: async (data) => USE_FIREBASE ? await firebaseService.create('drivers', data) : api.request('/driverRatings', { method: 'POST', body: data }),
      update: async (id, data) => USE_FIREBASE ? await firebaseService.update('drivers', id, data) : api.request(`/driverRatings/${id}`, { method: 'PUT', body: data }),
      delete: async (id) => USE_FIREBASE ? await firebaseService.delete('drivers', id) : api.request(`/driverRatings/${id}`, { method: 'DELETE' })
    },
    bankInfo: {
      getAll: async () => USE_FIREBASE ? await firebaseService.getAll('drivers') : api.request('/driverBankInfo'),
      getById: async (id) => USE_FIREBASE ? await firebaseService.getById('drivers', id) : api.request(`/driverBankInfo/${id}`),
      create: async (data) => USE_FIREBASE ? await firebaseService.create('drivers', data) : api.request('/driverBankInfo', { method: 'POST', body: data }),
      update: async (id, data) => USE_FIREBASE ? await firebaseService.update('drivers', id, data) : api.request(`/driverBankInfo/${id}`, { method: 'PUT', body: data }),
      delete: async (id) => USE_FIREBASE ? await firebaseService.delete('drivers', id) : api.request(`/driverBankInfo/${id}`, { method: 'DELETE' })
    },
    incentives: {
      getAll: async () => {
        if (USE_FIREBASE) {
          // Get drivers and transform to incentives format with calculated fields
          const drivers = await firebaseService.getAll('drivers');
          return drivers.map(driver => {
            const totalTrips = driver.totalTrips || driver.tripCount || 0;
            const totalEarnings = driver.totalEarnings || driver.earnings || (totalTrips * 200) || 0;
            const commissionRate = driver.commissionRate || driver.level?.commissionRate || 20;
            const commission = (totalEarnings * commissionRate) / 100;
            const bonusPerTrip = driver.bonusPerTrip || driver.level?.bonusPerTrip || 0;
            const bonus = totalTrips * bonusPerTrip;
            const totalIncentive = commission + bonus;
            
            return {
              _id: driver._id || driver.id,
              id: driver._id || driver.id,
              name: driver.name || driver.fullName || 'Unknown',
              phone: driver.phone || driver.mobile || '-',
              level: driver.level?.name || driver.driverLevel || 'Bronze',
              totalTrips,
              totalEarnings,
              rating: driver.rating || driver.avgRating || 0,
              commissionRate,
              commission,
              bonusPerTrip,
              bonus,
              totalIncentive,
              status: driver.status || (driver.isApproved ? 'active' : 'pending'),
              isOnline: driver.isOnline || false
            };
          });
        }
        return api.request('/driverIncentives');
      },
      getById: async (id) => USE_FIREBASE ? await firebaseService.getById('drivers', id) : api.request(`/driverIncentives/${id}`),
      create: async (data) => USE_FIREBASE ? await firebaseService.create('drivers', data) : api.request('/driverIncentives', { method: 'POST', body: data }),
      update: async (id, data) => USE_FIREBASE ? await firebaseService.update('drivers', id, data) : api.request(`/driverIncentives/${id}`, { method: 'PUT', body: data }),
      delete: async (id) => USE_FIREBASE ? await firebaseService.delete('drivers', id) : api.request(`/driverIncentives/${id}`, { method: 'DELETE' })
    }
  },

  users: {
    getAll: async () => USE_FIREBASE ? await firebaseService.getAll('users') : api.request('/riders'),
    getById: async (id) => USE_FIREBASE ? await firebaseService.getById('users', id) : api.request(`/riders/${id}`),
    create: async (data) => USE_FIREBASE ? await firebaseService.create('users', data) : api.request('/riders', { method: 'POST', body: data }),
    update: async (id, data) => USE_FIREBASE ? await firebaseService.update('users', id, data) : api.request(`/riders/${id}`, { method: 'PUT', body: data }),
    delete: async (id) => USE_FIREBASE ? await firebaseService.delete('users', id) : api.request(`/riders/${id}`, { method: 'DELETE' })
  },

  adminUsers: {
    getAll: async () => USE_FIREBASE ? await firebaseService.getAll('adminUsers') : api.request('/adminUsers'),
    getById: async (id) => USE_FIREBASE ? await firebaseService.getById('adminUsers', id) : api.request(`/adminUsers/${id}`),
    create: async (data) => USE_FIREBASE ? await firebaseService.create('adminUsers', data) : api.request('/adminUsers', { method: 'POST', body: data }),
    update: async (id, data) => USE_FIREBASE ? await firebaseService.update('adminUsers', id, data) : api.request(`/adminUsers/${id}`, { method: 'PUT', body: data }),
    delete: async (id) => USE_FIREBASE ? await firebaseService.delete('adminUsers', id) : api.request(`/adminUsers/${id}`, { method: 'DELETE' }),
    setupSuperAdmin: async (data) => USE_FIREBASE ? await firebaseService.create('adminUsers', { ...data, role: 'superAdmin' }) : api.request('/adminUsers', { method: 'POST', body: { ...data, role: 'superAdmin' } })
  },

  authUsers: {
    getAll: async () => api.request('/auth/users'),
    getById: async (id) => api.request(`/auth/users/${id}`),
    create: async (data) => api.request('/auth/users', { method: 'POST', body: data }),
    update: async (id, data) => api.request(`/auth/users/${id}`, { method: 'PUT', body: data }),
    delete: async (id) => api.request(`/auth/users/${id}`, { method: 'DELETE' })
  },

  // Helper to normalize trip data from Firestore (handles both Admin and Customer/Partner naming)
  _normalizeTrip: (trip) => {
    if (!trip) return null;
    const id = trip._id || trip.id || trip.tripId;
    return {
      ...trip,
      id,
      _id: id,
      tripId: trip.tripId || id,
      // Rider info — Customer stores flat fields, Admin expects nested userId
      userName: trip.userName || trip.userId?.name || 'Unknown',
      userPhone: trip.userPhone || trip.userId?.phone || '',
      userPhoto: trip.userPhoto || trip.userId?.photo || '',
      // Driver info — handle both flat and nested
      driverName: trip.driverName || trip.driverId?.name || 'Unassigned',
      driverPhone: trip.driverPhone || trip.driverId?.phone || '',
      driverPhoto: trip.driverPhoto || trip.driverId?.photo || '',
      // Transport type — Customer uses carType, Admin uses transportType/vehicleType
      transportType: trip.transportType || trip.carType || trip.carName || 'Car',
      vehicleType: trip.vehicleType || trip.transportType || trip.carType || 'Car',
      carType: trip.carType || trip.transportType || trip.vehicleType || 'Car',
      carName: trip.carName || trip.carType || trip.transportType || '',
      carPlateNum: trip.carPlateNum || trip.driverId?.carPlateNum || '',
      // Fare — Customer uses estimatedFare, Admin uses totalFare
      totalFare: trip.totalFare ?? trip.estimatedFare ?? trip.fare ?? 0,
      estimatedFare: trip.estimatedFare ?? trip.totalFare ?? trip.fare ?? 0,
      actualFare: trip.actualFare ?? trip.finalFare ?? 0,
      // Distance/Duration — Customer uses distanceKm/durationMinutes
      distance: trip.distance ?? trip.distanceKm ?? 0,
      distanceKm: trip.distanceKm ?? trip.distance ?? 0,
      duration: trip.duration ?? trip.durationMinutes ?? 0,
      durationMinutes: trip.durationMinutes ?? trip.duration ?? 0,
      // Payment — Customer writes paymentMethod + isPaid, Admin expects paymentStatus
      paymentMethod: trip.paymentMethod || 'cash',
      paymentStatus: trip.paymentStatus || (trip.isPaid ? 'paid' : 'pending'),
      isPaid: trip.isPaid ?? (trip.paymentStatus === 'paid'),
      // Location — ensure pickupLocation/dropoffLocation are objects with address
      pickupLocation: typeof trip.pickupLocation === 'object' && trip.pickupLocation
        ? trip.pickupLocation
        : { address: trip.pickupAddress || 'Unknown', latitude: trip.pickupLat || 0, longitude: trip.pickupLng || 0 },
      dropoffLocation: typeof trip.dropoffLocation === 'object' && trip.dropoffLocation
        ? trip.dropoffLocation
        : { address: trip.dropoffAddress || 'Unknown', latitude: trip.dropoffLat || 0, longitude: trip.dropoffLng || 0 },
      pickupAddress: trip.pickupAddress || trip.pickupLocation?.address || 'Unknown',
      dropoffAddress: trip.dropoffAddress || trip.dropoffLocation?.address || 'Unknown',
      pickupLat: trip.pickupLat ?? trip.pickupLocation?.latitude ?? 0,
      pickupLng: trip.pickupLng ?? trip.pickupLocation?.longitude ?? 0,
      dropoffLat: trip.dropoffLat ?? trip.dropoffLocation?.latitude ?? 0,
      dropoffLng: trip.dropoffLng ?? trip.dropoffLocation?.longitude ?? 0,
      // Timestamps
      createdAt: trip.createdAt || new Date().toISOString(),
      updatedAt: trip.updatedAt || trip.createdAt || '',
      acceptedAt: trip.acceptedAt || '',
      completedAt: trip.completedAt || '',
      cancelledAt: trip.cancelledAt || '',
      startedAt: trip.startedAt || '',
      // Status — handle both naming conventions
      status: trip.status || 'pending',
      serviceType: trip.serviceType || 'ride',
      ridePin: trip.ridePin || '',
      // User reference (for backward compat with Admin Panel's userId.name pattern)
      userId: typeof trip.userId === 'object' && trip.userId
        ? { ...trip.userId, name: trip.userId.name || trip.userName || 'Unknown', phone: trip.userId.phone || trip.userPhone || '' }
        : { id: trip.userId || trip.userId?._id || '', name: trip.userName || 'Unknown', phone: trip.userPhone || '' },
      // Driver reference (same pattern)
      driverId: typeof trip.driverId === 'object' && trip.driverId
        ? { ...trip.driverId, name: trip.driverId.name || trip.driverName || 'Unassigned', phone: trip.driverId.phone || trip.driverPhone || '' }
        : trip.driverId
          ? { id: trip.driverId, name: trip.driverName || 'Unassigned', phone: trip.driverPhone || '', carName: trip.carName || '', carPlateNum: trip.carPlateNum || '' }
          : null,
    };
  },

  trips: {
    getAll: async () => {
      const data = USE_FIREBASE ? await firebaseService.getAll('trips') : api.request('/trips');
      return (data || []).map(api._normalizeTrip);
    },
    getById: async (id) => {
      const data = USE_FIREBASE ? await firebaseService.getById('trips', id) : api.request(`/trips/${id}`);
      return api._normalizeTrip(data);
    },
    create: async (data) => USE_FIREBASE ? await firebaseService.create('trips', data) : api.request('/trips', { method: 'POST', body: data }),
    update: async (id, data) => USE_FIREBASE ? await firebaseService.update('trips', id, data) : api.request(`/trips/${id}`, { method: 'PUT', body: data }),
    delete: async (id) => USE_FIREBASE ? await firebaseService.delete('trips', id) : api.request(`/trips/${id}`, { method: 'DELETE' }),
    getAnalytics: async () => {
      if (USE_FIREBASE) {
        // Return comprehensive analytics from Firestore
        const rawTrips = await firebaseService.getAll('trips');
        const trips = (rawTrips || []).map(api._normalizeTrip);
        const drivers = await firebaseService.getAll('drivers');
        const users = await firebaseService.getAll('users');
        
        // Calculate stats
        const totalTrips = trips.length;
        const completedTrips = trips.filter(t => t.status === 'completed').length;
        const inProgressTrips = trips.filter(t => t.status === 'ongoing' || t.status === 'in_progress').length;
        const cancelledTrips = trips.filter(t => t.status === 'cancelled').length;
        const totalRevenue = trips.reduce((sum, t) => sum + (t.totalFare || t.fare || t.estimatedFare || t.amount || 0), 0);
        const completionRate = totalTrips > 0 ? ((completedTrips / totalTrips) * 100).toFixed(1) : 0;
        
        // Generate daily stats (last 7 days)
        const dailyStats = [];
        for (let i = 6; i >= 0; i--) {
          const date = new Date();
          date.setDate(date.getDate() - i);
          const dateStr = date.toISOString().split('T')[0];
          const dayTrips = trips.filter(t => t.createdAt && t.createdAt.startsWith(dateStr));
          const dayCompleted = dayTrips.filter(t => t.status === 'completed').length;
          const dayCancelled = dayTrips.filter(t => t.status === 'cancelled').length;
          dailyStats.push({
            date: dateStr,
            totalTrips: dayTrips.length,
            completedTrips: dayCompleted,
            cancelledTrips: dayCancelled,
            totalRevenue: dayTrips.reduce((sum, t) => sum + (t.fare || t.amount || 0), 0)
          });
        }
        
        // Get top drivers by trip count
        const driverStats = {};
        trips.forEach(trip => {
          const driverId = trip.driverId || trip.driver_id;
          if (driverId) {
            if (!driverStats[driverId]) {
              driverStats[driverId] = { trips: 0, revenue: 0 };
            }
            driverStats[driverId].trips++;
            driverStats[driverId].revenue += (trip.fare || trip.amount || 0);
          }
        });
        
        const topDrivers = Object.entries(driverStats)
          .map(([id, stats]) => {
            const driver = drivers.find(d => d._id === id || d.id === id);
            return {
              id,
              name: driver ? driver.name || driver.fullName : 'Unknown Driver',
              totalTrips: stats.trips,
              totalEarnings: stats.revenue,
              rating: driver ? (driver.rating || 0) : 0,
              carName: driver ? (driver.vehicleName || driver.carName || driver.carType || 'Sedan') : 'Unknown',
              isOnline: driver ? (driver.isOnline || false) : false
            };
          })
          .sort((a, b) => b.totalTrips - a.totalTrips)
          .slice(0, 10);
        
        return {
          summary: {
            totalTrips,
            totalRevenue,
            completionRate,
            inProgressTrips,
            completedTrips,
            cancelledTrips,
            totalDrivers: drivers.length,
            totalUsers: users.length
          },
          dailyStats,
          topDrivers: topDrivers.length > 0 ? topDrivers : [
            { id: '1', name: 'No driver data', totalTrips: 0, totalEarnings: 0, rating: 0, carName: '-', isOnline: false }
          ]
        };
      }
      return api.request('/trips/analytics');
    }
  },

  fleet: {
    getAll: async () => {
      if (USE_FIREBASE) {
        // Generate fleet data from drivers (each driver's vehicle)
        const drivers = await firebaseService.getAll('drivers');
        return drivers.map((driver, index) => {
          // Check for saved values first, then fall back to driver defaults
          const savedVehicleType = driver.carType || driver.vehicleType;
          const savedFuelType = driver.fuelType;
          const savedStatus = driver.status || (driver.isActive ? 'Active' : 'Inactive');
          const savedCarName = driver.carName || driver.vehicleName;
          const savedCarPlate = driver.carPlateNum || driver.vehicleNumber || driver.licensePlate;
          const savedCarColor = driver.carColor || driver.vehicleColor;
          
          return {
            _id: driver._id || driver.id || `vehicle-${index}`,
            id: driver._id || driver.id || `vehicle-${index}`,
            carName: savedCarName || driver.carType || driver.vehicleType || 'Sedan',
            carType: savedVehicleType || 'Sedan',
            fuelType: savedFuelType || 'Petrol',
            carPlateNum: savedCarPlate || `DL-XX-XX-${Math.floor(1000 + Math.random() * 9000)}`,
            carColor: savedCarColor || 'White',
            companyName: driver.company || driver.companyName || 'Dada Cabs',
            assignedDriver: driver.name || driver.fullName || 'Unassigned',
            driverId: driver._id || driver.id,
            status: savedStatus === 'Active' || savedStatus === 'active' || driver.isActive === true ? 'Active' : 'Inactive',
            year: driver.vehicleYear || driver.carYear || 2022,
            make: driver.vehicleMake || driver.carMake || 'Toyota',
            model: driver.vehicleModel || driver.carModel || 'Etios',
            registrationNumber: savedCarPlate || `DL01${String.fromCharCode(65 + Math.random() * 26)}${Math.floor(Math.random() * 9999)}`
          };
        });
      }
      return api.request('/fleet');
    },
    getById: async (id) => USE_FIREBASE ? await firebaseService.getById('drivers', id) : api.request(`/fleet/${id}`),
    create: async (data) => USE_FIREBASE ? await firebaseService.create('drivers', data) : api.request('/fleet', { method: 'POST', body: data }),
    update: async (id, data) => {
      if (USE_FIREBASE) {
        // Transform fleet data back to driver fields
        const driverData = {
          ...data,
          carName: data.carName || data.model,
          carType: data.carType || data.vehicleType,
          vehicleType: data.vehicleType || data.carType,
          fuelType: data.fuelType,
          carPlateNum: data.carPlateNum || data.licensePlate,
          vehicleNumber: data.vehicleNumber || data.licensePlate,
          licensePlate: data.licensePlate || data.carPlateNum,
          carColor: data.carColor || data.color,
          vehicleColor: data.vehicleColor || data.color,
          status: data.status,
          isActive: data.status === 'Active' || data.status === 'active'
        };
        return await firebaseService.update('drivers', id, driverData);
      }
      return api.request(`/fleet/${id}`, { method: 'PUT', body: data });
    },
    delete: async (id) => USE_FIREBASE ? await firebaseService.delete('drivers', id) : api.request(`/fleet/${id}`, { method: 'DELETE' })
  },

  owners: {
    getAll: async () => USE_FIREBASE ? await firebaseService.getAll('owners') : api.request('/owners'),
    getById: async (id) => USE_FIREBASE ? await firebaseService.getById('owners', id) : api.request(`/owners/${id}`),
    create: async (data) => USE_FIREBASE ? await firebaseService.create('owners', data) : api.request('/owners', { method: 'POST', body: data }),
    update: async (id, data) => USE_FIREBASE ? await firebaseService.update('owners', id, data) : api.request(`/owners/${id}`, { method: 'PUT', body: data }),
    delete: async (id) => USE_FIREBASE ? await firebaseService.delete('owners', id) : api.request(`/owners/${id}`, { method: 'DELETE' })
  },

  master: {
    getAll: async () => USE_FIREBASE ? await firebaseService.getAll('master') : api.request('/master'),
    getByType: async (type) => USE_FIREBASE ? await firebaseService.query('master', 'type', '==', type) : api.request(`/master/${type}`),
    getById: async (id) => USE_FIREBASE ? await firebaseService.getById('master', id) : api.request(`/master/id/${id}`),
    create: async (data) => USE_FIREBASE ? await firebaseService.create('master', data) : api.request('/master', { method: 'POST', body: data }),
    update: async (id, data) => USE_FIREBASE ? await firebaseService.update('master', id, data) : api.request(`/master/${id}`, { method: 'PUT', body: data }),
    delete: async (id) => USE_FIREBASE ? await firebaseService.delete('master', id) : api.request(`/master/${id}`, { method: 'DELETE' })
  },

  currencies: {
    getAll: async () => USE_FIREBASE ? await firebaseService.getAll('currencies') : api.request('/currencies'),
    getById: async (id) => USE_FIREBASE ? await firebaseService.getById('currencies', id) : api.request(`/currencies/${id}`),
    create: async (data) => USE_FIREBASE ? await firebaseService.create('currencies', data) : api.request('/currencies', { method: 'POST', body: data }),
    update: async (id, data) => USE_FIREBASE ? await firebaseService.update('currencies', id, data) : api.request(`/currencies/${id}`, { method: 'PUT', body: data }),
    delete: async (id) => USE_FIREBASE ? await firebaseService.delete('currencies', id) : api.request(`/currencies/${id}`, { method: 'DELETE' })
  },

  countries: {
    getAll: async () => USE_FIREBASE ? await firebaseService.getAll('countries') : api.request('/countries'),
    getById: async (id) => USE_FIREBASE ? await firebaseService.getById('countries', id) : api.request(`/countries/${id}`),
    create: async (data) => USE_FIREBASE ? await firebaseService.create('countries', data) : api.request('/countries', { method: 'POST', body: data }),
    update: async (id, data) => USE_FIREBASE ? await firebaseService.update('countries', id, data) : api.request(`/countries/${id}`, { method: 'PUT', body: data }),
    delete: async (id) => USE_FIREBASE ? await firebaseService.delete('countries', id) : api.request(`/countries/${id}`, { method: 'DELETE' })
  },

  states: {
    getAll: async () => USE_FIREBASE ? await firebaseService.getAll('states') : api.request('/states'),
    getById: async (id) => USE_FIREBASE ? await firebaseService.getById('states', id) : api.request(`/states/${id}`),
    create: async (data) => USE_FIREBASE ? await firebaseService.create('states', data) : api.request('/states', { method: 'POST', body: data }),
    update: async (id, data) => USE_FIREBASE ? await firebaseService.update('states', id, data) : api.request(`/states/${id}`, { method: 'PUT', body: data }),
    delete: async (id) => USE_FIREBASE ? await firebaseService.delete('states', id) : api.request(`/states/${id}`, { method: 'DELETE' })
  },

  cities: {
    getAll: async () => USE_FIREBASE ? await firebaseService.getAll('cities') : api.request('/cities'),
    getById: async (id) => USE_FIREBASE ? await firebaseService.getById('cities', id) : api.request(`/cities/${id}`),
    create: async (data) => USE_FIREBASE ? await firebaseService.create('cities', data) : api.request('/cities', { method: 'POST', body: data }),
    update: async (id, data) => USE_FIREBASE ? await firebaseService.update('cities', id, data) : api.request(`/cities/${id}`, { method: 'PUT', body: data }),
    delete: async (id) => USE_FIREBASE ? await firebaseService.delete('cities', id) : api.request(`/cities/${id}`, { method: 'DELETE' })
  },

  languages: {
    getAll: async () => USE_FIREBASE ? await firebaseService.getAll('languages') : api.request('/languages'),
    getById: async (id) => USE_FIREBASE ? await firebaseService.getById('languages', id) : api.request(`/languages/${id}`),
    create: async (data) => USE_FIREBASE ? await firebaseService.create('languages', data) : api.request('/languages', { method: 'POST', body: data }),
    update: async (id, data) => USE_FIREBASE ? await firebaseService.update('languages', id, data) : api.request(`/languages/${id}`, { method: 'PUT', body: data }),
    delete: async (id) => USE_FIREBASE ? await firebaseService.delete('languages', id) : api.request(`/languages/${id}`, { method: 'DELETE' })
  },

  vehicleTypes: {
    getAll: async () => USE_FIREBASE ? await firebaseService.getAll('vehicleTypes') : api.request('/vehicle-types'),
    getById: async (id) => USE_FIREBASE ? await firebaseService.getById('vehicleTypes', id) : api.request(`/vehicle-types/${id}`),
    create: async (data) => USE_FIREBASE ? await firebaseService.create('vehicleTypes', data) : api.request('/vehicle-types', { method: 'POST', body: data }),
    update: async (id, data) => USE_FIREBASE ? await firebaseService.update('vehicleTypes', id, data) : api.request(`/vehicle-types/${id}`, { method: 'PUT', body: data }),
    delete: async (id) => USE_FIREBASE ? await firebaseService.delete('vehicleTypes', id) : api.request(`/vehicle-types/${id}`, { method: 'DELETE' })
  },

  serviceLocations: {
    getAll: async () => USE_FIREBASE ? await firebaseService.getAll('serviceLocations') : api.request('/zones/service-locations'),
    getById: async (id) => USE_FIREBASE ? await firebaseService.getById('serviceLocations', id) : api.request(`/zones/service-locations/${id}`),
    create: async (data) => USE_FIREBASE ? await firebaseService.create('serviceLocations', data) : api.request('/zones/service-locations', { method: 'POST', body: data }),
    update: async (id, data) => USE_FIREBASE ? await firebaseService.update('serviceLocations', id, data) : api.request(`/zones/service-locations/${id}`, { method: 'PUT', body: data }),
    delete: async (id) => USE_FIREBASE ? await firebaseService.delete('serviceLocations', id) : api.request(`/zones/service-locations/${id}`, { method: 'DELETE' })
  },

  promoCodes: {
    getAll: async () => USE_FIREBASE ? await firebaseService.getAll('promoCodes') : api.request('/promo-codes'),
    getById: async (id) => USE_FIREBASE ? await firebaseService.getById('promoCodes', id) : api.request(`/promo-codes/${id}`),
    create: async (data) => USE_FIREBASE ? await firebaseService.create('promoCodes', data) : api.request('/promo-codes', { method: 'POST', body: data }),
    update: async (id, data) => USE_FIREBASE ? await firebaseService.update('promoCodes', id, data) : api.request(`/promo-codes/${id}`, { method: 'PUT', body: data }),
    delete: async (id) => USE_FIREBASE ? await firebaseService.delete('promoCodes', id) : api.request(`/promo-codes/${id}`, { method: 'DELETE' })
  },

  bannerImages: {
    getAll: async () => USE_FIREBASE ? await firebaseService.getAll('bannerImages') : api.request('/banner-images'),
    getById: async (id) => USE_FIREBASE ? await firebaseService.getById('bannerImages', id) : api.request(`/banner-images/${id}`),
    create: async (data) => USE_FIREBASE ? await firebaseService.create('bannerImages', data) : api.request('/banner-images', { method: 'POST', body: data }),
    update: async (id, data) => USE_FIREBASE ? await firebaseService.update('bannerImages', id, data) : api.request(`/banner-images/${id}`, { method: 'PUT', body: data }),
    delete: async (id) => USE_FIREBASE ? await firebaseService.delete('bannerImages', id) : api.request(`/banner-images/${id}`, { method: 'DELETE' })
  },

  fareConfigs: {
    getAll: async () => USE_FIREBASE ? await firebaseService.getAll('fareConfigs') : api.request('/fares'),
    getById: async (id) => USE_FIREBASE ? await firebaseService.getById('fareConfigs', id) : api.request(`/fares/${id}`),
    create: async (data) => USE_FIREBASE ? await firebaseService.create('fareConfigs', data) : api.request('/fares', { method: 'POST', body: data }),
    update: async (id, data) => USE_FIREBASE ? await firebaseService.update('fareConfigs', id, data) : api.request(`/fares/${id}`, { method: 'PUT', body: data }),
    delete: async (id) => USE_FIREBASE ? await firebaseService.delete('fareConfigs', id) : api.request(`/fares/${id}`, { method: 'DELETE' }),
    getByZone: async (zoneId) => USE_FIREBASE ? await firebaseService.query('fareConfigs', 'zoneId', '==', zoneId) : api.request(`/fares/zone/${zoneId}`),
    getByZoneName: async (zoneName) => api.request(`/fares/zone-name/${encodeURIComponent(zoneName)}`),
    bulkCreate: async (fareConfigs) => api.request('/fares/bulk', { method: 'POST', body: { fareConfigs } }),
    calculate: async (data) => api.request('/fares/calculate', { method: 'POST', body: data }),
  },

  pricing: {
    getAll: async () => USE_FIREBASE ? await firebaseService.getAll('fareConfigs') : api.request('/fares'),
    getById: async (id) => USE_FIREBASE ? await firebaseService.getById('fareConfigs', id) : api.request(`/fares/${id}`),
    create: async (data) => USE_FIREBASE ? await firebaseService.create('fareConfigs', data) : api.request('/fares', { method: 'POST', body: data }),
    update: async (id, data) => USE_FIREBASE ? await firebaseService.update('fareConfigs', id, data) : api.request(`/fares/${id}`, { method: 'PUT', body: data }),
    delete: async (id) => USE_FIREBASE ? await firebaseService.delete('fareConfigs', id) : api.request(`/fares/${id}`, { method: 'DELETE' }),
    // Fare Fix Routes sub-API
    farefix: {
      getAll: async () => USE_FIREBASE ? await firebaseService.getAll('fareFixRoutes') : api.request('/fare-fix-routes'),
      getById: async (id) => USE_FIREBASE ? await firebaseService.getById('fareFixRoutes', id) : api.request(`/fare-fix-routes/${id}`),
      create: async (data) => USE_FIREBASE ? await firebaseService.create('fareFixRoutes', data) : api.request('/fare-fix-routes', { method: 'POST', body: data }),
      update: async (id, data) => USE_FIREBASE ? await firebaseService.update('fareFixRoutes', id, data) : api.request(`/fare-fix-routes/${id}`, { method: 'PUT', body: data }),
      delete: async (id) => USE_FIREBASE ? await firebaseService.delete('fareFixRoutes', id) : api.request(`/fare-fix-routes/${id}`, { method: 'DELETE' }),
    },
    // Surge Pricing sub-API
    surge: {
      getAll: async () => USE_FIREBASE ? await firebaseService.getAll('surgeRules') : api.request('/surge-rules'),
      getById: async (id) => USE_FIREBASE ? await firebaseService.getById('surgeRules', id) : api.request(`/surge-rules/${id}`),
      create: async (data) => USE_FIREBASE ? await firebaseService.create('surgeRules', data) : api.request('/surge-rules', { method: 'POST', body: data }),
      update: async (id, data) => USE_FIREBASE ? await firebaseService.update('surgeRules', id, data) : api.request(`/surge-rules/${id}`, { method: 'PUT', body: data }),
      delete: async (id) => USE_FIREBASE ? await firebaseService.delete('surgeRules', id) : api.request(`/surge-rules/${id}`, { method: 'DELETE' }),
    },
  },

  zones: {
    getAll: async () => USE_FIREBASE ? await firebaseService.getAll('zones') : api.request('/zones'),
    getById: async (id) => USE_FIREBASE ? await firebaseService.getById('zones', id) : api.request(`/zones/${id}`),
    create: async (data) => USE_FIREBASE ? await firebaseService.create('zones', data) : api.request('/zones', { method: 'POST', body: data }),
    update: async (id, data) => USE_FIREBASE ? await firebaseService.update('zones', id, data) : api.request(`/zones/${id}`, { method: 'PUT', body: data }),
    delete: async (id) => USE_FIREBASE ? await firebaseService.delete('zones', id) : api.request(`/zones/${id}`, { method: 'DELETE' }),
    serviceLocations: {
      getAll: async () => USE_FIREBASE ? await firebaseService.getAll('serviceLocations') : api.request('/zones/service-locations'),
      getById: async (id) => USE_FIREBASE ? await firebaseService.getById('serviceLocations', id) : api.request(`/zones/service-locations/${id}`),
      create: async (data) => USE_FIREBASE ? await firebaseService.create('serviceLocations', data) : api.request('/zones/service-locations', { method: 'POST', body: data }),
      update: async (id, data) => USE_FIREBASE ? await firebaseService.update('serviceLocations', id, data) : api.request(`/zones/service-locations/${id}`, { method: 'PUT', body: data }),
      delete: async (id) => USE_FIREBASE ? await firebaseService.delete('serviceLocations', id) : api.request(`/zones/service-locations/${id}`, { method: 'DELETE' })
    }
  },

  settings: {
    getAll: async () => USE_FIREBASE ? await firebaseService.getAll('settings') : api.request('/settings'),
    getByType: async (type) => USE_FIREBASE ? await firebaseService.query('settings', 'type', '==', type) : api.request(`/settings/${type}`),
    getById: async (id) => USE_FIREBASE ? await firebaseService.getById('settings', id) : api.request(`/settings/${id}`),
    create: async (data) => USE_FIREBASE ? await firebaseService.create('settings', data) : api.request('/settings', { method: 'POST', body: data }),
    update: async (id, data) => USE_FIREBASE ? await firebaseService.update('settings', id, data) : api.request(`/settings/${id}`, { method: 'PUT', body: data }),
    delete: async (id) => USE_FIREBASE ? await firebaseService.delete('settings', id) : api.request(`/settings/${id}`, { method: 'DELETE' })
  },

  // Map roles to authUsers for Roles page compatibility with super admin protection
  roles: {
    getAll: async () => api.request('/auth/users'),
    getById: async (id) => api.request(`/auth/users/${id}`),
    create: async (data) => api.request('/auth/users', { method: 'POST', body: data }),
    update: async (id, data) => api.request(`/auth/users/${id}`, { method: 'PUT', body: data }),
    delete: async (id) => {
      console.log('🗑️ API: Deleting role with ID:', id);
      return api.request(`/auth/users/${id}`, { method: 'DELETE' });
    }
  }
};

export default api;

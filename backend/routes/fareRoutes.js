/**
 * Fare Configuration Routes
 * Manages zone-based pricing (Rapido-style base fare structure)
 * 
 * Fare Config structure:
 * {
 *   zoneId: string,
 *   zoneName: string,
 *   vehicleType: string,
 *   baseFare: number,        // Base fare amount
 *   baseDistance: number,     // Included distance in km
 *   perKmRate: number,       // Rate per km after base distance
 *   perMinuteRate: number,   // Rate per minute of ride time
 *   minimumFare: number,     // Minimum fare for any ride
 *   waitingCharge: number,   // Waiting charge per minute
 *   freeWaitingTime: number, // Free waiting minutes
 *   surgeMultiplier: number, // Current surge (1.0 = no surge)
 *   isActive: boolean,
 *   createdAt: timestamp,
 *   updatedAt: timestamp
 * }
 */

const express = require('express');
const router = express.Router();

module.exports = function(firestoreHelper) {

  // GET /api/fares - Get all fare configurations
  router.get('/', async (req, res) => {
    try {
      const { zoneId, vehicleType, isActive } = req.query;
      let fareConfigs = await firestoreHelper.getAll('fareConfigs');
      
      // Apply filters
      if (zoneId) {
        fareConfigs = fareConfigs.filter(f => f.zoneId === zoneId);
      }
      if (vehicleType) {
        fareConfigs = fareConfigs.filter(f => f.vehicleType === vehicleType);
      }
      if (isActive !== undefined) {
        fareConfigs = fareConfigs.filter(f => f.isActive === (isActive === 'true'));
      }
      
      res.json(fareConfigs);
    } catch (error) {
      console.error('Error fetching fare configs:', error);
      res.status(500).json({ error: error.message });
    }
  });

  // GET /api/fares/zone/:zoneId - Get fares for a specific zone
  router.get('/zone/:zoneId', async (req, res) => {
    try {
      let fareConfigs = await firestoreHelper.getAll('fareConfigs');
      fareConfigs = fareConfigs.filter(f => 
        f.zoneId === req.params.zoneId && f.isActive !== false
      );
      res.json(fareConfigs);
    } catch (error) {
      console.error('Error fetching fares for zone:', error);
      res.status(500).json({ error: error.message });
    }
  });

  // GET /api/fares/zone-name/:zoneName - Get fares by zone name
  router.get('/zone-name/:zoneName', async (req, res) => {
    try {
      const zoneName = decodeURIComponent(req.params.zoneName);
      let fareConfigs = await firestoreHelper.getAll('fareConfigs');
      fareConfigs = fareConfigs.filter(f => 
        f.zoneName === zoneName && f.isActive !== false
      );
      res.json(fareConfigs);
    } catch (error) {
      console.error('Error fetching fares for zone name:', error);
      res.status(500).json({ error: error.message });
    }
  });

  // GET /api/fares/:id - Get a single fare config
  router.get('/:id', async (req, res) => {
    try {
      const fareConfig = await firestoreHelper.getById('fareConfigs', req.params.id);
      if (!fareConfig) {
        return res.status(404).json({ error: 'Fare config not found' });
      }
      res.json(fareConfig);
    } catch (error) {
      console.error('Error fetching fare config:', error);
      res.status(500).json({ error: error.message });
    }
  });

  // POST /api/fares - Create a new fare configuration
  router.post('/', async (req, res) => {
    try {
      const fareData = {
        ...req.body,
        isActive: req.body.isActive !== undefined ? req.body.isActive : true,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
      };
      
      const fareConfig = await firestoreHelper.create('fareConfigs', fareData);
      res.status(201).json(fareConfig);
    } catch (error) {
      console.error('Error creating fare config:', error);
      res.status(500).json({ error: error.message });
    }
  });

  // POST /api/fares/bulk - Create multiple fare configurations at once
  router.post('/bulk', async (req, res) => {
    try {
      const { fareConfigs } = req.body;
      if (!Array.isArray(fareConfigs) || fareConfigs.length === 0) {
        return res.status(400).json({ error: 'fareConfigs array is required' });
      }

      const results = [];
      for (const config of fareConfigs) {
        const fareData = {
          ...config,
          isActive: config.isActive !== undefined ? config.isActive : true,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString()
        };
        const created = await firestoreHelper.create('fareConfigs', fareData);
        results.push(created);
      }
      
      res.status(201).json({ 
        message: `${results.length} fare configs created successfully`,
        data: results 
      });
    } catch (error) {
      console.error('Error bulk creating fare configs:', error);
      res.status(500).json({ error: error.message });
    }
  });

  // PUT /api/fares/:id - Update a fare configuration
  router.put('/:id', async (req, res) => {
    try {
      const updateData = {
        ...req.body,
        updatedAt: new Date().toISOString()
      };
      
      const fareConfig = await firestoreHelper.update('fareConfigs', req.params.id, updateData);
      if (!fareConfig) {
        return res.status(404).json({ error: 'Fare config not found' });
      }
      res.json(fareConfig);
    } catch (error) {
      console.error('Error updating fare config:', error);
      res.status(500).json({ error: error.message });
    }
  });

  // DELETE /api/fares/:id - Delete a fare configuration
  router.delete('/:id', async (req, res) => {
    try {
      await firestoreHelper.delete('fareConfigs', req.params.id);
      res.json({ message: 'Fare config deleted successfully' });
    } catch (error) {
      console.error('Error deleting fare config:', error);
      res.status(500).json({ error: error.message });
    }
  });

  // POST /api/fares/calculate - Calculate fare estimate for a ride
  router.post('/calculate', async (req, res) => {
    try {
      const { zoneName, vehicleType, distanceKm, durationMinutes, waitingMinutes } = req.body;
      
      if (!zoneName || !vehicleType || distanceKm === undefined) {
        return res.status(400).json({ 
          error: 'zoneName, vehicleType, and distanceKm are required' 
        });
      }

      // Find the fare config for this zone and vehicle type
      let fareConfigs = await firestoreHelper.getAll('fareConfigs');
      const fareConfig = fareConfigs.find(f => 
        f.zoneName === zoneName && 
        f.vehicleType === vehicleType && 
        f.isActive !== false
      );

      if (!fareConfig) {
        return res.status(404).json({ 
          error: `No fare config found for zone "${zoneName}" and vehicle type "${vehicleType}"` 
        });
      }

      // Calculate fare using Rapido-style formula
      const baseFare = fareConfig.baseFare || 0;
      const baseDistance = fareConfig.baseDistance || 2; // default 2 km
      const perKmRate = fareConfig.perKmRate || 0;
      const perMinuteRate = fareConfig.perMinuteRate || 0;
      const minimumFare = fareConfig.minimumFare || baseFare;
      const waitingCharge = fareConfig.waitingCharge || 0;
      const freeWaitingTime = fareConfig.freeWaitingTime || 3; // default 3 min free
      const surgeMultiplier = fareConfig.surgeMultiplier || 1.0;

      // Distance fare: baseFare covers baseDistance, then perKmRate for remaining
      let distanceFare = 0;
      if (distanceKm <= baseDistance) {
        distanceFare = 0; // covered by base fare
      } else {
        distanceFare = (distanceKm - baseDistance) * perKmRate;
      }

      // Time fare
      const timeFare = (durationMinutes || 0) * perMinuteRate;

      // Waiting charge (after free waiting time)
      let waitingFare = 0;
      if (waitingMinutes && waitingMinutes > freeWaitingTime) {
        waitingFare = (waitingMinutes - freeWaitingTime) * waitingCharge;
      }

      // Total before surge
      const subtotal = baseFare + distanceFare + timeFare + waitingFare;

      // Apply surge
      const totalFare = Math.round(Math.max(subtotal * surgeMultiplier, minimumFare));

      res.json({
        zoneName,
        vehicleType,
        baseFare,
        baseDistance,
        perKmRate,
        perMinuteRate,
        distanceKm,
        durationMinutes: durationMinutes || 0,
        waitingMinutes: waitingMinutes || 0,
        distanceFare: Math.round(distanceFare),
        timeFare: Math.round(timeFare),
        waitingFare: Math.round(waitingFare),
        surgeMultiplier,
        subtotal: Math.round(subtotal),
        minimumFare,
        totalFare,
        currency: '₹'
      });
    } catch (error) {
      console.error('Error calculating fare:', error);
      res.status(500).json({ error: error.message });
    }
  });

  return router;
};
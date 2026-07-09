import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Dadacabs/Container/Repositories/pool_repo.dart';
import 'package:Dadacabs/Model/Pooling/pool_trip_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:Dadacabs/Model/vehicle_type_model.dart';
import 'package:Dadacabs/Container/Providers/vehicle_providers.dart';
import 'package:Dadacabs/Container/Providers/user_data_provider.dart';

final availablePoolsProvider = StreamProvider.family<List<PoolTrip>, PoolSearchParams>((ref, params) {
  return ref.read(globalPoolRepoProvider).findAvailablePools(
    params.pickup,
    params.dropoff,
    params.seats,
  );
});

final userActivePoolProvider = StreamProvider<PoolTrip?>((ref) {
  final user = ref.watch(userDataProvider);
  if (user == null) return Stream.value(null);
  return ref.read(globalPoolRepoProvider).getUserActivePool(user.uid);
});

class PoolSearchParams {
  final LatLng pickup;
  final LatLng dropoff;
  final int seats;

  PoolSearchParams({
    required this.pickup,
    required this.dropoff,
    required this.seats,
  });
}

class PoolMatchingScreen extends ConsumerStatefulWidget {
  final LatLng pickupLocation;
  final LatLng dropoffLocation;
  final String pickupAddress;
  final String dropoffAddress;

  const PoolMatchingScreen({
    super.key,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.pickupAddress,
    required this.dropoffAddress,
  });

  @override
  ConsumerState<PoolMatchingScreen> createState() => _PoolMatchingScreenState();
}

class _PoolMatchingScreenState extends ConsumerState<PoolMatchingScreen> {
  int selectedSeats = 1;
  bool showSavings = true;

  @override
  Widget build(BuildContext context) {
    final searchParams = PoolSearchParams(
      pickup: widget.pickupLocation,
      dropoff: widget.dropoffLocation,
      seats: selectedSeats,
    );
    final poolsAsync = ref.watch(availablePoolsProvider(searchParams));
    final activePool = ref.watch(userActivePoolProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          "Share Your Ride",
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
            fontFamily: "bold",
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: activePool.when(
        data: (active) {
          if (active != null) {
            return _buildActivePoolView(context, active);
          }
          return _buildMatchingView(context, poolsAsync);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text("Error: $err", style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildMatchingView(BuildContext context, AsyncValue<List<PoolTrip>> poolsAsync) {
    return Column(
      children: [
        // Route Info Card
        Container(
          margin: const EdgeInsets.all(15),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Column(
                    children: [
                      const Icon(Icons.circle, color: Colors.green, size: 12),
                      Container(
                        width: 2,
                        height: 40,
                        color: Colors.grey[700],
                      ),
                      const Icon(Icons.location_on, color: Colors.red, size: 16),
                    ],
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.pickupAddress,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 25),
                        Text(
                          widget.dropoffAddress,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 30, color: Colors.grey),
              
              // Seat Selection
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Passengers",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: selectedSeats > 1
                            ? () => setState(() => selectedSeats--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                        color: selectedSeats > 1 ? Colors.blue : Colors.grey,
                      ),
                      Text(
                        "$selectedSeats",
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          fontFamily: "bold",
                          fontSize: 18,
                        ),
                      ),
                      IconButton(
                        onPressed: selectedSeats < 4
                            ? () => setState(() => selectedSeats++)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                        color: selectedSeats < 4 ? Colors.blue : Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Savings Toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Row(
            children: [
              Switch(
                value: showSavings,
                onChanged: (value) => setState(() => showSavings = value),
                activeThumbColor: Colors.green,
              ),
              Text(
                "Show potential savings",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        
        // Available Pools
        Expanded(
          child: poolsAsync.when(
            data: (pools) {
              if (pools.isEmpty) {
                return _buildNoPoolsView(context);
              }
              return ListView.builder(
                padding: const EdgeInsets.all(15),
                itemCount: pools.length,
                itemBuilder: (context, index) {
                  return _buildPoolCard(context, pools[index]);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(
              child: Text("Error: $err", style: const TextStyle(color: Colors.white)),
            ),
          ),
        ),
        
        // Create New Pool Button
        Padding(
          padding: const EdgeInsets.all(15),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _createNewPool(context),
              icon: const Icon(Icons.add),
              label: const Text("Create New Pool"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
                side: const BorderSide(color: Colors.blue),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPoolCard(BuildContext context, PoolTrip pool) {
    // Calculate individual fare estimate dynamically based on distance and vehicle rates
    final distanceMeters = Geolocator.distanceBetween(
      widget.pickupLocation.latitude,
      widget.pickupLocation.longitude,
      widget.dropoffLocation.latitude,
      widget.dropoffLocation.longitude,
    );
    final distanceKm = distanceMeters / 1000.0;

    final vehicleTypes = ref.watch(vehicleTypesStreamProvider).value ?? VehicleTypeModel.defaults;
    final economyType = vehicleTypes.firstWhere(
      (v) => v.id.toLowerCase() == 'economy' || v.id.toLowerCase() == 'sedan',
      orElse: () => vehicleTypes.first,
    );

    double estimatedIndividualFare = economyType.baseFare + (distanceKm * economyType.perKmRate);
    estimatedIndividualFare = estimatedIndividualFare < economyType.minimumFare ? economyType.minimumFare : estimatedIndividualFare;
    estimatedIndividualFare = double.parse(estimatedIndividualFare.toStringAsFixed(1));

    final poolFare = pool.passengerFares.isNotEmpty
        ? pool.passengerFares.values.first
        : estimatedIndividualFare * 0.7;
    final savings = estimatedIndividualFare - poolFare;
    final savingsPercent = estimatedIndividualFare > 0
        ? ((savings / estimatedIndividualFare) * 100).round()
        : 0;

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: pool.status == PoolStatus.matching
              ? Colors.orange
              : Colors.green,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_taxi, color: Colors.blue),
                    const SizedBox(width: 10),
                    Text(
                      pool.carType,
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        fontFamily: "bold",
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: pool.status == PoolStatus.matching
                        ? Colors.orange.withOpacity(0.2)
                        : Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    pool.statusText,
                    style: TextStyle(
                      color: pool.status == PoolStatus.matching
                          ? Colors.orange
                          : Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            
            // Driver Info
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Text(
                    pool.driverName.isNotEmpty ? pool.driverName[0] : "D",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pool.driverName,
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        fontFamily: "bold",
                      ),
                    ),
                    Text(
                      pool.carPlateNum,
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Rating
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 5),
                    Text(
                      "4.8", // Would come from driver rating
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 30, color: Colors.grey),
            
            // Passengers & Seats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.people, color: Colors.grey[600]),
                    const SizedBox(width: 10),
                    Text(
                      "${pool.currentPassengers}/${pool.maxPassengers} passengers",
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                Text(
                  "${pool.availableSeats} seats left",
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: pool.availableSeats >= selectedSeats
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            
            // Route Info
            Row(
              children: [
                const Icon(Icons.route, color: Colors.blue, size: 16),
                const SizedBox(width: 10),
                Text(
                  "${pool.estimatedDurationMinutes} min • ${pool.estimatedDistanceKm.toStringAsFixed(1)} km",
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            
            // Pricing
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "₹${poolFare.toStringAsFixed(0)}",
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        fontFamily: "bold",
                        fontSize: 24,
                        color: Colors.green,
                      ),
                    ),
                    if (showSavings)
                      Text(
                        "Save ₹${savings.toStringAsFixed(0)} ($savingsPercent%)",
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: Colors.green,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                ElevatedButton(
                  onPressed: pool.availableSeats >= selectedSeats
                      ? () => _joinPool(context, pool)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    disabledBackgroundColor: Colors.grey[800],
                  ),
                  child: const Text("Join Pool"),
                ),
              ],
            ),
            
            // Existing Passengers
            if (pool.passengers.isNotEmpty) ...[
              const SizedBox(height: 15),
              const Divider(height: 1, color: Colors.grey),
              const SizedBox(height: 10),
              Text(
                "Co-passengers:",
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 10,
                children: pool.passengers.map((p) {
                  return Chip(
                    avatar: CircleAvatar(
                      child: Text(p.name[0]),
                    ),
                    label: Text(p.name),
                    backgroundColor: Colors.grey[800],
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActivePoolView(BuildContext context, PoolTrip pool) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Active Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.green, Colors.greenAccent],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 50),
                const SizedBox(height: 10),
                Text(
                  "You're in a Pool!",
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    fontFamily: "bold",
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
                Text(
                  pool.statusText,
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          
          // Pool Details
          Card(
            color: Colors.grey[900],
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Trip Details",
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      fontFamily: "bold",
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Stops
                  ...pool.stops.asMap().entries.map((entry) {
                    final index = entry.key;
                    final stop = entry.value;
                    final isCompleted = stop.status == StopStatus.completed;
                    final isNext = stop.status == StopStatus.next;
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isCompleted
                            ? Colors.green
                            : isNext
                                ? Colors.blue
                                : Colors.grey[800],
                        child: Icon(
                          stop.type == StopType.pickup
                              ? Icons.person_add
                              : Icons.person_remove,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      title: Text(
                        stop.passengerName,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      subtitle: Text(
                        stop.address,
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? Colors.green.withOpacity(0.2)
                              : isNext
                                  ? Colors.blue.withOpacity(0.2)
                                  : Colors.grey[800],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isCompleted
                              ? "Done"
                              : isNext
                                  ? "Next"
                                  : "Pending",
                          style: TextStyle(
                            color: isCompleted
                                ? Colors.green
                                : isNext
                                    ? Colors.blue
                                    : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Co-passengers
          Card(
            color: Colors.grey[900],
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Co-passengers (${pool.passengers.length})",
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      fontFamily: "bold",
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 15),
                  ...pool.passengers.map((p) {
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(p.name[0]),
                      ),
                      title: Text(p.name),
                      subtitle: Text("Paid ₹${p.fare.toStringAsFixed(0)}"),
                      trailing: p.hasPaid
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.pending, color: Colors.orange),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPoolsView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            color: Colors.grey[700],
            size: 80,
          ),
          const SizedBox(height: 20),
          Text(
            "No pools available",
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Create a new pool or try individual ride",
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () => _createNewPool(context),
            icon: const Icon(Icons.add),
            label: const Text("Create Pool"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _joinPool(BuildContext context, PoolTrip pool) async {
    final user = ref.read(userDataProvider);
    if (user == null) return;
    
    final userId = user.uid;
    final userName = user.name.isNotEmpty ? user.name : 'Passenger';
    
    final request = PoolRequest(
      requestId: 'req_${DateTime.now().millisecondsSinceEpoch}',
      poolId: pool.poolId,
      passengerId: userId,
      passengerName: userName,
      pickupLocation: GeoPoint(
        widget.pickupLocation.latitude,
        widget.pickupLocation.longitude,
      ),
      pickupAddress: widget.pickupAddress,
      dropoffLocation: GeoPoint(
        widget.dropoffLocation.latitude,
        widget.dropoffLocation.longitude,
      ),
      dropoffAddress: widget.dropoffAddress,
      requestedAt: DateTime.now(),
      status: PoolRequestStatus.pending,
    );

    final success = await ref.read(globalPoolRepoProvider).requestToJoinPool(
      request,
      context,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Request sent! Waiting for confirmation."),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _createNewPool(BuildContext context) {
    // Navigate to create pool screen or show dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          "Create New Pool",
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
            fontFamily: "bold",
          ),
        ),
        content: Text(
          "Start a new pool for your route. Other passengers can join and share the cost!",
          style: Theme.of(context).textTheme.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement pool creation
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Pool creation coming soon!"),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }
}

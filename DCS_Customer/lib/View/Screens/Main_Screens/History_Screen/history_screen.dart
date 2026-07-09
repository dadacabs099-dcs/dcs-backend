import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Dadacabs/View/Screens/Nav_Screens/navigation_providers.dart';

import 'package:intl/intl.dart';
import 'package:Dadacabs/Container/Repositories/trip_repo.dart';
import 'package:Dadacabs/View/Themes/indian_heritage_theme.dart';
import 'package:Dadacabs/Container/Providers/theme_provider.dart';
import 'package:Dadacabs/Model/trip_model.dart';

import 'package:Dadacabs/Container/Providers/user_data_provider.dart';

final userTripsProvider = StreamProvider<List<TripModel>>((ref) {
  final user = ref.watch(userDataProvider);
  if (user == null) return Stream.value([]);
  return ref.read(globalTripRepoProvider).getUserTrips(user.uid);
});

final userTripHistoryProvider = StreamProvider<List<TripModel>>((ref) {
  final user = ref.watch(userDataProvider);
  if (user == null) return Stream.value([]);
  return ref.read(globalTripRepoProvider).getUserTripHistory(user.uid);
});

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Scaffold(
      backgroundColor: isDark ? IndianHeritageColors.darkBackground : IndianHeritageColors.marbleWhite,
      appBar: AppBar(
        backgroundColor: IndianHeritageColors.primaryYellow,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: IndianHeritageColors.charcoal),
          onPressed: () => ref.read(navigationScaffoldKeyProvider).currentState?.openDrawer(),
        ),
        title: const Text(
          "My Trips",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: IndianHeritageColors.charcoal,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: IndianHeritageColors.charcoal,
          indicatorWeight: 4,
          labelColor: IndianHeritageColors.charcoal,
          unselectedLabelColor: IndianHeritageColors.charcoal.withOpacity(0.5),
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          tabs: const [
            Tab(text: "All Trips"),
            Tab(text: "Completed"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTripsTab(context, ref, isHistory: false, isDark: isDark),
          _buildTripsTab(context, ref, isHistory: true, isDark: isDark),
        ],
      ),
    );
  }

  Widget _buildTripsTab(BuildContext context, WidgetRef ref, {required bool isHistory, required bool isDark}) {
    final tripsAsync = isHistory 
        ? ref.watch(userTripHistoryProvider)
        : ref.watch(userTripsProvider);

    return tripsAsync.when(
      data: (trips) {
        if (trips.isEmpty) {
          return _buildEmptyState(context, isHistory, isDark);
        }
        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: trips.length,
          itemBuilder: (context, index) {
            final trip = trips[index];
            return _buildTripCard(context, trip, isDark);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: IndianHeritageColors.primaryYellow)),
      error: (err, stack) => Center(
        child: Text(
          "Error: $err",
          style: TextStyle(color: isDark ? Colors.white : IndianHeritageColors.charcoal),
        ),
      ),
    );
  }

  Widget _buildTripCard(BuildContext context, TripModel trip, bool isDark) {
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final isCompleted = trip.status == TripStatus.completed;
    final isCancelled = trip.status == TripStatus.cancelled;

    return Card(
      color: isDark ? IndianHeritageColors.darkCard : Colors.white,
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Color(trip.statusColor).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    trip.statusText,
                    style: TextStyle(
                      color: Color(trip.statusColor),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  dateFormat.format(trip.createdAt),
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            
            // Service Type
            Row(
              children: [
                Icon(
                  trip.serviceType == 'ride' 
                      ? Icons.local_taxi 
                      : trip.serviceType == 'parcel_bike'
                          ? Icons.pedal_bike
                          : Icons.local_shipping,
                  color: IndianHeritageColors.primaryYellow,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  trip.serviceType == 'ride'
                      ? 'Ride'
                      : trip.serviceType == 'parcel_bike'
                          ? 'Parcel (Bike)'
                          : 'Parcel (Truck)',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    fontFamily: "bold",
                    color: isDark ? Colors.white : IndianHeritageColors.charcoal,
                  ),
                ),
                if (trip.driverName != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    "• ${trip.driverName}",
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 15),
            
            // Route Info
            Row(
              children: [
                Column(
                  children: [
                    const Icon(Icons.circle, color: Colors.green, size: 12),
                    Container(
                      width: 2,
                      height: 30,
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
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
                        trip.pickupAddress,
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: isDark ? Colors.white70 : IndianHeritageColors.charcoal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        trip.dropoffAddress,
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: isDark ? Colors.white70 : IndianHeritageColors.charcoal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 30, color: Colors.grey),
            
            // Footer with price and actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCancelled ? "Cancelled" : "Final Price",
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      isCancelled 
                          ? "No charge"
                          : "₹${trip.finalFare?.toStringAsFixed(0) ?? trip.estimatedFare.toStringAsFixed(0)}",
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        fontFamily: "bold",
                        fontSize: 18,
                        color: isCancelled ? Colors.grey : Colors.green,
                      ),
                    ),
                  ],
                ),
                if (isCompleted && trip.userRating == null)
                  ElevatedButton.icon(
                    onPressed: () => _showRatingDialog(context, trip, isDark),
                    icon: const Icon(Icons.star, size: 16, color: IndianHeritageColors.charcoal),
                    label: const Text("Rate"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: IndianHeritageColors.primaryYellow,
                      foregroundColor: IndianHeritageColors.charcoal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                if (isCompleted && trip.userRating != null)
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      const SizedBox(width: 5),
                      Text(
                        "${trip.userRating}",
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: isDark ? Colors.white : IndianHeritageColors.charcoal,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            
            // Parcel details if applicable
            if (trip.serviceType != 'ride' && trip.parcelDescription != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? IndianHeritageColors.darkBackground : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, 
                      color: Colors.grey, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "${trip.parcelDescription} • ${trip.parcelWeight ?? ''}",
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isHistory, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isHistory ? Icons.check_circle_outline : Icons.local_taxi,
            color: isDark ? Colors.grey[800] : Colors.grey[400],
            size: 80,
          ),
          const SizedBox(height: 20),
          Text(
            isHistory ? "No completed trips yet" : "No trips yet",
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              fontSize: 18,
              color: Colors.grey,
              fontFamily: "bold",
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isHistory 
                ? "Complete a ride to see it here"
                : "Book your first ride now!",
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog(BuildContext context, TripModel trip, bool isDark) {
    double rating = 5.0;
    final reviewController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDark ? IndianHeritageColors.darkSurface : Colors.white,
          title: Text(
            "Rate your trip",
            style: TextStyle(
              fontFamily: "bold",
              color: isDark ? Colors.white : IndianHeritageColors.charcoal,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () {
                      setState(() {
                        rating = index + 1.0;
                      });
                    },
                    icon: Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 40,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: reviewController,
                style: TextStyle(
                  color: isDark ? Colors.white : IndianHeritageColors.charcoal,
                ),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Write a review (optional)",
                  hintStyle: const TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Skip"),
            ),
            ElevatedButton(
              onPressed: () async {
                final repo = ref.read(globalTripRepoProvider);
                await repo.rateTrip(
                  trip.tripId,
                  rating,
                  reviewController.text.isNotEmpty 
                      ? reviewController.text 
                      : null,
                  context,
                );
                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: IndianHeritageColors.primaryYellow,
                foregroundColor: IndianHeritageColors.charcoal,
              ),
              child: const Text("Submit"),
            ),
          ],
        ),
      ),
    );
  }
}

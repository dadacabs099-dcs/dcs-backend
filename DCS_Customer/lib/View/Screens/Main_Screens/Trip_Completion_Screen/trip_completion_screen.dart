import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:Dadacabs/Model/trip_model.dart';
import 'package:Dadacabs/Container/Repositories/trip_repo.dart';
import 'package:Dadacabs/View/Routes/routes.dart';
import 'package:Dadacabs/View/Themes/indian_heritage_theme.dart';
import 'package:Dadacabs/Container/Providers/theme_provider.dart';

class TripCompletionScreen extends ConsumerWidget {
  final TripModel trip;

  const TripCompletionScreen({
    super.key,
    required this.trip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Scaffold(
      backgroundColor: isDark ? IndianHeritageColors.darkBackground : IndianHeritageColors.marbleWhite,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Success Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: size.height * 0.08,
                horizontal: 20,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [IndianHeritageColors.primaryYellow, IndianHeritageColors.deepGold],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: IndianHeritageColors.charcoal,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: IndianHeritageColors.primaryYellow,
                      size: 60,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Trip Completed!',
                    style: TextStyle(
                      fontFamily: 'bold',
                      fontSize: 28,
                      color: IndianHeritageColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Thank you for riding with us',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),

            // Trip Details Card
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? IndianHeritageColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Route
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          const Icon(Icons.circle, color: Colors.green, size: 12),
                          Container(
                            width: 2,
                            height: 40,
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
                            const Text(
                              'From',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              trip.pickupAddress,
                              style: TextStyle(
                                color: isDark ? Colors.white : IndianHeritageColors.charcoal,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 25),
                            const Text(
                              'To',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              trip.dropoffAddress,
                              style: TextStyle(
                                color: isDark ? Colors.white : IndianHeritageColors.charcoal,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 30, color: Colors.grey),

                  // Trip Stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatColumn(
                        context,
                        icon: Icons.directions,
                        value: '${trip.distanceKm?.toStringAsFixed(1) ?? "N/A"} km',
                        label: 'Distance',
                        isDark: isDark,
                      ),
                      _buildStatColumn(
                        context,
                        icon: Icons.schedule,
                        value: '${trip.durationMinutes ?? "N/A"} min',
                        label: 'Duration',
                        isDark: isDark,
                      ),
                      _buildStatColumn(
                        context,
                        icon: Icons.local_taxi,
                        value: trip.carType ?? 'Ride',
                        label: 'Vehicle',
                        isDark: isDark,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Fare Breakdown
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? IndianHeritageColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fare Breakdown',
                    style: TextStyle(
                      fontFamily: 'bold',
                      fontSize: 16,
                      color: isDark ? Colors.white : IndianHeritageColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFareRow(
                    'Base Fare',
                    '₹${trip.estimatedFare.toStringAsFixed(0)}',
                    isDark,
                  ),
                  if (trip.discountAmount != null && trip.discountAmount! > 0) ...[
                    _buildFareRow(
                      'Discount',
                      '-₹${trip.discountAmount!.toStringAsFixed(0)}',
                      isDark,
                      color: Colors.green,
                    ),
                  ],
                  const Divider(height: 16, color: Colors.grey),
                  _buildFareRow(
                    'Total Amount',
                    '₹${trip.finalFare?.toStringAsFixed(0) ?? trip.estimatedFare.toStringAsFixed(0)}',
                    isDark,
                    isBold: true,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: IndianHeritageColors.primaryYellow.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info, color: IndianHeritageColors.primaryYellow, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            trip.isPaid ? 'Paid to driver' : 'Payment pending',
                            style: TextStyle(
                              color: trip.isPaid ? Colors.green : Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Rating & Feedback Section
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? IndianHeritageColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rate Your Trip',
                    style: TextStyle(
                      fontFamily: 'bold',
                      fontSize: 16,
                      color: isDark ? Colors.white : IndianHeritageColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (trip.userRating == null)
                    _buildRatingButton(context, ref, trip)
                  else
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${trip.userRating!.toStringAsFixed(1)} stars',
                          style: TextStyle(
                            color: isDark ? Colors.white : IndianHeritageColors.charcoal,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  if (trip.userReview != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      trip.userReview!,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.goNamed(Routes().home);
                      },
                      icon: const Icon(Icons.home, color: IndianHeritageColors.charcoal),
                      label: const Text('Back to Home'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: IndianHeritageColors.primaryYellow,
                        foregroundColor: IndianHeritageColors.charcoal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        context.pushNamed(Routes().rideHistory);
                      },
                      icon: Icon(Icons.history, color: isDark ? IndianHeritageColors.primaryYellow : IndianHeritageColors.charcoal),
                      label: const Text('View Trip History'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? IndianHeritageColors.primaryYellow : IndianHeritageColors.charcoal,
                        side: BorderSide(
                          color: isDark ? IndianHeritageColors.primaryYellow : IndianHeritageColors.charcoal,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required bool isDark,
  }) {
    return Column(
      children: [
        Icon(icon, color: IndianHeritageColors.primaryYellow, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'bold',
            fontSize: 14,
            color: isDark ? Colors.white : IndianHeritageColors.charcoal,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildFareRow(
    String label,
    String amount,
    bool isDark, {
    Color? color,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            color: color ?? (isDark ? Colors.white : IndianHeritageColors.charcoal),
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildRatingButton(
    BuildContext context,
    WidgetRef ref,
    TripModel trip,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: ElevatedButton.icon(
        onPressed: () {
          _showRatingDialog(context, ref, trip);
        },
        icon: const Icon(Icons.star, color: IndianHeritageColors.charcoal),
        label: const Text('Rate Driver'),
        style: ElevatedButton.styleFrom(
          backgroundColor: IndianHeritageColors.primaryYellow,
          foregroundColor: IndianHeritageColors.charcoal,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _showRatingDialog(
    BuildContext context,
    WidgetRef ref,
    TripModel trip,
  ) {
    double rating = 5.0;
    final reviewController = TextEditingController();
    final isDark = ref.read(themeModeProvider) == ThemeMode.dark;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDark ? IndianHeritageColors.darkSurface : Colors.white,
          title: Text(
            'Rate your trip',
            style: TextStyle(
              fontFamily: 'bold',
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
                  hintText: 'Write a review (optional)',
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
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () async {
                final repo = ref.read(globalTripRepoProvider);
                await repo.rateTrip(
                  trip.tripId,
                  rating,
                  reviewController.text.isNotEmpty ? reviewController.text : null,
                  context,
                );
                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: IndianHeritageColors.primaryYellow,
                foregroundColor: IndianHeritageColors.charcoal,
              ),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}

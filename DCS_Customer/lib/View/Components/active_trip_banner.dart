import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Active_Trip_Screen/active_trip_providers.dart';
import 'package:Dadacabs/View/Routes/routes.dart';

class ActiveTripBanner extends ConsumerWidget {
  const ActiveTripBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTripAsync = ref.watch(userActiveTripProvider);

    return activeTripAsync.when(
      data: (trip) {
        if (trip == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            context.pushNamed(
              Routes().activeTrip,
              extra: trip,
            );
          },
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade200.withOpacity(0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.local_taxi,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Active Trip',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'bold',
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        trip.statusText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }
}

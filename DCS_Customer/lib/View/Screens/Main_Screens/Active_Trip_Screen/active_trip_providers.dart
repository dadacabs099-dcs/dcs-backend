
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Dadacabs/Model/trip_model.dart';
import 'package:Dadacabs/Container/Repositories/trip_repo.dart';

import 'package:Dadacabs/Container/Providers/user_data_provider.dart';
export 'package:Dadacabs/Container/Repositories/trip_repo.dart';

/// Provider to watch user's active trip
final userActiveTripProvider = StreamProvider<TripModel?>((ref) {
  final user = ref.watch(userDataProvider);
  if (user == null) return Stream.value(null);
  return ref.read(globalTripRepoProvider).getUserActiveTrip(user.uid);
});

/// Provider for trip action loading state
final tripActionLoadingProvider = StateProvider<bool>((ref) => false);

/// Provider to check if user has an active trip
final hasActiveTripProvider = Provider<bool>((ref) {
  final activeTrip = ref.watch(userActiveTripProvider);
  return activeTrip.value != null;
});

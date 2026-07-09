import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:Dadacabs/Model/driver_model.dart';

import '../../../../Model/direction_model.dart';
import 'package:Dadacabs/Model/direction_polyline_details_model.dart';

final homeScreenDirectionDetailsProvider = StateProvider<DirectionPolylineDetails?>((ref) {
  return null;
});

final homeScreenCameraMovementProvider = StateProvider<LatLng?>((ref) {
  return null;
});
final homeScreenPickUpLocationProvider = StateProvider<Direction?>((ref) {
  return null;
});
final homeScreenDropOffLocationProvider = StateProvider<Direction?>((ref) {
  return null;
});
final homeScreenSelectedRideProvider = StateProvider<int?>((ref) {
  return null;
});
final homeScreenStartDriverSearch = StateProvider<bool>((ref) {
  return false;
});
final homeScreenRateProvider = StateProvider<double?>((ref) {
  return null;
});

final homeScreenAvailableDriversProvider = StateProvider<List<DriverModel>>((ref) {
  return [];
});

final homeScreenAddressProvider = StateProvider<String?>((ref) {
  return null;
});

final homeScreenMainPolylinesProvider = StateProvider<Set<Polyline>>((ref) {
  return {};
});

final homeScreenMainMarkersProvider = StateProvider<Set<Marker>>((ref) {
  return {};
});

final homeScreenMainCirclesProvider = StateProvider<Set<Circle>>((ref) {
  return {};
});

final homeScreenSelectedPaymentProvider = StateProvider<String>((ref) => 'cash');

// Modified by Jayant Pandit on 2026-07-08 10:30:00
// Reason: Track passenger name when booking ride for someone else. null = booking for self, non-null = passenger name/phone.
final homeScreenBookingPassengerProvider = StateProvider<String?>((ref) => null);

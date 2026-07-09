import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Dadacabs/Model/vehicle_type_model.dart';

// Modified by Jayant Pandit on 2026-07-11 10:00:00
// Reason: Removed server-side isActive filter which silently excludes vehicles where isActive
// is stored as string "true" or is missing entirely. Now fetches all docs and filters client-side
// via VehicleTypeModel.fromMap which already handles all isActive formats.
final vehicleTypesStreamProvider = StreamProvider<List<VehicleTypeModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('vehicleTypes')
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => VehicleTypeModel.fromMap(d.data(), d.id))
          .where((v) => v.isActive)
          .toList());
});

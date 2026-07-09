// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:geolocator/geolocator.dart';

class DriverModel {
  String carName;
  String carPlateNum;
  String carType;
  Position driverLoc;
  String driverStatus;
  String email;
  String name;
  // Modified by Jayant Pandit on 2026-07-11 11:00:00
  // Reason: Added profileUrl field to store driver's profile photo URL from Firestore
  // 'profileUrl' field in drivers collection — written by Partner app on photo upload
  String? profileUrl;
  DriverModel(
     this.carName,
     this.carPlateNum,
     this.carType,
     this.driverLoc,
     this.driverStatus,
     this.email,
     this.name, {
    // Modified by Jayant Pandit on 2026-07-11 11:00:00
    // Reason: Optional named parameter for profileUrl — backward compatible with existing callers
    this.profileUrl,
  });
}

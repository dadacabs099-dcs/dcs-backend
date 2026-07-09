import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:Dadacabs/Container/utils/keys.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Home_Screen/home_providers.dart';
import '../../Model/direction_model.dart';

/// [addressParserProvider] used to cache the [AddressParser] class to prevent it from creating multiple instances

final globalAddressParserProvider = Provider<AddressParser>((ref) {
  return AddressParser();
});

/// This [AddressParser] has function [humanReadableAddress] which creates address that is in a readable form
/// from the provided [userPosition]'s latitude and longitude and returns response in form of [Direction] model.
/// Replicated from Partner APK for consistent fallback handling.

class AddressParser {
  dynamic humanReadableAddress(
      Position userPosition, context, WidgetRef ref) async {
    try {
      String url =
          "https://maps.googleapis.com/maps/api/geocode/json?latlng=${userPosition.latitude},${userPosition.longitude}&key=${AppKeys.mapKey}";

      Response res = await Dio().get(url);

      if (res.statusCode == 200 && res.data["status"] == "OK" && res.data["results"] != null && res.data["results"].isNotEmpty) {
        Direction model = Direction(
            locationLatitude: userPosition.latitude,
            locationLongitude: userPosition.longitude,
            humanReadableAddress: res.data["results"][0]["formatted_address"]);
        ref.read(homeScreenPickUpLocationProvider.notifier).update((state) => model);

        return res.data["results"][0]["formatted_address"];
      } else {
        // Fallback: always set a "Current Location" so the app doesn't break
        // (matching Partner APK's fallback behavior)
        Direction model = Direction(
            locationLatitude: userPosition.latitude,
            locationLongitude: userPosition.longitude,
            humanReadableAddress: "Current Location");
        ref.read(homeScreenPickUpLocationProvider.notifier).update((state) => model);
        
        return "Current Location";
      }
    } catch (e) {
      // Fallback even on network error to keep app functional
      // (matching Partner APK's error handling)
      Direction model = Direction(
          locationLatitude: userPosition.latitude,
          locationLongitude: userPosition.longitude,
          humanReadableAddress: "Current Location");
      ref.read(homeScreenPickUpLocationProvider.notifier).update((state) => model);
      
      print("AddressParser error (using fallback): $e");
      return "Current Location";
    }
  }
}

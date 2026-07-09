import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Dadacabs/Container/utils/keys.dart';
import 'package:Dadacabs/Model/predicted_places.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Sub_Screens/Where_To_Screen/where_to_providers.dart';

/// [predictedPlacesRepoProvider] used to cache the [PredictedPlacesRepo] class to prevent it from creating multiple instances

final globalPredictedPlacesRepoProvider = Provider<PredictedPlacesRepo>((ref) {
  return PredictedPlacesRepo();
});

class PredictedPlacesRepo {
  /// [getAllPredictedPlaces] gets the details of the location by getting the string from [text] and fetching the
  /// data related to this [text] and showing them inside the [WhereTo] screen as user adds types more words new [autoComplete] items are added to the
  /// [ListView] in the [WhereTo] screen by adding the newly created list of [predictedPlacesList] to the provider [predictedPlacesProvider] located in the [WhereTo] Screen

  void getAllPredictedPlaces(
      String text, BuildContext context, WidgetRef ref) async {
    try {
      if (text.length < 2) {
        return;
      }
      String url =
          "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(text)}&key=${AppKeys.mapKey}&components=country:in";

      Response res = await Dio().get(url);

      if (res.statusCode == 200) {
        var placePrediction = res.data["predictions"];

        var predictedPlacesList = (placePrediction as List)
            .map((e) => PredictedPlaces.fromJson(e))
            .toList();

        ref
            .read(whereToPredictedPlacesProvider.notifier)
            .update((state) => predictedPlacesList);
      } else {
        print("PredictedPlacesRepo: Received non-200 status ${res.statusCode}");
      }
    } catch (e) {
      print("PredictedPlacesRepo error: $e");
    }
  }
}

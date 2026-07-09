import 'package:flutter_riverpod/flutter_riverpod.dart';

// Delivery type: 'bike' or 'truck'
final parcelDeliveryTypeProvider = StateProvider<String?>((ref) => null);

// Sender address
final parcelSenderAddressProvider = StateProvider<String>((ref) => '');

// Receiver address
final parcelReceiverAddressProvider = StateProvider<String>((ref) => '');

// Receiver phone number
final parcelReceiverPhoneProvider = StateProvider<String>((ref) => '');

// Package description
final parcelDescriptionProvider = StateProvider<String>((ref) => '');

// Package weight selection
final parcelWeightProvider = StateProvider<String>((ref) => '1-2 kg');

// Estimated price based on delivery type and weight
final parcelEstimatedPriceProvider = Provider<double>((ref) {
  final deliveryType = ref.watch(parcelDeliveryTypeProvider);
  final weight = ref.watch(parcelWeightProvider);
  
  double basePrice = deliveryType == 'bike' ? 30 : 100;
  
  // Weight multiplier
  double weightMultiplier = 1.0;
  switch (weight) {
    case '1-2 kg':
      weightMultiplier = 1.0;
      break;
    case '2-5 kg':
      weightMultiplier = 1.2;
      break;
    case '5-10 kg':
      weightMultiplier = 1.5;
      break;
    case '10-20 kg':
      weightMultiplier = 2.0;
      break;
    case '20+ kg':
      weightMultiplier = 2.5;
      break;
  }
  
  return basePrice * weightMultiplier;
});

// Parcel booking status
final parcelBookingLoadingProvider = StateProvider<bool>((ref) => false);

// Active parcel delivery (when a driver is assigned)
final activeParcelDeliveryProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

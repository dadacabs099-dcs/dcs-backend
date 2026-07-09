import 'package:Dadacabs/Container/utils/keys.dart';

class VehicleTypeModel {
  final String id;
  final String name; // Firestore field: "vehicle" or "name"
  final String? imageUrl; // Firestore field: "image"
  final bool isActive;
  final double baseFare;
  final double perKmRate;
  final double perMinuteRate;
  final double minimumFare;
  final int capacity;

  const VehicleTypeModel({
    required this.id,
    required this.name,
    this.imageUrl,
    this.isActive = true,
    this.baseFare = 0.0,
    this.perKmRate = 0.0,
    this.perMinuteRate = 0.0,
    this.minimumFare = 0.0,
    this.capacity = 4,
  });

  // Modified by Jayant Pandit on 2026-07-09 18:00:00
  // Reason: Vehicle images in Firestore store relative paths (e.g. "/Auto.webp").
  // This getter prepends the Firebase Hosting base URL to make a valid absolute URL.
  String? get fullImageUrl {
    if (imageUrl == null || imageUrl!.isEmpty) return null;
    if (imageUrl!.startsWith('http://') || imageUrl!.startsWith('https://')) return imageUrl;
    final path = imageUrl!.startsWith('/') ? imageUrl! : '/$imageUrl';
    return '${AppKeys.vehicleImageBaseUrl}$path';
  }

  factory VehicleTypeModel.fromMap(Map<String, dynamic> data, String id) {
    // Modified by Jayant Pandit on 2026-07-11 10:00:00
    // Reason: Check multiple possible Firestore field names for vehicle image URL
    // to handle varying document schemas across vehicleTypes collection
    final dynamic rawImage = data['image']
        ?? data['imageUrl']
        ?? data['img']
        ?? data['imagePath']
        ?? data['vehicleImage']
        ?? data['icon']
        ?? data['photo']
        ?? data['imageURL'];
    final String? imageUrl = rawImage?.toString();
    if (imageUrl != null && imageUrl.isNotEmpty) {
      print('VEHICLE_IMAGE: id=$id field_image=$imageUrl');
    }
    return VehicleTypeModel(
      id: id,
      name: data['vehicle'] ?? data['name'] ?? 'Unknown',
      imageUrl: imageUrl,
      // Modified by Jayant Pandit on 2026-07-11 10:00:00
      // Reason: Default isActive to true if field is missing, so vehicles are shown even if field absent
      isActive: data['isActive'] == true || data['isActive'] == 'true' || data['isActive'] == 1 || !data.containsKey('isActive'),
      baseFare: (data['baseFare'] ?? 0.0).toDouble(),
      perKmRate: (data['perKmRate'] ?? data['perKm'] ?? 0.0).toDouble(),
      perMinuteRate: (data['perMinuteRate'] ?? data['perMinute'] ?? 0.0).toDouble(),
      minimumFare: (data['minimumFare'] ?? 0.0).toDouble(),
      capacity: (data['capacity'] ?? 4).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'isActive': isActive,
      'baseFare': baseFare,
      'perKmRate': perKmRate,
      'perMinuteRate': perMinuteRate,
      'minimumFare': minimumFare,
      'capacity': capacity,
    };
  }

  /// Default configurations — reasonable fare values for display
  /// Used when Firestore data is not available
  static List<VehicleTypeModel> get defaults => const [
        VehicleTypeModel(id: 'bike', name: 'Bike', capacity: 1, baseFare: 20, perKmRate: 8, perMinuteRate: 1.5, minimumFare: 30),
        VehicleTypeModel(id: 'auto', name: 'Auto', capacity: 3, baseFare: 30, perKmRate: 12, perMinuteRate: 2, minimumFare: 50),
        VehicleTypeModel(id: 'economy', name: 'Sedan', capacity: 4, baseFare: 40, perKmRate: 15, perMinuteRate: 2.5, minimumFare: 70),
        VehicleTypeModel(id: 'premium', name: 'Premium', capacity: 4, baseFare: 60, perKmRate: 20, perMinuteRate: 3, minimumFare: 100),
        VehicleTypeModel(id: 'xl', name: 'SUV', capacity: 6, baseFare: 80, perKmRate: 25, perMinuteRate: 3.5, minimumFare: 130),
        VehicleTypeModel(id: 'van', name: 'Van', capacity: 8, baseFare: 100, perKmRate: 30, perMinuteRate: 4, minimumFare: 160),
      ];
}

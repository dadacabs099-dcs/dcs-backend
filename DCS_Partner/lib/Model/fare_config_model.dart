/// Fare Configuration Model for Partner App
/// Represents zone-based pricing (Dadacabs-style base fare structure)
class FareConfigModel {
  final String id;
  final String zoneId;
  final String zoneName;
  final String vehicleType;
  final double baseFare;
  final double baseDistance;      // km covered by base fare
  final double perKmRate;        // rate per km after base distance
  final double perMinuteRate;    // rate per minute of ride
  final double minimumFare;
  final double waitingCharge;    // per minute after free time
  final double freeWaitingTime;  // free waiting minutes
  final double surgeMultiplier;
  final double maxSurgeMultiplier;
  final bool surgeEnabled;
  // Captain (Driver) earning
  final double captainBaseFare;
  final double captainPerKmRate;
  final double captainPerMinuteRate;
  // Fare Fix Routes
  final List<Map<String, dynamic>> fareFixRoutes;
  // Feature flags
  final bool enableAirportRide;
  final bool enableOutstationRide;
  final bool isActive;

  const FareConfigModel({
    required this.id,
    required this.zoneId,
    required this.zoneName,
    required this.vehicleType,
    this.baseFare = 0.0,
    this.baseDistance = 2.0,
    this.perKmRate = 0.0,
    this.perMinuteRate = 0.0,
    this.minimumFare = 0.0,
    this.waitingCharge = 0.0,
    this.freeWaitingTime = 3.0,
    this.surgeMultiplier = 1.0,
    this.maxSurgeMultiplier = 3.0,
    this.surgeEnabled = false,
    this.captainBaseFare = 0.0,
    this.captainPerKmRate = 0.0,
    this.captainPerMinuteRate = 0.0,
    this.fareFixRoutes = const [],
    this.enableAirportRide = false,
    this.enableOutstationRide = false,
    this.isActive = true,
  });

  factory FareConfigModel.fromMap(Map<String, dynamic> data, String id) {
    return FareConfigModel(
      id: id,
      zoneId: data['zoneId'] ?? '',
      zoneName: data['zoneName'] ?? '',
      vehicleType: data['vehicleType'] ?? '',
      baseFare: (data['baseFare'] ?? 0.0).toDouble(),
      baseDistance: (data['baseDistance'] ?? 2.0).toDouble(),
      perKmRate: (data['perKmRate'] ?? 0.0).toDouble(),
      perMinuteRate: (data['perMinuteRate'] ?? 0.0).toDouble(),
      minimumFare: (data['minimumFare'] ?? 0.0).toDouble(),
      waitingCharge: (data['waitingCharge'] ?? 0.0).toDouble(),
      freeWaitingTime: (data['freeWaitingTime'] ?? 3.0).toDouble(),
      surgeMultiplier: (data['surgeMultiplier'] ?? 1.0).toDouble(),
      maxSurgeMultiplier: (data['maxSurgeMultiplier'] ?? 3.0).toDouble(),
      surgeEnabled: data['surgeEnabled'] ?? false,
      captainBaseFare: (data['captainBaseFare'] ?? 0.0).toDouble(),
      captainPerKmRate: (data['captainPerKmRate'] ?? 0.0).toDouble(),
      captainPerMinuteRate: (data['captainPerMinuteRate'] ?? 0.0).toDouble(),
      fareFixRoutes: (data['fareFixRoutes'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e)).toList(),
      enableAirportRide: data['enableAirportRide'] ?? false,
      enableOutstationRide: data['enableOutstationRide'] ?? false,
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'zoneId': zoneId,
      'zoneName': zoneName,
      'vehicleType': vehicleType,
      'baseFare': baseFare,
      'baseDistance': baseDistance,
      'perKmRate': perKmRate,
      'perMinuteRate': perMinuteRate,
      'minimumFare': minimumFare,
      'waitingCharge': waitingCharge,
      'freeWaitingTime': freeWaitingTime,
      'surgeMultiplier': surgeMultiplier,
      'maxSurgeMultiplier': maxSurgeMultiplier,
      'surgeEnabled': surgeEnabled,
      'captainBaseFare': captainBaseFare,
      'captainPerKmRate': captainPerKmRate,
      'captainPerMinuteRate': captainPerMinuteRate,
      'fareFixRoutes': fareFixRoutes,
      'enableAirportRide': enableAirportRide,
      'enableOutstationRide': enableOutstationRide,
      'isActive': isActive,
    };
  }

  /// Calculate fare using Dadacabs-style formula
  double calculateFare({
    required double distanceKm,
    double durationMinutes = 0,
    double waitingMinutes = 0,
  }) {
    double distanceFare = 0;
    if (distanceKm > baseDistance) {
      distanceFare = (distanceKm - baseDistance) * perKmRate;
    }
    double timeFare = durationMinutes * perMinuteRate;
    double waitingFare = 0;
    if (waitingMinutes > freeWaitingTime) {
      waitingFare = (waitingMinutes - freeWaitingTime) * waitingCharge;
    }
    double subtotal = baseFare + distanceFare + timeFare + waitingFare;
    double total = subtotal * surgeMultiplier;
    if (total < minimumFare) total = minimumFare;
    return double.parse(total.toStringAsFixed(0));
  }

  /// Get fare info text for display
  String get fareInfoText => '₹${baseFare.toInt()} base • ${baseDistance.toInt()}km included • ₹$perKmRate/km after';
  
  /// Check if a fixed fare route exists between two locations
  String? getFixedFare(String from, String to) {
    for (final route in fareFixRoutes) {
      if (route['isActive'] == false) continue;
      final routeFrom = (route['fromLocation'] ?? '').toString().toLowerCase();
      final routeTo = (route['toLocation'] ?? '').toString().toLowerCase();
      if ((from.toLowerCase().contains(routeFrom) || routeFrom.contains(from.toLowerCase())) &&
          (to.toLowerCase().contains(routeTo) || routeTo.contains(to.toLowerCase()))) {
        return route['customerFare']?.toString();
      }
    }
    return null;
  }
  
  /// Calculate captain earning for a trip
  double calculateCaptainEarning({
    required double distanceKm,
    double durationMinutes = 0,
    double waitingMinutes = 0,
  }) {
    if (captainBaseFare == 0 && captainPerKmRate == 0) return 0;
    
    double distanceFare = distanceKm * captainPerKmRate;
    double timeFare = durationMinutes * captainPerMinuteRate;
    double subtotal = captainBaseFare + distanceFare + timeFare;
    double total = subtotal * surgeMultiplier;
    if (total < captainBaseFare) total = captainBaseFare;
    return double.parse(total.toStringAsFixed(0));
  }
}
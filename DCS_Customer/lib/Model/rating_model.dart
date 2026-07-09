// ignore_for_file: public_member_api_docs, sort_constructors_first

/// [RatingModel] represents a rating/review in the system
class RatingModel {
  String ratingId;
  String tripId;
  String fromUserId;
  String toUserId;
  String fromUserType; // 'rider' or 'driver'
  String toUserType;   // 'rider' or 'driver'
  
  double rating;       // 1-5 stars
  String? review;
  List<String>? tags;  // Predefined tags like 'Clean car', 'Good driver', etc.
  
  DateTime createdAt;
  DateTime? updatedAt;
  
  // Additional feedback
  bool? wouldRecommend;
  String? improvementSuggestion;

  RatingModel({
    required this.ratingId,
    required this.tripId,
    required this.fromUserId,
    required this.toUserId,
    required this.fromUserType,
    required this.toUserType,
    required this.rating,
    this.review,
    this.tags,
    required this.createdAt,
    this.updatedAt,
    this.wouldRecommend,
    this.improvementSuggestion,
  });

  Map<String, dynamic> toJson() {
    return {
      'ratingId': ratingId,
      'tripId': tripId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'fromUserType': fromUserType,
      'toUserType': toUserType,
      'rating': rating,
      'review': review,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'wouldRecommend': wouldRecommend,
      'improvementSuggestion': improvementSuggestion,
    };
  }

  factory RatingModel.fromJson(Map<String, dynamic> json) {
    return RatingModel(
      ratingId: json['ratingId'] ?? '',
      tripId: json['tripId'] ?? '',
      fromUserId: json['fromUserId'] ?? '',
      toUserId: json['toUserId'] ?? '',
      fromUserType: json['fromUserType'] ?? 'rider',
      toUserType: json['toUserType'] ?? 'driver',
      rating: json['rating']?.toDouble() ?? 5.0,
      review: json['review'],
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      wouldRecommend: json['wouldRecommend'],
      improvementSuggestion: json['improvementSuggestion'],
    );
  }

  /// Get star rating as emoji string
  String get starRating {
    return '★' * rating.round() + '☆' * (5 - rating.round());
  }

  /// Get rating text
  String get ratingText {
    if (rating >= 4.5) return 'Excellent';
    if (rating >= 4.0) return 'Very Good';
    if (rating >= 3.0) return 'Good';
    if (rating >= 2.0) return 'Fair';
    return 'Poor';
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
// ignore_for_file: public_member_api_docs, sort_constructors_first

/// [UserModel] represents a user/rider in the system
class UserModel {
  String uid;
  String name;
  String email;
  String phone;
  String? profileImage;
  String? homeAddress;
  String? workAddress;
  String? gender;
  DateTime createdAt;
  DateTime? lastLoginAt;
  bool isActive;
  List<String>? paymentMethods;
  double? walletBalance;
  int totalRides;
  double rating;
  String? preferredPaymentMethod;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    this.profileImage,
    this.homeAddress,
    this.workAddress,
    this.gender,
    required this.createdAt,
    this.lastLoginAt,
    this.isActive = true,
    this.paymentMethods,
    this.walletBalance = 0.0,
    this.totalRides = 0,
    this.rating = 5.0,
    this.preferredPaymentMethod = 'cash',
  });

  /// Convert UserModel to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'profileImage': profileImage,
      'homeAddress': homeAddress,
      'workAddress': workAddress,
      'gender': gender,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'isActive': isActive,
      'paymentMethods': paymentMethods,
      'walletBalance': walletBalance,
      'totalRides': totalRides,
      'rating': rating,
      'preferredPaymentMethod': preferredPaymentMethod,
    };
  }

  /// Create UserModel from Firestore JSON
  factory UserModel.fromJson(Map<String, dynamic> json, [String? id]) {
    DateTime parseDate(dynamic date) {
      if (date == null) return DateTime.now();
      if (date is Timestamp) return date.toDate();
      if (date is String) return DateTime.tryParse(date) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseDateNullable(dynamic date) {
      if (date == null) return null;
      if (date is Timestamp) return date.toDate();
      if (date is String) return DateTime.tryParse(date);
      return null;
    }

    return UserModel(
      uid: id ?? json['uid'] ?? '',
      name: json['name'] ?? json['Full Name'] ?? json['userName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? json['mobile'] ?? json['phoneNumber'] ?? json['Full Number'] ?? '',
      profileImage: json['profileImage'],
      homeAddress: json['homeAddress'],
      workAddress: json['workAddress'],
      gender: json['gender'],
      createdAt: parseDate(json['createdAt']),
      lastLoginAt: parseDateNullable(json['lastLoginAt']),
      isActive: json['isActive'] ?? true,
      paymentMethods: json['paymentMethods'] != null 
          ? List<String>.from(json['paymentMethods']) 
          : null,
      // Modified by Jayant Pandit on 2026-05-18 20:12:00
      // Reason: Parse walletBalance, totalRides, and rating safely to avoid type casting exceptions if strings are stored in Firestore
      walletBalance: double.tryParse(json['walletBalance']?.toString() ?? '0.0') ?? 0.0,
      totalRides: int.tryParse(json['totalRides']?.toString() ?? '0') ?? 0,
      rating: double.tryParse(json['rating']?.toString() ?? '5.0') ?? 5.0,
      preferredPaymentMethod: json['preferredPaymentMethod'] ?? 'cash',
    );
  }

  /// Create a copy of UserModel with updated fields
  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone,
    String? profileImage,
    String? homeAddress,
    String? workAddress,
    String? gender,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isActive,
    List<String>? paymentMethods,
    double? walletBalance,
    int? totalRides,
    double? rating,
    String? preferredPaymentMethod,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profileImage: profileImage ?? this.profileImage,
      homeAddress: homeAddress ?? this.homeAddress,
      workAddress: workAddress ?? this.workAddress,
      gender: gender ?? this.gender,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      walletBalance: walletBalance ?? this.walletBalance,
      totalRides: totalRides ?? this.totalRides,
      rating: rating ?? this.rating,
      preferredPaymentMethod: preferredPaymentMethod ?? this.preferredPaymentMethod,
    );
  }
}

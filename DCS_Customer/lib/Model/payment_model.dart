// ignore_for_file: public_member_api_docs, sort_constructors_first

/// PaymentStatus enum
enum PaymentStatus {
  pending,
  completed,
  failed,
  refunded,
}

/// PaymentMethod enum
enum PaymentMethodType {
  cash,
  card,
  wallet,
  upi,
}

/// [PaymentModel] represents a payment transaction
class PaymentModel {
  String paymentId;
  String tripId;
  String userId;
  String? driverId;
  
  double amount;
  double? discountApplied;
  double finalAmount;
  
  PaymentMethodType method;
  PaymentStatus status;
  
  DateTime createdAt;
  DateTime? completedAt;
  
  // Card/UPI details (masked)
  String? paymentMethodLast4;
  String? paymentMethodBrand; // visa, mastercard, etc.
  
  // Transaction IDs
  String? gatewayTransactionId;
  String? receiptUrl;
  
  // Refund details
  double? refundAmount;
  DateTime? refundedAt;
  String? refundReason;

  PaymentModel({
    required this.paymentId,
    required this.tripId,
    required this.userId,
    this.driverId,
    required this.amount,
    this.discountApplied,
    required this.finalAmount,
    this.method = PaymentMethodType.cash,
    this.status = PaymentStatus.pending,
    required this.createdAt,
    this.completedAt,
    this.paymentMethodLast4,
    this.paymentMethodBrand,
    this.gatewayTransactionId,
    this.receiptUrl,
    this.refundAmount,
    this.refundedAt,
    this.refundReason,
  });

  Map<String, dynamic> toJson() {
    return {
      'paymentId': paymentId,
      'tripId': tripId,
      'userId': userId,
      'driverId': driverId,
      'amount': amount,
      'discountApplied': discountApplied,
      'finalAmount': finalAmount,
      'method': method.name,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'paymentMethodLast4': paymentMethodLast4,
      'paymentMethodBrand': paymentMethodBrand,
      'gatewayTransactionId': gatewayTransactionId,
      'receiptUrl': receiptUrl,
      'refundAmount': refundAmount,
      'refundedAt': refundedAt?.toIso8601String(),
      'refundReason': refundReason,
    };
  }

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      paymentId: json['paymentId'] ?? '',
      tripId: json['tripId'] ?? '',
      userId: json['userId'] ?? '',
      driverId: json['driverId'],
      amount: json['amount']?.toDouble() ?? 0.0,
      discountApplied: json['discountApplied']?.toDouble(),
      finalAmount: json['finalAmount']?.toDouble() ?? 0.0,
      method: PaymentMethodType.values.firstWhere(
        (e) => e.name == json['method'],
        orElse: () => PaymentMethodType.cash,
      ),
      status: PaymentStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PaymentStatus.pending,
      ),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
      paymentMethodLast4: json['paymentMethodLast4'],
      paymentMethodBrand: json['paymentMethodBrand'],
      gatewayTransactionId: json['gatewayTransactionId'],
      receiptUrl: json['receiptUrl'],
      refundAmount: json['refundAmount']?.toDouble(),
      refundedAt: json['refundedAt'] != null ? DateTime.parse(json['refundedAt']) : null,
      refundReason: json['refundReason'],
    );
  }

  String get methodDisplay {
    switch (method) {
      case PaymentMethodType.cash:
        return 'Cash';
      case PaymentMethodType.card:
        return 'Card';
      case PaymentMethodType.wallet:
        return 'Wallet';
      case PaymentMethodType.upi:
        return 'UPI';
    }
  }

  String get statusDisplay {
    switch (status) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.completed:
        return 'Completed';
      case PaymentStatus.failed:
        return 'Failed';
      case PaymentStatus.refunded:
        return 'Refunded';
    }
  }
}

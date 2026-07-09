// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Dadacabs/Model/payment_model.dart';
import 'package:Dadacabs/Container/utils/error_notification.dart';

final globalPaymentRepoProvider = Provider<PaymentRepo>((ref) {
  return PaymentRepo();
});

/// [PaymentRepo] handles all payment operations
class PaymentRepo {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'payments';

  /// Create a new payment record
  Future<String?> createPayment(
    PaymentModel payment,
    BuildContext context,
  ) async {
    try {
      await _db.collection(_collection).doc(payment.paymentId).set(
            payment.toJson(),
          );
      return payment.paymentId;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(
            context, "Failed to create payment: $e");
      }
      return null;
    }
  }

  /// Get payment by ID
  Future<PaymentModel?> getPayment(
    String paymentId,
    BuildContext context,
  ) async {
    try {
      DocumentSnapshot<Map<String, dynamic>> doc =
          await _db.collection(_collection).doc(paymentId).get();

      if (doc.exists && doc.data() != null) {
        return PaymentModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(
            context, "Failed to get payment: $e");
      }
      return null;
    }
  }

  /// Get payment by trip ID
  Future<PaymentModel?> getPaymentByTrip(
    String tripId,
    BuildContext context,
  ) async {
    try {
      QuerySnapshot<Map<String, dynamic>> query = await _db
          .collection(_collection)
          .where('tripId', isEqualTo: tripId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return PaymentModel.fromJson(query.docs.first.data());
      }
      return null;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(
            context, "Failed to get payment: $e");
      }
      return null;
    }
  }

  /// Get user's payment history
  Stream<List<PaymentModel>> getUserPayments(String userId) {
    return _db
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PaymentModel.fromJson(doc.data()))
          .toList();
    });
  }

  /// Update payment status
  Future<bool> updatePaymentStatus(
    String paymentId,
    PaymentStatus status,
    BuildContext context,
  ) async {
    try {
      Map<String, dynamic> update = {'status': status.name};

      if (status == PaymentStatus.completed) {
        update['completedAt'] = DateTime.now().toIso8601String();
      }

      await _db.collection(_collection).doc(paymentId).update(update);
      return true;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(
            context, "Failed to update payment: $e");
      }
      return false;
    }
  }

  /// Process refund
  Future<bool> processRefund(
    String paymentId,
    double amount,
    String reason,
    BuildContext context,
  ) async {
    try {
      await _db.collection(_collection).doc(paymentId).update({
        'status': 'refunded',
        'refundAmount': amount,
        'refundedAt': DateTime.now().toIso8601String(),
        'refundReason': reason,
      });
      return true;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(
            context, "Failed to process refund: $e");
      }
      return false;
    }
  }

  /// Get wallet transactions (payments with method = 'wallet')
  Stream<List<PaymentModel>> getWalletTransactions(String userId) {
    return _db
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('method', isEqualTo: 'wallet')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PaymentModel.fromJson(doc.data()))
          .toList();
    });
  }

  /// Calculate total spending for a user
  Future<double> getTotalSpending(String userId, BuildContext context) async {
    try {
      QuerySnapshot<Map<String, dynamic>> query = await _db
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .get();

      double total = 0.0;
      for (var doc in query.docs) {
        total += doc.data()['finalAmount']?.toDouble() ?? 0.0;
      }
      return total;
    } catch (e) {
      return 0.0;
    }
  }

  /// Add money to wallet
  Future<bool> addToWallet(
    String userId,
    double amount,
    String paymentMethod,
    BuildContext context,
  ) async {
    try {
      final payment = PaymentModel(
        paymentId: 'wallet_${DateTime.now().millisecondsSinceEpoch}',
        tripId: '', // No trip for wallet top-up
        userId: userId,
        amount: -amount, // Negative because it's adding money
        finalAmount: -amount,
        method: PaymentMethodType.values.firstWhere(
          (m) => m.name == paymentMethod,
          orElse: () => PaymentMethodType.card,
        ),
        status: PaymentStatus.completed,
        createdAt: DateTime.now(),
        completedAt: DateTime.now(),
      );

      await createPayment(payment, context);
      return true;
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(
            context, "Failed to add to wallet: $e");
      }
      return false;
    }
  }
}

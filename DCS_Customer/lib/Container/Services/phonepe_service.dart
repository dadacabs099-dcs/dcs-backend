import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:phonepe_payment_sdk/phonepe_payment_sdk.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PhonePeService {
  // CONFIGURATION (In production, these should be securely fetched or handled via backend)
  static const String merchantId = "PGCHECKOUT"; // Sandbox Merchant ID
  static const String saltKey = "099eb0cd-02cf-4e2a-8aca-3e6c6aff0399"; // Sandbox Salt Key
  static const String saltIndex = "1";
  static const String appId = ""; // Optional for Android, required for iOS sometimes
  static const String environment = "SANDBOX"; // SANDBOX or PRODUCTION

  Future<bool> initSDK() async {
    try {
      bool isInitialized = await PhonePePaymentSdk.init(
        environment,
        appId,
        merchantId,
        true, // Logging enabled
      );
      return isInitialized;
    } catch (e) {
      print("PhonePe SDK Init Error: $e");
      return false;
    }
  }

  /// Get list of installed UPI apps on the device
  Future<List<dynamic>> getUpiApps() async {
    try {
      if (Platform.isAndroid) {
        final appsStr = await PhonePePaymentSdk.getUpiAppsForAndroid();
        if (appsStr != null && appsStr.isNotEmpty) {
          return json.decode(appsStr) as List<dynamic>;
        }
      } else if (Platform.isIOS) {
        final apps = await PhonePePaymentSdk.getInstalledUpiAppsForiOS();
        return apps ?? [];
      }
      return [];
    } catch (e) {
      print("Error fetching UPI apps: $e");
      return [];
    }
  }

  /// Initiates a payment.
  /// Note: In production, the payload and checksum MUST be generated on your server.
  Future<Map<dynamic, dynamic>?> startTransaction({
    required String transactionId,
    required double amount,
    required String userId,
    required String mobileNumber,
  }) async {
    try {
      // 1. Create Body Payload
      final requestBody = {
        "merchantId": merchantId,
        "merchantTransactionId": transactionId,
        "merchantUserId": userId,
        "amount": (amount * 100).toInt(), // PhonePe takes amount in paise
        "callbackUrl": "https://webhook.site/callback-url", // Replace with your real backend callback
        "mobileNumber": mobileNumber,
        "paymentInstrument": {"type": "PAY_PAGE"}
      };

      String base64Body = base64.encode(utf8.encode(json.encode(requestBody)));

      // 2. Generate Checksum (MANDATORY: DO THIS ON BACKEND FOR PRODUCTION)
      String checksum = _generateChecksum(base64Body, "/pg/v1/pay");

      // 3. Start Transaction
      final response = await PhonePePaymentSdk.startTransaction(
        base64Body,
        "", // appSchema
      );

      return response;
    } catch (e) {
      print("PhonePe Transaction Error: $e");
      return null;
    }
  }

  /// Initiates a transaction with a specific UPI app or VPA
  Future<Map<dynamic, dynamic>?> startUpiTransaction({
    required String transactionId,
    required double amount,
    required String userId,
    required String mobileNumber,
    String? packageName, // For App Intent (GPay, PhonePe, etc.)
    String? vpa, // For UPI Collect
  }) async {
    try {
      final Map<String, dynamic> paymentInstrument;
      
      if (vpa != null) {
        paymentInstrument = {
          "type": "UPI_COLLECT",
          "vpa": vpa,
        };
      } else if (packageName != null) {
        paymentInstrument = {
          "type": "UPI_INTENT",
          "targetApp": packageName,
        };
      } else {
        paymentInstrument = {"type": "PAY_PAGE"};
      }

      final requestBody = {
        "merchantId": merchantId,
        "merchantTransactionId": transactionId,
        "merchantUserId": userId,
        "amount": (amount * 100).toInt(),
        "callbackUrl": "https://webhook.site/callback-url",
        "mobileNumber": mobileNumber,
        "paymentInstrument": paymentInstrument
      };

      String base64Body = base64.encode(utf8.encode(json.encode(requestBody)));
      String checksum = _generateChecksum(base64Body, "/pg/v1/pay");

      final response = await PhonePePaymentSdk.startTransaction(
        base64Body,
        "", // appSchema
      );

      return response;
    } catch (e) {
      print("PhonePe UPI Transaction Error: $e");
      return null;
    }
  }

  String _generateChecksum(String base64Body, String apiPath) {
    // Checksum = sha256(base64Payload + apiPath + saltKey) + "###" + saltIndex
    String rawData = base64Body + apiPath + saltKey;
    var bytes = utf8.encode(rawData);
    var digest = sha256.convert(bytes);
    return "$digest###$saltIndex";
  }
}

final phonePeServiceProvider = Provider((ref) => PhonePeService());

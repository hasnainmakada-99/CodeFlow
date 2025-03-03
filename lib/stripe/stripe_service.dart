import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:codeflow/modals/courses_modal.dart';

class StripeService {
  // Your Stripe publishable key - use test key for development
  static const String _publishableKey = 'pk_test_YOUR_PUBLISHABLE_KEY';

  // Your backend API URL
  static const String _apiUrl = 'https://codeflow-api.onrender.com/api';

  // Initialize Stripe in your app's main.dart
  static Future<void> initialize() async {
    Stripe.publishableKey = _publishableKey;
    await Stripe.instance.applySettings();
  }

  // Start the payment flow
  static Future<bool> makePayment({
    required BuildContext context,
    required Courses course,
    required String userId,
  }) async {
    try {
      // 1. Create payment intent on the server
      final paymentIntentData = await _createPaymentIntent(
        amount: course.price.toString(),
        currency: 'usd', // Change according to your needs
        courseId: course.id,
        userId: userId,
      );

      if (paymentIntentData == null) {
        _showPaymentFailureDialog(context, 'Failed to create payment intent');
        return false;
      }

      // 2. Initialize payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntentData['clientSecret'],
          merchantDisplayName: 'CodeFlow Learning',
          customerId: paymentIntentData['customer'],
          customerEphemeralKeySecret: paymentIntentData['ephemeralKey'],
          style: ThemeMode.system,
        ),
      );

      // 3. Present payment sheet to user
      await Stripe.instance.presentPaymentSheet();

      // 4. Payment successful
      await _recordSuccessfulPurchase(course.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment completed successfully!')),
      );
      return true;
    } catch (e) {
      if (e is StripeException) {
        if (e.error.code == StripeException.) {
          // User canceled, no need to show error
          return false;
        }
        _showPaymentFailureDialog(
            context, e.error.localizedMessage ?? 'Payment failed');
      } else {
        _showPaymentFailureDialog(context, 'An unexpected error occurred: $e');
      }
      return false;
    }
  }

  // Create payment intent on the backend
  static Future<Map<String, dynamic>?> _createPaymentIntent({
    required String amount,
    required String currency,
    required String courseId,
    required String userId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken') ?? '';

      final response = await http.post(
        Uri.parse('$_apiUrl/create-payment-intent'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'amount': amount,
          'currency': currency,
          'courseId': courseId,
          'userId': userId,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Error creating payment intent: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception creating payment intent: $e');
      return null;
    }
  }

  // Save the course as purchased
  static Future<void> _recordSuccessfulPurchase(String courseId) async {
    final prefs = await SharedPreferences.getInstance();
    final purchasedCourses = prefs.getStringList('purchasedCourses') ?? [];

    if (!purchasedCourses.contains(courseId)) {
      purchasedCourses.add(courseId);
      await prefs.setStringList('purchasedCourses', purchasedCourses);
    }
  }

  // Check if a course has been purchased
  static Future<bool> isCoursePurchased(String courseId) async {
    final prefs = await SharedPreferences.getInstance();
    final purchasedCourses = prefs.getStringList('purchasedCourses') ?? [];
    return purchasedCourses.contains(courseId);
  }

  // Show an error dialog
  static void _showPaymentFailureDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

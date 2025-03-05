import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class SimpleUpiService {
  static Future<void> showPaymentQRBottomSheet({
    required BuildContext context,
    required String receiverUpiId,
    required String receiverName,
    required String courseTitle,
    required String amount,
    Function? onDismissed, // Add callback for when sheet is dismissed
    Function? onPaymentComplete, // Add callback for when payment is complete
  }) async {
    // Generate UPI payment link
    final upiUrl = _generateUpiUrl(
      receiverUpiId: receiverUpiId,
      receiverName: receiverName,
      transactionNote: "Payment for $courseTitle",
      amount: amount,
    );

    // Show bottom sheet with QR code
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async {
            // Handle back button press
            if (onDismissed != null) {
              onDismissed();
            }
            return true;
          },
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Scan to Pay",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  QrImageView(
                    data: upiUrl,
                    version: QrVersions.auto,
                    size: 200,
                  ),
                  const SizedBox(height: 20),
                  Text("Course: $courseTitle"),
                  Text("Amount: ₹$amount"),
                  const SizedBox(height: 20),
                  const Text(
                    "1. Open any UPI app\n2. Scan this QR code\n3. Complete the payment",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          // Call dismissal callback if provided
                          if (onDismissed != null) {
                            onDismissed();
                          }
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[400],
                        ),
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // Call payment complete callback if provided
                          if (onPaymentComplete != null) {
                            onPaymentComplete();
                          }
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                        ),
                        child: const Text("I've Paid"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      // If the sheet is dismissed by tapping outside
      if (onDismissed != null) {
        onDismissed();
      }
    });
  }

  static Widget generateQRImage({
    required String receiverUpiId,
    required String receiverName,
    required String transactionNote,
    required String amount,
    double size = 200,
  }) {
    // Generate UPI payment URL
    final upiUrl = _generateUpiUrl(
      receiverUpiId: receiverUpiId,
      receiverName: receiverName,
      transactionNote: transactionNote,
      amount: amount,
    );

    // Create and return QR image
    return QrImageView(
      data: upiUrl,
      version: QrVersions.auto,
      size: size,
      backgroundColor: Colors.white,
      padding: const EdgeInsets.all(10),
    );
  }

  // Helper method to generate UPI URL
  static String _generateUpiUrl({
    required String receiverUpiId,
    required String receiverName,
    required String transactionNote,
    required String amount,
  }) {
    // Format according to UPI deep linking specification
    return 'upi://pay?pa=$receiverUpiId&pn=$receiverName&tn=$transactionNote&am=$amount&cu=INR';
  }
}

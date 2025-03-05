import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:codeflow/auth%20and%20cloud/auth_provider.dart';
import 'package:codeflow/auth%20and%20cloud/cloud_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:codeflow/upi/SimpleUpiPaymentService.dart';
import 'package:codeflow/modals/payment_modal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

class PaymentVerificationWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const PaymentVerificationWrapper({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  ConsumerState<PaymentVerificationWrapper> createState() =>
      _PaymentVerificationWrapperState();
}

class _PaymentVerificationWrapperState
    extends ConsumerState<PaymentVerificationWrapper> {
  bool _isVerifying = true;
  bool _hasPendingPayment = false;
  String? _courseTitle;
  String? _courseId;
  String? _price;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _checkPendingPayments();
  }

  Future<void> _checkPendingPayments() async {
    setState(() {
      _isVerifying = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('pending_payment_user_id');
      final courseId = prefs.getString('pending_payment_course_id');

      if (userId != null && courseId != null) {
        // We have a pending payment
        final currentUser = ref.read(authStateChangesProvider).value;

        // Make sure it's the same user
        if (currentUser != null && currentUser.uid == userId) {
          final title = prefs.getString('pending_payment_course_title') ??
              'Premium Course';
          final price = prefs.getString('pending_payment_price') ?? '0';

          // Check if payment already completed
          final isPaymentComplete = await ref
              .read(cloudProvider)
              .checkPaymentForCourse(userId, courseId);

          if (isPaymentComplete) {
            // Payment already complete, clear pending status
            await _clearPendingPayment();
          } else {
            setState(() {
              _hasPendingPayment = true;
              _courseTitle = title;
              _courseId = courseId;
              _price = price;
              _userId = userId;
            });
          }
        } else {
          // Different user - clear pending payment
          await _clearPendingPayment();
        }
      }
    } catch (e) {
      print('Error checking pending payments: $e');
    } finally {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  Future<void> _clearPendingPayment() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove('pending_payment_user_id');
      await prefs.remove('pending_payment_course_id');
      await prefs.remove('pending_payment_course_title');
      await prefs.remove('pending_payment_price');
      await prefs.remove('pending_payment_timestamp');

      print('Cleared pending payment');
    } catch (e) {
      print('Error clearing pending payment: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isVerifying) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                'Verifying account status...',
                style: GoogleFonts.poppins(),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasPendingPayment && _courseId != null && _userId != null) {
      return _buildPendingPaymentScreen();
    }

    return widget.child;
  }

  Widget _buildPendingPaymentScreen() {
    return Scaffold(
      body: WillPopScope(
        onWillPop: () async => false, // Prevent back button
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Icon(
                  Icons.payment_rounded,
                  size: 80,
                  color: Colors.amber,
                ),
                const SizedBox(height: 24),
                Text(
                  'Complete Your Payment',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'You have a pending payment for $_courseTitle',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 3,
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Payment Details',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildPaymentDetail(
                          'Course', _courseTitle ?? 'Premium Course'),
                      _buildPaymentDetail('Price', '₹${_price ?? '0'}'),
                      _buildPaymentDetail('Status', 'Payment Required',
                          isHighlighted: true),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ElevatedButton(
                    onPressed: _resumePayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Complete Payment',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      // Show confirmation dialog
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => AlertDialog(
                          title: Text(
                            'Cancel Payment?',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold),
                          ),
                          content: Text(
                            'If you cancel, you will not be able to access this course. '
                            'Are you sure you want to cancel your payment?',
                            style: GoogleFonts.poppins(),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                'Continue Payment',
                                style: GoogleFonts.poppins(),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await _clearPendingPayment();
                                setState(() {
                                  _hasPendingPayment = false;
                                });
                              },
                              child: Text(
                                'Cancel Payment',
                                style: GoogleFonts.poppins(
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Text(
                      'Cancel Payment',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentDetail(String label, String value,
      {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: isHighlighted ? Colors.red : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resumePayment() async {
    if (_userId == null ||
        _courseId == null ||
        _courseTitle == null ||
        _price == null) {
      print('Missing payment information');
      return;
    }

    final completer = Completer<bool>();
    bool isVerifying = false;

    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false, // Prevent back button
          child: StatefulBuilder(
            builder: (context, setState) {
              // Start verification timer
              Timer? verificationTimer;

              void startVerificationLoop() {
                verificationTimer =
                    Timer.periodic(const Duration(seconds: 5), (timer) async {
                  if (!isVerifying) {
                    setState(() {
                      isVerifying = true;
                    });

                    try {
                      // Check if payment was verified on server side
                      final isVerified =
                          await _checkPaymentVerification(_userId!, _courseId!);

                      if (isVerified) {
                        // Payment verified, stop checking and proceed
                        verificationTimer?.cancel();
                        completer.complete(true);
                        Navigator.of(context).pop();
                      }
                    } catch (e) {
                      print('Error verifying payment: $e');
                    } finally {
                      if (mounted) {
                        setState(() {
                          isVerifying = false;
                        });
                      }
                    }
                  }
                });
              }

              // Start verification on build
              WidgetsBinding.instance.addPostFrameCallback((_) {
                startVerificationLoop();
              });

              // Clean up timer when dismissed
              Future.delayed(Duration.zero, () {
                if (ModalRoute.of(context)?.isCurrent == false) {
                  verificationTimer?.cancel();
                }
              });

              return Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Complete Payment",
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isVerifying)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SimpleUpiService.generateQRImage(
                      receiverUpiId: "hasnainmakada@ybl",
                      receiverName: "CodeFlow Courses",
                      transactionNote: "Payment for ${_courseTitle}",
                      amount: _price!,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Course: ${_courseTitle}",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Amount: ₹${_price}",
                      style: GoogleFonts.poppins(),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              Text(
                                "Payment Instructions",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "1. Open any UPI app (Google Pay, PhonePe, etc.)\n"
                            "2. Scan this QR code with your UPI app\n"
                            "3. Complete the payment process\n"
                            "4. Wait for automatic verification (don't close this screen)",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Verifying payment automatically...",
                      style: GoogleFonts.poppins(
                        fontStyle:
                            isVerifying ? FontStyle.normal : FontStyle.italic,
                        color: isVerifying ? Colors.blue : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isVerifying ? Colors.blue : Colors.blue.shade200,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          bool confirmed = await showDialog<bool>(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => AlertDialog(
                                  title: Text(
                                    'Cancel Payment?',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  content: Text(
                                    'You will not be able to access this premium course without payment. '
                                    'Are you sure you want to cancel?',
                                    style: GoogleFonts.poppins(),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: Text(
                                        'Continue Payment',
                                        style: GoogleFonts.poppins(),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: Text(
                                        'Yes, Cancel',
                                        style: GoogleFonts.poppins(
                                            color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              ) ??
                              false;

                          if (confirmed) {
                            verificationTimer?.cancel();
                            completer.complete(false);
                            Navigator.of(context).pop();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          "Cancel Payment",
                          style: GoogleFonts.poppins(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    // Handle completion
    final paymentSuccess = await completer.future;
    if (paymentSuccess) {
      // Payment successful, clear pending payment
      await _clearPendingPayment();
      setState(() {
        _hasPendingPayment = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment successful! You can now access the course.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<bool> _checkPaymentVerification(String userId, String courseId) async {
    try {
      // Check if payment exists in Firestore
      return await ref.read(cloudProvider).checkPaymentForCourse(
            userId,
            courseId,
          );
    } catch (e) {
      print('Error checking payment verification: $e');
      return false;
    }
  }
}

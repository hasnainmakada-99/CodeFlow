import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:codeflow/auth%20and%20cloud/auth_provider.dart';
import 'package:codeflow/auth%20and%20cloud/cloud_provider.dart';
import 'package:codeflow/modals/enrollments_modal.dart';
import 'package:codeflow/modals/payment_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:codeflow/upi/SimpleUpiPaymentService.dart';

class ResourceCard extends ConsumerStatefulWidget {
  final String imageUrl;
  final String title;
  final String description;
  final String shareLink;
  final String courseId;
  final String price; // Changed from int to String to match Courses model
  final bool isPaid; // Added to check if course is paid
  final Function navigateTo;

  const ResourceCard({
    Key? key,
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.shareLink,
    required this.courseId,
    required this.price,
    required this.isPaid,
    required this.navigateTo,
  }) : super(key: key);

  @override
  _ResourceCardState createState() => _ResourceCardState();
}

class _ResourceCardState extends ConsumerState<ResourceCard> {
  bool _isEnrolled = false;
  bool _hasPaymentVerified = false;
  bool _isLoading = false;
  bool _paymentInProgress = false;
  bool _paymentCancelled = false;
  int _userCourseCount = 0;
  Map<String, dynamic> _paymentStats = {'totalPayments': 0, 'totalSpent': 0.0};

  @override
  void initState() {
    super.initState();
    _checkEnrollmentStatus();
    _loadUserStats();
    // Debug logging
    print('ResourceCard initialized: ${widget.title}');
    print('isPaid: ${widget.isPaid}, price: ${widget.price}');
  }

  // Load user's course count and payment stats
  Future<void> _loadUserStats() async {
    final user = ref.read(authStateChangesProvider).value;
    if (user == null) return;

    try {
      final courseCount =
          await ref.read(cloudProvider).getUserCourseCount(user.uid);
      final stats = await ref.read(cloudProvider).getUserPaymentStats(user.uid);

      setState(() {
        _userCourseCount = courseCount;
        _paymentStats = stats;
      });

      print(
          'User Stats: Courses: $_userCourseCount, Payments: ${_paymentStats['totalPayments']}, Total Spent: ₹${_paymentStats['totalSpent']}');
    } catch (e) {
      print('Error loading user stats: $e');
    }
  }

  // Check if the user is enrolled and check payment status
  Future<void> _checkEnrollmentStatus() async {
    final user = ref.read(authStateChangesProvider).value;
    if (user != null) {
      try {
        // First check enrollment
        final isEnrolled = await ref
            .read(cloudProvider)
            .checkEnrollment(widget.courseId, user.uid);

        // For paid courses, also verify payment exists
        bool paymentVerified = false;
        if (isEnrolled && widget.isPaid && !_isFree) {
          // Check if there's a payment record in Firestore
          paymentVerified = await ref
              .read(cloudProvider)
              .checkPaymentForCourse(user.uid, widget.courseId);
        }

        setState(() {
          _isEnrolled = isEnrolled;
          _hasPaymentVerified = paymentVerified;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking enrollment status: $e')),
        );
      }
    }
  }

  // Record payment in Firestore
  Future<void> _recordPayment() async {
    final user = ref.read(authStateChangesProvider).value;
    if (user == null) return;

    try {
      // Generate a transaction ID (in a real app, this would come from the payment gateway)
      final transactionId = const Uuid().v4();

      // Create payment record
      final payment = Payment(
        paymentId: const Uuid().v4(),
        userId: user.uid,
        courseId: widget.courseId,
        courseTitle: widget.title,
        amount: double.tryParse(widget.price) ?? 0.0,
        paymentDate: DateTime.now(),
        transactionId: transactionId,
        paymentMethod: 'UPI',
        isVerified: true,
      );

      // Store payment in Firestore
      await ref.read(cloudProvider).recordPayment(payment);

      // Refresh user stats
      await _loadUserStats();

      print('Payment recorded: ${payment.paymentId}');
      return;
    } catch (e) {
      print('Error recording payment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error recording payment: $e')),
      );
      throw e;
    }
  }

  // Enroll the user in the course
  Future<void> _enrollInCourse() async {
    final user = ref.read(authStateChangesProvider).value;
    if (user != null) {
      try {
        setState(() {
          _isLoading = true; // Set loading state to true
        });

        // For paid courses, check if payment has been verified
        if (widget.isPaid && !_isFree && !_hasPaymentVerified) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment required before enrollment')),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }

        final enrollment = Enrollment(
          enrollmentId: const Uuid().v4(),
          courseId: widget.courseId,
          studentId: user.uid,
          enrollmentDate: DateTime.now(),
          // Add payment information for paid courses
          isPaid: widget.isPaid && !_isFree,
          paymentVerified: _hasPaymentVerified,
        );

        await ref.read(cloudProvider).enrollInCourse(enrollment);

        // Refresh user stats after enrollment
        await _loadUserStats();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully enrolled in ${widget.title}')),
        );

        setState(() {
          _isEnrolled = true;
          _isLoading = false; // Reset loading state
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to enroll: $e')),
        );
        setState(() {
          _isLoading = false; // Reset loading state
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to enroll')),
      );
    }
  }

  // Handle navigation with proper checks
  void _handleNavigation() {
    // If it's a paid course and user hasn't paid or enrolled
    if (widget.isPaid && !_isFree && !_hasPaymentVerified && !_isEnrolled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please pay for this course to access its content')),
      );
      return;
    }

    // Only allow navigation for free courses or paid+enrolled courses
    widget.navigateTo();
  }

  // Handle UPI payment
  // Change the _initiatePayment() method to make the payment process non-dismissible
  Future<void> _initiatePayment() async {
    print('Initiating payment for ${widget.title}');
    print('isPaid: ${widget.isPaid}, price: ${widget.price}');

    setState(() {
      _paymentInProgress = true;
      _paymentCancelled = false;
    });

    try {
      // Show payment confirmation dialog first
      final bool shouldProceed = await _showPaymentConfirmationDialog();
      if (!shouldProceed) {
        setState(() {
          _paymentInProgress = false;
          _paymentCancelled = true;
        });
        return;
      }

      // Store pending payment info in shared preferences for persistence across app restarts
      final user = ref.read(authStateChangesProvider).value;
      if (user != null) {
        await _storePendingPayment(
            user.uid, widget.courseId, widget.title, widget.price);
      }

      // Use a completer to properly handle QR sheet dismissal
      final completer = Completer<bool>();

      // Show UPI payment QR bottom sheet with proper handling for back button/dismissal
      await _showPaymentBottomSheet(completer);

      // Wait for payment process to complete or be cancelled
      final paymentSuccess = await completer.future;

      if (paymentSuccess) {
        print('Payment successful, recording payment and enrolling user');

        // Record payment in Firestore
        await _recordPayment();

        // Clear pending payment from shared preferences
        await _clearPendingPayment();

        // Mark payment as verified
        setState(() {
          _hasPaymentVerified = true;
          _paymentCancelled = false;
        });

        // Now enroll the user
        await _enrollInCourse();

        // Show a success message with updated stats
        _showPaymentSuccessDialog();
      } else {
        print('Payment cancelled or dismissed');

        // This is important - we don't clear the pending payment
        // so it will be checked when the app restarts

        setState(() {
          _paymentCancelled = true;
          _hasPaymentVerified = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Payment required to access this course')),
        );
      }
    } catch (e) {
      print('Payment error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during payment: $e')),
      );
    } finally {
      setState(() {
        _paymentInProgress = false;
      });
    }
  }

// New method to show a non-dismissible payment bottom sheet
  // Updated _showPaymentBottomSheet method
  Future<void> _showPaymentBottomSheet(Completer<bool> completer) async {
    // Create a key for the sheet to prevent multiple instances
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
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
          // Prevent back button completely
          onWillPop: () async => false,
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
                      final user = ref.read(authStateChangesProvider).value;
                      if (user != null) {
                        // Check if payment was verified on server side
                        final isVerified = await _checkPaymentVerification(
                            user.uid, widget.courseId);

                        if (isVerified) {
                          // Payment verified, stop checking and proceed
                          verificationTimer?.cancel();
                          completer.complete(true);
                          Navigator.of(context).pop();
                        }
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

              return Scaffold(
                key: scaffoldKey,
                backgroundColor: Colors.transparent,
                body: Container(
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
                        transactionNote: "Payment for ${widget.title}",
                        amount: widget.price,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Course: ${widget.title}",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Amount: ₹${widget.price}",
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
                                Icon(Icons.info_outline,
                                    color: Colors.blue[700]),
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
                            // Only allow cancellation with confirmation
                            bool confirmed =
                                await _showCancelPaymentDialog(context);
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
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<bool> _showCancelPaymentDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(
                'Cancel Payment?',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              content: Text(
                'You will not be able to access this premium course without payment. '
                'Are you sure you want to cancel?',
                style: GoogleFonts.poppins(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Continue Payment',
                    style: GoogleFonts.poppins(),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    'Yes, Cancel',
                    style: GoogleFonts.poppins(color: Colors.red),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<bool> _checkPaymentVerification(String userId, String courseId) async {
    try {
      // First check for a payment record directly
      final hasPayment = await ref.read(cloudProvider).checkPaymentForCourse(
            userId,
            courseId,
          );

      if (hasPayment) return true;

      // If no payment record found, this is where you'd implement server-side verification
      // For example, a webhook from your payment provider to your backend
      // Since this is a demo, we'll simulate a small random chance of payment success

      // NOTE: In production, REMOVE this random verification and implement actual verification
      // This is just for demonstration purposes
      final random = Random();
      if (random.nextDouble() < 0.1) {
        // 10% chance of "success" for demo purposes
        // Simulate a successful payment was received by server
        print('Payment verification succeeded for $courseId by $userId');

        // Manually create a payment record (in real app, your server would do this)
        final payment = Payment(
          paymentId: const Uuid().v4(),
          userId: userId,
          courseId: courseId,
          courseTitle: widget.title,
          amount: double.tryParse(widget.price) ?? 0.0,
          paymentDate: DateTime.now(),
          transactionId: 'server-verified-${const Uuid().v4()}',
          paymentMethod: 'UPI',
          isVerified: true,
        );

        await ref.read(cloudProvider).recordPayment(payment);
        return true;
      }

      return false;
    } catch (e) {
      print('Error verifying payment: $e');
      return false;
    }
  }

// Add these methods to store and retrieve pending payment info

// Store pending payment in shared preferences
  Future<void> _storePendingPayment(
      String userId, String courseId, String title, String price) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Store pending payment info
      await prefs.setString('pending_payment_user_id', userId);
      await prefs.setString('pending_payment_course_id', courseId);
      await prefs.setString('pending_payment_course_title', title);
      await prefs.setString('pending_payment_price', price);
      await prefs.setString(
          'pending_payment_timestamp', DateTime.now().toIso8601String());

      print('Stored pending payment for course: $courseId');
    } catch (e) {
      print('Error storing pending payment: $e');
    }
  }

// Clear pending payment after successful payment
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

  // Helper to check if the price is free (0)
  bool get _isFree {
    try {
      // Debug logging
      print('Checking if price "${widget.price}" is free');
      final parsed = double.tryParse(widget.price);
      print('Parsed price: $parsed');
      return parsed == null || parsed <= 0;
    } catch (e) {
      print('Error parsing price: $e');
      return true; // Default to free if can't parse
    }
  }

  // Show payment success dialog with stats
  void _showPaymentSuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[700]),
              const SizedBox(width: 10),
              const Text('Payment Successful'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Thank you for purchasing ${widget.title}!'),
              const SizedBox(height: 20),
              Text('Your Account Summary:'),
              const SizedBox(height: 10),
              _buildStatRow(
                  Icons.menu_book, 'Total Courses', '$_userCourseCount'),
              _buildStatRow(Icons.payment, 'Total Payments',
                  '${_paymentStats['totalPayments']}'),
              _buildStatRow(Icons.account_balance_wallet, 'Total Spent',
                  '₹${_paymentStats['totalSpent']}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Great!'),
            ),
          ],
        );
      },
    );
  }

  // Helper for building stat rows
  Widget _buildStatRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Text(label + ': '),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // More debug logging
    print('ResourceCard: ${widget.title}');
    print(
        'isPaid: ${widget.isPaid}, _isFree: $_isFree, _hasPaymentVerified: $_hasPaymentVerified');

    return Card(
      margin: const EdgeInsets.all(15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      elevation: 8,
      child: GestureDetector(
        onTap: _isEnrolled ? _handleNavigation : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 2,
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: Image.network(
                      widget.imageUrl,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 160,
                          width: double.infinity,
                          color: Colors.grey[200],
                          child: const Center(
                            child: Text('Error loading image'),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Add lock icon overlay for premium courses
                if (widget.isPaid && !_isFree && !_isEnrolled)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                        color: Colors.black.withOpacity(0.5),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.lock,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.title,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.description.length > 60
                        ? '${widget.description.substring(0, 60)}...'
                        : widget.description,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Price display
                  if (widget.isPaid && !_isFree)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Premium ₹${widget.price}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Free',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Share button
                      TextButton.icon(
                        icon: const Icon(Icons.share, size: 16),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue,
                        ),
                        label: const Text("SHARE"),
                        onPressed: () async {
                          await Share.share(
                            'Check out this resource: ${widget.title}\n ${widget.shareLink}\n',
                          );
                        },
                      ),

                      // Enrollment/Payment section
                      if (_isEnrolled)
                        Chip(
                          avatar: Icon(Icons.check_circle,
                              size: 16, color: Colors.green[700]),
                          label: Text(
                            "Enrolled",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.green[700],
                            ),
                          ),
                          backgroundColor: Colors.green[50],
                        )
                      else if (_isLoading || _paymentInProgress)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (widget.isPaid && !_isFree)
                        // Payment button for paid courses
                        ElevatedButton.icon(
                          icon: const Icon(Icons.payment, size: 16),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          label: const Text("PAY & ENROLL"),
                          onPressed: _initiatePayment,
                        )
                      else
                        // Regular enrollment for free courses
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text("ENROLL NOW"),
                          onPressed: () async {
                            bool confirmEnrollment =
                                await _showConfirmationDialog();
                            if (confirmEnrollment) {
                              await _enrollInCourse();
                            }
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Payment confirmation dialog
  Future<bool> _showPaymentConfirmationDialog() async {
    bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('You are about to pay for this premium course:'),
              const SizedBox(height: 10),
              Text(
                widget.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Price: ₹${widget.price}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade800,
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Proceed to Payment'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // Enrollment confirmation dialog
  Future<bool> _showConfirmationDialog() async {
    bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Enrollment'),
          content:
              const Text('Are you sure you want to enroll in this course?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Yes, Enroll'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }
}

import 'package:flutter/material.dart';
import '../modals/courses_modal.dart';
import 'SimpleUpiPaymentService.dart';

class CoursePaymentButton extends StatefulWidget {
  final Courses course;
  final Function(bool) onPaymentComplete;

  const CoursePaymentButton({
    Key? key,
    required this.course,
    required this.onPaymentComplete,
  }) : super(key: key);

  @override
  State<CoursePaymentButton> createState() => _CoursePaymentButtonState();
}

class _CoursePaymentButtonState extends State<CoursePaymentButton> {
  bool _isLoading = false;

  // Helper method to parse price safely
  double _getPriceAmount() {
    try {
      return double.parse(widget.course.price);
    } catch (e) {
      return 0.0; // Default to 0 if parsing fails
    }
  }

  void _initiatePayment() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Show UPI payment QR bottom sheet
      SimpleUpiService.showPaymentQRBottomSheet(
        context: context,
        receiverUpiId: "hasnainmakada@ybl", // Replace with your UPI ID
        receiverName: "CodeFlow Courses",
        courseTitle: widget.course.title,
        amount: widget.course.price,
      );

      // For testing/demo purposes, simulate successful payment after delay
      await Future.delayed(const Duration(seconds: 5));

      // Call the completion callback
      widget.onPaymentComplete(true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment Successful!')),
      );
    } catch (e) {
      widget.onPaymentComplete(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show the payment button if the course is paid
    if (!widget.course.isPaid) {
      return const SizedBox
          .shrink(); // Return an empty widget if course is not paid
    }

    return _isLoading
        ? const CircularProgressIndicator()
        : ElevatedButton.icon(
            icon: const Icon(Icons.payments_outlined),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: _initiatePayment,
            label: Text('Pay ₹${widget.course.price}'),
          );
  }
}

// Example usage in a course detail screen
import 'package:flutter/material.dart';
import '../modals/courses_modal.dart';
import '../upi/CoursePaymentButton.dart';

class CourseDetailScreen extends StatefulWidget {
  final Courses course;

  const CourseDetailScreen({Key? key, required this.course}) : super(key: key);

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  bool _hasPurchased = false;

  void _handlePaymentComplete(bool success) {
    if (success) {
      setState(() {
        _hasPurchased = true;
      });
      // Here you can update your backend or local storage to mark this course as purchased
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(widget.course.thumbnail),
            const SizedBox(height: 16),
            Text(
              widget.course.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('By ${widget.course.channelName}'),
            const SizedBox(height: 16),
            Text(widget.course.description),
            const SizedBox(height: 16),
            // Show price badge if paid
            if (widget.course.isPaid)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Premium ₹${widget.course.price}',
                  style: TextStyle(
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 24),
            if (widget.course.isPaid && !_hasPurchased)
              // Show payment button only for paid courses that aren't purchased
              CoursePaymentButton(
                course: widget.course,
                onPaymentComplete: _handlePaymentComplete,
              )
            else
              // For free courses or purchased courses
              ElevatedButton(
                onPressed: () {
                  // Navigate to course content or playback
                },
                child: const Text('Start Learning'),
              ),
          ],
        ),
      ),
    );
  }
}

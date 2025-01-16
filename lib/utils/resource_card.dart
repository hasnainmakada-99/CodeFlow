import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:codeflow/auth%20and%20cloud/auth_provider.dart';
import 'package:codeflow/auth%20and%20cloud/cloud_provider.dart';
import 'package:codeflow/modals/enrollments_modal.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';

class ResourceCard extends ConsumerStatefulWidget {
  final String imageUrl;
  final String title;
  final String description;
  final String shareLink;
  final String courseId;
  final int price; // Added price parameter
  final Function navigateTo;

  const ResourceCard({
    Key? key,
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.shareLink,
    required this.courseId,
    required this.price, // Added price parameter
    required this.navigateTo,
  }) : super(key: key);

  @override
  _ResourceCardState createState() => _ResourceCardState();
}

class _ResourceCardState extends ConsumerState<ResourceCard> {
  bool _isEnrolled = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkEnrollmentStatus();
  }

  // Check if the user is enrolled in the course
  Future<void> _checkEnrollmentStatus() async {
    final user = ref.read(authStateChangesProvider).value;
    if (user != null) {
      try {
        final isEnrolled = await ref
            .read(cloudProvider)
            .checkEnrollment(widget.courseId, user.uid);
        setState(() {
          _isEnrolled = isEnrolled;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking enrollment status: $e')),
        );
      }
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

        final enrollment = Enrollment(
          enrollmentId: const Uuid().v4(),
          courseId: widget.courseId,
          studentId: user.uid,
          enrollmentDate: DateTime.now(),
        );

        await ref.read(cloudProvider).enrollInCourse(enrollment);

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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      elevation: 8,
      child: GestureDetector(
        onTap: _isEnrolled ? () => widget.navigateTo() : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
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
                borderRadius: BorderRadius.only(
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
                  Text(
                    widget.price == 0
                        ? 'Free'
                        : '₹${widget.price.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: widget.price == 0 ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.transparent,
                        ),
                        child: const Text(
                          "SHARE",
                          style: TextStyle(color: Colors.blue),
                        ),
                        onPressed: () async {
                          await Share.share(
                            'Check out this resource: ${widget.title}\n ${widget.shareLink}\n ',
                          );
                        },
                      ),
                      _isEnrolled
                          ? Text(
                              "In Progress",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.green,
                              ),
                            )
                          : _isLoading
                              ? CircularProgressIndicator() // Show loading indicator while enrolling
                              : TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.transparent,
                                  ),
                                  child: const Text(
                                    "ENROLL",
                                    style: TextStyle(color: Colors.blue),
                                  ),
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

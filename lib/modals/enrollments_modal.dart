import 'package:cloud_firestore/cloud_firestore.dart';

class Enrollment {
  final String enrollmentId;
  final String courseId;
  final String studentId;
  final DateTime enrollmentDate;
  final bool isPaid; // Added to track if course is a paid one
  final bool paymentVerified; // Added to track payment verification status
  final String? transactionId; // Optional transaction reference ID
  final double? amountPaid; // Optional amount paid

  Enrollment({
    required this.enrollmentId,
    required this.courseId,
    required this.studentId,
    required this.enrollmentDate,
    this.isPaid = false, // Default to free course
    this.paymentVerified = false, // Default to not verified
    this.transactionId,
    this.amountPaid,
  });

  factory Enrollment.fromJson(Map<String, dynamic> json) => Enrollment(
        enrollmentId: json['enrollmentId'] as String,
        courseId: json['courseId'] as String,
        studentId: json['studentId'] as String,
        enrollmentDate: (json['enrollmentDate'] as Timestamp).toDate(),
        isPaid: json['isPaid'] as bool? ?? false,
        paymentVerified: json['paymentVerified'] as bool? ?? false,
        transactionId: json['transactionId'] as String?,
        amountPaid: json['amountPaid'] as double?,
      );

  Map<String, dynamic> toJson() => {
        'enrollmentId': enrollmentId,
        'courseId': courseId,
        'studentId': studentId,
        'enrollmentDate': enrollmentDate,
        'isPaid': isPaid,
        'paymentVerified': paymentVerified,
        'transactionId': transactionId,
        'amountPaid': amountPaid,
      };

  // Helper method to check if a paid course's payment is verified
  bool get canAccessPaidContent => !isPaid || paymentVerified;
}

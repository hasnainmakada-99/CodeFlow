import 'package:cloud_firestore/cloud_firestore.dart';

class Payment {
  final String paymentId;
  final String userId;
  final String courseId;
  final String courseTitle;
  final double amount;
  final DateTime paymentDate;
  final String transactionId; // Optional UPI transaction reference
  final String paymentMethod; // e.g., "UPI", "Card", etc.
  final bool isVerified;

  Payment({
    required this.paymentId,
    required this.userId,
    required this.courseId,
    required this.courseTitle,
    required this.amount,
    required this.paymentDate,
    required this.transactionId,
    this.paymentMethod = "UPI",
    this.isVerified = true,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        paymentId: json['paymentId'] as String,
        userId: json['userId'] as String,
        courseId: json['courseId'] as String,
        courseTitle: json['courseTitle'] as String,
        amount: (json['amount'] as num).toDouble(),
        paymentDate: (json['paymentDate'] as Timestamp).toDate(),
        transactionId: json['transactionId'] as String,
        paymentMethod: json['paymentMethod'] as String? ?? "UPI",
        isVerified: json['isVerified'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'paymentId': paymentId,
        'userId': userId,
        'courseId': courseId,
        'courseTitle': courseTitle,
        'amount': amount,
        'paymentDate': paymentDate,
        'transactionId': transactionId,
        'paymentMethod': paymentMethod,
        'isVerified': isVerified,
      };
}

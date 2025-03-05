import 'package:codeflow/modals/payment_modal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codeflow/modals/review_modal.dart';
import 'package:codeflow/modals/enrollments_modal.dart';
import 'package:uuid/uuid.dart';

final cloudProvider = Provider<CloudRepository>((ref) => CloudRepository());

class CloudRepository {
  final _firestore = FirebaseFirestore.instance;

  Future<void> addFeedback(Review review) async {
    try {
      final querySnapshot = await _firestore
          .collection('userFeedback')
          .where('studentId', isEqualTo: review.studentId)
          .where('courseId', isEqualTo: review.courseId)
          .get(); // check if user has already given feedback for the resource

      if (querySnapshot.docs.isNotEmpty) {
        final docId = querySnapshot
            .docs.first.id; // get the document ID of the user feedback
        await _firestore
            .collection('userFeedback')
            .doc(docId)
            .update(review.toJson());
      } else {
        await _firestore.collection('userFeedback').add(review.toJson());
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> enrollInCourse(Enrollment enrollment) async {
    try {
      await _firestore.collection('enrollments').add(enrollment.toJson());
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> checkEnrollment(String courseId, String studentId) async {
    try {
      final querySnapshot = await _firestore
          .collection('enrollments')
          .where('courseId', isEqualTo: courseId)
          .where('studentId', isEqualTo: studentId)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      rethrow;
    }
  }

  // Add these methods to your existing CloudProvider class

// Create a payment record in Firestore
  Future<void> recordPayment(Payment payment) async {
    try {
      await _firestore
          .collection('payments')
          .doc(payment.paymentId)
          .set(payment.toJson());
      print('Payment recorded successfully: ${payment.paymentId}');
    } catch (e) {
      print('Error recording payment: $e');
      throw e;
    }
  }

// Get all payments for a specific user
  Future<List<Payment>> getUserPayments(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .get();

      return snapshot.docs.map((doc) => Payment.fromJson(doc.data())).toList();
    } catch (e) {
      print('Error getting user payments: $e');
      throw e;
    }
  }

// Check if payment exists for a course
  Future<bool> checkPaymentForCourse(String userId, String courseId) async {
    try {
      final snapshot = await _firestore
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .where('courseId', isEqualTo: courseId)
          .where('isVerified', isEqualTo: true)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking payment: $e');
      throw e;
    }
  }

// Get user's course count
  Future<int> getUserCourseCount(String userId) async {
    try {
      final enrollmentsSnapshot = await _firestore
          .collection('enrollments')
          .where('studentId', isEqualTo: userId)
          .get();

      return enrollmentsSnapshot.docs.length;
    } catch (e) {
      print('Error getting user course count: $e');
      throw e;
    }
  }

// Get user's payment stats
  Future<Map<String, dynamic>> getUserPaymentStats(String userId) async {
    try {
      final paymentsSnapshot = await _firestore
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .get();

      final payments = paymentsSnapshot.docs
          .map((doc) => Payment.fromJson(doc.data()))
          .toList();

      double totalSpent = 0;
      for (var payment in payments) {
        totalSpent += payment.amount;
      }

      return {
        'totalPayments': payments.length,
        'totalSpent': totalSpent,
      };
    } catch (e) {
      print('Error getting user payment stats: $e');
      throw e;
    }
  }

  // Enroll user with payment verification
  Future<void> enrollInCourseWithPayment({
    required String courseId,
    required String userId,
    required bool paymentVerified,
  }) async {
    try {
      // Check if already enrolled
      final isEnrolled = await checkEnrollment(courseId, userId);

      if (!isEnrolled) {
        // Create a new enrollment with payment verification
        final enrollment = Enrollment(
          enrollmentId: const Uuid().v4(),
          courseId: courseId,
          studentId: userId,
          enrollmentDate: DateTime.now(),
          isPaid: true,
          paymentVerified: paymentVerified,
        );

        await _firestore
            .collection('enrollments')
            .doc(enrollment.enrollmentId)
            .set(enrollment.toJson());

        print('User enrolled with payment verification');
      } else {
        // Update existing enrollment to mark payment as verified
        final querySnapshot = await _firestore
            .collection('enrollments')
            .where('courseId', isEqualTo: courseId)
            .where('studentId', isEqualTo: userId)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          await _firestore
              .collection('enrollments')
              .doc(querySnapshot.docs.first.id)
              .update({'paymentVerified': paymentVerified});

          print('Updated existing enrollment with payment verification');
        }
      }
    } catch (e) {
      print('Error in enrollInCourseWithPayment: $e');
      throw e;
    }
  }
}

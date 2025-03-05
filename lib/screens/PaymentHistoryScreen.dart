import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:codeflow/auth%20and%20cloud/auth_provider.dart';
import 'package:codeflow/auth%20and%20cloud/cloud_provider.dart';
import 'package:codeflow/modals/payment_modal.dart';
import 'package:intl/intl.dart';

final userPaymentsProvider = FutureProvider<List<Payment>>((ref) async {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return [];

  return ref.read(cloudProvider).getUserPayments(user.uid);
});

class PaymentHistoryScreen extends ConsumerWidget {
  const PaymentHistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(userPaymentsProvider);
    final statsFuture = ref.watch(userPaymentStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Payment History',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Payment Stats Card
          statsFuture.when(
            data: (stats) => _buildStatsCard(stats, context),
            loading: () => const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => Container(
              height: 100,
              color: Colors.red.shade100,
              child: const Center(
                child: Text('Error loading payment stats'),
              ),
            ),
          ),

          // Payment History
          Expanded(
            child: paymentsAsync.when(
              data: (payments) {
                if (payments.isEmpty) {
                  return _buildEmptyState();
                }
                return _buildPaymentsList(payments);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text('Error: $error'),
                    ElevatedButton(
                      onPressed: () {
                        ref.refresh(userPaymentsProvider);
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(Map<String, dynamic> stats, BuildContext context) {
    final totalSpent = stats['totalSpent'] ?? 0.0;
    final formattedTotal = NumberFormat.currency(
      symbol: '₹',
      locale: 'en_IN',
      decimalDigits: 2,
    ).format(totalSpent);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade200.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment Summary',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              const Icon(Icons.account_balance_wallet, color: Colors.white),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatColumn('Total Spent', formattedTotal, context),
              _buildStatColumn(
                  'Courses', '${stats['totalPayments'] ?? 0}', context),
              _buildStatColumn('Last Payment',
                  _formatLastPayment(stats['lastPaymentDate']), context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  String _formatLastPayment(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    try {
      final date = timestamp.toDate();
      return DateFormat('MMM d').format(date);
    } catch (_) {
      return 'N/A';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/empty_payments.png', // Replace with your asset or an icon
            height: 150,
            width: 150,
            fit: BoxFit.contain,
            errorBuilder: (ctx, _, __) => Icon(
              Icons.payment_outlined,
              size: 100,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No payment history yet',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your course purchases will appear here',
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsList(List<Payment> payments) {
    // Sort payments by date (newest first)
    payments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: payments.length,
      itemBuilder: (context, index) {
        final payment = payments[index];
        return _buildPaymentCard(payment);
      },
    );
  }

  Widget _buildPaymentCard(Payment payment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    payment.courseTitle,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Chip(
                  label: Text(
                    '₹${payment.amount.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber[800],
                    ),
                  ),
                  backgroundColor: Colors.amber[50],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPaymentDetail(
                  Icons.calendar_today,
                  'Date',
                  DateFormat('MMM d, yyyy').format(payment.paymentDate),
                ),
                _buildPaymentDetail(
                  Icons.payments_outlined,
                  'Method',
                  payment.paymentMethod,
                ),
                _buildPaymentDetail(
                  Icons.check_circle_outline,
                  'Status',
                  payment.isVerified ? 'Verified' : 'Pending',
                  color: payment.isVerified ? Colors.green : Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transaction ID:',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                Text(
                  payment.transactionId.substring(0, 13) + '...',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDetail(
    IconData icon,
    String label,
    String value, {
    Color? color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

// Provider for payment stats
final userPaymentStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return {'totalPayments': 0, 'totalSpent': 0.0};

  return ref.read(cloudProvider).getUserPaymentStats(user.uid);
});

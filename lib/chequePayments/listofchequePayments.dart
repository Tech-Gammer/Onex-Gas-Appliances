import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../Provider/lanprovider.dart';

class CheckPaymentsPage extends StatelessWidget {
  const CheckPaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.isEnglish ? 'Cheque Payments' : 'چیک ادائیگی لسٹ',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blueAccent,
      ),
      body: Consumer<CheckPaymentProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.checkPayments.isEmpty) {
            return const Center(child: Text('No check payments found'));
          }

          return ListView.builder(
            itemCount: provider.checkPayments.length,
            itemBuilder: (context, index) {
              final payment = provider.checkPayments[index];
              return _CheckPaymentCard(
                payment: payment,
                onMarkCleared: () => provider.markCheckCleared(payment['key']),
              );
            },
          );
        },
      ),
    );
  }

}

class _CheckPaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  final VoidCallback onMarkCleared;

  const _CheckPaymentCard({
    required this.payment,
    required this.onMarkCleared,
  });

  @override
  Widget build(BuildContext context) {
    final isCleared = payment['status'] == 'cleared';
    final date = DateTime.tryParse(payment['date']) ?? DateTime.now();

    final amount = payment['amount']?.toDouble() ?? 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(
          isCleared ? Icons.check_circle : Icons.pending_actions,
          color: isCleared ? Colors.green : Colors.orange,
        ),
        title: Text('Filled #${payment['filledNumber']}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('MMM dd, yyyy').format(date)),
            Text(payment['description'] ?? 'No description'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('PKR-${amount.toStringAsFixed(2)}'),

          ],
        ),
      ),
    );
  }
}

class CheckPaymentProvider with ChangeNotifier {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _allPayments = [];
  bool _showCleared = true;
  bool _showPending = true;
  bool _isLoading = true;

  List<Map<String, dynamic>> get checkPayments => _allPayments.where((p) {
    if (p['status'] == 'cleared' && !_showCleared) return false;
    if (p['status'] != 'cleared' && !_showPending) return false;
    return true;
  }).toList();

  bool get showCleared => _showCleared;
  bool get showPending => _showPending;
  bool get isLoading => _isLoading;

  CheckPaymentProvider() {
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    try {
      final snapshot = await _db.child('filled').get();
      final List<Map<String, dynamic>> payments = [];

      if (snapshot.exists) {
        for (final filled in snapshot.children) {
          final checkPayments = filled.child('checkPayments');
          if (checkPayments.exists) {
            for (final payment in checkPayments.children) {
              payments.add({
                'key': payment.key,
                'filledId': filled.key,
                ...Map<String, dynamic>.from(payment.value as Map),
                'filledNumber': filled.child('filledNumber').value,
              });
            }
          }
        }
      }

      _allPayments = payments;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> markCheckCleared(String paymentKey) async {
    try {
      // Find the payment in the list
      final payment = _allPayments.firstWhere((p) => p['key'] == paymentKey);

      await _db.child('filled')
          .child(payment['filledId'])
          .child('checkPayments')
          .child(paymentKey)
          .update({'status': 'cleared'});

      await _loadPayments(); // Refresh the list
    } catch (e) {
      rethrow;
    }
  }

  void toggleShowCleared(bool value) {
    _showCleared = value;
    notifyListeners();
  }

  void toggleShowPending(bool value) {
    _showPending = value;
    notifyListeners();
  }
}
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../Provider/lanprovider.dart';

class PaymentProvider with ChangeNotifier {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _filledCheckPayments = [];
  List<Map<String, dynamic>> _invoiceCheckPayments = [];
  int _invoicePageSize = 20;
  int _invoiceCurrentMax = 20;
  bool _showCleared = true;
  bool _showPending = true;
  bool _isLoading = true;

  List<Map<String, dynamic>> get filledCheckPayments => _filtered(_filledCheckPayments);
  List<Map<String, dynamic>> get invoiceCheckPayments => _filtered(_invoiceCheckPayments);

  bool get showCleared => _showCleared;
  bool get showPending => _showPending;
  bool get isLoading => _isLoading;


  PaymentProvider() {
    _loadPayments();
  }

  List<Map<String, dynamic>> get paginatedCombinedCheckPayments =>
      combinedCheckPayments.take(_invoiceCurrentMax).toList();

  List<Map<String, dynamic>> get combinedCheckPayments =>
      _filtered([..._invoiceCheckPayments, ..._filledCheckPayments]);

  List<Map<String, dynamic>> get paginatedInvoiceCheckPayments =>
      _filtered(_invoiceCheckPayments).take(_invoiceCurrentMax).toList();

  void loadMoreInvoicePayments() {
    if (_invoiceCurrentMax < _invoiceCheckPayments.length) {
      _invoiceCurrentMax += _invoicePageSize;
      notifyListeners();
    }
  }

  void resetInvoicePagination() {
    _invoiceCurrentMax = _invoicePageSize;
    notifyListeners();
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> payments) {
    return payments.where((p) {
      if (p['status'] == 'cleared' && !_showCleared) return false;
      if (p['status'] != 'cleared' && !_showPending) return false;
      return true;
    }).toList();
  }

  Future<void> _loadPayments() async {
    _isLoading = true;
    notifyListeners();

    try {
      final filledSnapshot = await _db.child('filled').get();
      final invoiceSnapshot = await _db.child('invoices').get();

      final List<Map<String, dynamic>> filledPayments = [];
      final List<Map<String, dynamic>> invoicePayments = [];

      // Load from 'filled'
      if (filledSnapshot.exists) {
        for (final filled in filledSnapshot.children) {
          final filledNumber = filled.child('filledNumber').value;
          final checkPayments = filled.child('checkPayments');

          if (checkPayments.exists) {
            for (final payment in checkPayments.children) {
              filledPayments.add({
                'key': payment.key,
                'filledId': filled.key,
                ...Map<String, dynamic>.from(payment.value as Map),
                'filledNumber': filledNumber,
              });
            }
          }
        }
      }

      // Load from 'invoices'
      if (invoiceSnapshot.exists) {
        for (final invoice in invoiceSnapshot.children) {
          final invoiceNumber = invoice.child('invoiceNumber').value;
          final checkPayments = invoice.child('checkPayments');

          if (checkPayments.exists) {
            for (final payment in checkPayments.children) {
              invoicePayments.add({
                'key': payment.key,
                'invoiceId': invoice.key,
                ...Map<String, dynamic>.from(payment.value as Map),
                'invoiceNumber': invoiceNumber,
              });
            }
          }
        }
      }

      _filledCheckPayments = filledPayments;
      _invoiceCheckPayments = invoicePayments;

      resetInvoicePagination(); // <<-- Reset pagination here
    } catch (e) {
      // You might want to show an error in real app
      print("Error loading payments: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> markFilledCheckCleared(String paymentKey) async {
    try {
      final payment = _filledCheckPayments.firstWhere((p) => p['key'] == paymentKey);
      await _db.child('filled')
          .child(payment['filledId'])
          .child('checkPayments')
          .child(paymentKey)
          .update({'status': 'cleared'});
      await _loadPayments();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> markInvoiceCheckCleared(String paymentKey) async {
    try {
      final payment = _invoiceCheckPayments.firstWhere((p) => p['key'] == paymentKey);
      await _db.child('invoices')
          .child(payment['invoiceId'])
          .child('checkPayments')
          .child(paymentKey)
          .update({'status': 'cleared'});
      await _loadPayments();
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
class InvoiceCheckPaymentsPage extends StatefulWidget {
  const InvoiceCheckPaymentsPage({super.key});

  @override
  State<InvoiceCheckPaymentsPage> createState() => _InvoiceCheckPaymentsPageState();
}

class _InvoiceCheckPaymentsPageState extends State<InvoiceCheckPaymentsPage> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      Provider.of<PaymentProvider>(context, listen: false).loadMoreInvoicePayments();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.isEnglish ? 'Invoice Check Payments' : 'انوائس چیک ادائیگی لسٹ',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
      ),
      body: Consumer<PaymentProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // final payments = provider.paginatedInvoiceCheckPayments;
          final payments = provider.paginatedCombinedCheckPayments;

          if (payments.isEmpty) {
            return const Center(child: Text('No invoice check payments found'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              await provider._loadPayments(); // Refresh data
            },
            child: ListView.builder(
              controller: _scrollController,
              itemCount: payments.length + 1, // +1 for the loading indicator
              itemBuilder: (context, index) {
                if (index == payments.length) {
                  // Show a loading spinner when more data is available
                  final hasMore = payments.length < provider.invoiceCheckPayments.length;
                  return hasMore
                      ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                      : const SizedBox.shrink();
                }
            
                final payment = payments[index];
                return _InvoiceCheckPaymentCard(
                  payment: payment,
                  onMarkCleared: () => provider.markInvoiceCheckCleared(payment['key']),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _InvoiceCheckPaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  final VoidCallback onMarkCleared;

  const _InvoiceCheckPaymentCard({
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
        // title: Text('Invoice #${payment['invoiceNumber']}'),
        title: Text(
          payment.containsKey('invoiceNumber')
              ? 'Invoice #${payment['invoiceNumber']}'
              : 'Filled #${payment['filledNumber']}',
        ),

        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('MMM dd, yyyy').format(date)),
            Text(payment['description'] ?? 'No description'),
          ],
        ),
        trailing: Text('PKR-${amount.toStringAsFixed(2)}'),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;

class FilledCustomerReportProvider with ChangeNotifier {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  bool isLoading = false;
  String error = '';
  List<Map<String, dynamic>> transactions = [];
  Map<String, dynamic> report = {};
  double openingBalance = 0.0;

  Future<void> fetchCustomerReport(String customerId) async {
    try {
      isLoading = true;
      error = '';
      notifyListeners();

      report = {};
      transactions = [];

      // Fetch opening balance first
      await fetchOpeningBalance(customerId);

      final snapshot = await _db.child('filledledger/$customerId').once();

      if (snapshot.snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.snapshot.value as Map);

        double totalDebit = 0.0;
        double totalCredit = openingBalance; // Start with opening balance as credit
        double runningBalance = openingBalance; // Start balance with opening balance

        for (var entry in data.entries) {
          final transaction = Map<String, dynamic>.from(entry.value);

          final paymentMethod = transaction['paymentMethod']?.toString().toLowerCase();
          final status = transaction['status']?.toString().toLowerCase();

          // Skip uncleared cheques
          if (paymentMethod == 'cheque' && status != 'cleared') continue;

          final debit = (transaction['debitAmount'] ?? 0.0).toDouble();
          final credit = (transaction['creditAmount'] ?? 0.0).toDouble();

          runningBalance += credit - debit;

          transactions.add({
            'id': entry.key,
            'date': transaction['createdAt'] ?? 'N/A',
            'details': transaction['details'] ?? '',
            'filledNumber': transaction['filledNumber'] ?? '',
            'referenceNumber': transaction['referenceNumber'] ?? '',
            'bankName': transaction['bankName'] ?? '',
            'paymentMethod': paymentMethod ?? '',
            'debit': debit,
            'credit': credit,
            'balance': runningBalance,
          });

          totalDebit += debit;
          totalCredit += credit;
        }

        // Sort transactions by date (ascending)
        transactions.sort((a, b) {
          final dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime(2000);
          final dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime(2000);
          return dateA.compareTo(dateB); // Oldest first
        });

        report = {
          'debit': totalDebit,
          'credit': totalCredit,
          'balance': runningBalance,
        };
      } else {
        // If no transactions, balance is just the opening balance
        report = {
          'debit': 0.0,
          'credit': openingBalance,
          'balance': openingBalance
        };
      }
    } catch (e) {
      error = 'Failed to fetch customer report: $e';
      report = {'debit': 0.0, 'credit': openingBalance, 'balance': openingBalance};
      transactions = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchOpeningBalance(String customerId) async {
    try {
      final snapshot = await _db.child('customers/$customerId/openingBalance').once();
      if (snapshot.snapshot.exists && snapshot.snapshot.value != null) {
        openingBalance = (snapshot.snapshot.value as num).toDouble();
      } else {
        openingBalance = 0.0;
      }
    } catch (e) {
      print('Error fetching opening balance: $e');
      openingBalance = 0.0;
    }
  }
}
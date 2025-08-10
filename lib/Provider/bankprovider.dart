import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class BankProvider with ChangeNotifier {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('banks');
  Map<dynamic, dynamic> _banks = {};

  Map<dynamic, dynamic> get banks => _banks;

  Future<void> fetchBanks() async {
    final snapshot = await _dbRef.get();
    if (snapshot.exists) {
      _banks = snapshot.value as Map<dynamic, dynamic>;
      notifyListeners();
    }
  }

  double getTotalBankBalance() {
    return _banks.values.fold(0.0, (sum, bank) {
      final balance = (bank['balance'] as num).toDouble();
      return sum + balance;
    });
  }

  // New method to get today's bank transactions
  Map<dynamic, dynamic> getTodaysBanks() {
    final today = DateTime.now();
    return _banks.map((key, value) {
      final transactionDate = DateTime.parse(value['date']);
      if (transactionDate.year == today.year &&
          transactionDate.month == today.month &&
          transactionDate.day == today.day) {
        return MapEntry(key, value);
      }
      return MapEntry(key, null);
    })..removeWhere((key, value) => value == null);
  }

  // New method to get today's total bank balance
  double getTodaysTotalBankBalance() {
    final todaysBanks = getTodaysBanks();
    return todaysBanks.values.fold(0.0, (sum, bank) {
      final balance = (bank['balance'] as num).toDouble();
      return sum + balance;
    });
  }
}
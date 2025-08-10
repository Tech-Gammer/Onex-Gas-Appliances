import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

class ExpenseProvider with ChangeNotifier {
  List<Map<String, dynamic>> _expenses = [];

  List<Map<String, dynamic>> get expenses => _expenses;

  Future<void> fetchExpenses() async {
    final dbRef = FirebaseDatabase.instance.ref("dailyKharcha");
    final snapshot = await dbRef.get();

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      _expenses = [];

      data.forEach((date, expensesData) {
        if (expensesData['expenses'] != null) {
          final expenses = expensesData['expenses'] as Map<dynamic, dynamic>;
          expenses.forEach((key, value) {
            // Ensure 'amount' is treated as double
            final amount = (value['amount'] as num).toDouble();
            _expenses.add({
              'date': date,
              'description': value['description'],
              'amount': amount, // Use the converted double value
            });
          });
        }
      });

      notifyListeners();
    }
  }

  List<Map<String, dynamic>> getTodaysExpenses() {
    final today = DateFormat('dd:MM:yyyy').format(DateTime.now());
    return _expenses.where((expense) => expense['date'] == today).toList();
  }

  double getTotalExpenses(List<Map<String, dynamic>> expenses) {
    return expenses.fold(0.0, (sum, expense) => sum + (expense['amount'] as double));
  }
}
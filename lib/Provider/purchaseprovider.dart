import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class PurchaseProvider with ChangeNotifier {
  List<Map<String, dynamic>> _todaysPurchases = [];
  double _totalPurchaseAmount = 0.0;
  int _totalPurchaseCount = 0;

  double get totalPurchaseAmount => _totalPurchaseAmount;
  int get totalPurchaseCount => _totalPurchaseCount;

  List<Map<String, dynamic>> get todaysPurchases => _todaysPurchases;

  Future<void> fetchTodaysPurchases() async {
    final database = FirebaseDatabase.instance.ref();
    final snapshot = await database.child('purchases').get();

    if (snapshot.exists) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final purchases = (snapshot.value as Map<dynamic, dynamic>).values.map((purchase) {
        final purchaseDate = DateTime.parse(purchase['timestamp']);
        return {
          'itemName': purchase['itemName'],
          'vendorName': purchase['vendorName'],
          'quantity': purchase['quantity'],
          'purchasePrice': (purchase['purchasePrice'] as num).toDouble(), // Ensure double
          'total': (purchase['total'] as num).toDouble(), // Ensure double
          'timestamp': purchaseDate,
        };
      }).where((purchase) =>
      DateTime(purchase['timestamp'].year, purchase['timestamp'].month, purchase['timestamp'].day) == today).toList();

      _todaysPurchases = purchases;
      _totalPurchaseAmount = purchases.fold(0.0, (sum, item) => sum + (item['total'] as double));
      _totalPurchaseCount = purchases.length; // Count today's purchases

      notifyListeners();
    }
  }


}

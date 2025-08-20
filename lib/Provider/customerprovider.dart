import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class Customer {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String city;
  final double? openingBalance;
  final DateTime? openingBalanceDate; // Add this field

  Customer({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.city,
    this.openingBalance,
    this.openingBalanceDate, // Add this parameter
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'phone': phone,
      'city': city,
      'openingBalance': openingBalance ?? 0.0,
      'openingBalanceDate': openingBalanceDate?.toIso8601String(), // Include in JSON
    };
  }

  static Customer fromSnapshot(String id, Map<dynamic, dynamic> data) {
    return Customer(
      id: id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      phone: data['phone'] ?? '',
      city: data['city'] ?? '',
      openingBalance: (data['openingBalance'] as num?)?.toDouble(),
      openingBalanceDate: data['openingBalanceDate'] != null
          ? DateTime.tryParse(data['openingBalanceDate'])
          : null, // Handle null and parse date
    );
  }
}

class CustomerProvider with ChangeNotifier {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('customers');
  List<Customer> _customers = [];

  List<Customer> get customers => _customers;

  Future<void> fetchCustomers() async {
    final snapshot = await _dbRef.get();
    if (snapshot.exists) {
      _customers = (snapshot.value as Map).entries.map((e) => Customer.fromSnapshot(e.key, e.value)).toList();
      notifyListeners();
    }
  }


  Future<void> addCustomer(String name, String address, String phone, String city,
      [double openingBalance = 0.0, DateTime? openingBalanceDate]) async {
    final newCustomer = _dbRef.push();
    final customerId = newCustomer.key!;

    await newCustomer.set({
      'name': name,
      'address': address,
      'phone': phone,
      'city': city,
       'openingBalance': openingBalance,
       'openingBalanceDate': (openingBalanceDate ?? DateTime.now()).toIso8601String(),
    });

    // Add opening balance to ledger as credit
    if (openingBalance > 0) {
      await _addOpeningBalanceToLedger(
        customerId,
        openingBalance,
        openingBalanceDate ?? DateTime.now(),
      );
    }

    fetchCustomers(); // Refresh customer list
  }

  Future<void> _addOpeningBalanceToLedger(
      String customerId,
      double openingBalance,
      DateTime date
      ) async {
    final ledgerRef = FirebaseDatabase.instance.ref().child('filledledger').child(customerId);

    final ledgerData = {
      'referenceNumber': 'Opening Balance',
      'filledNumber': 'OPENING_BAL',
      'creditAmount': openingBalance,
      'debitAmount': 0.0,
      'remainingBalance': openingBalance, // Initial balance
      'createdAt': date.toIso8601String(),
      'paymentMethod': 'Opening Balance',
      'description': 'Opening Balance Credit',
    };

    await ledgerRef.push().set(ledgerData);
  }

  Future<void> updateCustomer(String id, String name, String address, String phone, String city,
      [double openingBalance = 0.0, DateTime? openingBalanceDate]) async {

    // Update customer node
    await _dbRef.child(id).update({
      'name': name,
      'address': address,
      'phone': phone,
      'city': city,
      'openingBalance': openingBalance,
      'openingBalanceDate': openingBalanceDate?.toIso8601String(),
    });

    // Update opening balance in filledledger
    await _updateOpeningBalanceInLedger(id, openingBalance, openingBalanceDate);

    fetchCustomers(); // Refresh list
  }

  Future<void> _updateOpeningBalanceInLedger(
      String customerId,
      double openingBalance,
      DateTime? date) async {
    final ledgerRef = FirebaseDatabase.instance.ref().child('filledledger').child(customerId);

    // First, try to find the existing opening balance entry
    final snapshot = await ledgerRef.orderByChild('filledNumber').equalTo('OPENING_BAL').once();

    if (snapshot.snapshot.exists) {
      // Update existing opening balance entry
      final Map<dynamic, dynamic> entries = snapshot.snapshot.value as Map<dynamic, dynamic>;
      final String entryKey = entries.keys.first;

      await ledgerRef.child(entryKey).update({
        'creditAmount': openingBalance,
        'remainingBalance': openingBalance,
        'createdAt': date?.toIso8601String() ?? DateTime.now().toIso8601String(),
      });
    } else {
      // Create new opening balance entry if it doesn't exist
      await _addOpeningBalanceToLedger(
        customerId,
        openingBalance,
        date ?? DateTime.now(),
      );
    }
  }

  Future<void> deleteCustomer(String id) async {
    try {
      await _dbRef.child(id).remove();
      // Also delete related ledger entries if needed
      // await FirebaseDatabase.instance.ref('invoices/$id').remove();
      // await FirebaseDatabase.instance.ref('ledger/$id').remove();
      // await FirebaseDatabase.instance.ref('filled/$id').remove();
      // await FirebaseDatabase.instance.ref('filledledger/$id').remove();
      await fetchCustomers();
    } catch (e) {
      print("Error deleting customer: $e");
      throw e;
    }
  }
}
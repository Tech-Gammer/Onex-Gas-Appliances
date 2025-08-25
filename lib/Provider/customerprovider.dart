import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class Customer {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String city;
  final double? openingBalance;
  final DateTime? openingBalanceDate;
  final String customerSerial;

  Customer({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.city,
    this.openingBalance,
    this.openingBalanceDate,
    this.customerSerial = '',
  });

  // Helper method to get numerical value for sorting
  int get serialNumberValue {
    if (customerSerial.isEmpty) return 0;

    // Simple conversion for sorting: A=1, B=2, ..., Z=26, AA=27, AB=28, etc.
    int value = 0;
    for (int i = 0; i < customerSerial.length; i++) {
      value = value * 26 + (customerSerial.codeUnitAt(i) - 64);
    }
    return value;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'phone': phone,
      'city': city,
      'openingBalance': openingBalance ?? 0.0,
      'openingBalanceDate': openingBalanceDate?.toIso8601String(),
      'customerSerial': customerSerial,
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
          : null,
      customerSerial: data['customerSerial']?.toString() ?? '',
    );
  }
}

class CustomerProvider with ChangeNotifier {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('customers');
  final DatabaseReference _serialRef = FirebaseDatabase.instance.ref().child('customerSerialCounter');

  List<Customer> _customers = [];
  List<Customer> get customers => _customers;

  String _numberToAlphabetical(int number) {
    String result = '';
    while (number > 0) {
      number--; // Adjust for 1-based indexing
      result = String.fromCharCode(65 + (number % 26)) + result;
      number = number ~/ 26;
    }
    return result.isEmpty ? 'A' : result;
  }

  int _alphabeticalToNumber(String alphabetical) {
    int result = 0;
    for (int i = 0; i < alphabetical.length; i++) {
      result = result * 26 + (alphabetical.codeUnitAt(i) - 64); // A=1, B=2, etc.
    }
    return result;
  }


  Future<String> _generateCustomerSerial() async {
    final counterSnapshot = await _serialRef.get();
    int lastNumber = 0;

    if (counterSnapshot.exists) {
      final data = counterSnapshot.value as Map<dynamic, dynamic>;
      lastNumber = (data['lastNumber'] as int?) ?? 0;
    }

    // Increment and save the counter
    lastNumber++;

    await _serialRef.set({
      'lastNumber': lastNumber,
      'lastUpdated': DateTime.now().toIso8601String(),
    });

    // Convert number to alphabetical representation
    return _numberToAlphabetical(lastNumber);
  }

  Future<void> fetchCustomers() async {
    final snapshot = await _dbRef.get();
    if (snapshot.exists) {
      _customers = (snapshot.value as Map).entries.map((e) => Customer.fromSnapshot(e.key, e.value)).toList();

      // Sort customers by their serial number (alphabetical order)
      _customers.sort((a, b) {
        if (a.customerSerial.isEmpty && b.customerSerial.isEmpty) return 0;
        if (a.customerSerial.isEmpty) return 1;
        if (b.customerSerial.isEmpty) return -1;

        // Convert alphabetical serials back to numbers for proper sorting
        int aNum = _alphabeticalToNumber(a.customerSerial);
        int bNum = _alphabeticalToNumber(b.customerSerial);
        return aNum.compareTo(bNum);
      });

      notifyListeners();
    }
  }

  Future<void> addCustomerWithSerial(String name, String address, String phone, String city,
      [double openingBalance = 0.0, DateTime? openingBalanceDate]) async {

    // Generate serial number first
    final customerSerial = await _generateCustomerSerial();
    final newCustomer = _dbRef.push();
    final customerId = newCustomer.key!;

    await newCustomer.set({
      'name': name,
      'address': address,
      'phone': phone,
      'city': city,
      'openingBalance': openingBalance,
      'openingBalanceDate': (openingBalanceDate ?? DateTime.now()).toIso8601String(),
      'customerSerial': customerSerial, // Add the serial number
      'createdAt': DateTime.now().toIso8601String(),
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
      )
  async {
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

    // First get the current customer to preserve serial number
    final customerSnapshot = await _dbRef.child(id).get();
    String customerSerial = '';

    if (customerSnapshot.exists) {
      final data = customerSnapshot.value as Map<dynamic, dynamic>;
      customerSerial = data['customerSerial']?.toString() ?? '';
    }

    // If no serial exists (old customer), generate one
    if (customerSerial.isEmpty) {
      customerSerial = await _generateCustomerSerial();
    }

    // Update customer node
    await _dbRef.child(id).update({
      'name': name,
      'address': address,
      'phone': phone,
      'city': city,
      'openingBalance': openingBalance,
      'openingBalanceDate': openingBalanceDate?.toIso8601String(),
      'customerSerial': customerSerial, // Ensure serial is set
    });

    // Update opening balance in filledledger
    await _updateOpeningBalanceInLedger(id, openingBalance, openingBalanceDate);

    fetchCustomers(); // Refresh list
  }

  Future<void> _updateOpeningBalanceInLedger(
      String customerId,
      double openingBalance,
      DateTime? date)
  async {
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
      await fetchCustomers();
    } catch (e) {
      print("Error deleting customer: $e");
      throw e;
    }
  }

  Future<void> addCustomer(String name, String address, String phone, String city,
      [double openingBalance = 0.0, DateTime? openingBalanceDate]) async {
    await addCustomerWithSerial(name, address, phone, city, openingBalance, openingBalanceDate);
  }

  // Update the Customer model to include serial number
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
          : null,
      customerSerial: data['customerSerial']?.toString() ?? '', // Add this line
    );
  }

}
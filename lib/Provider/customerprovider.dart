import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class Customer {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String city;
  final double? openingBalance; // Add this field

  Customer({required this.id, required this.name, required this.address, required this.phone,required this.city, this.openingBalance});

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'phone': phone,
      'city': city,
      'openingBalance': openingBalance??0.0, // Include in JSON

    };
  }

  static Customer fromSnapshot(String id, Map<dynamic, dynamic> data) {
    return Customer(
      id: id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      phone: data['phone'] ?? '',
      city: data['city'] ?? '',
      openingBalance: (data['openingBalance'] as num?)?.toDouble(), // Handle null

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


  Future<void> addCustomer(String name, String address, String phone, String city, [double openingBalance = 0.0]) async {
    final newCustomer = _dbRef.push();
    await newCustomer.set({'name': name, 'address': address, 'phone': phone,'city':city,'openingBalance': openingBalance});
    fetchCustomers(); // Refresh customer list
  }

  Future<void> updateCustomer(String id, String name, String address, String phone,String city, [double openingBalance = 0.0]) async {
    await _dbRef.child(id).update({'name': name, 'address': address, 'phone': phone, 'city': city,'openingBalance': openingBalance});
    fetchCustomers(); // Refresh list
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

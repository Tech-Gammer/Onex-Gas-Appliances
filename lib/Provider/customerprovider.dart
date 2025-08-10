import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class Customer {
  final String id;
  final String name;
  final String address;
  final String phone;

  Customer({required this.id, required this.name, required this.address, required this.phone});

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'phone': phone,
    };
  }

  static Customer fromSnapshot(String id, Map<dynamic, dynamic> data) {
    return Customer(
      id: id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      phone: data['phone'] ?? '',
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


  Future<void> addCustomer(String name, String address, String phone) async {
    final newCustomer = _dbRef.push();
    await newCustomer.set({'name': name, 'address': address, 'phone': phone});
    fetchCustomers(); // Refresh customer list
  }

  Future<void> updateCustomer(String id, String name, String address, String phone) async {
    await _dbRef.child(id).update({'name': name, 'address': address, 'phone': phone});
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

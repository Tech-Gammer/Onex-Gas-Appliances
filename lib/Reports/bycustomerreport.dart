import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';

import '../Provider/lanprovider.dart';

class byCustomerReport extends StatefulWidget {
  final String customerId;
  final String customerName;
  final String customerPhone;

  byCustomerReport({
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
  });

  @override
  _byCustomerReportState createState() => _byCustomerReportState();
}

class _byCustomerReportState extends State<byCustomerReport> {

  double? remainingBalance;

  @override
  void initState() {
    super.initState();
    // Fetch the remaining balance from Firebase
    _getCustomerBalance(widget.customerId);
  }

  Future<void> _getCustomerBalance(String customerId) async {
    try {
      final DatabaseReference ledgerRef = FirebaseDatabase.instance.ref().child('ledger').child(customerId);

      // Query to get the latest ledger entry
      final snapshot = await ledgerRef.orderByChild('createdAt').limitToLast(1).get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        // Since data is a map, we need to access the correct values.
        final lastTransaction = data.values.first;
        if (lastTransaction is Map) {
          setState(() {
            // Extract and safely convert the remainingBalance
            var balance = lastTransaction['remainingBalance'];
            if (balance is int) {
              remainingBalance = balance.toDouble();  // Convert int to double
            } else if (balance is double) {
              remainingBalance = balance;  // If already a double, use it as is
            } else {
              remainingBalance = 0.0;  // Default to 0.0 if it's neither int nor double
            }
          });
        }
      } else {
        setState(() {
          remainingBalance = 0.0; // If no ledger entries exist, set balance to 0
        });
      }
    } catch (e) {
      print('Error fetching customer balance: $e');
      setState(() {
        remainingBalance = 0.0; // In case of error, set balance to 0
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.isEnglish ? 'Customer Report' : 'کسٹمر رپورٹ',
          style: TextStyle(
            color: Colors.white
          ),// Dynamic text based on language

        ),
        backgroundColor: Colors.teal,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customer: ${widget.customerName}',
              style: TextStyle(fontSize: 18, color: Colors.teal.shade800),
            ),
            Text(
              'Phone: ${widget.customerPhone}',
              style: TextStyle(fontSize: 16, color: Colors.teal.shade600),
            ),
            SizedBox(height: 20),
            remainingBalance == null
                ? CircularProgressIndicator() // Show loading indicator while fetching data
                : Text(
              'Remaining Balance: Rs. ${remainingBalance?.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 18, color: Colors.red.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

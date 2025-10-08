import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../Provider/lanprovider.dart';
import '../Provider/customerprovider.dart';
import '../Provider/filled provider.dart';

class BalanceSummaryPage extends StatefulWidget {
  const BalanceSummaryPage({super.key});

  @override
  State<BalanceSummaryPage> createState() => _BalanceSummaryPageState();
}

class _BalanceSummaryPageState extends State<BalanceSummaryPage> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // Summary data
  double _totalCustomerDebit = 0.0;
  double _totalCustomerCredit = 0.0;
  double _totalVendorDebit = 0.0;
  double _totalVendorCredit = 0.0;
  double _totalPurchaseAmount = 0.0;

  // Detailed lists
  List<Map<String, dynamic>> _customerBalances = [];
  List<Map<String, dynamic>> _vendorBalances = [];
  List<Map<String, dynamic>> _recentPurchases = [];

  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadBalanceSummary();
  }

  Future<void> _loadBalanceSummary() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _loadCustomerBalances(),
        _loadVendorBalances(),
        _loadPurchaseSummary(),
      ]);
    } catch (e) {
      print('Error loading balance summary: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCustomerBalances() async {
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    await customerProvider.fetchCustomers();

    _totalCustomerDebit = 0.0;
    _totalCustomerCredit = 0.0;
    _customerBalances.clear();

    for (final customer in customerProvider.customers) {
      final balance = await _getCustomerBalance(customer.id);

      if (balance > 0) {
        _totalCustomerDebit += balance;
      } else if (balance < 0) {
        _totalCustomerCredit += balance.abs();
      }

      _customerBalances.add({
        'id': customer.id,
        'name': customer.name,
        'balance': balance,
        'type': 'customer',
      });
    }

    // Sort by balance (highest debt first)
    _customerBalances.sort((a, b) => b['balance'].compareTo(a['balance']));
  }

  Future<void> _loadVendorBalances() async {
    final vendorSnapshot = await _db.child('vendors').get();

    _totalVendorDebit = 0.0;
    _totalVendorCredit = 0.0;
    _vendorBalances.clear();

    if (vendorSnapshot.exists) {
      final vendors = vendorSnapshot.value as Map<dynamic, dynamic>;

      for (final entry in vendors.entries) {
        final vendor = entry.value as Map<dynamic, dynamic>;
        final vendorId = entry.key.toString();

        // Calculate vendor balance (amount we owe to vendor)
        final openingBalance = (vendor['openingBalance'] ?? 0.0).toDouble();
        final paidAmount = (vendor['paidAmount'] ?? 0.0).toDouble();

        // Get total purchases from this vendor
        final purchaseBalance = await _getVendorPurchaseBalance(vendorId);

        // Balance = (Opening Balance + Purchases) - Payments
        final totalBalance = (openingBalance + purchaseBalance) - paidAmount;

        if (totalBalance > 0) {
          _totalVendorCredit += totalBalance; // We owe this to vendor
        } else if (totalBalance < 0) {
          _totalVendorDebit += totalBalance.abs(); // Vendor owes us (advance payment)
        }

        _vendorBalances.add({
          'id': vendorId,
          'name': vendor['name'] ?? 'Unknown Vendor',
          'balance': totalBalance,
          'type': 'vendor',
          'openingBalance': openingBalance,
          'purchases': purchaseBalance,
          'paid': paidAmount,
        });
      }
    }

    // Sort by balance (highest credit first)
    _vendorBalances.sort((a, b) => b['balance'].compareTo(a['balance']));
  }

  Future<void> _loadPurchaseSummary() async {
    final purchaseSnapshot = await _db.child('purchases')
        .orderByChild('timestamp')
        .limitToLast(50) // Last 50 purchases
        .get();

    _totalPurchaseAmount = 0.0;
    _recentPurchases.clear();

    if (purchaseSnapshot.exists) {
      final purchases = purchaseSnapshot.value as Map<dynamic, dynamic>;

      for (final entry in purchases.entries) {
        final purchase = entry.value as Map<dynamic, dynamic>;
        final amount = (purchase['grandTotal'] ?? 0.0).toDouble();

        _totalPurchaseAmount += amount;

        _recentPurchases.add({
          'id': entry.key,
          'vendorName': purchase['vendorName'] ?? 'Unknown Vendor',
          'amount': amount,
          'date': purchase['timestamp'] ?? '',
          'items': purchase['items'] ?? [],
        });
      }
    }

    // Sort by date (newest first)
    _recentPurchases.sort((a, b) => b['date'].compareTo(a['date']));
  }

  Future<double> _getCustomerBalance(String customerId) async {
    try {
      final ledgerRef = _db.child('filledledger').child(customerId);
      final snapshot = await ledgerRef.orderByChild('createdAt').once();

      double balance = 0.0;

      if (snapshot.snapshot.exists) {
        final ledgerEntries = snapshot.snapshot.value as Map<dynamic, dynamic>;

        ledgerEntries.forEach((key, value) {
          if (value != null && value is Map) {
            final debitAmount = (value['debitAmount'] ?? 0.0).toDouble();
            final creditAmount = (value['creditAmount'] ?? 0.0).toDouble();
            balance = balance + creditAmount - debitAmount;
          }
        });
      }

      return balance;
    } catch (e) {
      print("Error calculating customer balance: $e");
      return 0.0;
    }
  }

  Future<double> _getVendorPurchaseBalance(String vendorId) async {
    try {
      final purchaseSnapshot = await _db.child('purchases')
          .orderByChild('vendorId')
          .equalTo(vendorId)
          .get();

      double totalPurchases = 0.0;

      if (purchaseSnapshot.exists) {
        final purchases = purchaseSnapshot.value as Map<dynamic, dynamic>;

        purchases.forEach((key, value) {
          if (value != null && value is Map) {
            totalPurchases += (value['grandTotal'] ?? 0.0).toDouble();
          }
        });
      }

      return totalPurchases;
    } catch (e) {
      print("Error calculating vendor purchase balance: $e");
      return 0.0;
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadBalanceSummary();
    }
  }

  Widget _buildSummaryCard(String title, double debit, double credit, Color color) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  languageProvider.isEnglish ? 'Debit (Receivable)' : 'ڈیبٹ (وصولی)',
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                  '${debit.toStringAsFixed(2)} Rs',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  languageProvider.isEnglish ? 'Credit (Payable)' : 'کریڈٹ (ادائیگی)',
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                  '${credit.toStringAsFixed(2)} Rs',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(color: color.withOpacity(0.3)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  languageProvider.isEnglish ? 'Net Balance' : 'نیٹ بیلنس',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${(debit - credit).toStringAsFixed(2)} Rs',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: (debit - credit) >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceList(String title, List<Map<String, dynamic>> balances, Color color) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            if (balances.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  languageProvider.isEnglish ? 'No records found' : 'کوئی ریکارڈ نہیں ملا',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              )
            else
              Column(
                children: balances.map((balance) {
                  final amount = balance['balance'] as double;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: color.withOpacity(0.2),
                      child: Icon(
                        balance['type'] == 'customer' ? Icons.person : Icons.business,
                        color: color,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      balance['name'],
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: balance['type'] == 'vendor'
                        ? Text(
                        '${languageProvider.isEnglish ? 'Purchases' : 'خریداری'}: ${(balance['purchases'] ?? 0.0).toStringAsFixed(2)} | '
                            '${languageProvider.isEnglish ? 'Paid' : 'ادا کیا'}: ${(balance['paid'] ?? 0.0).toStringAsFixed(2)}'
                    )
                        : null,
                    trailing: Text(
                      '${amount.toStringAsFixed(2)} Rs',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: amount >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseSummary() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  languageProvider.isEnglish ? 'Recent Purchases' : 'حالیہ خریداریاں',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                Text(
                  '${_totalPurchaseAmount.toStringAsFixed(2)} Rs',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_recentPurchases.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  languageProvider.isEnglish ? 'No purchases found' : 'کوئی خریداری نہیں ملی',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              )
            else
              Column(
                children: _recentPurchases.take(5).map((purchase) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.withOpacity(0.2),
                      child: const Icon(Icons.shopping_cart, color: Colors.orange, size: 20),
                    ),
                    title: Text(
                      purchase['vendorName'],
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      DateFormat('MMM dd, yyyy').format(
                        DateTime.parse(purchase['date']),
                      ),
                    ),
                    trailing: Text(
                      '${purchase['amount'].toStringAsFixed(2)} Rs',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.isEnglish ? 'Balance Summary' : 'بیلنس کا خلاصہ',
          style: const TextStyle(color: Colors.white),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF8A65), Color(0xFFFFB74D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadBalanceSummary,
            tooltip: languageProvider.isEnglish ? 'Refresh' : 'تازہ کریں',
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: () => _selectDate(context),
            tooltip: languageProvider.isEnglish ? 'Select Date' : 'تاریخ منتخب کریں',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      languageProvider.isEnglish ? 'Summary as of:' : 'تاریخ تک کا خلاصہ:',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      DateFormat('MMMM dd, yyyy').format(_selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Customer Summary
            _buildSummaryCard(
              languageProvider.isEnglish ? 'Customer Balances' : 'کسٹمر بیلنس',
              _totalCustomerDebit,
              _totalCustomerCredit,
              Colors.blue,
            ),

            const SizedBox(height: 16),

            // Vendor Summary
            _buildSummaryCard(
              languageProvider.isEnglish ? 'Vendor Balances' : 'وینڈر بیلنس',
              _totalVendorDebit,
              _totalVendorCredit,
              Colors.purple,
            ),

            const SizedBox(height: 24),

            // Customer Balances List
            _buildBalanceList(
              languageProvider.isEnglish ? 'Customer Details' : 'کسٹمر کی تفصیلات',
              _customerBalances.where((c) => c['balance'] != 0).toList(),
              Colors.blue,
            ),

            const SizedBox(height: 16),

            // Vendor Balances List
            _buildBalanceList(
              languageProvider.isEnglish ? 'Vendor Details' : 'وینڈر کی تفصیلات',
              _vendorBalances.where((v) => v['balance'] != 0).toList(),
              Colors.purple,
            ),

            const SizedBox(height: 16),

            // Purchase Summary
            _buildPurchaseSummary(),

            const SizedBox(height: 20),

            // Overall Summary
            Card(
              elevation: 4,
              color: Colors.grey[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      languageProvider.isEnglish ? 'Overall Summary' : 'مجموعی خلاصہ',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryRow(
                      languageProvider.isEnglish ? 'Total Receivable from Customers' : 'کسٹمرز سے کل وصولی',
                      _totalCustomerDebit,
                      Colors.green,
                    ),
                    _buildSummaryRow(
                      languageProvider.isEnglish ? 'Total Payable to Customers' : 'کسٹمرز کو کل ادائیگی',
                      _totalCustomerCredit,
                      Colors.red,
                    ),
                    _buildSummaryRow(
                      languageProvider.isEnglish ? 'Total Receivable from Vendors' : 'وینڈرز سے کل وصولی',
                      _totalVendorDebit,
                      Colors.green,
                    ),
                    _buildSummaryRow(
                      languageProvider.isEnglish ? 'Total Payable to Vendors' : 'وینڈرز کو کل ادائیگی',
                      _totalVendorCredit,
                      Colors.red,
                    ),
                    const Divider(),
                    _buildSummaryRow(
                      languageProvider.isEnglish ? 'Net Business Balance' : 'نیٹ بزنس بیلنس',
                      (_totalCustomerDebit + _totalVendorDebit) - (_totalCustomerCredit + _totalVendorCredit),
                      (_totalCustomerDebit + _totalVendorDebit) - (_totalCustomerCredit + _totalVendorCredit) >= 0
                          ? Colors.green
                          : Colors.red,
                      isBold: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${value.toStringAsFixed(2)} Rs',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
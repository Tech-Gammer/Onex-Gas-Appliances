import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Provider/lanprovider.dart';

class VendorChequesPage extends StatefulWidget {
  const VendorChequesPage({super.key});

  @override
  State<VendorChequesPage> createState() => _VendorChequesPageState();
}

class _VendorChequesPageState extends State<VendorChequesPage> {
  List<Map<String, dynamic>> _cheques = [];
  bool _isLoading = true;
  String _filterStatus = 'all';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCheques();
    _searchController.addListener(_filterCheques);
  }

  Future<void> _fetchCheques() async {
    try {
      final snapshot = await FirebaseDatabase.instance.ref('vendorCheques').get();
      if (snapshot.value == null) {
        setState(() {
          _cheques = [];
          _isLoading = false;
        });
        return;
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      final List<Map<String, dynamic>> cheques = [];

      data.forEach((key, value) {
        cheques.add({
          'id': key.toString(),
          'vendorId': value['vendorId'] ?? '',
          'vendorName': value['vendorName'] ?? 'Unknown Vendor',
          'amount': (value['amount'] ?? 0.0).toDouble(),
          'chequeNumber': value['chequeNumber'] ?? '',
          'chequeDate': value['chequeDate'] ?? '',
          'bankId': value['bankId'] ?? '',
          'bankName': value['bankName'] ?? 'Unknown Bank',
          'status': value['status'] ?? 'pending',
          'dateIssued': value['dateIssued'] ?? DateTime.now().toString(),
          'description': value['description'] ?? '',
          'image': value['image'] ?? '',
        });
      });

      setState(() {
        _cheques = cheques;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching cheques: $e')),
      );
    }
  }

  void _filterCheques() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _cheques = _cheques.where((cheque) {
        final matchesSearch = cheque['vendorName'].toLowerCase().contains(query) ||
            cheque['chequeNumber'].contains(query);
        final matchesStatus = _filterStatus == 'all' ||
            cheque['status'] == _filterStatus;
        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  Future<void> _updateChequeStatus(String chequeId, String newStatus) async {
    try {
      final chequeRef = FirebaseDatabase.instance.ref('vendorCheques/$chequeId');
      final chequeSnapshot = await chequeRef.get();
      final cheque = chequeSnapshot.value as Map<dynamic, dynamic>;

      if (newStatus == 'cleared') {
        final vendorRef = FirebaseDatabase.instance.ref('vendors/${cheque['vendorId']}');

        // Create payment data
        final paymentData = {
          'amount': cheque['amount'],
          'date': DateTime.now().toIso8601String(),
          'method': 'Cheque',
          'description': cheque['description'] ?? 'Cheque Payment',
          'vendorId': cheque['vendorId'],
          'vendorName': cheque['vendorName'],
          'chequeNumber': cheque['chequeNumber'],
          'chequeDate': cheque['chequeDate'],
          'bankId': cheque['bankId'],
          'bankName': cheque['bankName'],
          'status': 'cleared',
          if (cheque['image'] != null) 'image': cheque['image'],
        };

        // Add to vendor payments
        final paymentRef = vendorRef.child('payments').push();
        await paymentRef.set(paymentData);

        // Update vendor's paid amount
        await vendorRef.child('paidAmount')
            .set(ServerValue.increment(cheque['amount']));

        // Update cheque record with payment reference
        await chequeRef.update({
          'status': 'cleared',
          'statusUpdatedAt': DateTime.now().toIso8601String(),
          'vendorPaymentId': paymentRef.key,
        });

        // Update bank balance
        final bankRef = FirebaseDatabase.instance.ref('banks/${cheque['bankId']}/balance');
        final currentBalance = (await bankRef.get()).value as num? ?? 0.0;
        await bankRef.set(currentBalance - cheque['amount']);
      } else {
        // For other status changes (pending/bounced)
        await chequeRef.update({
          'status': newStatus,
          'statusUpdatedAt': DateTime.now().toIso8601String(),
        });

        // If changing from cleared to another status, remove the payment
        if (cheque['status'] == 'cleared' && cheque['vendorPaymentId'] != null) {
          final vendorRef = FirebaseDatabase.instance.ref('vendors/${cheque['vendorId']}');
          await vendorRef.child('payments/${cheque['vendorPaymentId']}').remove();
          await vendorRef.child('paidAmount')
              .set(ServerValue.increment(-cheque['amount']));
        }
      }

      // Refresh the list
      await _fetchCheques();

      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(languageProvider.isEnglish
            ? 'Cheque status updated successfully!'
            : 'چیک کی حیثیت کامیابی سے اپ ڈیٹ ہو گئی!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating cheque: $e')),
      );
    }
  }

  void _showChequeDetails(Map<String, dynamic> cheque) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.isEnglish ? 'Cheque Details' : 'چیک کی تفصیلات'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(languageProvider.isEnglish ? 'Vendor' : 'فروش', cheque['vendorName']),
              _buildDetailRow(languageProvider.isEnglish ? 'Amount' : 'رقم', '${cheque['amount']} Rs'),
              _buildDetailRow(languageProvider.isEnglish ? 'Cheque Number' : 'چیک نمبر', cheque['chequeNumber']),
              _buildDetailRow(languageProvider.isEnglish ? 'Cheque Date' : 'چیک کی تاریخ', cheque['chequeDate']),
              _buildDetailRow(languageProvider.isEnglish ? 'Bank' : 'بینک', cheque['bankName']),
              _buildDetailRow(
                languageProvider.isEnglish ? 'Status' : 'حالت',
                cheque['status'],
                style: TextStyle(
                  color: _getStatusColor(cheque['status']),
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (cheque['status'] == 'cleared')
                _buildDetailRow(languageProvider.isEnglish ? 'Cleared Date' : 'کلئیر ہونے کی تاریخ',
                    cheque['statusUpdatedAt'] ?? ''),
              _buildDetailRow(languageProvider.isEnglish ? 'Issued Date' : 'جاری کرنے کی تاریخ', cheque['dateIssued']),
              if (cheque['description'].isNotEmpty)
                _buildDetailRow(languageProvider.isEnglish ? 'Description' : 'تفصیل', cheque['description']),

              if (cheque['image'] != null && cheque['image'].isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: GestureDetector(
                    onTap: () => _showFullScreenImage(base64Decode(cheque['image'])),
                    child: Image.memory(
                      base64Decode(cheque['image']),
                      height: 100,
                      width: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(languageProvider.isEnglish ? 'Close' : 'بند کریں'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {TextStyle? style}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              style: style,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFullScreenImage(Uint8List imageBytes) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.memory(imageBytes),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'cleared':
        return Colors.green;
      case 'bounced':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(languageProvider.isEnglish ? 'Vendor Cheques' : 'فروش چیکس'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF8A65), Color(0xFFFFB74D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: languageProvider.isEnglish ? 'Search cheques' : 'چیک تلاش کریں',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _filterStatus,
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text(languageProvider.isEnglish ? 'All' : 'سب'),
                    ),
                    DropdownMenuItem(
                      value: 'pending',
                      child: Text(languageProvider.isEnglish ? 'Pending' : 'زیر التوا'),
                    ),
                    DropdownMenuItem(
                      value: 'cleared',
                      child: Text(languageProvider.isEnglish ? 'Cleared' : 'کلئیر'),
                    ),
                    DropdownMenuItem(
                      value: 'bounced',
                      child: Text(languageProvider.isEnglish ? 'Bounced' : 'باؤنس'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _filterStatus = value!);
                    _filterCheques();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _cheques.isEmpty
                ? Center(
              child: Text(
                languageProvider.isEnglish
                    ? 'No cheques found'
                    : 'کوئی چیک نہیں ملا',
              ),
            )
                : ListView.builder(
              itemCount: _cheques.length,
              itemBuilder: (context, index) {
                final cheque = _cheques[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getStatusColor(cheque['status']),
                      child: Text(
                        cheque['amount'].toStringAsFixed(0),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(cheque['vendorName']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${languageProvider.isEnglish ? 'Cheque No' : 'چیک نمبر'}: ${cheque['chequeNumber']}',
                        ),
                        Text(
                          '${languageProvider.isEnglish ? 'Bank' : 'بینک'}: ${cheque['bankName']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          '${languageProvider.isEnglish ? 'Status' : 'حالت'}: ${cheque['status']}',
                          style: TextStyle(
                            color: _getStatusColor(cheque['status']),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) =>
                          _updateChequeStatus(cheque['id'], value),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'pending',
                          child: Text(languageProvider.isEnglish
                              ? 'Mark as Pending'
                              : 'زیر التوا کے طور پر نشان زد کریں'),
                        ),
                        PopupMenuItem(
                          value: 'cleared',
                          child: Text(languageProvider.isEnglish
                              ? 'Mark as Cleared'
                              : 'کلئیر کے طور پر نشان زد کریں'),
                        ),
                        PopupMenuItem(
                          value: 'bounced',
                          child: Text(languageProvider.isEnglish
                              ? 'Mark as Bounced'
                              : 'باؤنس کے طور پر نشان زد کریں'),
                        ),
                      ],
                    ),
                    onTap: () => _showChequeDetails(cheque),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
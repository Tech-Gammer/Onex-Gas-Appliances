import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import '../Provider/customerprovider.dart';
import '../Provider/lanprovider.dart';
import 'package:pdf/pdf.dart';

class CustomerPaymentHistoryPage extends StatefulWidget {
  final Customer customer;

  const CustomerPaymentHistoryPage({Key? key, required this.customer}) : super(key: key);

  @override
  _CustomerPaymentHistoryPageState createState() => _CustomerPaymentHistoryPageState();
}

class _CustomerPaymentHistoryPageState extends State<CustomerPaymentHistoryPage> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _filteredPayments = [];
  bool _isLoading = true;
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _searchController = TextEditingController();
  Set<String> _selectedPaymentMethods = {};
  List<String> _availablePaymentMethods = [];

  @override
  void initState() {
    super.initState();
    _loadPaymentHistory();
    // Set default date range to last 30 days
    _endDate = DateTime.now();
    _startDate = DateTime.now().subtract(const Duration(days: 30));
  }

  Future<void> _loadPaymentHistory() async {
    try {
      final customerLedgerRef = _db.child('filledledger').child(widget.customer.id);
      final DatabaseEvent snapshot = await customerLedgerRef.orderByChild('createdAt').once();

      if (snapshot.snapshot.exists) {
        final Map<dynamic, dynamic> ledgerEntries = snapshot.snapshot.value as Map<dynamic, dynamic>;
        final List<Map<String, dynamic>> payments = [];
        final Set<String> paymentMethods = {};

        ledgerEntries.forEach((key, value) {
          if (value != null && value is Map) {
            final debitAmount = (value['debitAmount'] ?? 0.0).toDouble();
            if (debitAmount > 0) { // Only show debit entries (payments)
              final paymentMethod = value['paymentMethod'] ?? '';
              payments.add({
                'key': key,
                'amount': debitAmount,
                'date': value['createdAt'] ?? '',
                'method': paymentMethod,
                'description': value['description'] ?? '',
                'bankName': value['bankName'] ?? '',
                'chequeNumber': value['chequeNumber'] ?? '',
                'filledNumber': value['filledNumber'] ?? '',
                'referenceNumber': value['referenceNumber'] ?? '',
              });

              // Add to available payment methods
              if (paymentMethod.isNotEmpty) {
                paymentMethods.add(paymentMethod);
              }
            }
          }
        });

        // Sort by date descending
        payments.sort((a, b) => b['date'].compareTo(a['date']));

        setState(() {
          _payments = payments;
          _availablePaymentMethods = paymentMethods.toList()..sort();
          // Select all payment methods by default
          _selectedPaymentMethods = paymentMethods.toSet();
          _filteredPayments = _applyFilters(payments);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading payment history: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> payments) {
    List<Map<String, dynamic>> filtered = List.from(payments);

    // Apply date filter
    if (_startDate != null && _endDate != null) {
      filtered = filtered.where((payment) {
        final paymentDate = DateTime.parse(payment['date']);
        return paymentDate.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
            paymentDate.isBefore(_endDate!.add(const Duration(days: 1)));
      }).toList();
    }

    // Apply payment method filter
    if (_selectedPaymentMethods.isNotEmpty) {
      filtered = filtered.where((payment) {
        return _selectedPaymentMethods.contains(payment['method']);
      }).toList();
    }

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((payment) {
        return payment['method'].toLowerCase().contains(query) ||
            payment['description'].toLowerCase().contains(query) ||
            (payment['bankName'] != null && payment['bankName'].toLowerCase().contains(query)) ||
            (payment['chequeNumber'] != null && payment['chequeNumber'].toLowerCase().contains(query)) ||
            (payment['filledNumber'] != null && payment['filledNumber'].toLowerCase().contains(query)) ||
            (payment['referenceNumber'] != null && payment['referenceNumber'].toLowerCase().contains(query)) ||
            payment['amount'].toString().contains(query);
      }).toList();
    }

    return filtered;
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
        end: _endDate ?? DateTime.now(),
      ),
      helpText: languageProvider.isEnglish ? 'Select Date Range' : 'تاریخ کی حد منتخب کریں',
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _filteredPayments = _applyFilters(_payments);
      });
    }
  }

  void _showPaymentMethodFilterDialog(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(languageProvider.isEnglish
                  ? 'Filter by Payment Method'
                  : 'ادائیگی کے طریقے سے فلٹر کریں'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_availablePaymentMethods.isNotEmpty)
                      ..._availablePaymentMethods.map((method) {
                        return CheckboxListTile(
                          title: Text(method),
                          value: _selectedPaymentMethods.contains(method),
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                _selectedPaymentMethods.add(method);
                              } else {
                                _selectedPaymentMethods.remove(method);
                              }
                            });
                          },
                        );
                      }).toList(),
                    if (_availablePaymentMethods.isEmpty)
                      Text(languageProvider.isEnglish
                          ? 'No payment methods available'
                          : 'کوئی ادائیگی کا طریقہ دستیاب نہیں ہے'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      // Select all methods
                      _selectedPaymentMethods = _availablePaymentMethods.toSet();
                    });
                    Navigator.of(context).pop();
                    _filteredPayments = _applyFilters(_payments);
                  },
                  child: Text(languageProvider.isEnglish ? 'Select All' : 'سب منتخب کریں'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      // Clear all selections
                      _selectedPaymentMethods.clear();
                    });
                    Navigator.of(context).pop();
                    _filteredPayments = _applyFilters(_payments);
                  },
                  child: Text(languageProvider.isEnglish ? 'Clear All' : 'سب صاف کریں'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _filteredPayments = _applyFilters(_payments);
                    });
                  },
                  child: Text(languageProvider.isEnglish ? 'Apply' : 'لاگو کریں'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      setState(() {
        _filteredPayments = _applyFilters(_payments);
      });
    });
  }

  Future<void> _generateAndPrintPDF() async {
    final pdf = pw.Document();
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              languageProvider.isEnglish
                  ? 'Payment History - ${widget.customer.name}'
                  : 'ادائیگی کی تاریخ - ${widget.customer.name}',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 16),
          if (_startDate != null && _endDate != null)
            pw.Text(
              languageProvider.isEnglish
                  ? 'Date Range: ${DateFormat('yyyy-MM-dd').format(_startDate!)} to ${DateFormat('yyyy-MM-dd').format(_endDate!)}'
                  : 'تاریخ کی حد: ${DateFormat('yyyy-MM-dd').format(_startDate!)} سے ${DateFormat('yyyy-MM-dd').format(_endDate!)}',
              style: const pw.TextStyle(fontSize: 12),
            ),
          if (_selectedPaymentMethods.isNotEmpty)
            pw.Text(
              languageProvider.isEnglish
                  ? 'Payment Methods: ${_selectedPaymentMethods.join(', ')}'
                  : 'ادائیگی کے طریقے: ${_selectedPaymentMethods.join(', ')}',
              style: const pw.TextStyle(fontSize: 12),
            ),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: [
              languageProvider.isEnglish ? 'Date' : 'تاریخ',
              languageProvider.isEnglish ? 'Method' : 'طریقہ',
              languageProvider.isEnglish ? 'Amount' : 'رقم',
              languageProvider.isEnglish ? 'Description' : 'تفصیل',
              languageProvider.isEnglish ? 'Reference' : 'حوالہ',
            ],
            data: _filteredPayments.map((payment) {
              return [
                DateFormat('yyyy-MM-dd').format(DateTime.parse(payment['date'])),
                payment['method'],
                '${payment['amount'].toStringAsFixed(2)} Rs',
                payment['description'] ?? '',
                payment['referenceNumber'] ?? payment['filledNumber'] ?? '',
              ];
            }).toList(),
            border: pw.TableBorder.all(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                languageProvider.isEnglish ? 'Total Payments:' : 'کل ادائیگیاں:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                '${_calculateTotal().toStringAsFixed(2)} Rs',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  double _calculateTotal() {
    return _filteredPayments.fold(0.0, (sum, payment) => sum + (payment['amount'] ?? 0.0));
  }

  Future<void> _deletePayment(Map<String, dynamic> payment) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);

    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.isEnglish
            ? 'Delete Payment?'
            : 'ادائیگی حذف کریں؟'),
        content: Text(languageProvider.isEnglish
            ? 'Are you sure you want to delete this payment of Rs. ${payment['amount']}?'
            : 'کیا آپ واقعی اس ${payment['amount']} روپے کی ادائیگی کو حذف کرنا چاہتے ہیں؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(languageProvider.isEnglish ? 'Delete' : 'حذف کریں'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Delete from filledledger
        await _db.child('filledledger').child(widget.customer.id).child(payment['key']).remove();

        // Refresh the list
        await _loadPaymentHistory();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(languageProvider.isEnglish
                ? 'Payment deleted successfully'
                : 'ادائیگی کامیابی سے حذف ہو گئی'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting payment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.isEnglish
              ? 'Payment History - ${widget.customer.name}'
              : 'ادائیگی کی تاریخ - ${widget.customer.name}',
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
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: _generateAndPrintPDF,
            tooltip: languageProvider.isEnglish ? 'Export PDF' : 'پی ڈی ایف ایکسپورٹ کریں',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Date Range Filter
                Card(
                  elevation: 2,
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: Text(
                      _startDate != null && _endDate != null
                          ? '${DateFormat('yyyy-MM-dd').format(_startDate!)} - ${DateFormat('yyyy-MM-dd').format(_endDate!)}'
                          : languageProvider.isEnglish
                          ? 'Select Date Range'
                          : 'تاریخ کی حد منتخب کریں',
                    ),
                    trailing: const Icon(Icons.arrow_drop_down),
                    onTap: () => _selectDateRange(context),
                  ),
                ),
                const SizedBox(height: 16),

                // Payment Method Filter
                Card(
                  elevation: 2,
                  child: ListTile(
                    leading: const Icon(Icons.payment),
                    title: Text(
                      _selectedPaymentMethods.isEmpty
                          ? languageProvider.isEnglish
                          ? 'All Payment Methods'
                          : 'تمام ادائیگی کے طریقے'
                          : '${_selectedPaymentMethods.length} ${languageProvider.isEnglish ? 'methods selected' : 'طریقے منتخب'}',
                    ),
                    trailing: const Icon(Icons.arrow_drop_down),
                    onTap: () => _showPaymentMethodFilterDialog(context),
                  ),
                ),
                const SizedBox(height: 16),

                // Search Filter
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: languageProvider.isEnglish ? 'Search Payments' : 'ادائیگیاں تلاش کریں',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _filteredPayments = _applyFilters(_payments);
                    });
                  },
                ),
              ],
            ),
          ),

          // Summary Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              elevation: 3,
              color: Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      languageProvider.isEnglish ? 'Total Payments:' : 'کل ادائیگیاں:',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      '${_calculateTotal().toStringAsFixed(2)} Rs',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Payments List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPayments.isEmpty
                ? Center(
              child: Text(
                languageProvider.isEnglish
                    ? 'No payments found'
                    : 'کوئی ادائیگی نہیں ملی',
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
                : ListView.builder(
              itemCount: _filteredPayments.length,
              itemBuilder: (context, index) {
                final payment = _filteredPayments[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                  child: ListTile(
                    leading: Icon(
                      Icons.payment,
                      color: Colors.green[700],
                    ),
                    title: Text(
                      '${payment['amount']} Rs',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${payment['method']}'),
                        if (payment['bankName'] != null && payment['bankName'].isNotEmpty)
                          Text('Bank: ${payment['bankName']}'),
                        if (payment['chequeNumber'] != null && payment['chequeNumber'].isNotEmpty)
                          Text('Cheque: ${payment['chequeNumber']}'),
                        Text(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(payment['date']))),
                        if (payment['description'] != null && payment['description'].isNotEmpty)
                          Text('Desc: ${payment['description']}'),
                        if (payment['referenceNumber'] != null && payment['referenceNumber'].isNotEmpty)
                          Text('Ref: ${payment['referenceNumber']}'),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deletePayment(payment),
                    ),
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
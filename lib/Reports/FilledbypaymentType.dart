import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:ui' as ui;

import '../Provider/customerprovider.dart';
import '../Provider/lanprovider.dart';
import '../bankmanagement/banknames.dart';

class FilledPaymentTypeReportPage extends StatefulWidget {
  final String? customerId;
  final String? customerName;
  final String? customerPhone;

  const FilledPaymentTypeReportPage({
    Key? key,
    this.customerId,
    this.customerName,
    this.customerPhone,
  }) : super(key: key);

  @override
  _FilledPaymentTypeReportPageState createState() => _FilledPaymentTypeReportPageState();
}

class _FilledPaymentTypeReportPageState extends State<FilledPaymentTypeReportPage> {
  String _selectedPaymentType = 'all';
  String? _selectedCustomerId;
  String? _selectedCustomerName;
  DateTimeRange? _selectedDateRange;
  String _selectedPaymentMethod = 'all';
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final Map<String, pw.MemoryImage> _bankIcons = {};
  List<Map<String, dynamic>> _reportData = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    await _fetchTodayReportData();
    await _fetchReportData();
    setState(() => _isLoading = false);
  }

  String? _getBankAssetPath(String bankName) {
    try {
      return pakistaniBanks.firstWhere(
            (b) => b.name == bankName,
        orElse: () => Bank(name: bankName, iconPath: 'assets/default_bank.png'),
      ).iconPath;
    } catch (e) {
      return 'assets/default_bank.png';
    }
  }

  Future<void> _loadBankIcons() async {
    _bankIcons.clear();
    final bankNames = _reportData
        .where((invoice) => invoice['paymentMethod'] == 'Bank' && invoice['bankName'] != null)
        .map((invoice) => invoice['bankName'] as String)
        .toSet();

    for (final bankName in bankNames) {
      final assetPath = _getBankAssetPath(bankName);
      if (assetPath != null) {
        try {
          final imageData = await rootBundle.load(assetPath);
          final bytes = imageData.buffer.asUint8List();
          _bankIcons[bankName] = pw.MemoryImage(bytes);
        } catch (e) {
          debugPrint("Failed to load icon for $bankName: $e");
        }
      }
    }
  }

  Widget _getBankIcon(String? bankName) {
    if (bankName == null) return const Icon(Icons.account_balance, size: 20);

    final matchedBank = pakistaniBanks.firstWhere(
          (b) => b.name == bankName,
      orElse: () => Bank(name: bankName, iconPath: 'assets/default_bank.png'),
    );

    return Image.asset(
      matchedBank.iconPath,
      height: 20,
      width: 20,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.account_balance, size: 20);
      },
    );
  }

  Widget _getPaymentMethodWidget(Map<String, dynamic> invoice) {
    // Handle Bank payments
    if (invoice['paymentMethod'] == 'Bank' && invoice['bankName'] != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _getBankIcon(invoice['bankName']),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '${invoice['paymentMethod']} (${invoice['bankName']})',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    // Handle Cheque payments with bank name
    else if (invoice['paymentMethod'] == 'Cheque' && invoice['bankName'] != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _getBankIcon(invoice['bankName']),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '${invoice['paymentMethod']} (${invoice['bankName']})',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    // Default case
    return Text(invoice['paymentMethod']?.toString() ?? 'N/A');
  }

  Future<void> _fetchTodayReportData() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

    setState(() {
      _selectedDateRange = DateTimeRange(start: startOfDay, end: endOfDay);
    });
  }


  void _processCashPayments(Map<String, dynamic> filled, String? filledId, List<Map<String, dynamic>> reportData) {
    final cashPayments = filled['cashPayments'] != null
        ? Map<String, dynamic>.from(filled['cashPayments'])
        : {};

    for (final payment in cashPayments.values) {
      final paymentDate = DateTime.parse(payment['date']);
      if (_shouldSkipPayment(paymentDate)) continue;

      reportData.add({
        'filledId': filledId,
        'referenceNumber': filled['referenceNumber'],
        'customerId': filled['customerId'],
        'customerName': filled['customerName'],
        'paymentType': filled['paymentType'],
        'paymentMethod': 'Cash',
        'amount': payment['amount'],
        'date': payment['date'],
        'createdAt': filled['createdAt'],
      });
    }
  }

  void _processOnlinePayments(Map<String, dynamic> filled, String? filledId, List<Map<String, dynamic>> reportData) {
    final onlinePayments = filled['onlinePayments'] != null
        ? Map<String, dynamic>.from(filled['onlinePayments'])
        : {};

    for (final payment in onlinePayments.values) {
      final paymentDate = DateTime.parse(payment['date']);
      if (_shouldSkipPayment(paymentDate)) continue;

      reportData.add({
        'filledId': filledId,
        'referenceNumber': filled['referenceNumber'],
        'customerId': filled['customerId'],
        'customerName': filled['customerName'],
        'paymentType': filled['paymentType'],
        'paymentMethod': 'Online',
        'amount': payment['amount'],
        'date': payment['date'],
        'createdAt': filled['createdAt'],
      });
    }
  }

  void _processChequePayments(Map<String, dynamic> filled, String? filledId, List<Map<String, dynamic>> reportData) {
    final chequePayments = filled['chequePayments'] != null
        ? Map<String, dynamic>.from(filled['chequePayments'])
        : {};

    for (final payment in chequePayments.values) {
      // Skip pending or bounced cheques
      if (payment['status'] == 'pending' || payment['status'] == 'bounced') {
        continue;
      }

      final paymentDate = DateTime.parse(payment['date']);
      if (_shouldSkipPayment(paymentDate)) continue;

      reportData.add({
        'filledId': filledId,
        'referenceNumber': filled['referenceNumber'],
        'customerId': filled['customerId'],
        'customerName': filled['customerName'],
        'paymentType': filled['paymentType'],
        'paymentMethod': 'Cheque',
        'bankName': payment['bankName'], // Add bank name for cheque
        'amount': payment['amount'],
        'date': payment['date'],
        'createdAt': filled['createdAt'],
      });
    }
  }

  void _processBankPayments(Map<String, dynamic> filled, String? filledId, List<Map<String, dynamic>> reportData) {
    final bankPayments = filled['bankPayments'] != null
        ? Map<String, dynamic>.from(filled['bankPayments'])
        : {};

    for (final payment in bankPayments.values) {
      final paymentDate = DateTime.parse(payment['date']);
      if (_shouldSkipPayment(paymentDate)) continue;

      reportData.add({
        'filledId': filledId,
        'referenceNumber': filled['referenceNumber'],
        'customerId': filled['customerId'],
        'customerName': filled['customerName'],
        'paymentType': filled['paymentType'],
        'paymentMethod': 'Bank',
        'bankName': payment['bankName'],
        'amount': payment['amount'],
        'date': payment['date'],
        'createdAt': filled['createdAt'],
      });
    }
  }

  void _processSlipPayments(Map<String, dynamic> filled, String? filledId, List<Map<String, dynamic>> reportData) {
    final slipPayments = filled['slipPayments'] != null
        ? Map<String, dynamic>.from(filled['slipPayments'])
        : {};

    for (final payment in slipPayments.values) {
      final paymentDate = DateTime.parse(payment['date']);
      if (_shouldSkipPayment(paymentDate)) continue;

      reportData.add({
        'filledId': filledId,
        'referenceNumber': filled['referenceNumber'],
        'customerId': filled['customerId'],
        'customerName': filled['customerName'],
        'paymentType': filled['paymentType'],
        'paymentMethod': 'Slip',
        'amount': payment['amount'],
        'date': payment['date'],
        'createdAt': filled['createdAt'],
      });
    }
  }

  bool _shouldSkipPayment(DateTime paymentDate) {
    return _selectedDateRange != null &&
        (paymentDate.isBefore(_selectedDateRange!.start) ||
            paymentDate.isAfter(_selectedDateRange!.end));
  }

  Future<void> _fetchReportData() async {
    try {
      setState(() => _isLoading = true);
      final DatabaseReference filledsRef = _db.ref('filled');
      final filledsSnapshot = await filledsRef.get();

      if (!filledsSnapshot.exists) {
        throw Exception("No filled data found.");
      }

      final List<Map<String, dynamic>> reportData = [];

      for (final filledSnapshot in filledsSnapshot.children) {
        final filledId = filledSnapshot.key;
        final filled = Map<String, dynamic>.from(filledSnapshot.value as Map);

        // Apply filters
        if (_selectedCustomerId != null && filled['customerId'] != _selectedCustomerId) continue;
        if (_selectedPaymentType != 'all' && filled['paymentType'] != _selectedPaymentType) continue;

        // Process payments based on selected method
        if (_selectedPaymentMethod == 'all' || _selectedPaymentMethod == 'cash') {
          _processCashPayments(filled, filledId, reportData);
        }

        if (_selectedPaymentMethod == 'all' || _selectedPaymentMethod == 'online') {
          _processOnlinePayments(filled, filledId, reportData);
        }

        if (_selectedPaymentMethod == 'all' || _selectedPaymentMethod == 'cheque') {
          _processChequePayments(filled, filledId, reportData);
        }

        if (_selectedPaymentMethod == 'all' || _selectedPaymentMethod == 'bank') {
          _processBankPayments(filled, filledId, reportData);
        }

        if (_selectedPaymentMethod == 'all' || _selectedPaymentMethod == 'slip') {
          _processSlipPayments(filled, filledId, reportData);
        }
      }

      setState(() {
        _reportData = reportData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch report: ${e.toString()}')),
      );
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              surface: Theme.of(context).scaffoldBackgroundColor,
            ),
            dialogBackgroundColor: Theme.of(context).scaffoldBackgroundColor,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      await _fetchReportData();
    }
  }

  Future<void> _selectCustomer(BuildContext context) async {
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    await customerProvider.fetchCustomers();

    String searchQuery = '';
    List<Customer> filteredCustomers = customerProvider.customers;

    final customerId = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            filteredCustomers = customerProvider.customers.where((customer) {
              return customer.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                  (customer.phone != null && customer.phone!.contains(searchQuery));
            }).toList();

            return AlertDialog(
              title: const Text('Select Customer'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Search by name or phone',
                        prefixIcon: Icon(Icons.search, color: Theme.of(context).primaryColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (value) => setState(() => searchQuery = value),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filteredCustomers.isEmpty
                          ? const Center(child: Text('No customers found'))
                          : ListView.builder(
                        itemCount: filteredCustomers.length,
                        itemBuilder: (context, index) {
                          final customer = filteredCustomers[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                              child: Text(
                                customer.name[0].toUpperCase(),
                                style: TextStyle(color: Theme.of(context).primaryColor),
                              ),
                            ),
                            title: Text(customer.name),
                            subtitle: customer.phone != null ? Text(customer.phone!) : null,
                            onTap: () => Navigator.pop(context, customer.id),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );

    if (customerId != null) {
      final selectedCustomer = customerProvider.customers.firstWhere((customer) => customer.id == customerId);
      setState(() {
        _selectedCustomerId = customerId;
        _selectedCustomerName = selectedCustomer.name;
      });
      await _fetchReportData();
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedPaymentType = 'all';
      _selectedCustomerId = null;
      _selectedCustomerName = null;
      _selectedDateRange = null;
      _selectedPaymentMethod = 'all';
    });
    _fetchReportData();
  }

  double _calculateTotalAmount() {
    return _reportData.fold(0.0, (sum, filled) {
      return sum + (filled['amount'] ?? 0.0);
    });
  }

  Future<pw.MemoryImage> _createTextImage(String text) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromPoints(const Offset(0, 0), const Offset(500, 50)));
    final textStyle = TextStyle(
      fontSize: 18,
      fontFamily: 'JameelNoori',
      color: Colors.black,
      fontWeight: FontWeight.bold,
    );

    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.left,
      textDirection: ui.TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(canvas, const Offset(0, 0));

    final picture = recorder.endRecording();
    final img = await picture.toImage(textPainter.width.toInt(), textPainter.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    return pw.MemoryImage(buffer);
  }

  Future<void> _sharePdf() async {
    try {
      final pdfBytes = await _generatePdfBytes();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/payment_report.pdf');
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Payment Report - Sarya',
        subject: 'Payment Report',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share PDF: ${e.toString()}')),
      );
    }
  }

  Future<void> _generateAndPrintPDF() async {
    try {
      final pdfBytes = await _generatePdfBytes();
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) => pdfBytes);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: ${e.toString()}')),
      );
    }
  }

  Future<Uint8List> _generatePdfBytes() async {
    await _loadBankIcons();
    final pdf = pw.Document();
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    // Load images
    final ByteData footerBytes = await rootBundle.load('assets/images/devlogo.png');
    final footerBuffer = footerBytes.buffer.asUint8List();
    final footerLogo = pw.MemoryImage(footerBuffer);

    final ByteData logoBytes = await rootBundle.load('assets/images/logo.png');
    final logoBuffer = logoBytes.buffer.asUint8List();
    final logoImage = pw.MemoryImage(logoBuffer);

    final customerNameImage = await _createTextImage(_selectedCustomerName ?? 'All');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        header: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              children: [
                pw.Image(logoImage, width: 130, height: 130, dpi: 1000),
                 pw.SizedBox(height: 20),
                pw.Text(
                  'Payment Type Report',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                 pw.SizedBox(height: 20),
                pw.Image(customerNameImage),
                 pw.SizedBox(height: 20),
              ],
            ),
          );//s
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(),
               pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(footerLogo, width: 30, height: 30),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Developed By: Umair Arshad',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Contact: 0307-6455926',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
               pw.SizedBox(height: 10),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
            ],
          );
        },
        build: (pw.Context context) => [
          pw.Table.fromTextArray(
            context: context,
            cellStyle: const pw.TextStyle(fontSize: 12),
            headerStyle: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            data: [
              ['Customer', 'Payment Type', 'Payment Method', 'Amount', 'Date'],
              ..._reportData.map((filled) => [
                pw.Image(customerNameImage, width: 50, height: 20),
                filled['paymentType'] ?? 'N/A',
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8.0),
                  child: _buildPdfPaymentMethodWidget(filled),
                ),
                'Rs ${filled['amount']}',
                DateFormat.yMMMd().format(DateTime.parse(filled['createdAt'])),
              ]).toList(),
            ],
          ),
           pw.SizedBox(height: 20),
          pw.Text(
            'Total Amount: Rs ${_calculateTotalAmount().toStringAsFixed(2)}',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  pw.Widget _buildPdfPaymentMethodWidget(Map<String, dynamic> filled) {
    final bankName = filled['bankName'];
    final bankLogo = _bankIcons[bankName];

    if (filled['paymentMethod'] == 'Bank' && bankName != null && bankLogo != null) {
      return pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SizedBox(
            width: 20,
            height: 20,
            child: pw.Image(bankLogo),
          ),
          pw.SizedBox(width: 5),
          pw.Text('${filled['paymentMethod']} ($bankName)'),
        ],
      );
    }
    // Handle Cheque payments
    else if (filled['paymentMethod'] == 'Cheque' && bankName != null && bankLogo != null) {
      return pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SizedBox(
            width: 20,
            height: 20,
            child: pw.Image(bankLogo),
          ),
          pw.SizedBox(width: 5),
          pw.Text('${filled['paymentMethod']} ($bankName)'),
        ],
      );
    }
    return pw.Text(filled['paymentMethod']?.toString() ?? 'N/A');
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish = languageProvider.isEnglish;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEnglish ? 'Payment Type Report' : 'ادائیگی کی قسم کی رپورٹ',
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
            tooltip: isEnglish ? 'Generate PDF' : 'پی ڈی ایف بنائیں',
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _sharePdf,
            tooltip: isEnglish ? 'Share Report' : 'رپورٹ شیئر کریں',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF3E0), // Light orange
              Color(0xFFFFE0B2), // Lighter orange
            ],
          ),
        ),
        child: _isLoading
            ? Center(child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Color(0xFFFF8A65)),
        ))
            : Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFilterSection(context, isEnglish),
              const SizedBox(height: 20),
              Expanded(
                child: _buildReportTable(),
              ),
              _buildTotalAmountSection(isEnglish),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection(BuildContext context, bool isEnglish) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEnglish ? 'Filters' : 'فلٹرز',
              style: TextStyle(
                color: Color(0xFFE65100), // Dark orange
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildPaymentTypeDropdown(),
                _buildCustomerFilterButton(context, isEnglish),
                _buildDateRangeButton(context, isEnglish),
                _buildClearFiltersButton(isEnglish),
                if (_selectedPaymentType == 'instant')
                  _buildPaymentMethodDropdown(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentTypeDropdown() {
    return Container(
      width: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFFF8A65)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<String>(
        isExpanded: true,
        value: _selectedPaymentType,
        onChanged: (value) {
          setState(() {
            _selectedPaymentType = value!;
            if (value != 'instant') _selectedPaymentMethod = 'all';
          });
          _fetchReportData();
        },
        items: <String>['all', 'udhaar', 'instant'].map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(
              value == 'all' ? 'All Payments' : value == 'udhaar' ? 'Udhaar' : 'Instant',
              style: TextStyle(color: Colors.grey[800]),
            ),
          );
        }).toList(),
        underline: const SizedBox(),
      ),
    );
  }

  Widget _buildCustomerFilterButton(BuildContext context, bool isEnglish) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFFFF8A65).withOpacity(0.1),
        foregroundColor: Color(0xFFE65100),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Color(0xFFFF8A65)),
        ),
      ),
      onPressed: () => _selectCustomer(context),
      child: Text(
        _selectedCustomerName == null
            ? isEnglish ? 'Select Customer' : 'کسٹمر چوز کریں'
            : '${_selectedCustomerName!.length > 15 ? '${_selectedCustomerName!.substring(0, 15)}...' : _selectedCustomerName}',
      ),
    );
  }

  Widget _buildDateRangeButton(BuildContext context, bool isEnglish) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFFFF8A65).withOpacity(0.1),
        foregroundColor: Color(0xFFE65100),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Color(0xFFFF8A65)),
        ),
      ),
      onPressed: () => _selectDateRange(context),
      child: Text(
        _selectedDateRange == null
            ? isEnglish ? 'Select Date Range' : 'تاریخ چوز کریں'
            : isEnglish ? 'Date Range' : 'تاریخ کی حد',
      ),
    );
  }

  Widget _buildClearFiltersButton(bool isEnglish) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.withOpacity(0.1),
        foregroundColor: Colors.red,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Colors.red),
        ),
      ),
      onPressed: _clearFilters,
      child: Text(isEnglish ? 'Clear Filters' : 'فلٹرز صاف کریں۔'),
    );
  }

  Widget _buildPaymentMethodDropdown() {
    return Container(
      width: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFFF8A65)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<String>(
        isExpanded: true,
        value: _selectedPaymentMethod,
        onChanged: (value) {
          setState(() => _selectedPaymentMethod = value!);
          _fetchReportData();
        },
        items: <String>['all', 'online', 'cash', 'check', 'bank', 'slip'].map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(
              value == 'all' ? 'All Methods'
                  : value == 'online' ? 'Online'
                  : value == 'cash' ? 'Cash'
                  : value == 'check' ? 'Check'
                  : value == 'bank' ? 'Bank'
                  : 'Slip',
              style: TextStyle(color: Colors.grey[800]),
            ),
          );
        }).toList(),
        underline: const SizedBox(),
      ),
    );
  }

  Widget _buildReportTable() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: DataTable(
                    columnSpacing: 24,
                    dataRowHeight: 56,
                    headingRowColor: MaterialStateProperty.all(Color(0xFFFFB74D).withOpacity(0.2)),
                    headingTextStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE65100), // Dark orange
                    ),
                    columns: [
                      DataColumn(label: Text('Customer')),
                      DataColumn(label: Text('Payment Type')),
                      DataColumn(label: Text('Invoice ID')),
                      DataColumn(label: Text('Payment Method')),
                      DataColumn(label: Text('Amount', textAlign: TextAlign.end)),
                      DataColumn(label: Text('Date')),
                    ],
                    rows: _reportData.map((filled) {
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              filled['customerName']?.toString() ?? 'N/A',
                              style: TextStyle(color: Colors.grey[800]),
                            ),
                          ),
                          DataCell(
                            Text(
                              filled['paymentType']?.toString() ?? 'N/A',
                              style: TextStyle(color: Colors.grey[800]),
                            ),
                          ),
                          DataCell(
                            Text(
                              filled['referenceNumber']?.toString() ?? filled['filledId']?.toString() ?? 'N/A',
                              style: TextStyle(color: Colors.grey[800]),
                            ),
                          ),
                          DataCell(_getPaymentMethodWidget(filled)),
                          DataCell(
                            Text(
                              filled['amount']?.toString() ?? '0',
                              textAlign: TextAlign.end,
                              style: TextStyle(color: Colors.grey[800]),
                            ),
                          ),
                          DataCell(
                            Text(
                              DateFormat.yMMMd().format(DateTime.parse(filled['date'])),
                              style: TextStyle(color: Colors.grey[800]),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalAmountSection(bool isEnglish) {
    return Card(
      elevation: 4,
      color: Color(0xFFFFB74D).withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isEnglish
                  ? 'Total: ${_calculateTotalAmount().toStringAsFixed(2)} Rs'
                  : 'کل رقم: ${_calculateTotalAmount().toStringAsFixed(2)} روپے',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFE65100), // Dark orange
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

}

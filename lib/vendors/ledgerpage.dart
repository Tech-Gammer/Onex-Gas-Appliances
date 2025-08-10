import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../bankmanagement/banknames.dart';

class VendorLedgerPage extends StatefulWidget {
  final String vendorId;
  final String vendorName;

  const VendorLedgerPage({
    super.key,
    required this.vendorId,
    required this.vendorName,
  });

  @override
  State<VendorLedgerPage> createState() => _VendorLedgerPageState();
}

class _VendorLedgerPageState extends State<VendorLedgerPage> {
  List<Map<String, dynamic>> _ledgerEntries = [];
  List<Map<String, dynamic>> _filteredLedgerEntries = [];
  bool _isLoading = true;
  double _totalCredit = 0.0;
  double _totalDebit = 0.0;
  double _currentBalance = 0.0;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _fetchLedgerData();
  }

  // Add this static map for bank icons
  static final Map<String, String> _bankIconMap = _createBankIconMap();

  static Map<String, String> _createBankIconMap() {
    return {
      for (var bank in pakistaniBanks)
        bank.name.toLowerCase(): bank.iconPath
    };
  }

  String? _getBankName(Map<String, dynamic> transaction) {
    if (transaction['bankName'] != null && transaction['bankName'].toString().isNotEmpty) {
      return transaction['bankName'].toString();
    }

    String paymentMethod = transaction['paymentMethod']?.toString().toLowerCase() ?? '';
    if (paymentMethod == 'cheque' || paymentMethod == 'check') {
      if (transaction['chequeBankName'] != null && transaction['chequeBankName'].toString().isNotEmpty) {
        return transaction['chequeBankName'].toString();
      }
    }

    return null;
  }

  String? _getBankLogoPath(String? bankName) {
    if (bankName == null) return null;
    final key = bankName.toLowerCase();
    return _bankIconMap[key];
  }

  Future<void> _fetchLedgerData() async {
    try {
      final DatabaseReference vendorRef = FirebaseDatabase.instance.ref('vendors/${widget.vendorId}');
      final DatabaseReference purchasesRef = FirebaseDatabase.instance.ref('purchases');
      final DatabaseReference paymentsRef = FirebaseDatabase.instance.ref('vendors/${widget.vendorId}/payments');

      // Fetch vendor data to get Opening Balance
      final vendorSnapshot = await vendorRef.get();
      double openingBalance = 0.0;
      String openingBalanceDate = "Unknown Date";

      if (vendorSnapshot.exists) {
        final vendorData = vendorSnapshot.value as Map<dynamic, dynamic>;
        openingBalance = (vendorData['openingBalance'] ?? 0.0).toDouble();

        final rawDate = vendorData['openingBalanceDate'] ?? "Unknown Date";
        final parsedDate = DateTime.tryParse(rawDate);
        openingBalanceDate = parsedDate != null
            ? "${parsedDate.month}/${parsedDate.day}/${parsedDate.year % 100}"
            : "Unknown Date";
      }


      // Fetch purchases data
      final purchasesSnapshot = await purchasesRef
          .orderByChild('vendorId')
          .equalTo(widget.vendorId)
          .get();

      final List<Map<String, dynamic>> purchases = [];

      if (purchasesSnapshot.exists) {
        final purchasesMap = purchasesSnapshot.value as Map<dynamic, dynamic>;

        purchasesMap.forEach((purchaseKey, purchaseValue) {
          if (purchaseValue is Map) {
            purchases.add({
              'date': purchaseValue['timestamp'] ?? 'Unknown Date',
              'description': 'Purchase',
              // 'credit': (purchaseValue['total'] ?? 0.0).toDouble(),
              'credit': (purchaseValue['grandTotal'] ?? 0.0).toDouble(),
              'debit': 0.0,
              'type': 'credit',
            });
          }
        });
      }
      final paymentsSnapshot = await paymentsRef.get();
      final List<Map<String, dynamic>> payments = [];

      if (paymentsSnapshot.exists) {
        final paymentsMap = paymentsSnapshot.value as Map<dynamic, dynamic>;

        paymentsMap.forEach((paymentKey, paymentValue) {
          if (paymentValue is Map) {
            // Get the payment method - check both 'method' and 'paymentMethod' keys
            final paymentMethod = paymentValue['method'] ??
                paymentValue['paymentMethod'] ??
                'Unknown Method';

            // payments.add({
            //   'date': paymentValue['date'] ?? 'Unknown Date',
            //   'description': 'Payment via $paymentMethod', // This will now show the correct method
            //   'credit': 0.0,
            //   'debit': (paymentValue['amount'] ?? 0.0).toDouble(),
            //   'type': 'debit',
            //   'method': paymentMethod, // Store the method separately if needed
            // });
            payments.add({
              'date': paymentValue['date'] ?? 'Unknown Date',
              'description': 'Payment via $paymentMethod',
              'credit': 0.0,
              'debit': (paymentValue['amount'] ?? 0.0).toDouble(),
              'type': 'debit',
              'method': paymentMethod,
              'bankName': paymentValue['bankName'] ?? paymentValue['chequeBankName'],
            });
          }
        });
      }

      // Combine and sort entries
      final combinedEntries = [...purchases, ...payments];
      combinedEntries.sort((a, b) {
        final dateA = DateTime.tryParse(a['date']) ?? DateTime(1970);
        final dateB = DateTime.tryParse(b['date']) ?? DateTime(1970);
        return dateA.compareTo(dateB);
      });

      // Add Opening Balance as the first row
      final openingBalanceEntry = {
        'date': openingBalanceDate,
        'description': 'Opening Balance',
        'credit': openingBalance,
        'debit': 0.0,
        'balance': openingBalance,
      };

      combinedEntries.insert(0, openingBalanceEntry);

      // Calculate running balance
      double balance = openingBalance;
      double totalCredit = openingBalance;
      double totalDebit = 0.0;

      for (final entry in combinedEntries.skip(1)) {
        balance += entry['credit'] - entry['debit'];
        totalCredit += entry['credit'];
        totalDebit += entry['debit'];
        entry['balance'] = balance;
      }

      setState(() {
        _ledgerEntries = combinedEntries;
        _filteredLedgerEntries = combinedEntries;
        _totalCredit = totalCredit;
        _totalDebit = totalDebit;
        _currentBalance = balance;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading ledger: $e')),
      );
      setState(() => _isLoading = false);
    }
  }



  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;

        // Include the opening balance if it is before or equal to the selected start date
        final List<Map<String, dynamic>> filtered = _ledgerEntries.where((entry) {
          final entryDate = DateTime.tryParse(entry['date']) ?? DateTime(1970);
          return entryDate.isAfter(picked.start.subtract(const Duration(days: 1))) &&
              entryDate.isBefore(picked.end.add(const Duration(days: 1)));
        }).toList();

        // Check if the opening balance is missing and add it if needed
        final openingBalanceIndex = filtered.indexWhere((e) => e['description'] == 'Opening Balance');
        if (openingBalanceIndex == -1) {
          final openingBalanceEntry = _ledgerEntries.firstWhere(
                (e) => e['description'] == 'Opening Balance',
            orElse: () => {},
          );
          if (openingBalanceEntry.isNotEmpty) {
            filtered.insert(0, openingBalanceEntry);
          }
        }

        _filteredLedgerEntries = filtered;
      });
    }
  }

  // Future<void> _printLedger() async {
  //   final pdf = pw.Document();
  //
  //   // Load the logo image
  //   final logoImage = await rootBundle.load('assets/images/logo.png');
  //   final logo = pw.MemoryImage(logoImage.buffer.asUint8List());
  //
  //   // Load the footer logo if different
  //   final ByteData footerBytes = await rootBundle.load('assets/images/devlogo.png');
  //   final footerBuffer = footerBytes.buffer.asUint8List();
  //   final footerLogo = pw.MemoryImage(footerBuffer);
  //
  //   // Helper method to format the date
  //   String _getFormattedDate(String dateString) {
  //     final DateTime? parsedDate = DateTime.tryParse(dateString);
  //     return parsedDate != null
  //         ? "${parsedDate.month}/${parsedDate.day}/${parsedDate.year % 100}"
  //         : "Unknown Date";
  //   }
  //
  //   Map<String, pw.MemoryImage> bankLogoImages = {};
  //   for (var bank in pakistaniBanks) {
  //     try {
  //       final logoBytes = await rootBundle.load(bank.iconPath);
  //       final logoBuffer = logoBytes.buffer.asUint8List();
  //       bankLogoImages[bank.name.toLowerCase()] = pw.MemoryImage(logoBuffer);
  //     } catch (e) {
  //       print('Error loading bank logo: ${bank.iconPath} - $e');
  //     }
  //   }
  //
  //   pdf.addPage(
  //     pw.MultiPage(
  //       pageFormat: PdfPageFormat.a4,
  //       margin: const pw.EdgeInsets.all(20),
  //       build: (pw.Context context) => [
  //         pw.Row(
  //           mainAxisAlignment: pw.MainAxisAlignment.center,
  //           children: [
  //             pw.Header(
  //               level: 0,
  //               child: pw.Column(
  //                 children: [
  //                   pw.Image(logo, width: 120, height: 120),
  //                   pw.Text(
  //                     'M. Zeeshan: 0300-6400717',
  //                     style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
  //                   ),
  //                   pw.SizedBox(height: 5),
  //                   pw.Text('Vendor: ${widget.vendorName}',
  //                       style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
  //                   if (_selectedDateRange != null)
  //                     pw.Text(
  //                       'Date Range: ${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month}/${_selectedDateRange!.start.year} - '
  //                           '${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}/${_selectedDateRange!.end.year}',
  //                       style: const pw.TextStyle(fontSize: 12),
  //                     ),
  //                 ],
  //               ),
  //             ),
  //           ]
  //         ),
  //
  //         pw.Table.fromTextArray(
  //           context: context,
  //           cellAlignment: pw.Alignment.centerLeft,
  //           headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
  //           columnWidths: {
  //             0: const pw.FlexColumnWidth(1.2),
  //             1: const pw.FlexColumnWidth(3),
  //             2: const pw.FlexColumnWidth(1.5),
  //             3: const pw.FlexColumnWidth(1.5),
  //             4: const pw.FlexColumnWidth(1.5),
  //           },
  //           headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
  //           cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
  //           rowDecoration: pw.BoxDecoration(
  //             border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200)),
  //           ),
  //           headers: [
  //             'Date',
  //             'Transaction Details',
  //             'Credit (Rs)',
  //             'Debit (Rs)',
  //             'Balance (Rs)',
  //           ],
  //           data: [
  //             ..._filteredLedgerEntries.map((entry) => [
  //               entry['description'] == 'Opening Balance'
  //                   ? entry['date']
  //                   : _getFormattedDate(entry['date']),
  //               entry['description'],
  //               entry['credit'].toStringAsFixed(2),
  //               entry['debit'].toStringAsFixed(2),
  //               entry['balance'].toStringAsFixed(2),
  //             ]),
  //             [
  //               'Total',
  //               '',
  //               _totalCredit.toStringAsFixed(2),
  //               _totalDebit.toStringAsFixed(2),
  //               _currentBalance.toStringAsFixed(2),
  //             ]
  //           ],
  //         ),
  //
  //         pw.Container(
  //           alignment: pw.Alignment.centerRight,
  //           margin: const pw.EdgeInsets.only(top: 10),
  //           child: pw.Text(
  //             'Printed on: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
  //             style: const pw.TextStyle(fontSize: 10),
  //           ),
  //         ),
  //         // Footer Section
  //         pw.Spacer(), // Push footer to the bottom of the page
  //         pw.Divider(),
  //         pw.Row(
  //           mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  //           children: [
  //             pw.Image(footerLogo, width: 20, height: 20), // Footer logo
  //             pw.Column(
  //               crossAxisAlignment: pw.CrossAxisAlignment.center,
  //               children: [
  //                 pw.Text(
  //                   'Developed By: Umair Arshad',
  //                   style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
  //                 ),
  //                 pw.Text(
  //                   'Contact: 0307-6455926',
  //                   style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
  //                 ),
  //               ],
  //             ),
  //           ],
  //         ),
  //       ],
  //     ),
  //   );
  //
  //   await Printing.layoutPdf(onLayout: (format) => pdf.save());
  // }
  //
  // Future<void> _shareLedger() async {
  //   final pdf = pw.Document();
  //
  //   // Load the logo image
  //   final logoImage = await rootBundle.load('assets/images/logo.png');
  //   final logo = pw.MemoryImage(logoImage.buffer.asUint8List());
  //
  //   String _getFormattedDate(String dateString) {
  //     final DateTime? parsedDate = DateTime.tryParse(dateString);
  //     return parsedDate != null
  //         ? "${parsedDate.month}/${parsedDate.day}/${parsedDate.year % 100}"
  //         : "Unknown Date";
  //   }
  //
  //   // Generate PDF
  //   pdf.addPage(
  //     pw.MultiPage(
  //       pageFormat: PdfPageFormat.a4,
  //       margin: const pw.EdgeInsets.all(20),
  //       build: (pw.Context context) => [
  //         pw.Column(
  //           crossAxisAlignment: pw.CrossAxisAlignment.center,
  //           children: [
  //             pw.Image(logo, width: 80, height: 80),
  //             pw.SizedBox(height: 10),
  //             pw.Text(
  //               'Alsaeed Sweets & Bakers',
  //               style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
  //             ),
  //             pw.SizedBox(height: 5),
  //             pw.Text(
  //               'Vendor: ${widget.vendorName}',
  //               style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
  //             ),
  //             if (_selectedDateRange != null)
  //               pw.Text(
  //                 'Date Range: ${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month}/${_selectedDateRange!.start.year} - '
  //                     '${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}/${_selectedDateRange!.end.year}',
  //                 style: const pw.TextStyle(fontSize: 12),
  //               ),
  //             pw.SizedBox(height: 20),
  //           ],
  //         ),
  //
  //         pw.Table.fromTextArray(
  //           context: context,
  //           cellAlignment: pw.Alignment.centerLeft,
  //           headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
  //           columnWidths: {
  //             0: const pw.FlexColumnWidth(1.2),
  //             1: const pw.FlexColumnWidth(3),
  //             2: const pw.FlexColumnWidth(1.5),
  //             3: const pw.FlexColumnWidth(1.5),
  //             4: const pw.FlexColumnWidth(1.5),
  //           },
  //           headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
  //           cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
  //           rowDecoration: pw.BoxDecoration(
  //             border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200)),
  //           ),
  //           headers: [
  //             'Date',
  //             'Transaction Details',
  //             'Credit (Rs)',
  //             'Debit (Rs)',
  //             'Balance (Rs)',
  //           ],
  //           data: [
  //             ..._filteredLedgerEntries.map((entry) => [
  //               entry['description'] == 'Opening Balance'
  //                   ? entry['date']
  //                   : _getFormattedDate(entry['date']),
  //               entry['description'],
  //               entry['credit'].toStringAsFixed(2),
  //               entry['debit'].toStringAsFixed(2),
  //               entry['balance'].toStringAsFixed(2),
  //             ]),
  //             [
  //               'Total',
  //               '',
  //               _totalCredit.toStringAsFixed(2),
  //               _totalDebit.toStringAsFixed(2),
  //               _currentBalance.toStringAsFixed(2),
  //             ]
  //           ],
  //         ),
  //
  //         pw.Container(
  //           alignment: pw.Alignment.centerRight,
  //           margin: const pw.EdgeInsets.only(top: 10),
  //           child: pw.Text(
  //             'Printed on: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
  //             style: const pw.TextStyle(fontSize: 10),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  //
  //   // Save PDF to temporary directory
  //   final output = await getTemporaryDirectory();
  //   final file = File('${output.path}/ledger_${widget.vendorName}.pdf');
  //   await file.writeAsBytes(await pdf.save());
  //
  //   // Share the PDF
  //   await Share.shareXFiles([XFile(file.path)], text: 'Vendor Ledger for ${widget.vendorName}');
  // }

  Future<void> _printLedger() async {
    final pdf = pw.Document();

    // Load the logo image
    final logoImage = await rootBundle.load('assets/images/logo.png');
    final logo = pw.MemoryImage(logoImage.buffer.asUint8List());

    // Load the footer logo if different
    final ByteData footerBytes = await rootBundle.load('assets/images/devlogo.png');
    final footerBuffer = footerBytes.buffer.asUint8List();
    final footerLogo = pw.MemoryImage(footerBuffer);

    // Helper method to format the date
    String _getFormattedDate(String dateString) {
      final DateTime? parsedDate = DateTime.tryParse(dateString);
      return parsedDate != null
          ? "${parsedDate.month}/${parsedDate.day}/${parsedDate.year % 100}"
          : "Unknown Date";
    }

    // Load bank logos
    Map<String, pw.MemoryImage> bankLogoImages = {};
    for (var bank in pakistaniBanks) {
      try {
        final logoBytes = await rootBundle.load(bank.iconPath);
        final logoBuffer = logoBytes.buffer.asUint8List();
        bankLogoImages[bank.name.toLowerCase()] = pw.MemoryImage(logoBuffer);
      } catch (e) {
        print('Error loading bank logo: ${bank.iconPath} - $e');
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) => [
          pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Column(
                    children: [
                      pw.Image(logo, width: 120, height: 120),
                      pw.Text(
                        'M. Zeeshan: 0300-6400717',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text('Vendor: ${widget.vendorName}',
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      if (_selectedDateRange != null)
                        pw.Text(
                          'Date Range: ${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month}/${_selectedDateRange!.start.year} - '
                              '${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}/${_selectedDateRange!.end.year}',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ]
          ),

          // Updated table with payment method and bank columns
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(1.2), // Date
              1: const pw.FlexColumnWidth(2),    // Description
              2: const pw.FlexColumnWidth(1),    // Method
              3: const pw.FlexColumnWidth(1.5),  // Bank
              4: const pw.FlexColumnWidth(1.2),  // Credit
              5: const pw.FlexColumnWidth(1.2),  // Debit
              6: const pw.FlexColumnWidth(1.5),  // Balance
            },
            border: pw.TableBorder.all(),
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _buildPdfHeaderCell('Date'),
                  _buildPdfHeaderCell('Description'),
                  _buildPdfHeaderCell('Method'),
                  _buildPdfHeaderCell('Bank'),
                  _buildPdfHeaderCell('Credit (Rs)'),
                  _buildPdfHeaderCell('Debit (Rs)'),
                  _buildPdfHeaderCell('Balance (Rs)'),
                ],
              ),
              // Data rows
              ..._filteredLedgerEntries.map((entry) {
                final bankName = _getBankName(entry);
                final bankLogo = bankName != null ? bankLogoImages[bankName.toLowerCase()] : null;
                final isPayment = entry['description'].toString().contains('Payment');

                return pw.TableRow(
                  children: [
                    _buildPdfCell(entry['description'] == 'Opening Balance'
                        ? entry['date']
                        : _getFormattedDate(entry['date'])),
                    _buildPdfCell(entry['description']),
                    _buildPdfCell(isPayment ? (entry['method'] ?? '-') : '-'),
                    isPayment
                        ? pw.Row(
                      children: [
                        if (bankLogo != null)
                          pw.Container(
                            width: 20,
                            height: 20,
                            margin: const pw.EdgeInsets.only(right: 4),
                            child: pw.Image(bankLogo),
                          ),
                        pw.Text(bankName ?? '-', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    )
                        : _buildPdfCell('-'),
                    _buildPdfCell(entry['credit'].toStringAsFixed(2)),
                    _buildPdfCell(entry['debit'].toStringAsFixed(2)),
                    _buildPdfCell(entry['balance'].toStringAsFixed(2)),
                  ],
                );
              }).toList(),
              // Total row
              pw.TableRow(
                children: [
                  _buildPdfCell('Total', isHeader: true),
                  _buildPdfCell(''),
                  _buildPdfCell(''),
                  _buildPdfCell(''),
                  _buildPdfCell(_totalCredit.toStringAsFixed(2), isHeader: true),
                  _buildPdfCell(_totalDebit.toStringAsFixed(2), isHeader: true),
                  _buildPdfCell(_currentBalance.toStringAsFixed(2), isHeader: true),
                ],
              ),
            ],
          ),

          pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Printed on: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
          // Footer Section
          pw.Spacer(), // Push footer to the bottom of the page
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(footerLogo, width: 20, height: 20), // Footer logo
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
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  Future<void> _shareLedger() async {
    final pdf = pw.Document();

    // Load the logo image
    final logoImage = await rootBundle.load('assets/images/logo.png');
    final logo = pw.MemoryImage(logoImage.buffer.asUint8List());

    String _getFormattedDate(String dateString) {
      final DateTime? parsedDate = DateTime.tryParse(dateString);
      return parsedDate != null
          ? "${parsedDate.month}/${parsedDate.day}/${parsedDate.year % 100}"
          : "Unknown Date";
    }

    // Load bank logos
    Map<String, pw.MemoryImage> bankLogoImages = {};
    for (var bank in pakistaniBanks) {
      try {
        final logoBytes = await rootBundle.load(bank.iconPath);
        final logoBuffer = logoBytes.buffer.asUint8List();
        bankLogoImages[bank.name.toLowerCase()] = pw.MemoryImage(logoBuffer);
      } catch (e) {
        print('Error loading bank logo: ${bank.iconPath} - $e');
      }
    }

    // Generate PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Image(logo, width: 80, height: 80),
              pw.SizedBox(height: 10),
              pw.Text(
                'Alsaeed Sweets & Bakers',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Vendor: ${widget.vendorName}',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              if (_selectedDateRange != null)
                pw.Text(
                  'Date Range: ${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month}/${_selectedDateRange!.start.year} - '
                      '${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}/${_selectedDateRange!.end.year}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              pw.SizedBox(height: 20),
            ],
          ),

          // Updated table with payment method and bank columns
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(1.2), // Date
              1: const pw.FlexColumnWidth(2),    // Description
              2: const pw.FlexColumnWidth(1),    // Method
              3: const pw.FlexColumnWidth(1.5),  // Bank
              4: const pw.FlexColumnWidth(1.2),  // Credit
              5: const pw.FlexColumnWidth(1.2),  // Debit
              6: const pw.FlexColumnWidth(1.5),  // Balance
            },
            border: pw.TableBorder.all(),
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _buildPdfHeaderCell('Date'),
                  _buildPdfHeaderCell('Description'),
                  _buildPdfHeaderCell('Method'),
                  _buildPdfHeaderCell('Bank'),
                  _buildPdfHeaderCell('Credit (Rs)'),
                  _buildPdfHeaderCell('Debit (Rs)'),
                  _buildPdfHeaderCell('Balance (Rs)'),
                ],
              ),
              // Data rows
              ..._filteredLedgerEntries.map((entry) {
                final bankName = _getBankName(entry);
                final bankLogo = bankName != null ? bankLogoImages[bankName.toLowerCase()] : null;
                final isPayment = entry['description'].toString().contains('Payment');

                return pw.TableRow(
                  children: [
                    _buildPdfCell(entry['description'] == 'Opening Balance'
                        ? entry['date']
                        : _getFormattedDate(entry['date'])),
                    _buildPdfCell(entry['description']),
                    _buildPdfCell(isPayment ? (entry['method'] ?? '-') : '-'),
                    isPayment
                        ? pw.Row(
                      children: [
                        if (bankLogo != null)
                          pw.Container(
                            width: 20,
                            height: 20,
                            margin: const pw.EdgeInsets.only(right: 4),
                            child: pw.Image(bankLogo),
                          ),
                        pw.Text(bankName ?? '-', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    )
                        : _buildPdfCell('-'),
                    _buildPdfCell(entry['credit'].toStringAsFixed(2)),
                    _buildPdfCell(entry['debit'].toStringAsFixed(2)),
                    _buildPdfCell(entry['balance'].toStringAsFixed(2)),
                  ],
                );
              }).toList(),
              // Total row
              pw.TableRow(
                children: [
                  _buildPdfCell('Total', isHeader: true),
                  _buildPdfCell(''),
                  _buildPdfCell(''),
                  _buildPdfCell(''),
                  _buildPdfCell(_totalCredit.toStringAsFixed(2), isHeader: true),
                  _buildPdfCell(_totalDebit.toStringAsFixed(2), isHeader: true),
                  _buildPdfCell(_currentBalance.toStringAsFixed(2), isHeader: true),
                ],
              ),
            ],
          ),

          pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Printed on: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );

    // Save PDF to temporary directory
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/ledger_${widget.vendorName}.pdf');
    await file.writeAsBytes(await pdf.save());

    // Share the PDF
    await Share.shareXFiles([XFile(file.path)], text: 'Vendor Ledger for ${widget.vendorName}');
  }

// Helper method to create PDF header cells
  pw.Widget _buildPdfHeaderCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      ),
    );
  }

// Helper method to create PDF data cells
  pw.Widget _buildPdfCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 9,
        ),
      ),
    );
  }

  String _getFormattedDate(String dateString, bool isOpeningBalance) {
    if (isOpeningBalance) {
      return dateString; // Show formatted `openingBalanceDate`
    }

    final DateTime? parsedDate = DateTime.tryParse(dateString);
    if (parsedDate != null) {
      return "${parsedDate.month}/${parsedDate.day}/${parsedDate.year % 100}";
    }
    return "Unknown Date"; // Fallback for invalid date
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.vendorName} Ledger'),
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
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: () => _selectDateRange(context),
          ),
          IconButton(
            icon: const Icon(Icons.print, color: Colors.white),
            onPressed: _printLedger,
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _shareLedger, // New Share Button
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildSummaryCards(),
          Expanded(
            child: isMobile ? _buildMobileLedgerView() : _buildDesktopLedgerView(),
          ),
        ],
      ),
    );
  }


  Widget _buildMobileLedgerView() {
    const double fontSize = 10.0;

    return ListView(
      padding: const EdgeInsets.all(8.0),
      children: [
        // Table header with vertical borders
        Container(
          color: Colors.blue[100],
          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.black, width: 1))),
                  child: const Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)),
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.black, width: 1))),
                  child: const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)),
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.black, width: 1))),
                  child: const Text('Credit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize), textAlign: TextAlign.right),
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.black, width: 1))),
                  child: const Text('Debit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize), textAlign: TextAlign.right),
                ),
              ),
              const Expanded(
                flex: 2,
                child: Text('Balance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize), textAlign: TextAlign.right),
              ),
            ],
          ),
        ),

        // Table rows with vertical borders
        ..._filteredLedgerEntries.map((entry) {
          final isOpeningBalance = entry['description'] == 'Opening Balance';
          final dateText = _getFormattedDate(entry['date'], isOpeningBalance);

          return Container(
            color: isOpeningBalance ? Colors.yellow[100] : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.black, width: 1))),
                    child: Text(dateText, style: TextStyle(fontWeight: isOpeningBalance ? FontWeight.bold : FontWeight.normal, fontSize: fontSize)),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.black, width: 1))),
                    child: Text(entry['description'], style: TextStyle(fontWeight: isOpeningBalance ? FontWeight.bold : FontWeight.normal, fontSize: fontSize)),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.black, width: 1))),
                    child: Text(entry['credit'].toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: fontSize)),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.black, width: 1))),
                    child: Text(entry['debit'].toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: fontSize)),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(entry['balance'].toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: fontSize)),
                ),
              ],
            ),
          );
        }).toList(),

        // Total row with vertical borders
        Container(
          color: Colors.grey[300],
          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.black, width: 1))),
                  child: const Text('', style: TextStyle(fontSize: fontSize)),
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.black, width: 1))),
                  child: const Text('Totals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)),
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.black, width: 1))),
                  child: Text(_totalCredit.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)),
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.black, width: 1))),
                  child: Text(_totalDebit.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(_currentBalance.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLedgerView() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 100,
        columns: const [
          // DataColumn(label: Text('Date')),
          // DataColumn(label: Text('Description')),
          // DataColumn(label: Text('Credit (Rs)'), numeric: true),
          // DataColumn(label: Text('Debit (Rs)'), numeric: true),
          // DataColumn(label: Text('Balance (Rs)'), numeric: true),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Description')),
          DataColumn(label: Text('Method')),
          DataColumn(label: Text('Bank')),
          DataColumn(label: Text('Credit (Rs)'), numeric: true),
          DataColumn(label: Text('Debit (Rs)'), numeric: true),
          DataColumn(label: Text('Balance (Rs)'), numeric: true),
        ],
        rows: _filteredLedgerEntries.map((data) {
          final isOpeningBalance = data['description'] == 'Opening Balance';
          final dateText = _getFormattedDate(data['date'], isOpeningBalance);

          return DataRow(
            color: MaterialStateProperty.resolveWith<Color?>(
                  (states) => isOpeningBalance ? Colors.yellow[200] : null,
            ),
            cells: [
              DataCell(Text(dateText, style: isOpeningBalance ? const TextStyle(fontWeight: FontWeight.bold) : null)),
              DataCell(Text(data['description'], style: isOpeningBalance ? const TextStyle(fontWeight: FontWeight.bold) : null)),
              DataCell(Text(data['method'] ?? '-')),
              DataCell(
                Row(
                  children: [
                    if (data['method'] != null && _getBankLogoPath(_getBankName(data)) != null)
                      Image.asset(_getBankLogoPath(_getBankName(data))!, width: 30, height: 30),
                    if (data['method'] != null && _getBankLogoPath(_getBankName(data)) != null)
                      const SizedBox(width: 8),
                    Text(_getBankName(data) ?? '-'),
                  ],
                ),
              ),
              DataCell(Text(data['credit'].toStringAsFixed(2))),
              DataCell(Text(data['debit'].toStringAsFixed(2))),
              DataCell(Text(data['balance'].toStringAsFixed(2))),
            ],
          );
        }).toList(),
      ),
    );
  }


  Widget _buildSummaryCards() {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        alignment: WrapAlignment.center,
        children: [
          _buildSummaryCard(
            title: 'Total Credit',
            value: _totalCredit,
            color: Colors.green,
            icon: Icons.arrow_upward,
            isMobile: isMobile,
          ),
          _buildSummaryCard(
            title: 'Total Debit',
            value: _totalDebit,
            color: Colors.red,
            icon: Icons.arrow_downward,
            isMobile: isMobile,
          ),
          _buildSummaryCard(
            title: 'Current Balance',
            value: _currentBalance,
            color: _currentBalance >= 0 ? Colors.blue : Colors.orange,
            icon: Icons.account_balance_wallet,
            isMobile: isMobile,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double value,
    required Color color,
    required IconData icon,
    required bool isMobile,
  })
  {
    final double fontSize = isMobile ? 12.0 : 18.0;
    final double valueSize = isMobile ? 14.0 : 20.0;
    final double iconSize = isMobile ? 20.0 : 30.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: iconSize, color: color),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: fontSize,
                color: color,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Rs ${value.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: valueSize,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

}
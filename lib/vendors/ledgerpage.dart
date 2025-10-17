import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../Provider/lanprovider.dart';
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
  Set<String> _expandedPurchases = {};
  Map<String, List<Map<String, dynamic>>> _purchaseItems = {};

  @override
  void initState() {
    super.initState();
    _fetchLedgerData();
  }

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

  String _getDisplayDate(Map<String, dynamic> transaction) {
    // For cheque payments, use chequeDate if available
    final paymentMethod = transaction['method']?.toString().toLowerCase() ?? '';
    if (paymentMethod == 'cheque' || paymentMethod == 'check') {
      if (transaction['chequeDate'] != null && transaction['chequeDate'].toString().isNotEmpty) {
        return transaction['chequeDate'].toString();
      }
    }

    // For other transactions, use the regular date
    return transaction['date'] ?? 'Unknown Date';
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

      // Fetch purchases data with details
      final purchasesSnapshot = await purchasesRef
          .orderByChild('vendorId')
          .equalTo(widget.vendorId)
          .get();

      final List<Map<String, dynamic>> purchases = [];

      if (purchasesSnapshot.exists) {
        final purchasesMap = purchasesSnapshot.value as Map<dynamic, dynamic>;

        purchasesMap.forEach((purchaseKey, purchaseValue) {
          if (purchaseValue is Map) {
            final purchaseData = {
              'date': purchaseValue['timestamp'] ?? 'Unknown Date',
              'description': 'Purchase',
              'credit': (purchaseValue['grandTotal'] ?? 0.0).toDouble(),
              'debit': 0.0,
              'type': 'credit',
              'purchaseId': purchaseKey,
              'purchaseNumber': purchaseValue['purchaseNumber'] ?? purchaseKey,
              'items': purchaseValue['items'] ?? [],
              'grandTotal': purchaseValue['grandTotal'] ?? 0.0,
            };
            purchases.add(purchaseData);

            // Store purchase items for expansion
            if (purchaseValue['items'] != null) {
              List<Map<String, dynamic>> itemsList = [];

              if (purchaseValue['items'] is Map) {
                // Handle map format
                final itemsMap = purchaseValue['items'] as Map<dynamic, dynamic>;
                itemsList = itemsMap.entries.map((entry) {
                  final itemData = entry.value;
                  return {
                    'itemName': itemData['itemName'] ?? 'Unknown Item',
                    'quantity': (itemData['quantity'] ?? 0).toDouble(),
                    'price': (itemData['purchasePrice'] ?? itemData['price'] ?? 0.0).toDouble(),
                    'total': (itemData['total'] ?? ((itemData['quantity'] ?? 0) * (itemData['purchasePrice'] ?? itemData['price'] ?? 0.0))).toDouble(),
                  };
                }).toList();
              } else if (purchaseValue['items'] is List) {
                // Handle list format
                final itemsListData = purchaseValue['items'] as List<dynamic>;
                itemsList = itemsListData.map((item) {
                  if (item is Map) {
                    return {
                      'itemName': item['itemName'] ?? 'Unknown Item',
                      'quantity': (item['quantity'] ?? 0).toDouble(),
                      'price': (item['purchasePrice'] ?? item['price'] ?? 0.0).toDouble(),
                      'total': (item['total'] ?? ((item['quantity'] ?? 0) * (item['purchasePrice'] ?? item['price'] ?? 0.0))).toDouble(),
                    };
                  }
                  return {
                    'itemName': 'Unknown Item',
                    'quantity': 0.0,
                    'price': 0.0,
                    'total': 0.0,
                  };
                }).toList();
              }

              _purchaseItems[purchaseKey] = itemsList;
            }
          }
        });
      }

      // Fetch payments data
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

            payments.add({
              'date': paymentValue['date'] ?? 'Unknown Date',
              'chequeDate': paymentValue['chequeDate'], // Add cheque date
              'description': 'Payment via $paymentMethod',
              'credit': 0.0,
              'debit': (paymentValue['amount'] ?? 0.0).toDouble(),
              'type': 'debit',
              'method': paymentMethod,
              'bankName': paymentValue['bankName'] ?? paymentValue['chequeBankName'],
              'paymentId': paymentKey,
            });
          }
        });
      }

      // Combine and sort entries
      final combinedEntries = [...purchases, ...payments];
      combinedEntries.sort((a, b) {
        // Use display date for sorting
        final dateA = DateTime.tryParse(_getDisplayDate(a)) ?? DateTime(1970);
        final dateB = DateTime.tryParse(_getDisplayDate(b)) ?? DateTime(1970);
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

  void _togglePurchaseExpansion(String purchaseId) {
    setState(() {
      if (_expandedPurchases.contains(purchaseId)) {
        _expandedPurchases.remove(purchaseId);
      } else {
        _expandedPurchases.add(purchaseId);
      }
    });
  }

  bool _isPurchaseExpanded(String purchaseId) {
    return _expandedPurchases.contains(purchaseId);
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
          final entryDate = DateTime.tryParse(_getDisplayDate(entry)) ?? DateTime(1970);
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

  Widget _buildPurchaseItems(String purchaseId, Map<String, dynamic> entry) {
    final purchaseItems = _purchaseItems[purchaseId] ?? [];
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (purchaseItems.isEmpty) {
      return Container(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text(
            'No items found for this purchase',
            style: TextStyle(
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced Header for the expanded section
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Color(0xFFFFB74D), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFFE65100),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.shopping_cart, color: Colors.white, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'PURCHASE ITEMS DETAIL',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFFE65100),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green[300]!),
                  ),
                  child: Text(
                    'Total: Rs ${entry['grandTotal']?.toStringAsFixed(2) ?? '0.00'}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.green[800],
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Enhanced Purchase items content
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: _buildEnhancedDesktopPurchaseTable(purchaseItems),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedDesktopPurchaseTable(List<Map<String, dynamic>> purchaseItems) {
    // Calculate total quantity
    double totalQuantity = purchaseItems.fold(0.0, (sum, item) => sum + (item['quantity'] ?? 0));
    // Calculate total amount
    double totalAmount = purchaseItems.fold(0.0, (sum, item) => sum + (item['total'] ?? 0));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        constraints: BoxConstraints(minWidth: 600),
        child: DataTable(
          columnSpacing: 24,
          dataRowHeight: 50,
          headingRowHeight: 48,
          headingRowColor: MaterialStateProperty.all(Color(0xFFF5F5F5)),
          border: TableBorder.all(
            color: Colors.grey[300]!,
            borderRadius: BorderRadius.circular(4),
          ),
          headingTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFE65100),
            fontSize: 14,
            letterSpacing: 0.3,
          ),
          dataTextStyle: TextStyle(
            fontSize: 13,
            color: Colors.black87,
          ),
          columns: [
            DataColumn(
              label: Container(
                width: 250,
                child: Text(
                  'Item Name',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            DataColumn(
              label: Text('Quantity'),
              numeric: true,
            ),
            DataColumn(
              label: Text('Unit Price'),
              numeric: true,
            ),
            DataColumn(
              label: Text('Total Amount'),
              numeric: true,
            ),
          ],
          rows: [
            // Data rows
            ...purchaseItems.map((item) {
              return DataRow(
                cells: [
                  DataCell(
                    Container(
                      width: 250,
                      child: Text(
                        item['itemName']?.toString() ?? '-',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item['quantity']?.toString() ?? '0',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[800],
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      'Rs ${(item['price'] ?? 0).toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Rs ${(item['total'] ?? 0).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),

            // Total row
            DataRow(
              color: MaterialStateProperty.all(Colors.grey[100]),
              cells: [
                DataCell(
                  Container(
                    width: 250,
                    child: Text(
                      'TOTAL',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE65100),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.blue[300]!),
                    ),
                    child: Text(
                      totalQuantity.toStringAsFixed(2),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    '-',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green[300]!),
                    ),
                    child: Text(
                      'Rs ${totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[900],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
                        'M. Hamza: 0335-4393403',
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

          // Updated table with payment method, bank, and quantity columns
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(1.2), // Date
              1: const pw.FlexColumnWidth(2),    // Description
              2: const pw.FlexColumnWidth(1),    // Method
              3: const pw.FlexColumnWidth(1.5),  // Bank
              4: const pw.FlexColumnWidth(1),    // Quantity
              5: const pw.FlexColumnWidth(1.2),  // Credit
              6: const pw.FlexColumnWidth(1.2),  // Debit
              7: const pw.FlexColumnWidth(1.5),  // Balance
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
                  _buildPdfHeaderCell('Qty'),
                  _buildPdfHeaderCell('Credit (Rs)'),
                  _buildPdfHeaderCell('Debit (Rs)'),
                  _buildPdfHeaderCell('Balance (Rs)'),
                ],
              ),
              // Data rows
              ..._filteredLedgerEntries.expand((entry) {
                final List<pw.TableRow> rows = [];
                final bankName = _getBankName(entry);
                final bankLogo = bankName != null ? bankLogoImages[bankName.toLowerCase()] : null;
                final isPayment = entry['description'].toString().contains('Payment');
                final isPurchase = entry['description'].toString().contains('Purchase');
                final isOpeningBalance = entry['description'] == 'Opening Balance';
                final displayDate = isOpeningBalance
                    ? entry['date']
                    : _getFormattedDate(_getDisplayDate(entry));

                // Calculate total quantity for purchases
                double totalQuantity = 0.0;
                if (isPurchase && _isPurchaseExpanded(entry['purchaseId'])) {
                  final purchaseItems = _purchaseItems[entry['purchaseId']] ?? [];
                  totalQuantity = purchaseItems.fold(0.0, (sum, item) => sum + (item['quantity'] ?? 0));
                }

                // Main row
                rows.add(
                  pw.TableRow(
                    children: [
                      _buildPdfCell(displayDate),
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
                      _buildPdfCell(isPurchase ? totalQuantity.toStringAsFixed(2) : '-'),
                      _buildPdfCell(entry['credit'].toStringAsFixed(2)),
                      _buildPdfCell(entry['debit'].toStringAsFixed(2)),
                      _buildPdfCell(entry['balance'].toStringAsFixed(2)),
                    ],
                  ),
                );

                // Add purchase details if expanded
                if (isPurchase && _isPurchaseExpanded(entry['purchaseId'])) {
                  final purchaseItems = _purchaseItems[entry['purchaseId']] ?? [];
                  if (purchaseItems.isNotEmpty) {
                    // Add header for purchase details
                    rows.add(
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                        children: [
                          _buildPdfCell('', isHeader: true),
                          _buildPdfCell('Item Name', isHeader: true),
                          _buildPdfCell('Qty', isHeader: true),
                          _buildPdfCell('Price', isHeader: true),
                          _buildPdfCell('Total', isHeader: true),
                          _buildPdfCell('', isHeader: true),
                          _buildPdfCell('', isHeader: true),
                          _buildPdfCell('', isHeader: true),
                        ],
                      ),
                    );

                    // Add purchase items
                    for (final item in purchaseItems) {
                      rows.add(
                        pw.TableRow(
                          children: [
                            _buildPdfCell(''),
                            _buildPdfCell(item['itemName']),
                            _buildPdfCell(item['quantity'].toString()),
                            _buildPdfCell(item['price'].toStringAsFixed(2)),
                            _buildPdfCell(item['total'].toStringAsFixed(2)),
                            _buildPdfCell(''),
                            _buildPdfCell(''),
                            _buildPdfCell(''),
                          ],
                        ),
                      );
                    }

                    // Add purchase summary with total quantity
                    final totalAmount = purchaseItems.fold(0.0, (sum, item) => sum + (item['total'] ?? 0));

                    rows.add(
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey50),
                        children: [
                          _buildPdfCell('', isHeader: true),
                          _buildPdfCell('Purchase Summary:', isHeader: true),
                          _buildPdfCell('', isHeader: true),
                          _buildPdfCell('', isHeader: true),
                          _buildPdfCell('', isHeader: true),
                          _buildPdfCell('', isHeader: true),
                          _buildPdfCell('', isHeader: true),
                          _buildPdfCell('', isHeader: true),
                        ],
                      ),
                    );

                    // Total Quantity row
                    rows.add(
                      pw.TableRow(
                        children: [
                          _buildPdfCell(''),
                          _buildPdfCell('Total Quantity:'),
                          _buildPdfCell(totalQuantity.toStringAsFixed(2), isHeader: true),
                          _buildPdfCell(''),
                          _buildPdfCell(''),
                          _buildPdfCell(''),
                          _buildPdfCell(''),
                          _buildPdfCell(''),
                        ],
                      ),
                    );

                    // Grand Total row
                    rows.add(
                      pw.TableRow(
                        children: [
                          _buildPdfCell(''),
                          _buildPdfCell('Grand Total:'),
                          _buildPdfCell(''),
                          _buildPdfCell(''),
                          _buildPdfCell(entry['grandTotal']?.toStringAsFixed(2) ?? '0.00', isHeader: true),
                          _buildPdfCell(''),
                          _buildPdfCell(''),
                          _buildPdfCell(''),
                        ],
                      ),
                    );
                  }
                }

                return rows;
              }).toList(),

              // Total row - Calculate overall total quantity
              pw.TableRow(
                children: [
                  _buildPdfCell('Total', isHeader: true),
                  _buildPdfCell(''),
                  _buildPdfCell(''),
                  _buildPdfCell(''),
                  _buildPdfCell(_calculateTotalQuantity().toStringAsFixed(2), isHeader: true),
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

// Helper method to calculate total quantity across all purchases
  double _calculateTotalQuantity() {
    double totalQuantity = 0.0;

    for (final entry in _filteredLedgerEntries) {
      if (entry['description'] == 'Purchase' && _isPurchaseExpanded(entry['purchaseId'])) {
        final purchaseItems = _purchaseItems[entry['purchaseId']] ?? [];
        totalQuantity += purchaseItems.fold(0.0, (sum, item) => sum + (item['quantity'] ?? 0));
      }
    }

    return totalQuantity;
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
              ..._filteredLedgerEntries.expand((entry) {
                final List<pw.TableRow> rows = [];
                final bankName = _getBankName(entry);
                final bankLogo = bankName != null ? bankLogoImages[bankName.toLowerCase()] : null;
                final isPayment = entry['description'].toString().contains('Payment');
                final isPurchase = entry['description'].toString().contains('Purchase');
                final displayDate = entry['description'] == 'Opening Balance'
                    ? entry['date']
                    : _getFormattedDate(_getDisplayDate(entry));

                // Main row
                rows.add(
                  pw.TableRow(
                    children: [
                      _buildPdfCell(displayDate),
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
                  ),
                );

                // Add purchase details if expanded
                if (isPurchase && _isPurchaseExpanded(entry['purchaseId'])) {
                  final purchaseItems = _purchaseItems[entry['purchaseId']] ?? [];
                  if (purchaseItems.isNotEmpty) {
                    // Add header for purchase details
                    rows.add(
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                        children: [
                          _buildPdfCell('', isHeader: true),
                          _buildPdfCell('Item Name', isHeader: true),
                          _buildPdfCell('Qty', isHeader: true),
                          _buildPdfCell('Price', isHeader: true),
                          _buildPdfCell('Total', isHeader: true),
                          _buildPdfCell('', isHeader: true),
                          _buildPdfCell('', isHeader: true),
                        ],
                      ),
                    );

                    // Add purchase items
                    for (final item in purchaseItems) {
                      rows.add(
                        pw.TableRow(
                          children: [
                            _buildPdfCell(''),
                            _buildPdfCell(item['itemName']),
                            _buildPdfCell(item['quantity'].toString()),
                            _buildPdfCell(item['price'].toStringAsFixed(2)),
                            _buildPdfCell(item['total'].toStringAsFixed(2)),
                            _buildPdfCell(''),
                            _buildPdfCell(''),
                          ],
                        ),
                      );
                    }

                    // Add purchase summary
                    rows.add(
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey50),
                        children: [
                          _buildPdfCell('', isHeader: true),
                          _buildPdfCell('Purchase Total:', isHeader: true),
                          _buildPdfCell('', isHeader: true),
                          _buildPdfCell('', isHeader: true),
                          _buildPdfCell('', isHeader: true),
                          _buildPdfCell('', isHeader: true),
                          _buildPdfCell('', isHeader: true),
                        ],
                      ),
                    );
                    rows.add(
                      pw.TableRow(
                        children: [
                          _buildPdfCell(''),
                          _buildPdfCell('Grand Total:'),
                          _buildPdfCell(''),
                          _buildPdfCell(''),
                          _buildPdfCell(entry['grandTotal']?.toStringAsFixed(2) ?? '0.00', isHeader: true),
                          _buildPdfCell(''),
                          _buildPdfCell(''),
                        ],
                      ),
                    );
                  }
                }

                return rows;
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
            onPressed: _shareLedger,
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
        // Table header
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

        // Table rows with purchase expansion
        ..._filteredLedgerEntries.expand((entry) {
          final List<Widget> rows = [];
          final isOpeningBalance = entry['description'] == 'Opening Balance';
          final isPurchase = entry['description'] == 'Purchase';
          final dateText = isOpeningBalance
              ? entry['date']
              : _getFormattedDate(_getDisplayDate(entry), false);

          // Main row
          rows.add(
            Container(
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
                      child: Row(
                        children: [
                          if (isPurchase)
                            IconButton(
                              icon: Icon(
                                _isPurchaseExpanded(entry['purchaseId']) ? Icons.expand_less : Icons.expand_more,
                                size: 16,
                              ),
                              onPressed: () => _togglePurchaseExpansion(entry['purchaseId']),
                            ),
                          Expanded(
                            child: Text(
                              entry['description'],
                              style: TextStyle(fontWeight: isOpeningBalance ? FontWeight.bold : FontWeight.normal, fontSize: fontSize),
                            ),
                          ),
                        ],
                      ),
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
            ),
          );

          // Purchase details if expanded
          if (isPurchase && _isPurchaseExpanded(entry['purchaseId'])) {
            rows.add(_buildPurchaseItems(entry['purchaseId'], entry));
          }

          return rows;
        }).toList(),

        // Total row
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

  Widget _buildExpandedHeaderCell(String text, double flexValue) {
    return Expanded(
      flex: (flexValue * 10).round(),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Colors.grey[300]!)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFE65100),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildExpandedTransactionRow(
      Map<String, dynamic> entry,
      bool isOpeningBalance,
      bool isPurchase,
      )
  {
    final dateText = isOpeningBalance
        ? entry['date']
        : _getFormattedDate(_getDisplayDate(entry), false);

    final bankName = _getBankName(entry);
    final bankLogoPath = _getBankLogoPath(bankName);
    final isExpanded = isPurchase && _isPurchaseExpanded(entry['purchaseId']);

    return GestureDetector(
      onTap: isPurchase ? () {
        _togglePurchaseExpansion(entry['purchaseId']);
      } : null,
      child: Container(
        decoration: BoxDecoration(
          color: isOpeningBalance
              ? Colors.yellow[100]
              : (isPurchase && isExpanded
              ? Color(0xFFFFB74D).withOpacity(0.1)
              : Colors.white),
          border: Border(
            bottom: BorderSide(color: Colors.grey[300]!),
            left: BorderSide(color: Colors.grey[300]!),
            right: BorderSide(color: Colors.grey[300]!),
          ),
        ),
        child: Row(
          children: [
            _buildExpandedDataCell(dateText, 1, false),
            _buildExpandedDataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  if (isPurchase)
                    IconButton(
                      icon: Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 16,
                        color: Color(0xFFE65100),
                      ),
                      onPressed: () => _togglePurchaseExpansion(entry['purchaseId']),
                    ),
                  Expanded(
                    child: Text(
                      entry['description'],
                      style: TextStyle(
                        fontWeight: isOpeningBalance ? FontWeight.bold : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              2,
              false,
            ),
            _buildExpandedDataCell(entry['method'] ?? '-', 1, false),
            _buildExpandedDataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (bankLogoPath != null) ...[
                    Image.asset(bankLogoPath, width: 24, height: 24),
                    SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      bankName ?? '-',
                      style: TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              1.5,
              false,
            ),
            _buildExpandedDataCell(
              entry['credit'] > 0 ? 'Rs ${entry['credit'].toStringAsFixed(2)}' : '-',
              1,
              false,
              textColor: entry['credit'] > 0 ? Colors.green : Colors.grey,
            ),
            _buildExpandedDataCell(
              entry['debit'] > 0 ? 'Rs ${entry['debit'].toStringAsFixed(2)}' : '-',
              1,
              false,
              textColor: entry['debit'] > 0 ? Colors.red : Colors.grey,
            ),
            _buildExpandedDataCell(
              'Rs ${entry['balance'].toStringAsFixed(2)}',
              1,
              false,
              fontWeight: FontWeight.bold,
              textColor: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedDataCell(
      dynamic content,
      double flexValue,
      bool isMobile, {
        Color? textColor,
        FontWeight? fontWeight,
      })
  {
    return Expanded(
      flex: (flexValue * 10).round(),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Colors.grey[300]!)),
        ),
        child: content is Widget
            ? content
            : Text(
          content.toString(),
          style: TextStyle(
            fontSize: 12,
            color: textColor ?? Colors.black87,
            fontWeight: fontWeight,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }


  Widget _buildDesktopLedgerView() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    return Column(
      children: [
        // Enhanced Table Header
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF8A65), Color(0xFFFFB74D)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildEnhancedHeaderCell('Date', 1.2),
              _buildEnhancedHeaderCell('Description', 2.5),
              _buildEnhancedHeaderCell('Method', 1.2),
              _buildEnhancedHeaderCell('Bank', 2),
              _buildEnhancedHeaderCell('Credit (Rs)', 1.3),
              _buildEnhancedHeaderCell('Debit (Rs)', 1.3),
              _buildEnhancedHeaderCell('Balance (Rs)', 1.5),
            ],
          ),
        ),

        // Table Content
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Data Rows
                  ..._filteredLedgerEntries.asMap().entries.expand((entryWithIndex) {
                    final index = entryWithIndex.key;
                    final entry = entryWithIndex.value;
                    final List<Widget> rows = [];
                    final isOpeningBalance = entry['description'] == 'Opening Balance';
                    final isPurchase = entry['description'] == 'Purchase';
                    final dateText = isOpeningBalance
                        ? entry['date']
                        : _getFormattedDate(_getDisplayDate(entry), false);

                    // Alternate row colors for better readability
                    final bool isEvenRow = index % 2 == 0;

                    // Main row
                    rows.add(
                      _buildEnhancedTransactionRow(
                          entry,
                          isOpeningBalance,
                          isPurchase,
                          isEvenRow ? Colors.white : Colors.grey[50]!
                      ),
                    );

                    // Purchase details if expanded
                    if (isPurchase && _isPurchaseExpanded(entry['purchaseId'])) {
                      rows.add(
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isEvenRow ? Colors.orange[25] : Colors.orange[50],
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                            ),
                          ),
                          child: _buildPurchaseItems(entry['purchaseId'], entry),
                        ),
                      );
                    }

                    return rows;
                  }).toList(),

                  // Enhanced Total Row
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.grey[100]!, Colors.grey[200]!],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      border: Border(
                        top: BorderSide(color: Colors.grey[400]!, width: 2),
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildEnhancedDataCell(
                          'GRAND TOTAL',
                          1.2,
                          false,
                          fontWeight: FontWeight.bold,
                          backgroundColor: Colors.transparent,
                        ),
                        _buildEnhancedDataCell('', 2.5, false, backgroundColor: Colors.transparent),
                        _buildEnhancedDataCell('', 1.2, false, backgroundColor: Colors.transparent),
                        _buildEnhancedDataCell('', 2, false, backgroundColor: Colors.transparent),
                        _buildEnhancedDataCell(
                          'Rs ${_totalCredit.toStringAsFixed(2)}',
                          1.3,
                          false,
                          fontWeight: FontWeight.bold,
                          textColor: Colors.green[800],
                          backgroundColor: Colors.transparent,
                        ),
                        _buildEnhancedDataCell(
                          'Rs ${_totalDebit.toStringAsFixed(2)}',
                          1.3,
                          false,
                          fontWeight: FontWeight.bold,
                          textColor: Colors.red[800],
                          backgroundColor: Colors.transparent,
                        ),
                        _buildEnhancedDataCell(
                          'Rs ${_currentBalance.toStringAsFixed(2)}',
                          1.5,
                          false,
                          fontWeight: FontWeight.bold,
                          textColor: _currentBalance >= 0 ? Colors.blue[800] : Colors.orange[800],
                          backgroundColor: Colors.transparent,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildEnhancedHeaderCell(String text, double flexValue) {
    return Expanded(
      flex: (flexValue * 10).round(),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Colors.white.withOpacity(0.3))),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildEnhancedTransactionRow(
      Map<String, dynamic> entry,
      bool isOpeningBalance,
      bool isPurchase,
      Color backgroundColor,
      )
  {
    final dateText = isOpeningBalance
        ? entry['date']
        : _getFormattedDate(_getDisplayDate(entry), false);

    final bankName = _getBankName(entry);
    final bankLogoPath = _getBankLogoPath(bankName);
    final isExpanded = isPurchase && _isPurchaseExpanded(entry['purchaseId']);

    return GestureDetector(
      onTap: isPurchase ? () {
        _togglePurchaseExpansion(entry['purchaseId']);
      } : null,
      child: MouseRegion(
        cursor: isPurchase ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          decoration: BoxDecoration(
            color: isOpeningBalance
                ? Colors.amber[50]
                : (isPurchase && isExpanded
                ? Color(0xFFFFB74D).withOpacity(0.15)
                : backgroundColor),
            border: Border(
              bottom: BorderSide(color: Colors.grey[200]!),
            ),
          ),
          child: Row(
            children: [
              _buildEnhancedDataCell(dateText, 1.2, false,
                fontWeight: isOpeningBalance ? FontWeight.bold : FontWeight.normal,
                textColor: isOpeningBalance ? Colors.orange[800] : Colors.black87,
              ),
              _buildEnhancedDataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    if (isPurchase)
                      Container(
                        margin: EdgeInsets.only(right: 8),
                        child: IconButton(
                          icon: Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            size: 18,
                            color: Color(0xFFE65100),
                          ),
                          onPressed: () => _togglePurchaseExpansion(entry['purchaseId']),
                          padding: EdgeInsets.all(4),
                          constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        entry['description'],
                        style: TextStyle(
                          fontWeight: isOpeningBalance ? FontWeight.bold : FontWeight.normal,
                          color: isOpeningBalance ? Colors.orange[800] : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                2.5,
                false,
              ),
              _buildEnhancedDataCell(
                entry['method'] ?? '-',
                1.2,
                false,
                textColor: Colors.grey[700],
              ),
              _buildEnhancedDataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (bankLogoPath != null) ...[
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Image.asset(bankLogoPath),
                      ),
                      SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        bankName ?? '-',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[800],
                          fontWeight: bankName != null ? FontWeight.w500 : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                2,
                false,
              ),
              _buildEnhancedDataCell(
                entry['credit'] > 0 ? 'Rs ${entry['credit'].toStringAsFixed(2)}' : '-',
                1.3,
                false,
                fontWeight: entry['credit'] > 0 ? FontWeight.w600 : FontWeight.normal,
                textColor: entry['credit'] > 0 ? Colors.green[700] : Colors.grey[500],
              ),
              _buildEnhancedDataCell(
                entry['debit'] > 0 ? 'Rs ${entry['debit'].toStringAsFixed(2)}' : '-',
                1.3,
                false,
                fontWeight: entry['debit'] > 0 ? FontWeight.w600 : FontWeight.normal,
                textColor: entry['debit'] > 0 ? Colors.red[700] : Colors.grey[500],
              ),
              _buildEnhancedDataCell(
                'Rs ${entry['balance'].toStringAsFixed(2)}',
                1.5,
                false,
                fontWeight: FontWeight.bold,
                textColor: entry['balance'] >= 0 ? Colors.blue[700] : Colors.orange[700],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedDataCell(
      dynamic content,
      double flexValue,
      bool isMobile, {
        Color? textColor,
        FontWeight? fontWeight,
        Color backgroundColor = Colors.transparent,
      })
  {
    return Expanded(
      flex: (flexValue * 10).round(),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(right: BorderSide(color: Colors.grey[200]!)),
        ),
        child: content is Widget
            ? content
            : Text(
          content.toString(),
          style: TextStyle(
            fontSize: 13,
            color: textColor ?? Colors.black87,
            fontWeight: fontWeight ?? FontWeight.normal,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
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
  }) {
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
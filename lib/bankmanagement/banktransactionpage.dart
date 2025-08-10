import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;


class BankTransactionsPage extends StatefulWidget {
  final String bankId;
  final String bankName;

  const BankTransactionsPage({required this.bankId, required this.bankName});

  @override
  State<BankTransactionsPage> createState() => _BankTransactionsPageState();
}

class _BankTransactionsPageState extends State<BankTransactionsPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isCashIn = true;
  double remainingBalance = 0;
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _selectedTransactionDateTime;
  List<MapEntry<dynamic, dynamic>> displayTransactions = [];


  Future<pw.MemoryImage> _createTextImage(String text) async {
    const double scaleFactor = 2.0; // Higher scale for better quality
    final String displayText = text.isEmpty ? "N/A" : text;

    final textStyle = const TextStyle(
      fontSize: 8 * scaleFactor,
      fontFamily: 'JameelNoori',
      color: Colors.black,
    );

    final textSpan = TextSpan(text: displayText, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: ui.TextDirection.rtl,
    );

    textPainter.layout();

    // Calculate image dimensions with padding
    final width = textPainter.width + (10 * scaleFactor); // Add padding
    final height = textPainter.height + (4 * scaleFactor);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromPoints(Offset.zero, Offset(width, height)),
    );

    // Draw background
    final paint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTRB(0, 0, width, height), paint);

    // Paint text centered
    textPainter.paint(
      canvas,
      Offset(5 * scaleFactor, 2 * scaleFactor), // Adjust padding
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.ceil(), height.ceil());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    return pw.MemoryImage(buffer);
  }

  void _addTransaction() {
    if (_amountController.text.isNotEmpty && _descriptionController.text.isNotEmpty) {
      double amount = double.parse(_amountController.text);

      if (!_isCashIn && amount > remainingBalance) {
        _showWarningDialog(amount);
      } else {
        _processTransaction(amount);
      }
    }
  }

  void _processTransaction(double amount) {
    // final transaction = {
    //   'amount': amount,
    //   'description': _descriptionController.text,
    //   'type': _isCashIn ? 'cash_in' : 'cash_out',
    //   'timestamp': _selectedTransactionDateTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
    //   // 'timestamp': DateTime.now().millisecondsSinceEpoch,
    // };
    final transaction = {
      'amount': amount,
      'description': _descriptionController.text,
      'type': _isCashIn ? 'cash_in' : 'cash_out',
      'timestamp': _selectedTransactionDateTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
    };

    _dbRef.child('banks/${widget.bankId}/transactions').push().set(transaction).then((_) {
      _amountController.clear();
      _descriptionController.clear();
    });
  }

  void _showWarningDialog(double amount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Warning'),
        content: Text(
            'You are trying to cash out $amount Rs, but the remaining balance is only $remainingBalance Rs.\n\nDo you want to proceed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _processTransaction(amount);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _editTransaction(String transactionKey, Map transactionData) {
    _amountController.text = transactionData['amount'].toString();
    _descriptionController.text = transactionData['description'];
    bool isInitialDeposit = transactionData['type'] == 'initial_deposit';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isInitialDeposit ? 'Edit Initial Deposit' : 'Edit Transaction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (_amountController.text.isNotEmpty && _descriptionController.text.isNotEmpty) {
                final updatedTransaction = {
                  'amount': double.parse(_amountController.text),
                  'description': _descriptionController.text,
                  'type': transactionData['type'],
                  'timestamp': transactionData['timestamp'],
                };

                _dbRef.child('banks/${widget.bankId}/transactions/$transactionKey').set(updatedTransaction);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
// Add these new methods
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  // Save PDF to device
  Future<String?> _savePdf(Uint8List pdfBytes) async {
    try {
      final directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${widget.bankName}_Transactions_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(pdfBytes);
      return file.path;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving PDF: ${e.toString()}')),
      );
      return null;
    }
  }

  // Share PDF via other apps
  Future<void> _sharePdf(Uint8List pdfBytes) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/Share_${widget.bankName}_Transactions.pdf');
      await file.writeAsBytes(pdfBytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '${widget.bankName} Transactions Report',
        subject: 'Bank Transactions PDF',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing PDF: ${e.toString()}')),
      );
    }
  }

  // Generate PDF
  Future<Uint8List> _generatePdf(Map<dynamic, dynamic> transactions, double totalCashIn, double totalCashOut) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');


    // Separate initial deposit and other transactions
    MapEntry<dynamic, dynamic>? initialDeposit;
    final otherTransactions = <MapEntry<dynamic, dynamic>>[];

    transactions.entries.forEach((entry) {
      if (entry.value['type'] == 'initial_deposit') {
        initialDeposit = entry;
      } else {
        otherTransactions.add(entry);
      }
    });
// Load the image asset for the logo
    final ByteData bytes = await rootBundle.load('assets/images/logo.png');
    final buffer = bytes.buffer.asUint8List();
    final image = pw.MemoryImage(buffer);

    // Load the footer logo if different
    final ByteData footerBytes = await rootBundle.load('assets/images/devlogo.png');
    final footerBuffer = footerBytes.buffer.asUint8List();
    final footerLogo = pw.MemoryImage(footerBuffer);


    if (initialDeposit != null) {
      displayTransactions.add(initialDeposit!);
    }
    displayTransactions.addAll(otherTransactions);

// Pre-generate images for descriptions
    List<pw.MemoryImage> descriptionImages = [];
    for (var entry in displayTransactions) {
      final description = entry.value['description']?.toString() ?? '';
      final image = await _createTextImage(description);
      descriptionImages.add(image);
    }

    // Sort transactions by timestamp (newest first)
    otherTransactions.sort((a, b) => b.value['timestamp'].compareTo(a.value['timestamp']));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginLeft: 10,
          marginRight: 10,
          marginBottom: 15,
          marginTop: 15
        ),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (_startDate != null || _endDate != null)
                    pw.Text(
                      'Date Range: ${_startDate != null ? dateFormat.format(_startDate!) : 'Start'} - ${_endDate != null ? dateFormat.format(_endDate!) : 'End'}',
                      style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                    ),
                  pw.Divider(thickness: 2),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Image(image, width: 70, height: 70,dpi: 1000), // Logo at the tops
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(widget.bankName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 4),
                          pw.Text('Transaction Report', style: pw.TextStyle(fontSize: 16, color: PdfColors.grey600)),
                        ],
                      ),
                    ],
                  ),
                  pw.Divider(thickness: 2),
                ],
              ),
            ),

            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(3), // Wider for images
                3: const pw.FlexColumnWidth(2),
              },
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                // Header Row
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Type', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Amount (Rs)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Date & Time', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                // Data Rows
                for (int i = 0; i < displayTransactions.length; i++)
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          displayTransactions[i].value['type'] == 'initial_deposit'
                              ? 'INITIAL DEPOSIT'
                              : (displayTransactions[i].value['type'] == 'cash_in' ? 'Cash In' : 'Cash Out'),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('${displayTransactions[i].value['amount']}'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Image(descriptionImages[i], fit: pw.BoxFit.contain,dpi: 2000),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(dateFormat.format(
                          // DateTime.fromMillisecondsSinceEpoch(displayTransactions[i].value['timestamp']).toLocal(),
                            DateTime.fromMillisecondsSinceEpoch(displayTransactions[i].value['timestamp'] ?? 0)                     )
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Total Cash In:   $totalCashIn Rs',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold,fontSize: 16,
                    )),
                pw.Text('Total Cash Out: $totalCashOut Rs',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold,fontSize: 16)),
                pw.Divider(),
                pw.Text('Remaining Balance: ${totalCashIn - totalCashOut} Rs',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 20,
                      color: PdfColors.blue700,
                    )),
              ],
            ),
          ];
        },
        footer: (pw.Context context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 4), // Reduced top padding
          child: pw.Column(
            children: [
              pw.Divider(thickness: 1, color: PdfColors.grey), // Divider above footer
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(footerLogo, width: 30, height: 30),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Dev Valley Software House',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)), // Slightly reduced font size
                      pw.Text('Contact: 0303-4889663',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),


      ),
    );
    return pdf.save();
    // await Printing.layoutPdf(
    //   onLayout: (PdfPageFormat format) async => pdf.save(),
    // );
  }

  void _deleteTransaction(String transactionKey) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text('Are you sure you want to delete this transaction?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _dbRef.child('banks/${widget.bankId}/transactions/$transactionKey').remove().then((_) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transaction deleted successfully')),
                );
              });
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.bankName} Transactions',style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold),),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              final snapshot = await _dbRef.child('banks/${widget.bankId}/transactions').get();
              if (snapshot.exists) {
                var transactions = snapshot.value as Map<dynamic, dynamic>;
                // Apply date filter
                if (_startDate != null || _endDate != null) {
                  transactions = Map.fromEntries(transactions.entries.where((entry) {
                    final timestamp = entry.value['timestamp'] as int;
                    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
                    final isAfterStart = _startDate == null || date.isAfter(_startDate!);
                    final isBeforeEnd = _endDate == null || date.isBefore(_endDate!.add(Duration(days: 1)));
                    return isAfterStart && isBeforeEnd;
                  }));
                }
                double totalCashIn = 0;
                double totalCashOut = 0;

                for (var entry in transactions.entries) {
                  if (entry.value['type'] == 'cash_in' || entry.value['type'] == 'initial_deposit') {
                    totalCashIn += (entry.value['amount'] as num).toDouble();
                  } else if (entry.value['type'] == 'cash_out') {
                    totalCashOut += (entry.value['amount'] as num).toDouble();
                  }
                }

                final pdfBytes = await _generatePdf(transactions, totalCashIn, totalCashOut);

                switch (value) {
                  case 'print':
                    await Printing.layoutPdf(onLayout: (format) => pdfBytes);
                    break;
                  case 'save':
                    final path = await _savePdf(pdfBytes);
                    if (path != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('PDF saved to $path')),
                      );
                    }
                    break;
                  case 'share':
                    await _sharePdf(pdfBytes);
                    break;
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'print',
                child: ListTile(
                  leading: Icon(Icons.print),
                  title: Text('Print PDF'),
                ),
              ),
              const PopupMenuItem(
                value: 'save',
                child: ListTile(
                  leading: Icon(Icons.save_alt),
                  title: Text('Save PDF'),
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: ListTile(
                  leading: Icon(Icons.share),
                  title: Text('Share PDF'),
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
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
      body: StreamBuilder(
        stream: _dbRef.child('banks/${widget.bankId}/transactions').onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || (snapshot.data! as DatabaseEvent).snapshot.value == null) {
            return const Center(child: Text('No transactions found'));
          }

          final transactions = (snapshot.data! as DatabaseEvent).snapshot.value as Map<dynamic, dynamic>; // Cast to Map<dynamic, dynamic>
          final transactionList = transactions.entries.toList();
          // Filter transactions based on date range
          if (_startDate != null || _endDate != null) {
            // transactionList.retainWhere((entry) {
            //   final timestamp = entry.value['timestamp'] as int;
            //   final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
            //   final isAfterStart = _startDate == null || date.isAfter(_startDate!);
            //   final isBeforeEnd = _endDate == null || date.isBefore(_endDate!.add(Duration(days: 1)));
            //   return isAfterStart && isBeforeEnd;
            // });
            transactionList.retainWhere((entry) {
              final timestamp = entry.value['timestamp'] as int? ?? 0;
              final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
              final isAfterStart = _startDate == null || date.isAfter(_startDate!);
              final isBeforeEnd = _endDate == null || date.isBefore(_endDate!.add(Duration(days: 1)));
              return isAfterStart && isBeforeEnd;
            });
          }

          MapEntry<dynamic, dynamic>? initialDeposit;
          transactionList.removeWhere((entry) {
            if (entry.value['type'] == 'initial_deposit') {
              initialDeposit ??= MapEntry(entry.key, entry.value);
              return true;
            }
            return false;
          });

          // transactionList.sort((a, b) => b.value['timestamp'].compareTo(a.value['timestamp']));
          transactionList.sort((a, b) {
            final aTimestamp = a.value['timestamp'] as int? ?? 0;
            final bTimestamp = b.value['timestamp'] as int? ?? 0;
            return bTimestamp.compareTo(aTimestamp); // Sort newest first
          });

          double totalCashIn = initialDeposit != null ? (initialDeposit!.value['amount'] as num).toDouble() : 0;
          double totalCashOut = 0;

          for (var transaction in transactionList) {
            // double amount = (transaction.value['amount'] as num).toDouble();
            double amount = (transaction.value['amount'] as num?)?.toDouble() ?? 0;
            if (transaction.value['type'] == 'cash_in') {
              totalCashIn += amount;
            } else if (transaction.value['type'] == 'cash_out') {
              totalCashOut += amount;
            }
          }

          remainingBalance = totalCashIn - totalCashOut;
          _dbRef.child('banks/${widget.bankId}/balance').set(remainingBalance);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.date_range, size: 20),
                                label: Text(
                                  'Select Date Range',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Theme.of(context).primaryColor,
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: Theme.of(context).primaryColor,
                                      width: 1.2,
                                    ),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                ),
                                onPressed: () => _selectDateRange(context),
                              ),
                            ),
                            if (_startDate != null || _endDate != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: IconButton(
                                  icon: Icon(Icons.clear, color: Colors.red),
                                  tooltip: 'Clear filter',
                                  onPressed: _clearDateFilter,
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.red.shade50,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (_startDate != null || _endDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 8.0),
                        child: Row(
                          children: [
                            Icon(Icons.filter_alt, size: 16, color: Colors.grey.shade600),
                            SizedBox(width: 8),
                            RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade800,
                                  fontStyle: FontStyle.italic,
                                ),
                                children: [
                                  TextSpan(text: 'Showing transactions from \n'),
                                  TextSpan(
                                    text: '${_startDate != null ? DateFormat('dd MMM yyyy').format(_startDate!) : 'beginning'}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                  TextSpan(text: ' to '),
                                  TextSpan(
                                    text: '${_endDate != null ? DateFormat('dd MMM yyyy').format(_endDate!) : 'now'}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    if (initialDeposit != null)
                      ListTile(
                        title: Text('Initial Deposit', style: TextStyle(color: Colors.blue)),
                        //subtitle: Text('${initialDeposit!.value['amount']} Rs\n${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(initialDeposit!.value['timestamp']))}'),
                        // For initial deposit
                        subtitle: Text('${initialDeposit!.value['amount']} Rs\n${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(initialDeposit!.value['timestamp'] ?? 0))}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editTransaction(initialDeposit!.key.toString(), initialDeposit!.value),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteTransaction(initialDeposit!.key.toString()),
                            ),
                          ],
                        ),
                        // onTap: () => _editTransaction(initialDeposit!.key.toString(), initialDeposit!.value),
                      ),
                    for (var transaction in transactionList)
                      ListTile(
                        title: Text(
                          transaction.value['type'] == 'cash_in' ? 'Cash In' : 'Cash Out',
                          style: TextStyle(
                            color: transaction.value['type'] == 'cash_in' ? Colors.green : Colors.red,
                          ),
                        ),//s
                        //subtitle: Text('${transaction.value['amount']} Rs - ${transaction.value['description']} \n${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(transaction.value['timestamp']))}'),
                        // For regular transactions
                        subtitle: Text('${transaction.value['amount']} Rs - ${transaction.value['description']} \n${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(transaction.value['timestamp'] ?? 0))}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.grey),
                              onPressed: () => _editTransaction(transaction.key.toString(), transaction.value),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteTransaction(transaction.key.toString()),
                            ),
                          ],
                        ),                        // onTap: () => _editTransaction(transaction.key.toString(), transaction.value),
                      ),
                  ],
                ),
              ),
              Text('Remaining Balance: $remainingBalance Rs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.blueGrey.shade800,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Amount',
                              floatingLabelStyle: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                              prefixIcon: Container(
                                padding: const EdgeInsets.only(left: 12, right: 6),
                                child: Text(
                                  'PKR',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Theme.of(context).primaryColor,
                                  width: 1.5,
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14),
                              hintText: '0.00',
                              hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontWeight: FontWeight.w500),
                              helperText: 'Enter numeric value',
                              helperStyle: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500),
                            ),
                          ),
                        ),
                        SizedBox(width: 4),
                        IconButton(
                          onPressed: () async {
                            final DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (pickedDate != null) {
                              final TimeOfDay? pickedTime = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (pickedTime != null) {
                                setState(() {
                                  _selectedTransactionDateTime = DateTime(
                                    pickedDate.year,
                                    pickedDate.month,
                                    pickedDate.day,
                                    pickedTime.hour,
                                    pickedTime.minute,
                                  );
                                });
                              }
                            }
                          },
                          icon: Icon(Icons.access_time, color: Colors.blue),
                          tooltip: _selectedTransactionDateTime == null
                              ? 'Select Date & Time'
                              : 'Selected: ${DateFormat('dd/MM/yyyy HH:mm').format(_selectedTransactionDateTime!)}',
                        ),
                        Expanded(
                          child: TextField(
                            controller: _descriptionController,
                            decoration: InputDecoration(
                              labelText: 'Description',
                              floatingLabelStyle: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                              prefixIcon: Icon(Icons.description_outlined,
                                  size: 20,
                                  color: Colors.grey.shade600),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Theme.of(context).primaryColor,
                                  width: 1.5,
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14),
                              hintText: 'Transaction details...',
                              hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontWeight: FontWeight.w500),
                              helperText: 'Max 50 characters',
                              helperStyle: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500),
                            ),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.blueGrey.shade800,
                            ),
                            maxLength: 50,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _isCashIn = true);
                        _addTransaction();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text('Cash In'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _isCashIn = false);
                        _addTransaction();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Cash Out'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
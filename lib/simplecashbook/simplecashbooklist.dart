import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';
import '../Models/cashbookModel.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;
import '../Provider/customerprovider.dart';
import '../Provider/lanprovider.dart';
import '../bankmanagement/banknames.dart';
import 'simplecashbookform.dart';

class SimpleCashbookListPage extends StatefulWidget {
  final DatabaseReference databaseRef;
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(DateTime?, DateTime?) onDateRangeChanged;
  final VoidCallback onClearDateFilter;

  const SimpleCashbookListPage({
    Key? key,
    required this.databaseRef,
    this.startDate,
    this.endDate,
    required this.onDateRangeChanged,
    required this.onClearDateFilter,
  }) : super(key: key);

  @override
  _SimpleCashbookListPageState createState() => _SimpleCashbookListPageState();
}

class _SimpleCashbookListPageState extends State<SimpleCashbookListPage> {
  List<Map<String, dynamic>> _banks = [];
  Map<String, dynamic>? _selectedBank;
  Map<String, dynamic>? _selectedChequeBank;
  bool _isLoadingBanks = false;
  List<Map<String, dynamic>> _cachedBanks = [];
  TextEditingController _chequeNumberController = TextEditingController();
  DateTime? _selectedChequeDate;
  String _selectedLedgerType = 'ledger'; // Default to 'ledger'

// Add this method to fetch banks
  Future<void> _fetchBanks() async {
    setState(() => _isLoadingBanks = true);
    try {
      DataSnapshot snapshot = await FirebaseDatabase.instance.ref().child('banks').get();
      if (snapshot.value != null) {
        Map<dynamic, dynamic> banksMap = snapshot.value as Map<dynamic, dynamic>;
        _banks = banksMap.entries.map((entry) {
          return {
            'id': entry.key,
            'name': entry.value['bankName'] ?? 'No Name',
          };
        }).toList();
      }
    } catch (e) {
      print('Error fetching banks: $e');
    } finally {
      setState(() => _isLoadingBanks = false);
    }
  }

  Future<Map<String, dynamic>?> _selectBank(BuildContext context) async {
    if (_cachedBanks.isEmpty) {
      final bankSnapshot = await FirebaseDatabase.instance.ref('banks').once();
      if (bankSnapshot.snapshot.value == null) return null;

      final banks = bankSnapshot.snapshot.value as Map<dynamic, dynamic>;
      _cachedBanks = banks.entries.map((e) => {
        'id': e.key,
        'name': e.value['name'],
        'balance': e.value['balance']
      }).toList();
    }

    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    Map<String, dynamic>? selectedBank;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.isEnglish ? 'Select Bank' : 'بینک منتخب کریں'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _cachedBanks.length,
            itemBuilder: (context, index) {
              final bankData = _cachedBanks[index];
              final bankName = bankData['name'];

              // Find matching bank from pakistaniBanks list
              Bank? matchedBank = pakistaniBanks.firstWhere(
                    (b) => b.name.toLowerCase() == bankName.toLowerCase(),
                orElse: () => Bank(
                    name: bankName,
                    iconPath: 'assets/default_bank.png'
                ),
              );

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Image.asset(
                    matchedBank.iconPath,
                    width: 40,
                    height: 40,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.account_balance, size: 40);
                    },
                  ),
                  title: Text(
                    bankName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  // subtitle: Text(
                  //   '${languageProvider.isEnglish ? "Balance" : "بیلنس"}: ${bankData['balance']} Rs',
                  // ),
                  onTap: () {
                    selectedBank = {
                      'id': bankData['id'],
                      'name': bankName,
                      'balance': bankData['balance']
                    };
                    Navigator.pop(context);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
          ),
        ],
      ),
    );

    return selectedBank;
  }

  Future<List<CashbookEntry>> _getFilteredEntries() async {
    DataSnapshot snapshot = await widget.databaseRef.get();
    List<CashbookEntry> entries = [];

    if (snapshot.value != null) {
      Map<dynamic, dynamic> entriesMap = snapshot.value as Map<dynamic, dynamic>;

      // In _getFilteredEntries():
      DateTime todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      DateTime todayEnd = DateTime(todayStart.year, todayStart.month, todayStart.day, 23, 59, 59);

      DateTime? filterStart = widget.startDate ?? todayStart;
      DateTime? filterEnd = widget.endDate ?? todayEnd;

      entriesMap.forEach((key, value) {
        CashbookEntry entry = CashbookEntry.fromJson(Map<String, dynamic>.from(value));

        if ((entry.dateTime.isAfter(filterStart) ||
            entry.dateTime.isAtSameMomentAs(filterStart)) &&
            (entry.dateTime.isBefore(filterEnd.add(const Duration(days: 1))) ||
                entry.dateTime.isAtSameMomentAs(filterEnd))) {
          entries.add(entry);
        }

      });
    }
    return entries;
  }

  Map<String, double> _calculateTotals(List<CashbookEntry> entries) {
    double totalCashIn = 0;
    double totalCashOut = 0;

    for (final entry in entries) {
      if (entry.type == 'cash_in') {
        totalCashIn += entry.amount;
      } else {
        totalCashOut += entry.amount;
      }
    }

    return {
      'cashIn': totalCashIn,
      'cashOut': totalCashOut,
      'remaining': totalCashIn - totalCashOut,
    };
  }

  Future<Uint8List> _createTextImage(String text) async {
    final String displayText = text.isEmpty ? "N/A" : text;
    const double scaleFactor = 1.5;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
        recorder,
        Rect.fromPoints(
          const Offset(0, 0),
          Offset(500 * scaleFactor, 50 * scaleFactor),
        )
    );

    final textStyle = TextStyle(
      fontSize: 12 * scaleFactor,
      fontFamily: 'JameelNoori',
      color: Colors.black,
      fontWeight: FontWeight.bold,
    );

    final textSpan = TextSpan(text: displayText, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.left,
      textDirection: ui.TextDirection.rtl,
    );

    textPainter.layout();
    textPainter.paint(canvas, Offset.zero);

    final picture = recorder.endRecording();
    final img = await picture.toImage(
      (textPainter.width * scaleFactor).toInt(),
      (textPainter.height * scaleFactor).toInt(),
    );

    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _printPdf() async {
    final entries = await _getFilteredEntries();
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No entries to print')));
      return;
    }

    final Uint8List pdfBytes = await _generatePdfBytes(entries);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) => pdfBytes,
    );
  }

  Future<void> _sharePdf() async {
    final entries = await _getFilteredEntries();
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No entries to share')));
      return;
    }

    final Uint8List pdfBytes = await _generatePdfBytes(entries);
    final output = await getTemporaryDirectory();
    final file = File("${output.path}/simplecashbook_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(pdfBytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Cashbook Report',
    );
  }

  Future<Uint8List> _generatePdfBytes(List<CashbookEntry> entries) async {
    final pdf = pw.Document();
    final totals = _calculateTotals(entries);

    // Pre-generate all description images
    List<Uint8List> descriptionImages = [];
    for (var entry in entries) {
      final imageData = await _createTextImage(entry.description);
      descriptionImages.add(imageData);
    }

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text('Cashbook Report',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Type', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                ...entries.asMap().entries.map((entry) {
                  final index = entry.key;
                  final cashEntry = entry.value;
                  return pw.TableRow(
                    verticalAlignment: pw.TableCellVerticalAlignment.middle,
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(DateFormat('yyyy-MM-dd HH:mm').format(cashEntry.dateTime)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Image(
                          pw.MemoryImage(descriptionImages[index]),
                          height: 30,
                          fit: pw.BoxFit.contain,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(cashEntry.type),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(cashEntry.amount.toString()),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
            pw.SizedBox(height: 20),
            _buildPdfTotalRow('Total Cash In', totals['cashIn']!),
            _buildPdfTotalRow('Total Cash Out', totals['cashOut']!),
            _buildPdfTotalRow('Remaining Cash', totals['remaining']!,
                isHighlighted: true),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfTotalRow(String label, double value,
      {bool isHighlighted = false})
  {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4.0),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isHighlighted ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isHighlighted ? PdfColors.blue : PdfColors.black,
            ),
          ),
          pw.Text(
            '${value.toStringAsFixed(2)}Pkr',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: isHighlighted ? PdfColors.green : PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: widget.startDate != null && widget.endDate != null
          ? DateTimeRange(start: widget.startDate!, end: widget.endDate!)
          : DateTimeRange(
        start: DateTime.now(),
        end: DateTime.now(),
      ),
    );

    if (picked != null) {
      widget.onDateRangeChanged(picked.start, picked.end);
      setState(() {}); // Refresh UI
    }
  }

  Future<void> _deleteEntry(String id) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    try {
      await widget.databaseRef.child(id).remove();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.isEnglish
                  ? 'Entry deleted successfully'
                  : 'انٹری کامیابی سے حذف ہو گئی',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.isEnglish
                  ? 'Failed to delete entry: $error'
                  : 'انٹری حذف کرنے میں ناکام: $error',
            ),
          ),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmation(String entryId) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.isEnglish
            ? 'Delete Entry'
            : 'انٹری حذف کریں'),
        content: Text(languageProvider.isEnglish
            ? 'Are you sure you want to delete this entry?'
            : 'کیا آپ واقعی اس انٹری کو حذف کرنا چاہتے ہیں؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              languageProvider.isEnglish ? 'Delete' : 'حذف کریں',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await _deleteEntry(entryId);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          languageProvider.isEnglish ? 'Entries' : 'انٹریز',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            IconButton(
                onPressed: () => _selectDateRange(context),
                icon: const Icon(Icons.date_range)),
            IconButton(
                onPressed: _printPdf,
                icon: const Icon(Icons.print)),
            IconButton(
                onPressed: _sharePdf,
                icon: const Icon(Icons.share)),
            IconButton(
                onPressed: widget.onClearDateFilter,
                icon: const Icon(Icons.clear)),
          ],
        ),
        const SizedBox(height: 10),
        _buildCashbookList(),
      ],
    );
  }

  Widget _buildCashbookList() {
    return FutureBuilder<List<CashbookEntry>>(
      future: _getFilteredEntries(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No entries found'));
        } else {
          final entries = snapshot.data!;
          final totals = _calculateTotals(entries);

          return Column(
            children: [
              _buildTotalDisplay(totals),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      // title: Text(entry.description),
                      // subtitle: Text(
                      //   '${entry.type} - ${entry.amount} - '
                      //       '${DateFormat('yyyy-MM-dd HH:mm').format(entry.dateTime)}',
                      // ),
                      // In ListTile
                      title: Row(
                        children: [
                          if (entry.type == 'cash_out' && entry.isPaid)
                            const Icon(Icons.check_circle, color: Colors.green, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(entry.description)),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${entry.type} - ${entry.amount} - '
                                '${DateFormat('yyyy-MM-dd HH:mm').format(entry.dateTime)}',
                          ),
                          if (entry.isPaid)
                            Text(
                              'Paid via ${entry.paymentMethod} on '
                                  '${DateFormat('yyyy-MM-dd').format(entry.paymentDate!)}',
                              style: TextStyle(color: Colors.green[700]),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // PAYMENT BUTTON - Only show for cash_out entries
                          // if (entry.type == 'cash_out')
                          // IconButton(
                          //   icon: Icon(
                          //     entry.isPaid ? Icons.payment : Icons.payment_outlined,
                          //     color: entry.isPaid ? Colors.green : Colors.blue,
                          //   ),
                          //   onPressed: () => _showPaymentDialog(entry),
                          // ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _editEntry(entry),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _showDeleteConfirmation(entry.id!),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        }
      },
    );
  }


  Future<void> _showPaymentDialog(CashbookEntry entry) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    String? _selectedCustomerId;
    String? _selectedCustomerName;
    final CustomerProvider customerProvider = Provider.of<CustomerProvider>(context, listen: false);

    String? selectedPaymentMethod;
    final TextEditingController _amountController =
    TextEditingController(text: entry.amount.toString());
    final TextEditingController _descriptionController =
    TextEditingController(text: entry.description);
    final TextEditingController _referenceController = TextEditingController();
    DateTime _selectedDate = DateTime.now();
    Uint8List? _imageBytes;

    // Reset cheque fields
    _chequeNumberController.clear();
    _selectedChequeDate = null;
    _selectedChequeBank = null;
    _selectedBank = null;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(languageProvider.isEnglish
                  ? 'Record Payment'
                  : 'ادائیگی ریکارڈ کریں'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: Text(_selectedCustomerName ?? 'Select Customer'),
                      trailing: const Icon(Icons.arrow_drop_down),
                      onTap: () async {
                        await customerProvider.fetchCustomers();
                        final customer = await showDialog<Customer>(
                          context: context,
                          builder: (context) => CustomerSelectionDialog(
                            customers: customerProvider.customers,
                          ),
                        );
                        if (customer != null) {
                          setState(() {
                            _selectedCustomerId = customer.id;
                            _selectedCustomerName = customer.name;
                          });
                        }
                      },
                    ),
                    // Payment Date
                    ListTile(
                      title: Text(
                          '${languageProvider.isEnglish ? 'Date' : 'تاریخ'}: '
                              '${DateFormat('yyyy-MM-dd').format(_selectedDate)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) {
                          setState(() => _selectedDate = pickedDate);
                        }
                      },
                    ),

                    // Reference Number
                    TextField(
                      controller: _referenceController,
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish
                            ? 'Reference Number'
                            : 'ریفرنس نمبر',
                        border: const OutlineInputBorder(),
                      ),
                    ),

                    // Payment Method
                    DropdownButtonFormField<String>(
                      value: selectedPaymentMethod,
                      items: [
                        DropdownMenuItem(
                          value: 'Cash',
                          child: Text(languageProvider.isEnglish ? 'Cash' : 'نقد'),
                        ),
                        DropdownMenuItem(
                          value: 'Online',
                          child: Text(languageProvider.isEnglish ? 'Online Transfer' : 'آن لائن ٹرانسفر'),
                        ),
                        DropdownMenuItem(
                          value: 'Bank',
                          child: Text(languageProvider.isEnglish ? 'Bank Transfer' : 'بینک ٹرانسفر'),
                        ),
                        DropdownMenuItem(
                          value: 'Cheque',
                          child: Text(languageProvider.isEnglish ? 'Cheque' : 'چیک'),
                        ),
                        DropdownMenuItem(
                          value: 'Slip',
                          child: Text(languageProvider.isEnglish ? 'Slip' : 'پرچی'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => selectedPaymentMethod = value);
                      },
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish
                            ? 'Payment Method'
                            : 'ادائیگی کا طریقہ',
                        border: const OutlineInputBorder(),
                      ),
                    ),

                    // Bank Selection for Bank Transfer or Cheque
                    // if (selectedPaymentMethod == 'Bank' || selectedPaymentMethod == 'Cheque') ...[
                    if (selectedPaymentMethod != null &&
                        (selectedPaymentMethod == 'Bank' || selectedPaymentMethod == 'Cheque')) ...[
                      const SizedBox(height: 16),
                      Card(
                        child: ListTile(
                          title: Text(
                            (selectedPaymentMethod == 'Bank' && _selectedBank?['name'] != null)
                                ? _selectedBank!['name']
                                : (selectedPaymentMethod == 'Cheque' && _selectedChequeBank?['name'] != null)
                                ? _selectedChequeBank!['name']
                                : (languageProvider.isEnglish ? 'Select Bank' : 'بینک منتخب کریں'),
                          ),
                          trailing: const Icon(Icons.arrow_drop_down),
                          onTap: () async {
                            final selectedBank = await _selectBank(context);
                            if (selectedBank != null) {
                              setState(() {
                                if (selectedPaymentMethod == 'Bank') {
                                  _selectedBank = selectedBank;
                                } else {
                                  _selectedChequeBank = selectedBank;
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ],

                    // Cheque Details for Cheque Payment
                    // if (selectedPaymentMethod == 'Cheque') ...[
                    if (selectedPaymentMethod != null && selectedPaymentMethod == 'Cheque') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _chequeNumberController,
                        decoration: InputDecoration(
                          labelText: languageProvider.isEnglish
                              ? 'Cheque Number'
                              : 'چیک نمبر',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        title: Text(
                          _selectedChequeDate == null
                              ? (languageProvider.isEnglish
                              ? 'Select Cheque Date'
                              : 'چیک کی تاریخ منتخب کریں')
                              : DateFormat('yyyy-MM-dd').format(_selectedChequeDate!),
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate != null) {
                            setState(() => _selectedChequeDate = pickedDate);
                          }
                        },
                      ),
                    ],

                    // Amount
                    const SizedBox(height: 16),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish
                            ? 'Amount'
                            : 'رقم',
                        border: const OutlineInputBorder(),
                      ),
                    ),

                    // Description
                    const SizedBox(height: 16),
                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish
                            ? 'Description'
                            : 'تفصیل',
                        border: const OutlineInputBorder(),
                      ),
                    ),

                    // Image Upload
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        final image = await ImagePicker().pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          final bytes = await image.readAsBytes();
                          setState(() => _imageBytes = bytes);
                        }
                      },
                      child: Text(languageProvider.isEnglish
                          ? 'Upload Receipt'
                          : 'رسید اپ لوڈ کریں'),
                    ),
                    if (_imageBytes != null)
                      Image.memory(_imageBytes!, height: 100),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(_amountController.text);
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(languageProvider.isEnglish
                            ? 'Please enter a valid amount'
                            : 'براہ کرم درست رقم درج کریں')),
                      );
                      return;
                    }

                    if (_selectedCustomerId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a customer')),
                      );
                      return;
                    }

                    if (selectedPaymentMethod == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(languageProvider.isEnglish
                            ? 'Please select payment method'
                            : 'براہ کرم ادائیگی کا طریقہ منتخب کریں')),
                      );
                      return;
                    }

                    // Validate bank selection for bank transfer
                    if (selectedPaymentMethod == 'Bank' && _selectedBank == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(languageProvider.isEnglish
                            ? 'Please select a bank'
                            : 'براہ کرم بینک منتخب کریں')),
                      );
                      return;
                    }

                    // Validate cheque details
                    if (selectedPaymentMethod == 'Cheque') {
                      if (_selectedChequeBank == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(languageProvider.isEnglish
                              ? 'Please select a bank for the cheque'
                              : 'براہ کرم چیک کے لیے بینک منتخب کریں')),
                        );
                        return;
                      }
                      if (_chequeNumberController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(languageProvider.isEnglish
                              ? 'Please enter cheque number'
                              : 'براہ کرم چیک نمبر درج کریں')),
                        );
                        return;
                      }
                      if (_selectedChequeDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(languageProvider.isEnglish
                              ? 'Please select cheque date'
                              : 'براہ کرم چیک کی تاریخ منتخب کریں')),
                        );
                        return;
                      }
                    }

                    try {
                      // Update cashbook entry
                      Map<String, dynamic> updateData = {
                        'isPaid': true,
                        'paymentMethod': selectedPaymentMethod!,
                        'paidAmount': amount,
                        'paymentDate': _selectedDate.toIso8601String(),
                        'description': _descriptionController.text,
                        'referenceNumber': _referenceController.text,
                        if (_imageBytes != null) 'image': base64Encode(_imageBytes!),
                      };

                      // Handle Bank Transfer
                      if (selectedPaymentMethod == 'Bank') {
                        updateData['bankId'] = _selectedBank!['id'];
                        updateData['bankName'] = _selectedBank!['name'];

                        // Record bank transaction
                        await _recordBankTransaction(
                          bankId: _selectedBank!['id'],
                          amount: amount,
                          description: _descriptionController.text,
                          type: 'cash_in', // Since it's a payment
                          date: _selectedDate,
                        );
                      }

                      // Handle Cheque Payment
                      if (selectedPaymentMethod == 'Cheque') {
                        updateData['chequeBankId'] = _selectedChequeBank!['id'];
                        updateData['chequeBankName'] = _selectedChequeBank!['name'];
                        updateData['chequeNumber'] = _chequeNumberController.text;
                        updateData['chequeDate'] = _selectedChequeDate!.toIso8601String();
                        updateData['isHeld'] = true; // Mark as held in cashbook

                        // Record cheque payment
                        await _recordChequePayment(
                          bankId: _selectedChequeBank!['id'],
                          bankName: _selectedChequeBank!['name'],
                          chequeNumber: _chequeNumberController.text,
                          chequeDate: _selectedChequeDate!,
                          amount: amount,
                          description: _descriptionController.text,
                          customerId: _selectedCustomerId!,
                          customerName: _selectedCustomerName!,
                        );
                      }

                      await widget.databaseRef.child(entry.id!).update(updateData);

                      // Update ledger (similar to invoice payment)
                      await _updateLedger(
                        customerId: _selectedCustomerId!,
                        amount: amount,
                        paymentMethod: selectedPaymentMethod!,
                        referenceNumber: _referenceController.text,
                        description: _descriptionController.text,
                        date: _selectedDate,
                        bankId: _selectedBank?['id'] ?? _selectedChequeBank?['id'],
                        bankName: _selectedBank?['name'] ?? _selectedChequeBank?['name'],
                        chequeNumber: selectedPaymentMethod == 'Cheque'
                            ? _chequeNumberController.text
                            : null,
                        chequeDate: selectedPaymentMethod == 'Cheque'
                            ? _selectedChequeDate
                            : null,
                        isDebit: true, // <-- Add this line
                      );

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(languageProvider.isEnglish
                              ? 'Payment recorded successfully!'
                              : 'ادائیگی کامیابی سے ریکارڈ ہو گئی!')),
                        );
                        setState(() {});
                      }
                    } catch (error) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(languageProvider.isEnglish
                              ? 'Failed to record payment: $error'
                              : 'ادائیگی ریکارڈ کرنے میں ناکامی: $error')),
                        );
                      }
                    }

                    Navigator.pop(context);
                  },
                  child: Text(languageProvider.isEnglish
                      ? 'Record Payment'
                      : 'ادائیگی ریکارڈ کریں'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  Future<void> _updateLedger({
    required String customerId,
    required double amount,
    required String paymentMethod,
    required String referenceNumber,
    required String description,
    required DateTime date,
    String? bankId,
    String? bankName,
    String? chequeNumber,
    DateTime? chequeDate,
    required bool isDebit,
  }) async {
    try {
      // Use FILLEDLEDGER exclusively
      final ledgerRef = FirebaseDatabase.instance.ref().child('filledledger/$customerId');

      // Get last balance
      final snapshot = await ledgerRef.orderByChild('createdAt').limitToLast(1).get();
      double lastRemainingBalance = 0.0;

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final lastTransaction = data.values.first;
        lastRemainingBalance = (lastTransaction['remainingBalance'] as num?)?.toDouble() ?? 0.0;
      }

      // Calculate new balance
      final newRemainingBalance = isDebit
          ? lastRemainingBalance - amount  // Debit decreases liability
          : lastRemainingBalance + amount; // Credit increases liability

      // Ledger data
      final ledgerData = {
        'referenceNumber': referenceNumber,
        'description': description,
        'paymentMethod': paymentMethod,
        'remainingBalance': newRemainingBalance,
        'createdAt': date.toIso8601String(),
        if (bankId != null) 'bankId': bankId,
        if (bankName != null) 'bankName': bankName,
        if (chequeNumber != null) 'chequeNumber': chequeNumber,
        if (chequeDate != null) 'chequeDate': chequeDate.toIso8601String(),
      };

      // Add debit/credit amount
      if (isDebit) {
        ledgerData['debitAmount'] = amount;
      } else {
        ledgerData['creditAmount'] = amount;
      }

      // Write to FILLEDLEDGER
      await ledgerRef.push().set(ledgerData);
    } catch (e) {
      print('Error updating ledger: $e');
      rethrow;
    }
  }


  Future<void> _recordBankTransaction({
    required String bankId,
    required double amount,
    required String description,
    required String type, // 'cash_in' or 'cash_out'
    DateTime? date,
  })
  async {
    try {
      final transactionData = {
        'amount': amount,
        'description': description,
        'type': type,
        'timestamp': (date ?? DateTime.now()).millisecondsSinceEpoch,
        'date': (date ?? DateTime.now()).toIso8601String(),
      };

      // Record the transaction
      await FirebaseDatabase.instance.ref()
          .child('banks/$bankId/transactions')
          .push()
          .set(transactionData);

      // Update bank balance
      final bankBalanceRef = FirebaseDatabase.instance.ref().child('banks/$bankId/balance');
      final currentBalance = (await bankBalanceRef.get()).value as num? ?? 0.0;
      final newBalance = type == 'cash_in'
          ? currentBalance + amount
          : currentBalance - amount;
      await bankBalanceRef.set(newBalance);

    } catch (e) {
      print('Error recording bank transaction: $e');
      rethrow;
    }
  }

  // Future<void> _recordChequePayment({
  //   required String bankId,
  //   required String bankName,
  //   required String chequeNumber,
  //   required DateTime chequeDate,
  //   required double amount,
  //   required String description,
  // })
  // async {
  //   try {
  //     final chequeData = {
  //       'bankId': bankId,
  //       'bankName': bankName,
  //       'chequeNumber': chequeNumber,
  //       'chequeDate': chequeDate.toIso8601String(),
  //       'amount': amount,
  //       'description': description,
  //       'status': 'pending',
  //       'createdAt': DateTime.now().toIso8601String(),
  //     };
  //
  //     // Record the cheque payment
  //     await FirebaseDatabase.instance.ref()
  //         .child('cheques')
  //         .push()
  //         .set(chequeData);
  //
  //     // Also record in bank's cheques node
  //     await FirebaseDatabase.instance.ref()
  //         .child('banks/$bankId/cheques')
  //         .push()
  //         .set(chequeData);
  //
  //   } catch (e) {
  //     print('Error recording cheque payment: $e');
  //     rethrow;
  //   }
  // }

  Future<void> _recordChequePayment({
    required String bankId,
    required String bankName,
    required String chequeNumber,
    required DateTime chequeDate,
    required double amount,
    required String description,
    required String customerId,
    required String customerName,
  }) async {
    try {
      final chequeData = {
        'bankId': bankId,
        'bankName': bankName,
        'chequeNumber': chequeNumber,
        'chequeDate': chequeDate.toIso8601String(),
        'amount': amount,
        'description': description,
        'customerId': customerId,
        'customerName': customerName,
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
      };
      final _dbRef = FirebaseDatabase.instance.ref();
      // Record in both paths
      await _dbRef.child('cheques').push().set(chequeData);
      await _dbRef.child('banks/$bankId/cheques').push().set(chequeData);
    } catch (e) {
      print('Error recording cheque payment: $e');
      rethrow;
    }
  }

  Widget _buildTotalDisplay(Map<String, double> totals) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildTotalRow(
                languageProvider.isEnglish ? 'Total Cash In' : 'ٹوٹل کیش ان',
                totals['cashIn']!),
            _buildTotalRow(
                languageProvider.isEnglish ? 'Total Cash Out' : 'ٹوٹل کیش آؤٹ',
                totals['cashOut']!),
            _buildTotalRow(
                languageProvider.isEnglish ? 'Remaining Cash' : 'بقایا رقم',
                totals['remaining']!,
                isHighlighted: true),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, double value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              color: isHighlighted ? Colors.blue : Colors.black,
            ),
          ),
          Text(
            '${value.toStringAsFixed(2)}Pkr',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isHighlighted ? Colors.green : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  void _editEntry(CashbookEntry entry) {
    // Navigate to form page with entry data
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SimpleCashbookFormPage(
          databaseRef: widget.databaseRef,
          editingEntry: entry,
        ),
      ),
    );
  }
}

class CustomerSelectionDialog extends StatefulWidget {
  final List<Customer> customers;

  const CustomerSelectionDialog({required this.customers});

  @override
  _CustomerSelectionDialogState createState() => _CustomerSelectionDialogState();
}

class _CustomerSelectionDialogState extends State<CustomerSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Customer> _filteredCustomers = [];

  @override
  void initState() {
    super.initState();
    _filteredCustomers = widget.customers;
    _searchController.addListener(_filterCustomers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCustomers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCustomers = widget.customers.where((customer) {
        return customer.name.toLowerCase().contains(query) ||
            customer.phone.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Customer'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400, // Fixed height for better UX
        child: Column(
          children: [
            // Search TextField
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search Customer',
                hintText: 'Enter name or phone number',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // Customer List
            Expanded(
              child: widget.customers.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredCustomers.isEmpty
                  ? const Center(
                child: Text(
                  'No customers found',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              )
                  : ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredCustomers.length,
                itemBuilder: (context, index) {
                  final customer = _filteredCustomers[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text(
                          customer.name.isNotEmpty
                              ? customer.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        customer.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(customer.phone),
                      onTap: () => Navigator.pop(context, customer),
                    ),
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
  }
}
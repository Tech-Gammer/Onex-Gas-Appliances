import 'dart:io';
import 'dart:ui' as ui;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../Provider/filled provider.dart';
import '../Provider/filledreportprovider.dart';
import '../Provider/lanprovider.dart';
import '../Provider/reportprovider.dart';
import '../bankmanagement/banknames.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

class FilledLedgerReportPage extends StatefulWidget {
  final String customerId;
  final String customerName;
  final String customerPhone;

  const FilledLedgerReportPage({
    Key? key,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
  }) : super(key: key);

  @override
  State<FilledLedgerReportPage> createState() => _FilledLedgerReportPageState();
}

class _FilledLedgerReportPageState extends State<FilledLedgerReportPage> {
  DateTimeRange? selectedDateRange;
  static final Map<String, String> _bankIconMap = _createBankIconMap();
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

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

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    return ChangeNotifierProvider(
      create: (_) => FilledCustomerReportProvider()..fetchCustomerReport(widget.customerId),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            languageProvider.isEnglish ? 'Customer Ledger' : 'کسٹمر لیجر',
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
            Consumer<FilledCustomerReportProvider>(
              builder: (context, provider, _) {
                return Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                      onPressed: () {
                        if (provider.isLoading || provider.error.isNotEmpty) return;
                        final transactions = selectedDateRange == null
                            ? provider.transactions
                            : provider.transactions.where((transaction) {
                          final date = DateTime.parse(transaction['date']);
                          return date.isAfter(selectedDateRange!.start.subtract(const Duration(days: 1))) &&
                              date.isBefore(selectedDateRange!.end.add(const Duration(days: 1)));
                        }).toList();
                        _generateAndPrintPDF(provider.report, transactions, false,  provider.expandedTransactions,);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.white),
                      onPressed: () async {
                        if (provider.isLoading || provider.error.isNotEmpty) return;
                        final transactions = selectedDateRange == null
                            ? provider.transactions
                            : provider.transactions.where((transaction) {
                          final date = DateTime.parse(transaction['date']);
                          return date.isAfter(selectedDateRange!.start.subtract(const Duration(days: 1))) &&
                              date.isBefore(selectedDateRange!.end.add(const Duration(days: 1)));
                        }).toList();
                        await _generateAndPrintPDF(provider.report, transactions, true,  provider.expandedTransactions,);
                      },
                    ),
                  ],
                );
              },
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
          child: Consumer<FilledCustomerReportProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return Center(child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xFFFF8A65)),
                ));
              }
              if (provider.error.isNotEmpty) {
                return Center(child: Text(provider.error));
              }
              final report = provider.report;
              final transactions = selectedDateRange == null
                  ? provider.transactions
                  : provider.transactions.where((transaction) {
                final date = DateTime.parse(transaction['date']);
                return date.isAfter(selectedDateRange!.start.subtract(const Duration(days: 1))) &&
                    date.isBefore(selectedDateRange!.end.add(const Duration(days: 1)));
              }).toList();

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCustomerInfo(context, languageProvider),
                      _buildDateRangeSelector(languageProvider),
                      _buildSummaryCards(report),
                      Text(
                        'No. of Entries: ${transactions.length} (Filtered)',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Color(0xFFE65100), // Dark orange
                          fontSize: 12,
                        ),
                      ),
                      _buildTransactionTable(languageProvider),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<pw.MemoryImage> _createTextImage(String text) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromPoints(Offset(0, 0), Offset(500, 50)));
    final paint = Paint()..color = Colors.black;

    final textStyle = TextStyle(fontSize: 18, fontFamily: 'JameelNoori',color: Colors.black,fontWeight: FontWeight.bold);
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.left,
        textDirection: ui.TextDirection.ltr
    );

    textPainter.layout();
    textPainter.paint(canvas, Offset(0, 0));

    final picture = recorder.endRecording();
    final img = await picture.toImage(textPainter.width.toInt(), textPainter.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    return pw.MemoryImage(buffer);
  }


  Future<void> _generateAndPrintPDF(
      Map<String, dynamic> report,
      List<Map<String, dynamic>> transactions,
      bool isShare,
      Set<String> expandedTransactions,
      ) async {
    try {
      final pdf = pw.Document();
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      final reportProvider = Provider.of<FilledCustomerReportProvider>(context, listen: false);

      // For PDF generation, we want to show all invoice items
      // So let's create a set of all invoice transaction keys
      Set<String> allInvoiceKeys = {};

      // Load invoice items for all invoices in the transactions
      for (var transaction in transactions) {
        final isInvoice = (transaction['credit'] ?? 0) != 0;
        if (isInvoice) {
          final transactionKey = transaction['key']?.toString() ?? '';
          if (transactionKey.isNotEmpty) {
            allInvoiceKeys.add(transactionKey);
            // Ensure invoice items are loaded for this transaction
            await reportProvider.loadInvoiceItems(transactionKey);
          }
        }
      }

      // Create Urdu text images if needed
      pw.MemoryImage? customerNameImage;
      pw.MemoryImage? phoneNumberImage;

      if (!languageProvider.isEnglish) {
        customerNameImage = await _createTextImage(widget.customerName);
        phoneNumberImage = await _createTextImage('فون نمبر: ${widget.customerPhone}');
      }

      // Calculate running balance
      double runningBalance = (report['openingBalance'] ?? 0).toDouble();
      List<Map<String, dynamic>> transactionsWithBalance = [];

      for (var transaction in transactions) {
        final debit = (transaction['debit'] ?? 0).toDouble();
        final credit = (transaction['credit'] ?? 0).toDouble();
        runningBalance = runningBalance - debit + credit;

        transactionsWithBalance.add({
          ...transaction,
          'runningBalance': runningBalance,
        });
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(20),
          header: (context) => _buildPDFHeader(languageProvider, customerNameImage, phoneNumberImage),
          footer: (context) => _buildPDFFooter(context),
          build: (context) => [
            _buildPDFSummary(report),
            pw.SizedBox(height: 20),
            _buildPDFTransactionTable(
              transactionsWithBalance,
              languageProvider,
              report,
              allInvoiceKeys, // Pass all invoice keys to show all items in PDF
              reportProvider,
            ),
          ],
        ),
      );

      if (isShare) {
        await _sharePDF(pdf);
      } else {
        await _printPDF(pdf);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  pw.Widget _buildPDFHeader(
      LanguageProvider languageProvider,
      pw.MemoryImage? customerNameImage,
      pw.MemoryImage? phoneNumberImage,
      )
  {
    return pw.Container(
      padding: pw.EdgeInsets.only(bottom: 20),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Company/App Title
          pw.Text(
            'Customer Ledger Report',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.orange700,
            ),
          ),
          pw.SizedBox(height: 10),

          // Customer Information
          if (languageProvider.isEnglish) ...[
            pw.Text(
              widget.customerName,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Phone: ${widget.customerPhone}',
              style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
            ),
          ] else ...[
            if (customerNameImage != null)
              pw.Image(customerNameImage, height: 30),
            if (phoneNumberImage != null)
              pw.Image(phoneNumberImage, height: 20),
          ],

          pw.SizedBox(height: 5),

          // Date Range
          pw.Text(
            selectedDateRange == null
                ? 'All Transactions'
                : '${DateFormat('dd MMM yyyy').format(selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(selectedDateRange!.end)}',
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
          ),

          pw.Text(
            'Generated on: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}',
        style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
      ),
    );
  }

  pw.Widget _buildPDFSummary(Map<String, dynamic> report) {
    return pw.Container(
      padding: pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.orange50,
        border: pw.Border.all(color: PdfColors.orange200),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildPDFSummaryCard('Total Debit', 'Rs ${(report['debit'] ?? 0).toStringAsFixed(2)}', PdfColors.red),
          _buildPDFSummaryCard('Total Credit', 'Rs ${(report['credit'] ?? 0).toStringAsFixed(2)}', PdfColors.green),
          _buildPDFSummaryCard('Net Balance', 'Rs ${(report['balance'] ?? 0).toStringAsFixed(2)}', PdfColors.orange700),
        ],
      ),
    );
  }

  pw.Widget _buildPDFSummaryCard(String title, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
        pw.SizedBox(height: 5),
        pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  pw.Widget _buildPDFTransactionTable(
      List<Map<String, dynamic>> transactions,
      LanguageProvider languageProvider,
      Map<String, dynamic> report,
      Set<String> expandedTransactions,
      FilledCustomerReportProvider reportProvider,
      ) {
    final headers = [
      languageProvider.isEnglish ? 'Date' : 'Date',
      languageProvider.isEnglish ? 'Details' : 'Details',
      languageProvider.isEnglish ? 'Type' : 'Type',
      languageProvider.isEnglish ? 'Payment Method' : 'Method',
      languageProvider.isEnglish ? 'Bank' : 'Bank',
      languageProvider.isEnglish ? 'Debit' : 'Debit',
      languageProvider.isEnglish ? 'Credit' : 'Credit',
      languageProvider.isEnglish ? 'Balance' : 'Balance',
    ];

    // Change this line: List<pw.Widget> to List<pw.TableRow>
    List<pw.TableRow> tableRows = [];

    // Add opening balance row if exists
    final openingBalance = (report['openingBalance'] ?? 0).toDouble();
    if (openingBalance > 0) {
      tableRows.add(
        pw.TableRow(
          children: [
            _buildPdfTableCell(''),
            _buildPdfTableCell('Opening Balance'),
            _buildPdfTableCell(''),
            _buildPdfTableCell(''),
            _buildPdfTableCell(''),
            _buildPdfTableCell(''),
            _buildPdfTableCell('Rs ${openingBalance.toStringAsFixed(2)}', color: PdfColors.green),
            _buildPdfTableCell('Rs ${openingBalance.toStringAsFixed(2)}', color: PdfColors.blue),
          ],
        ),
      );
    }

    // Add transactions
    for (var transaction in transactions) {
      final date = DateTime.tryParse(transaction['date']?.toString() ?? '') ?? DateTime(2000);
      final details = transaction['details']?.toString() ??
          transaction['referenceNumber']?.toString() ??
          transaction['filledNumber']?.toString() ?? '-';
      final isInvoice = (transaction['credit'] ?? 0) != 0;
      final paymentMethod = transaction['paymentMethod']?.toString() ?? '-';
      final bankName = _getBankName(transaction) ?? '-';
      final debit = (transaction['debit'] ?? 0) > 0 ? 'Rs ${(transaction['debit']).toStringAsFixed(2)}' : '-';
      final credit = (transaction['credit'] ?? 0) > 0 ? 'Rs ${(transaction['credit']).toStringAsFixed(2)}' : '-';
      final balance = 'Rs ${(transaction['runningBalance']).toStringAsFixed(2)}';
      final transactionKey = transaction['key']?.toString() ?? '';
      final isExpanded = expandedTransactions.contains(transactionKey);

      // Add main transaction row
      tableRows.add(
        pw.TableRow(
          children: [
            _buildPdfTableCell(DateFormat('dd/MM/yy').format(date)),
            _buildPdfTableCell(details.length > 20 ? '${details.substring(0, 17)}...' : details),
            _buildPdfTableCell(isInvoice ? 'Invoice' : 'Payment'),
            _buildPdfTableCell(_getPaymentMethodText(paymentMethod, languageProvider)),
            _buildPdfTableCell(bankName.length > 15 ? '${bankName.substring(0, 12)}...' : bankName),
            _buildPdfTableCell(debit, color: (transaction['debit'] ?? 0) > 0 ? PdfColors.red : PdfColors.grey),
            _buildPdfTableCell(credit, color: (transaction['credit'] ?? 0) > 0 ? PdfColors.green : PdfColors.grey),
            _buildPdfTableCell(balance, color: PdfColors.blue),
          ],
        ),
      );

      // Add invoice items if expanded
      if (isInvoice && isExpanded) {
        final invoiceItems = reportProvider.invoiceItems[transactionKey] ?? [];
        if (invoiceItems.isNotEmpty) {
          // Add a row that spans all columns for invoice items
          tableRows.add(
            pw.TableRow(
              children: [
                // Span across all columns using a Container
                pw.Container(
                  padding: pw.EdgeInsets.all(8),
                  color: PdfColors.orange50,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Invoice Items:',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.orange700,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      // Create a sub-table for invoice items
                      pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                        columnWidths: {
                          0: pw.FlexColumnWidth(3), // Item Name
                          1: pw.FlexColumnWidth(1), // Quantity
                          2: pw.FlexColumnWidth(1.5), // Unit Price
                          3: pw.FlexColumnWidth(1.5), // Total
                        },
                        children: [
                          // Sub-table header
                          pw.TableRow(
                            decoration: pw.BoxDecoration(color: PdfColors.grey200),
                            children: [
                              _buildPdfTableCell('Item Name'),
                              _buildPdfTableCell('Qty'),
                              _buildPdfTableCell('Unit Price'),
                              _buildPdfTableCell('Total'),
                            ],
                          ),
                          // Invoice item rows
                          ...invoiceItems.map((item) {
                            return pw.TableRow(
                              children: [
                                _buildPdfTableCell(item['itemName']?.toString() ?? '-'),
                                _buildPdfTableCell(item['quantity']?.toString() ?? '0'),
                                _buildPdfTableCell('Rs ${(item['price'] ?? 0).toStringAsFixed(2)}'),
                                _buildPdfTableCell('Rs ${(item['total'] ?? 0).toStringAsFixed(2)}', color: PdfColors.green),
                              ],
                            );
                          }).toList(),
                          // Invoice total row
                          pw.TableRow(
                            decoration: pw.BoxDecoration(color: PdfColors.green50),
                            children: [
                              _buildPdfTableCell('Total', color: PdfColors.green700),
                              _buildPdfTableCell(''),
                              _buildPdfTableCell(''),
                              _buildPdfTableCell(
                                'Rs ${invoiceItems.fold(0.0, (sum, item) => sum + (item['total'] ?? 0)).toStringAsFixed(2)}',
                                color: PdfColors.green700,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Empty cells for the remaining columns
                for (int i = 0; i < 7; i++) pw.Container(),
              ],
            ),
          );
        } else {
          // If no invoice items found, add a loading message
          tableRows.add(
            pw.TableRow(
              children: [
                pw.Container(
                  padding: pw.EdgeInsets.all(8),
                  color: PdfColors.grey100,
                  child: pw.Text(
                    'Loading invoice items... (Items may not be available in PDF)',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.grey600,
                    ),
                  ),
                ),
                // Empty cells for the remaining columns
                for (int i = 0; i < 7; i++) pw.Container(),
              ],
            ),
          );
        }
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Transaction Details (${transactions.length} entries)',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: pw.FixedColumnWidth(60),  // Date
            1: pw.FixedColumnWidth(80),  // Details
            2: pw.FixedColumnWidth(50),  // Type
            3: pw.FixedColumnWidth(60),  // Payment Method
            4: pw.FixedColumnWidth(70),  // Bank
            5: pw.FixedColumnWidth(60),  // Debit
            6: pw.FixedColumnWidth(60),  // Credit
            7: pw.FixedColumnWidth(60),  // Balance
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.orange100),
              children: headers.map((header) =>
                  pw.Padding(
                    padding: pw.EdgeInsets.all(4),
                    child: pw.Text(
                      header,
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
              ).toList(),
            ),
            // Data rows - now correctly using List<pw.TableRow>
            ...tableRows,
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPdfTableCell(String text, {PdfColor? color}) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7,
          color: color ?? PdfColors.black,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  Future<void> _printPDF(pw.Document pdf) async {
    try {
      if (kIsWeb) {
        // Web platform - download PDF
        final bytes = await pdf.save();
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download = 'customer_ledger_${widget.customerName}_${DateFormat('ddMMyyyy').format(DateTime.now())}.pdf';
        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF downloaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Mobile/Desktop platform - use printing package
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save(),
          name: 'customer_ledger_${widget.customerName}_${DateFormat('ddMMyyyy').format(DateTime.now())}.pdf',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error printing PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sharePDF(pw.Document pdf) async {
    try {
      final bytes = await pdf.save();
      final fileName = 'customer_ledger_${widget.customerName}_${DateFormat('ddMMyyyy').format(DateTime.now())}.pdf';

      if (kIsWeb) {
        // For web, download the file
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download = fileName;
        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF downloaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // For mobile/desktop, save to temporary directory and share
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(bytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Customer Ledger Report for ${widget.customerName}',
          subject: 'Customer Ledger Report',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  Widget _buildCustomerInfo(BuildContext context, LanguageProvider languageProvider) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Center(
      child: Column(
        children: [
          Text(
            widget.customerName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 20 : 24,
              color: Color(0xFFE65100), // Dark orange
            ),
          ),
          Text(
            '${languageProvider.isEnglish ? 'Phone Number:' : 'فون نمبر:'} ${widget.customerPhone}',
            style: TextStyle(color: Color(0xFFFF8A65)),
          ),
          const SizedBox(height: 10),
          Text(
            selectedDateRange == null
                ? 'All Transactions'
                : '${DateFormat('dd MMM yy').format(selectedDateRange!.start)} - ${DateFormat('dd MMM yy').format(selectedDateRange!.end)}',
            style: TextStyle(color: Color(0xFFFF8A65)),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeSelector(LanguageProvider languageProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ElevatedButton.icon(
          onPressed: () async {
            final pickedDateRange = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
            );
            if (pickedDateRange != null) {
              setState(() => selectedDateRange = pickedDateRange);
            }
          },
          icon: const Icon(Icons.date_range),
          label: Text(languageProvider.isEnglish ? 'Select Date Range' : 'تاریخ منتخب کریں'),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Color(0xFFFF8A65), // Orange button
          ),
        ),
        if (selectedDateRange != null)
          TextButton(
            onPressed: () => setState(() => selectedDateRange = null),
            child: Text(
              languageProvider.isEnglish ? 'Clear Filter' : 'فلٹر صاف کریں',
              style: TextStyle(color: Color(0xFFFF8A65)),
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> report) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Wrap(
        spacing: 12.0,
        runSpacing: 12.0,
        alignment: WrapAlignment.center,
        children: [
          _buildSummaryCard('Total Debit', report['debit']?.toStringAsFixed(2) ?? '0.00', Colors.red, isMobile),
          _buildSummaryCard('Total Credit', report['credit']?.toStringAsFixed(2) ?? '0.00', Colors.green, isMobile),
          _buildSummaryCard('Net Balance', report['balance']?.toStringAsFixed(2) ?? '0.00', Color(0xFFFF8A65), isMobile), // Orange balance card
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color, bool isMobile) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: color.withOpacity(0.1),
      child: SizedBox(
        width: isMobile ? 120 : 180,
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: [
              Icon(Icons.pie_chart, size: isMobile ? 20 : 30, color: color),
              const SizedBox(height: 6),
              Text(title, style: TextStyle(fontSize: isMobile ? 12 : 16, color: color, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Rs $value', style: TextStyle(fontSize: isMobile ? 14 : 18, color: Colors.black87, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceItems(String transactionKey, FilledCustomerReportProvider reportProvider, DateTime date) {
    final invoiceItems = reportProvider.invoiceItems[transactionKey] ?? [];
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Color(0xFFFFB74D), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header for the expanded section
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFFFFB74D).withOpacity(0.3),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.receipt, color: Color(0xFFE65100), size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Invoice Items - ${DateFormat('dd MMM yyyy').format(date)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 12 : 14,
                      color: Color(0xFFE65100),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'Total: Rs ${(invoiceItems.fold(0.0, (sum, item) => sum + (item['total'] ?? 0))).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 12 : 14,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ),

          // Invoice items content
          Padding(
            padding: EdgeInsets.all(12),
            child: invoiceItems.isEmpty
                ? Container(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Color(0xFFFF8A65)),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Loading invoice items...',
                      style: TextStyle(
                        color: Color(0xFFE65100),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            )
                : isMobile
                ? _buildMobileInvoiceTable(invoiceItems)
                : _buildDesktopInvoiceTable(invoiceItems),
          ),
        ],
      ),
    );
  }

// Mobile-friendly table layout
  Widget _buildMobileInvoiceTable(List<Map<String, dynamic>> invoiceItems) {
    return Column(
      children: invoiceItems.map((item) {
        return Container(
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item['itemName']?.toString() ?? '-',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Qty: ${item['quantity']?.toString() ?? '0'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    'Unit: Rs ${(item['price'] ?? 0).toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                  ),
                  Text(
                    'Total: Rs ${(item['total'] ?? 0).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

// Desktop table layout with proper constraints
  Widget _buildDesktopInvoiceTable(List<Map<String, dynamic>> invoiceItems) {
    return Container(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 100,
          ),
          child: DataTable(
            columnSpacing: 20,
            dataRowHeight: 45,
            headingRowHeight: 40,
            headingRowColor: MaterialStateProperty.all(Colors.white),
            border: TableBorder.all(color: Colors.grey[300]!),
            headingTextStyle: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFFE65100),
              fontSize: 13,
            ),
            dataTextStyle: TextStyle(
              fontSize: 12,
              color: Colors.black87,
            ),
            columns: [
              DataColumn(
                label: Expanded(
                  child: Text('Item Name'),
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
                label: Text('Total'),
                numeric: true,
              ),
            ],
            rows: invoiceItems.map((item) {
              return DataRow(
                cells: [
                  DataCell(
                    Container(
                      width: 200,
                      child: Text(
                        item['itemName']?.toString() ?? '-',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      item['quantity']?.toString() ?? '0',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  DataCell(
                    Text(
                      'Rs ${(item['price'] ?? 0).toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.blue[700]),
                    ),
                  ),
                  DataCell(
                    Text(
                      'Rs ${(item['total'] ?? 0).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // Replace your _buildTransactionTable method with this:
  Widget _buildTransactionTable(LanguageProvider languageProvider) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Consumer<FilledCustomerReportProvider>(
      builder: (context, reportProvider, child) {
        final openingBalance = reportProvider.openingBalance ?? 0;
        final transactions = reportProvider.transactions ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Opening Balance Card (if > 0)
            if (openingBalance > 0)
              Card(
                margin: EdgeInsets.only(bottom: 10),
                color: Colors.grey[100],
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        languageProvider.isEnglish ? 'Opening Balance' : 'ابتدائی بیلنس',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Rs ${openingBalance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Custom Table with inline invoice items
            _buildCustomTransactionTable(transactions, reportProvider, isMobile, languageProvider),
          ],
        );
      },
    );
  }

// New method to build custom table with inline invoice items
  Widget _buildCustomTransactionTable(
      List<Map<String, dynamic>> transactions,
      FilledCustomerReportProvider reportProvider,
      bool isMobile,
      LanguageProvider languageProvider,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Table Header
        Container(
          decoration: BoxDecoration(
            color: Color(0xFFFFB74D).withOpacity(0.2),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildHeaderCell(languageProvider.isEnglish ? 'Date' : 'ڈیٹ', 120),
                _buildHeaderCell(languageProvider.isEnglish ? 'Details' : 'تفصیلات', 120),
                _buildHeaderCell(languageProvider.isEnglish ? 'Type' : 'قسم', 100),
                _buildHeaderCell(languageProvider.isEnglish ? 'Payment Method' : 'ادائیگی کا طریقہ', 120),
                _buildHeaderCell(languageProvider.isEnglish ? 'Bank' : 'بینک', 150),
                _buildHeaderCell(languageProvider.isEnglish ? 'Debit' : 'ڈیبٹ', 100),
                _buildHeaderCell(languageProvider.isEnglish ? 'Credit' : 'کریڈٹ', 100),
                _buildHeaderCell(languageProvider.isEnglish ? 'Balance' : 'بیلنس', 100),
              ],
            ),
          ),
        ),

        // Table Rows with inline invoice items
        ...transactions.expand((transaction) {
          List<Widget> rowWidgets = [];

          // Add the main transaction row
          rowWidgets.add(_buildTransactionRow(transaction, reportProvider, isMobile, languageProvider));

          // Add invoice items right after this row if it's expanded
          final isInvoice = (transaction['credit'] ?? 0) != 0;
          final transactionKey = transaction['key']?.toString() ?? '';
          final isExpanded = reportProvider.expandedTransactions.contains(transactionKey);

          if (isInvoice && isExpanded) {
            final date = DateTime.tryParse(transaction['date']?.toString() ?? '') ?? DateTime(2000);
            rowWidgets.add(_buildInvoiceItems(transactionKey, reportProvider, date));
          }

          return rowWidgets;
        }).toList(),
      ],
    );
  }

  Widget _buildHeaderCell(String text, double width) {
    return Container(
      width: width,
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
      ),
    );
  }

  Widget _buildTransactionRow(
      Map<String, dynamic> transaction,
      FilledCustomerReportProvider reportProvider,
      bool isMobile,
      LanguageProvider languageProvider,
      )
  {
    final bankName = _getBankName(transaction);
    final bankLogoPath = _getBankLogoPath(bankName);
    final isInvoice = (transaction['credit'] ?? 0) != 0;
    final transactionKey = transaction['key']?.toString() ?? '';
    final isExpanded = reportProvider.expandedTransactions.contains(transactionKey);

    final date = DateTime.tryParse(transaction['date']?.toString() ?? '') ?? DateTime(2000);
    final details = transaction['details']?.toString() ??
        transaction['referenceNumber']?.toString() ??
        transaction['filledNumber']?.toString() ??
        '-';
    final paymentMethod = transaction['paymentMethod']?.toString() ?? '-';
    final debit = transaction['debit']?.toStringAsFixed(2) ?? '0.00';
    final credit = transaction['credit']?.toStringAsFixed(2) ?? '0.00';
    final balance = transaction['balance']?.toStringAsFixed(2) ?? '0.00';

    return GestureDetector(
      onTap: isInvoice ? () {
        reportProvider.toggleTransactionExpansion(transactionKey);
      } : null,
      child: Container(
        decoration: BoxDecoration(
          color: isInvoice && isExpanded
              ? Color(0xFFFFB74D).withOpacity(0.1)
              : Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.grey[300]!),
            left: BorderSide(color: Colors.grey[300]!),
            right: BorderSide(color: Colors.grey[300]!),
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildDataCell(
                DateFormat('dd MMM yyyy').format(date),
                120,
                isMobile,
              ),
              _buildDataCell(details, 120, isMobile),
              _buildDataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isInvoice ? 'Invoice' : 'Payment',
                      style: TextStyle(fontSize: isMobile ? 10 : 12),
                    ),
                    if (isInvoice) ...[
                      SizedBox(width: 4),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 16,
                        color: Color(0xFFE65100),
                      ),
                    ],
                  ],
                ),
                100,
                isMobile,
              ),
              _buildDataCell(
                _getPaymentMethodText(paymentMethod, languageProvider),
                120,
                isMobile,
              ),
              _buildDataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (bankLogoPath != null) ...[
                      Image.asset(bankLogoPath, width: 24, height: 24),
                      SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        bankName ?? '-',
                        style: TextStyle(fontSize: isMobile ? 10 : 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                150,
                isMobile,
              ),
              _buildDataCell(
                (transaction['debit'] ?? 0) > 0 ? 'Rs $debit' : '-',
                100,
                isMobile,
                textColor: (transaction['debit'] ?? 0) > 0 ? Colors.red : Colors.grey,
              ),
              _buildDataCell(
                (transaction['credit'] ?? 0) > 0 ? 'Rs $credit' : '-',
                100,
                isMobile,
                textColor: (transaction['credit'] ?? 0) > 0 ? Colors.green : Colors.grey,
              ),
              _buildDataCell(
                'Rs $balance',
                100,
                isMobile,
                fontWeight: FontWeight.bold,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataCell(
      dynamic content,
      double width,
      bool isMobile, {
        Color? textColor,
        FontWeight? fontWeight,
      }) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey[300]!)),
      ),
      child: content is Widget
          ? content
          : Text(
        content.toString(),
        style: TextStyle(
          fontSize: isMobile ? 10 : 12,
          color: textColor ?? Colors.black87,
          fontWeight: fontWeight,
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }



  String _getPaymentMethodText(String? method, LanguageProvider languageProvider) {
    if (method == null) return '-';
    switch (method.toLowerCase()) {
      case 'cash': return languageProvider.isEnglish ? 'Cash' : 'نقد';
      case 'online': return languageProvider.isEnglish ? 'Online' : 'آن لائن';
      case 'check':
      case 'cheque': return languageProvider.isEnglish ? 'Cheque' : 'چیک';
      case 'bank': return languageProvider.isEnglish ? 'Bank Transfer' : 'بینک ٹرانسفر';
      case 'slip': return languageProvider.isEnglish ? 'Slip' : 'پرچی';
      case 'udhaar': return languageProvider.isEnglish ? 'Udhaar' : 'ادھار';
      default: return method;
    }
  }

}

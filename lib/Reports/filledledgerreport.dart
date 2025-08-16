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
                        _generateAndPrintPDF(provider.report, transactions, false);
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
                        await _generateAndPrintPDF(provider.report, transactions, true);
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
      bool shouldShare,
      )
  async {
    final pdf = pw.Document();
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final reportProvider = Provider.of<FilledCustomerReportProvider>(context, listen: false);
    final font = await PdfGoogleFonts.robotoRegular();

    double totalDebit = 0.0;
    double totalCredit = 0.0;

    for (var transaction in transactions) {
      totalDebit += transaction['debit'] ?? 0.0;
      totalCredit += transaction['credit'] ?? 0.0;
    }

    double totalBalance = totalCredit - totalDebit;
    String printDate = DateFormat('dd MMM yyyy').format(DateTime.now());

    // Load images
    final ByteData footerBytes = await rootBundle.load('assets/images/devlogo.png');
    final footerBuffer = footerBytes.buffer.asUint8List();
    final footerLogo = pw.MemoryImage(footerBuffer);

    final ByteData bytes = await rootBundle.load('assets/images/logo.png');
    final buffer = bytes.buffer.asUint8List();
    final image = pw.MemoryImage(buffer);

    final customerDetailsImage = await _createTextImage('Customer Name: ${widget.customerName}');

    // Preload bank logos for PDF
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

    // Build PDF content
    List<pw.Widget> pdfContent = [];

    // Header
    pdfContent.add(
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Image(image, width: 80, height: 80, dpi: 1000),
        ],
      ),
    );

    pdfContent.add(pw.SizedBox(height: 20));

    pdfContent.add(
      pw.Text('Customer Ledger',
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
    );

    pdfContent.add(pw.SizedBox(height: 20));

    pdfContent.add(pw.Image(customerDetailsImage, width: 300, dpi: 1000));
    pdfContent.add(pw.Text('Phone Number: ${widget.customerPhone}', style: pw.TextStyle(fontSize: 18)));
    pdfContent.add(pw.SizedBox(height: 10));
    pdfContent.add(pw.Text('Print Date: $printDate',
        style: pw.TextStyle(fontSize: 16, color: PdfColors.grey)));
    pdfContent.add(pw.SizedBox(height: 20));

    // Add opening balance if exists
    final openingBalance = reportProvider.openingBalance ?? 0;
    if (openingBalance > 0) {
      pdfContent.add(
        pw.Container(
          padding: pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            border: pw.Border.all(color: PdfColors.grey300),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Opening Balance', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.Text('Rs ${openingBalance.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.green)),
            ],
          ),
        ),
      );
      pdfContent.add(pw.SizedBox(height: 20));
    }

    pdfContent.add(
      pw.Text('Transactions:',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
    );

    // Main Transaction Table
    pdfContent.add(
      pw.Table(
        columnWidths: {
          0: const pw.FlexColumnWidth(1.5),
          1: const pw.FlexColumnWidth(1),
          2: const pw.FlexColumnWidth(1),
          3: const pw.FlexColumnWidth(1.5),
          4: const pw.FlexColumnWidth(1.5),
          5: const pw.FlexColumnWidth(1.2),
          6: const pw.FlexColumnWidth(1.2),
          7: const pw.FlexColumnWidth(1.2),
        },
        children: [
          // Header row
          pw.TableRow(
            children: [
              _buildPdfHeaderCell('Date'),
              _buildPdfHeaderCell('Filled #'),
              _buildPdfHeaderCell('T-Type'),
              _buildPdfHeaderCell('Payment Method'),
              _buildPdfHeaderCell('Bank'),
              _buildPdfHeaderCell('Debit(-)'),
              _buildPdfHeaderCell('Credit(+)'),
              _buildPdfHeaderCell('Balance'),
            ],
          ),
          // Data rows
          ...transactions.map((transaction) {
            final bankName = _getBankName(transaction);
            final bankLogo = bankName != null ? bankLogoImages[bankName.toLowerCase()] : null;
            final isInvoice = (transaction['credit'] ?? 0) != 0;

            return pw.TableRow(
              children: [
                _buildPdfCell(DateFormat('dd MMM yyyy, hh:mm a')
                    .format(DateTime.parse(transaction['date']))),
                _buildPdfCell(transaction['referenceNumber'] ?? transaction['filledNumber'] ?? '-'),
                _buildPdfCell(isInvoice ? 'Invoice' : 'Payment'),
                _buildPdfCell(transaction['paymentMethod'] ?? '-'),
                pw.Row(
                  children: [
                    if (bankLogo != null)
                      pw.Container(
                        height: 20,
                        width: 40,
                        margin: const pw.EdgeInsets.only(right: 2),
                        child: pw.Image(bankLogo),
                      ),
                    pw.Expanded(child: _buildPdfCell(bankName ?? '-')),
                  ],
                ),
                _buildPdfCell(transaction['debit'] != 0.0
                    ? 'Rs ${transaction['debit']?.toStringAsFixed(2)}'
                    : '-'),
                _buildPdfCell(transaction['credit'] != 0.0
                    ? 'Rs ${transaction['credit']?.toStringAsFixed(2)}'
                    : '-'),
                _buildPdfCell('Rs ${transaction['balance']?.toStringAsFixed(2)}'),
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
              _buildPdfCell(''),
              _buildPdfCell('Rs ${totalDebit.toStringAsFixed(2)}', isHeader: true),
              _buildPdfCell('Rs ${totalCredit.toStringAsFixed(2)}', isHeader: true),
              _buildPdfCell('Rs ${totalBalance.toStringAsFixed(2)}', isHeader: true),
            ],
          ),
        ],
      ),
    );

    // Add invoice details for expanded transactions
    for (var transaction in transactions) {
      final isInvoice = (transaction['credit'] ?? 0) != 0;
      final transactionKey = transaction['key']?.toString() ?? '';
      final isExpanded = reportProvider.expandedTransactions.contains(transactionKey);

      if (isInvoice && isExpanded) {
        final invoiceItems = reportProvider.invoiceItems[transactionKey] ?? [];
        final date = DateTime.tryParse(transaction['date']?.toString() ?? '') ?? DateTime(2000);

        pdfContent.add(pw.SizedBox(height: 15));

        // Invoice header
        pdfContent.add(
          pw.Container(
            padding: pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.orange100,
              border: pw.Border.all(color: PdfColors.orange300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Invoice Items - ${DateFormat('dd MMM yyyy').format(date)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                ),
                pw.Text(
                  'Total: Rs ${(transaction['credit'] ?? 0).toStringAsFixed(2)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.green),
                ),
              ],
            ),
          ),
        );

        if (invoiceItems.isNotEmpty) {
          // Invoice items table
          pdfContent.add(
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
              },
              children: [
                // Invoice items header
                pw.TableRow(
                  children: [
                    _buildPdfHeaderCell('Item Name'),
                    _buildPdfHeaderCell('Quantity'),
                    _buildPdfHeaderCell('Unit Price'),
                    _buildPdfHeaderCell('Total'),
                  ],
                ),
                // Invoice items data
                ...invoiceItems.map((item) {
                  return pw.TableRow(
                    children: [
                      _buildPdfCell(item['itemName']?.toString() ?? '-'),
                      _buildPdfCell(item['quantity']?.toString() ?? '0'),
                      _buildPdfCell('Rs ${(item['price'] ?? 0).toStringAsFixed(2)}'),
                      _buildPdfCell('Rs ${(item['total'] ?? 0).toStringAsFixed(2)}'),
                    ],
                  );
                }).toList(),
              ],
            ),
          );
        } else {
          pdfContent.add(
            pw.Container(
              padding: pw.EdgeInsets.all(15),
              child: pw.Text(
                'Loading invoice items...',
                style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: PdfColors.grey600),
              ),
            ),
          );
        }
      }
    }

    pdfContent.add(pw.SizedBox(height: 20));
    pdfContent.add(pw.Divider());
    pdfContent.add(pw.Spacer());

    // Footer
    pdfContent.add(
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
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) => pdfContent,
      ),
    );

    final pdfBytes = await pdf.save();

    // Rest of the sharing/printing logic remains the same
    if (kIsWeb) {
      if (shouldShare) {
        try {
          final blob = html.Blob([pdfBytes], 'application/pdf');
          final file = html.File([blob], 'filled_ledger_report.pdf', {'type': 'application/pdf'});
          if (html.window.navigator is html.Navigator &&
              (html.window.navigator as dynamic).canShare != null &&
              (html.window.navigator as dynamic).canShare({'files': [file]})) {
            await (html.window.navigator as dynamic).share({
              'title': 'Filled Ledger Report',
              'text': 'Filled Ledger Report for ${widget.customerName}',
              'files': [file],
            });
            return;
          }
        } catch (e) {
          print('Web share failed: $e');
        }
        _downloadPdfWeb(pdfBytes);
      } else {
        try {
          await Printing.layoutPdf(
            onLayout: (PdfPageFormat format) async => pdfBytes,
            usePrinterSettings: false,
          );
        } catch (e) {
          print('Web printing failed: $e');
          _downloadPdfWeb(pdfBytes);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Printing not supported, PDF downloaded instead')),
          );
        }
      }
    } else {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/filled_ledger_report.pdf');
      await file.writeAsBytes(pdfBytes);

      if (shouldShare) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Filled Ledger Report for ${widget.customerName}',
          subject: 'Filled Ledger Report',
        );
      } else {
        await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfBytes);
      }
    }
  }

  pw.Widget _buildPdfHeaderCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
      child: pw.Text(
        text,
        style:  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
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

  void _downloadPdfWeb(Uint8List bytes) {
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = 'filled_ledger_report_${widget.customerName}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF downloaded successfully')),
    );
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

// Updated transaction table with better row structure
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

            // Main Transaction Table
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(Color(0xFFFFB74D).withOpacity(0.2)),
                headingTextStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE65100),
                ),
                columns: [
                  DataColumn(label: Text(languageProvider.isEnglish ? 'Date' : 'ڈیٹ')),
                  DataColumn(label: Text(languageProvider.isEnglish ? 'Details' : 'تفصیلات')),
                  DataColumn(label: Text(languageProvider.isEnglish ? 'Type' : 'قسم')),
                  DataColumn(label: Text(languageProvider.isEnglish ? 'Payment Method' : 'ادائیگی کا طریقہ')),
                  DataColumn(label: Text(languageProvider.isEnglish ? 'Bank' : 'بینک')),
                  DataColumn(label: Text(languageProvider.isEnglish ? 'Debit' : 'ڈیبٹ')),
                  DataColumn(label: Text(languageProvider.isEnglish ? 'Credit' : 'کریڈٹ')),
                  DataColumn(label: Text(languageProvider.isEnglish ? 'Balance' : 'بیلنس')),
                ],
                rows: _buildDataRows(transactions, reportProvider, isMobile, languageProvider),
              ),
            ),

            // Expanded invoice items displayed outside the DataTable
            ...transactions.where((transaction) {
              final isInvoice = (transaction['credit'] ?? 0) != 0;
              final transactionKey = transaction['key']?.toString() ?? '';
              final isExpanded = reportProvider.expandedTransactions.contains(transactionKey);
              return isInvoice && isExpanded;
            }).map((transaction) {
              final transactionKey = transaction['key']?.toString() ?? '';
              final date = DateTime.tryParse(transaction['date']?.toString() ?? '') ?? DateTime(2000);
              return _buildInvoiceItems(transactionKey, reportProvider, date);
            }).toList(),
          ],
        );
      },
    );
  }

// Helper method to build data rows without nested DataTables
  List<DataRow> _buildDataRows(
      List<Map<String, dynamic>> transactions,
      FilledCustomerReportProvider reportProvider,
      bool isMobile,
      LanguageProvider languageProvider,
      ) {
    return transactions.map((transaction) {
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

      return DataRow(
        onSelectChanged: isInvoice ? (_) {
          reportProvider.toggleTransactionExpansion(transactionKey);
        } : null,
        color: isInvoice && isExpanded
            ? MaterialStateProperty.all(Color(0xFFFFB74D).withOpacity(0.1))
            : null,
        cells: [
          DataCell(Text(
            DateFormat('dd MMM yyyy').format(date),
            style: TextStyle(fontSize: isMobile ? 10 : 12),
          )),
          DataCell(Text(
            details,
            style: TextStyle(fontSize: isMobile ? 10 : 12),
          )),
          DataCell(Row(
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
                ),
              ],
            ],
          )),
          DataCell(Text(
            _getPaymentMethodText(paymentMethod, languageProvider),
            style: TextStyle(fontSize: isMobile ? 10 : 12),
          )),
          DataCell(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (bankLogoPath != null) ...[
                  Image.asset(bankLogoPath, width: 30, height: 30),
                  SizedBox(width: 8),
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
          ),
          DataCell(Text(
            (transaction['debit'] ?? 0) > 0 ? 'Rs $debit' : '-',
            style: TextStyle(
              fontSize: isMobile ? 10 : 12,
              color: (transaction['debit'] ?? 0) > 0 ? Colors.red : Colors.grey,
            ),
          )),
          DataCell(Text(
            (transaction['credit'] ?? 0) > 0 ? 'Rs $credit' : '-',
            style: TextStyle(
              fontSize: isMobile ? 10 : 12,
              color: (transaction['credit'] ?? 0) > 0 ? Colors.green : Colors.grey,
            ),
          )),
          DataCell(Text(
            'Rs $balance',
            style: TextStyle(
              fontSize: isMobile ? 10 : 12,
              fontWeight: FontWeight.bold,
            ),
          )),
        ],
      );
    }).toList();
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

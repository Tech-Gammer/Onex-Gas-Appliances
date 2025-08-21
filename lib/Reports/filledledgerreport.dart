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
  final String customerAddress;
  final String customerCity;

  const FilledLedgerReportPage({
    Key? key,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.customerCity
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
              builder: (context, provider, child) {
                return IconButton(
                  icon: Icon(Icons.print),
                  onPressed: () => _generateAndPrintPDF(provider, languageProvider),
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

              final transactions = provider.transactions;

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCustomerInfo(context, languageProvider,provider),
                      _buildDateRangeSelector(languageProvider),
                      _buildSummaryCards(report),
                      Text(
                        'No. of Entries: ${transactions.length + (provider.openingBalance != 0 ? 1 : 0)} (Filtered)',
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

  Future<void> _generateAndPrintPDF(FilledCustomerReportProvider provider, LanguageProvider languageProvider) async {
    try {
      final pdf = pw.Document();
      final openingBalance = provider.openingBalance ?? 0;
      final transactions = provider.transactions ?? [];

      // Add customer information
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Customer Ledger Report',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Customer: ${widget.customerName}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Phone: ${widget.customerPhone}'),
                        pw.Text('Address: ${widget.customerAddress}'),
                        pw.Text('City: ${widget.customerCity}'),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Date Range: ${provider.isFiltered && provider.dateRangeFilter != null
                            ? '${DateFormat('dd MMM yy').format(provider.dateRangeFilter!.start)} - ${DateFormat('dd MMM yy').format(provider.dateRangeFilter!.end)}'
                            : 'All Transactions'}'),
                        pw.Text('Generated: ${DateFormat('dd MMM yyyy hh:mm a').format(DateTime.now())}'),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              // Summary section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildPdfSummaryCard('Total Debit', provider.report['debit']?.toStringAsFixed(2) ?? '0.00'),
                  _buildPdfSummaryCard('Total Credit', provider.report['credit']?.toStringAsFixed(2) ?? '0.00'),
                  _buildPdfSummaryCard('Net Balance', provider.report['balance']?.toStringAsFixed(2) ?? '0.00'),
                ],
              ),
              pw.SizedBox(height: 20),
            ];
          },
        ),
      );

      // Add transaction table
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 1,
                child: pw.Text('Transaction Details'),
              ),
              pw.SizedBox(height: 10),
              _buildPDFTransactionTable(provider, languageProvider),
            ];
          },
        ),
      );

      // Print the PDF
      await _printPDF(pdf);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  pw.Widget _buildPdfSummaryCard(String title, String value) {
    return pw.Container(
      width: 150,
      padding: pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          pw.Text('Rs $value', style: pw.TextStyle(fontSize: 14)),
        ],
      ),
    );
  }


  pw.Widget _buildPDFTransactionTable(
      FilledCustomerReportProvider provider,
      LanguageProvider languageProvider,
      ) {
    final openingBalance = provider.openingBalance ?? 0.0;
    final transactions = provider.transactions ?? [];

    List<pw.Widget> rows = [];

    // 👉 Opening Balance row
    rows.add(
      pw.Container(
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(color: PdfColors.grey200),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              provider.openingBalanceDate != null
                  ? DateFormat('dd MMM yyyy').format(provider.openingBalanceDate!)
                  : '-',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.Text(
              languageProvider.isEnglish ? 'Opening Balance' : 'ابتدائی بیلنس',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Rs ${openingBalance.toStringAsFixed(2)}',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
          ],
        ),
      ),
    );

    // 👉 Transactions
    for (var transaction in transactions) {
      final date = DateTime.tryParse(transaction['date']?.toString() ?? '') ?? DateTime(2000);
      final details = transaction['details']?.toString() ??
          transaction['referenceNumber']?.toString() ??
          transaction['filledNumber']?.toString() ??
          '-';
      final debit = (transaction['debit'] ?? 0).toDouble();
      final credit = (transaction['credit'] ?? 0).toDouble();
      final balance = (transaction['balance'] ?? 0).toDouble();

      // Transaction row
      rows.add(
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(DateFormat('dd MMM yyyy').format(date), style: const pw.TextStyle(fontSize: 10)),
              pw.Text(details, style: const pw.TextStyle(fontSize: 10)),
              pw.Text(
                debit > 0 ? 'Rs ${debit.toStringAsFixed(2)}' : '-',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: debit > 0 ? PdfColors.red : PdfColors.black,
                ),
              ),
              pw.Text(
                credit > 0 ? 'Rs ${credit.toStringAsFixed(2)}' : '-',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: credit > 0 ? PdfColors.green800 : PdfColors.black,
                ),
              ),
              pw.Text(
                'Rs ${balance.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
            ],
          ),
        ),
      );

      // 👉 If Invoice and Expanded → Show Items
      final isInvoice = credit != 0;
      final transactionKey = transaction['key']?.toString() ?? '';
      final isExpanded = provider.expandedTransactions.contains(transactionKey);

      if (isInvoice && isExpanded) {
        final invoiceItems = provider.invoiceItems[transactionKey] ?? [];
        if (invoiceItems.isNotEmpty) {
          rows.add(
            pw.Container(
              margin: const pw.EdgeInsets.only(left: 20, top: 4, bottom: 4),
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                borderRadius: pw.BorderRadius.circular(4),
                color: PdfColors.grey100,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    languageProvider.isEnglish ? "Invoice Items" : "انوائس آئٹمز",
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.3),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(3),
                      1: const pw.FlexColumnWidth(1),
                      2: const pw.FlexColumnWidth(1),
                      3: const pw.FlexColumnWidth(1),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.orange100),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(3),
                            child: pw.Text("Item", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(3),
                            child: pw.Text("Qty", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(3),
                            child: pw.Text("Rate", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(3),
                            child: pw.Text("Total", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          ),
                        ],
                      ),
                      ...invoiceItems.map<pw.TableRow>((item) {
                        return pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(3),
                              child: pw.Text(item['itemName']?.toString() ?? '-', style: const pw.TextStyle(fontSize: 8)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(3),
                              child: pw.Text("${item['quantity']}", style: const pw.TextStyle(fontSize: 8)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(3),
                              child: pw.Text("Rs ${(item['price'] ?? 0).toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 8)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(3),
                              child: pw.Text(
                                "Rs ${(item['total'] ?? 0).toStringAsFixed(2)}",
                                style:  pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                          ],
                        );
                      }),
                      // 👉 Invoice Grand Total Row
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.green100),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(3),
                            child: pw.Text("Grand Total", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.SizedBox(),
                          pw.SizedBox(),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(3),
                            child: pw.Text(
                              "Rs ${credit.toStringAsFixed(2)}",
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
      }
    }

    return pw.Column(children: rows);
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

  Widget _buildCustomerInfo(BuildContext context, LanguageProvider languageProvider, FilledCustomerReportProvider provider) {
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
          Text(
            '${languageProvider.isEnglish ? 'Address:' : 'پتہ:'} ${widget.customerAddress}',
            style: TextStyle(color: Color(0xFFFF8A65)),
          ),
          Text(
            '${languageProvider.isEnglish ? 'City:' : 'شہر:'} ${widget.customerCity}',
            style: TextStyle(color: Color(0xFFFF8A65)),
          ),
          const SizedBox(height: 10),
          Text(
            provider.isFiltered && provider.dateRangeFilter != null
                ? '${DateFormat('dd MMM yy').format(provider.dateRangeFilter!.start)} - ${DateFormat('dd MMM yy').format(provider.dateRangeFilter!.end)}'
                : 'All Transactions',
            style: TextStyle(color: Color(0xFFFF8A65)),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeSelector(LanguageProvider languageProvider) {
    return Consumer<FilledCustomerReportProvider>(
      builder: (context, provider, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () async {
                final pickedDateRange = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                  initialDateRange: provider.dateRangeFilter,
                );
                if (pickedDateRange != null) {
                  provider.setDateRangeFilter(pickedDateRange);
                }
              },
              icon: const Icon(Icons.date_range),
              label: Text(languageProvider.isEnglish ? 'Select Date Range' : 'تاریخ منتخب کریں'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Color(0xFFFF8A65),
              ),
            ),
            if (provider.isFiltered)
              TextButton(
                onPressed: () {
                  provider.setDateRangeFilter(null);
                },
                child: Text(
                  languageProvider.isEnglish ? 'Clear Filter' : 'فلٹر صاف کریں',
                  style: const TextStyle(color: Color(0xFFFF8A65)),
                ),
              ),
          ],
        );
      },
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

  Widget _buildTransactionTable(LanguageProvider languageProvider) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Consumer<FilledCustomerReportProvider>(
      builder: (context, reportProvider, child) {
        final openingBalance = reportProvider.openingBalance ?? 0;
        final transactions = reportProvider.transactions ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
      )
  {
    final openingBalance = reportProvider.openingBalance ?? 0;

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

        // Opening Balance Row
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!),
              left: BorderSide(color: Colors.grey[300]!),
              right: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: SingleChildScrollView  (
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDataCell(
                  reportProvider.openingBalanceDate != null
                      ? DateFormat('dd MMM yyyy').format(reportProvider.openingBalanceDate!)
                      : '-',
                  120,
                  isMobile,
                ),
                _buildDataCell(
                  languageProvider.isEnglish ? 'Opening Balance' : 'ابتدائی بیلنس',
                  120,
                  isMobile,
                ),
                _buildDataCell(
                  '-',
                  100,
                  isMobile,
                ),
                _buildDataCell(
                  '-',
                  120,
                  isMobile,
                ),
                _buildDataCell(
                  '-',
                  150,
                  isMobile,
                ),
                _buildDataCell(
                  '-',
                  100,
                  isMobile,
                ),
                _buildDataCell(
                  'Rs ${openingBalance.toStringAsFixed(2)}',
                  100,
                  isMobile,
                  fontWeight: FontWeight.bold,
                  textColor: openingBalance > 0 ? Colors.green : Colors.red,
                ),
                _buildDataCell(
                  'Rs ${openingBalance.toStringAsFixed(2)}',
                  100,
                  isMobile,
                  fontWeight: FontWeight.bold,
                  textColor: openingBalance > 0 ? Colors.green : Colors.red,
                ),
              ],
            ),
          ),
        ),

        ...transactions.expand((transaction) {
          List<Widget> rowWidgets = [];

          rowWidgets.add(_buildTransactionRow(transaction, reportProvider, isMobile, languageProvider));

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
      })
  {
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
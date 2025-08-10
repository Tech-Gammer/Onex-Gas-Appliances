import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;

class CustomerReportProvider with ChangeNotifier {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  bool isLoading = false;
  String error = '';
  List<Map<String, dynamic>> transactions = [];
  Map<String, dynamic> report = {};

  Future<void> exportReportPDF() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Section
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('Moon Flex Printing', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Phone Number: 03006194719'),
                    pw.SizedBox(height: 10),
                    pw.Text('Customer Statement', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text('11 Jan 23 - 31 Dec 24'),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              // Summary Section
              pw.Container(
                padding: const pw.EdgeInsets.all(8.0),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSummaryItemPDF('Opening Balance', 'Rs 0 (Settled)'),
                    _buildSummaryItemPDF('Total Debit (-)', 'Rs ${report['debit']?.toStringAsFixed(2)}'),
                    _buildSummaryItemPDF('Total Credit (+)', 'Rs ${report['credit']?.toStringAsFixed(2)}'),
                    _buildSummaryItemPDF(
                      'Net Balance',
                      'Rs ${report['balance']?.toStringAsFixed(2)}',
                      isHighlight: true,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              // Transactions Table
              pw.Table.fromTextArray(
                headers: ['Date', 'Details', 'Debit (-)', 'Credit (+)', 'Balance'],
                data: transactions.map((transaction) {
                  return [
                    transaction['date'] ?? 'N/A',
                    transaction['details'] ?? 'N/A',
                    transaction['debit']?.toStringAsFixed(2) ?? '-',
                    transaction['credit']?.toStringAsFixed(2) ?? '-',
                    transaction['balance']?.toStringAsFixed(2) ?? '-',
                  ];
                }).toList(),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  pw.Widget _buildSummaryItemPDF(String title, String value, {bool isHighlight = false}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 12,
            color: isHighlight ? PdfColors.red : PdfColors.black,
            fontWeight: isHighlight ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Future<void> fetchCustomerReport(String customerId) async {
    try {
      isLoading = true;
      error = '';
      report = {};
      transactions = [];

      final ledgerSnapshot = await _db.child('ledger').child(customerId).get();
      if (ledgerSnapshot.exists) {
        final ledgerData = Map<String, dynamic>.from(ledgerSnapshot.value as Map<dynamic, dynamic>);

        ledgerData.forEach((key, value) {
          final debit = (value['debitAmount'] ?? 0.0).toDouble();
          final credit = (value['creditAmount'] ?? 0.0).toDouble();

          if (debit != 0.0 || credit != 0.0) {
            transactions.add({
              'id': key,
              'date': value['createdAt'],
              'invoiceNumber': value['invoiceNumber'],
              'referenceNumber': value['referenceNumber'],
              'debit': debit,
              'credit': credit,
              'paymentMethod': value['paymentMethod'], // ADD PAYMENT METHOD
              'bankName':value['bankName']
            });
          }
        });

        transactions.sort((a, b) {
          final dateA = DateTime.parse(a['date']);
          final dateB = DateTime.parse(b['date']);
          return dateA.compareTo(dateB);
        });

        double totalDebit = 0.0;
        double totalCredit = 0.0;
        double runningBalance = 0.0;

        transactions.forEach((transaction) {
          final debit = transaction['debit'] ?? 0.0;
          final credit = transaction['credit'] ?? 0.0;

          totalDebit += debit;
          totalCredit += credit;
          runningBalance += credit - debit;

          transaction['balance'] = runningBalance;
        });

        report = {
          'debit': totalDebit,
          'credit': totalCredit,
          'balance': runningBalance,
        };
      }

      isLoading = false;
      notifyListeners();
    } catch (e) {
      error = 'Failed to fetch customer report: $e';
      isLoading = false;
      notifyListeners();
    }
  }

}

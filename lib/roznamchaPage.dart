import 'dart:io';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'Provider/bankprovider.dart';
import 'Provider/expenseprovider.dart';
import 'Provider/filled provider.dart';
import 'Provider/invoice provider.dart';
import 'Provider/lanprovider.dart';
import 'Provider/purchaseprovider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class Roznamchapage extends StatefulWidget {
  const Roznamchapage({super.key});

  @override
  State<Roznamchapage> createState() => _RoznamchapageState();
}

class _RoznamchapageState extends State<Roznamchapage> {
  double _cashbookRemaining = 0.0;


  Future<void> _getCashbookRemaining() async {
    final DatabaseReference ref = FirebaseDatabase.instance.ref().child('cashbook');
    final snapshot = await ref.get();

    double cashIn = 0;
    double cashOut = 0;

    if (snapshot.exists) {
      final Map<dynamic, dynamic> values = snapshot.value as Map<dynamic, dynamic>;
      values.forEach((key, value) {
        if (value['type'] == 'cash_in') {
          cashIn += value['amount'];
        } else {
          cashOut += value['amount'];
        }
      });
    }

    setState(() {
      _cashbookRemaining = cashIn - cashOut;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCashbookRemaining();
      Provider.of<InvoiceProvider>(context, listen: false).fetchInvoices();
      Provider.of<FilledProvider>(context, listen: false).fetchFilled();
      Provider.of<ExpenseProvider>(context, listen: false).fetchExpenses();
      Provider.of<BankProvider>(context, listen: false).fetchBanks();
      Provider.of<PurchaseProvider>(context, listen: false).fetchTodaysPurchases();
    });
  }

  @override
  Widget build(BuildContext context) {
    final invoiceProvider = Provider.of<InvoiceProvider>(context);
    final todaysInvoices = invoiceProvider.getTodaysInvoices();
    final totalAmountinvoice = invoiceProvider.getTotalAmount(todaysInvoices);
    final totalPaidAmountinvoice = invoiceProvider.getTotalPaidAmount(todaysInvoices);

    final filledProvider = Provider.of<FilledProvider>(context);
    final todaysFilled = filledProvider.getTodaysFilled();
    final totalAmountfilled = filledProvider.getTotalAmountfilled(todaysFilled);
    final totalPaidAmountfilled = filledProvider.getTotalPaidAmountfilled(todaysFilled);

    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final todaysExpenses = expenseProvider.getTodaysExpenses();
    final totalExpenses = expenseProvider.getTotalExpenses(todaysExpenses);

    final purchaseProvider = Provider.of<PurchaseProvider>(context);
    final totalPurchases = purchaseProvider.totalPurchaseAmount;

    final bankProvider = Provider.of<BankProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);

    // In Roznamchapage's build method
    final totalRemainingCash = (totalPaidAmountinvoice + totalPaidAmountfilled + bankProvider.getTotalBankBalance()) -
        (totalExpenses + totalPurchases);

    return Scaffold(
      appBar: AppBar(
        title:  Text(
            // 'Roznamcha',
            languageProvider.isEnglish ? 'Roznamcha' : 'روزنامچہ',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
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
            icon: const Icon(Icons.print, color: Colors.white),
            onPressed: () async {
              await RoznamchaPDFHelper.generateAndPrintPDF(context,
                invoiceCount: todaysInvoices.length,
                totalInvoiceAmount: totalAmountinvoice,
                totalPaidInvoice: totalPaidAmountinvoice,
                remainingInvoice: totalAmountinvoice - totalPaidAmountinvoice,
                filledCount: todaysFilled.length,
                totalFilledAmount: totalAmountfilled,
                totalPaidFilled: totalPaidAmountfilled,
                remainingFilled: totalAmountfilled - totalPaidAmountfilled,
                expenseCount: todaysExpenses.length,
                totalExpenses: totalExpenses,
                bankBalance: bankProvider.getTotalBankBalance(),
                purchaseCount: purchaseProvider.totalPurchaseCount,
                totalPurchases: purchaseProvider.totalPurchaseAmount,
                cashbookRemaining: _cashbookRemaining, // Add this

              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () async {
              await RoznamchaPDFHelper.generateAndSharePDF(context,
                invoiceCount: todaysInvoices.length,
                totalInvoiceAmount: totalAmountinvoice,
                totalPaidInvoice: totalPaidAmountinvoice,
                remainingInvoice: totalAmountinvoice - totalPaidAmountinvoice,
                filledCount: todaysFilled.length,
                totalFilledAmount: totalAmountfilled,
                totalPaidFilled: totalPaidAmountfilled,
                remainingFilled: totalAmountfilled - totalPaidAmountfilled,
                expenseCount: todaysExpenses.length,
                totalExpenses: totalExpenses,
                bankBalance: bankProvider.getTotalBankBalance(),
                purchaseCount: purchaseProvider.totalPurchaseCount,
                totalPurchases: purchaseProvider.totalPurchaseAmount,
                cashbookRemaining: _cashbookRemaining, // Add this

              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Today\'s Filled'),
            _buildInfoCard(
              languageProvider.isEnglish ? 'Filled Count' : 'فلڈ کی گنتی',
              todaysFilled.length.toString(),
              Icons.inventory,
            ),
            _buildInfoCard(
              languageProvider.isEnglish ? 'Total Amount' : 'کل رقم',
              'Rs ${totalAmountfilled.toStringAsFixed(2)}',
              Icons.attach_money,
            ),
            _buildInfoCard(
              languageProvider.isEnglish ? 'Total Paid Amount' : 'کل ادا شدہ رقم',
              'Rs ${totalPaidAmountfilled.toStringAsFixed(2)}',
              Icons.payment,
            ),
            _buildInfoCard(
              languageProvider.isEnglish ? 'Remaining Amount' : 'بقایا رقم',
              'Rs ${(totalAmountfilled - totalPaidAmountfilled).toStringAsFixed(2)}',
              Icons.money_off,
              color: Colors.red,
            ),
            const Divider(),
            _buildSectionHeader('Today\'s Expenses'),
            _buildInfoCard(
              languageProvider.isEnglish ? 'Expenses Count' : 'اخراجات کا گنتی',
              todaysExpenses.length.toString(),
              Icons.money_off,
            ),
            _buildInfoCard(
              languageProvider.isEnglish ? 'Total Expenses' : 'کل اخراجات',
              'Rs ${totalExpenses.toStringAsFixed(2)}',
              Icons.attach_money,
            ),
            const Divider(),
            _buildSectionHeader('Bank Balances'),
            Consumer<BankProvider>(
              builder: (context, bankProvider, _) {
                return _buildInfoCard(
                  languageProvider.isEnglish ? 'Total Bank Balance' : 'کل بینک بیلنس',
                  'Rs ${bankProvider.getTotalBankBalance().toStringAsFixed(2)}',
                  Icons.account_balance,
                );
              },
            ),
            const Divider(),
            _buildSectionHeader('Today\'s Purchases'),
            _buildInfoCard(
              languageProvider.isEnglish ? 'Purchases Count' : 'خریداریوں کی تعداد',
              purchaseProvider.totalPurchaseCount.toString(),
              Icons.shopping_cart,
            ),
            _buildInfoCard(
              languageProvider.isEnglish ? 'Total Purchases Amount' : 'خریداری کی کل رقم',
              'Rs ${purchaseProvider.totalPurchaseAmount.toStringAsFixed(2)}',
              Icons.attach_money,
            ),
            // Add after purchases section
            const Divider(),
            _buildSectionHeader('Cashbook Balance'),
            _buildInfoCard(
              languageProvider.isEnglish ? 'Cashbook Remaining' : 'کیش بک بقایا',
              'Rs ${_cashbookRemaining.toStringAsFixed(2)}',
              Icons.account_balance_wallet,
              color: Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title,
        style:  TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.orange[300],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, {Color color = Colors.orange}) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}




class RoznamchaPDFHelper {

  static Future<void> generateAndPrintPDF(
      BuildContext context, {
        required int invoiceCount,
        required double totalInvoiceAmount,
        required double totalPaidInvoice,
        required double remainingInvoice,
        required int filledCount,
        required double totalFilledAmount,
        required double totalPaidFilled,
        required double remainingFilled,
        required int expenseCount,
        required double totalExpenses,
        required double bankBalance,
        required int purchaseCount,
        required double totalPurchases,
        required double cashbookRemaining,

      }) async {
    final pdf = pw.Document();

    // Load logo image
    final logoBytes = await rootBundle.load('assets/images/logo.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Center(
            child: pw.Image(logoImage, height: 80,dpi: 1000),
          ),
          pw.Center(
            child: pw.Text(
              'Roznamcha Report',
              style: pw.TextStyle(
                fontSize: 26,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
          ),
          pw.SizedBox(height: 5),

          // Filled Section
          _buildSectionHeader("Today's Invoices"),
          _buildDataRow("Invoices Count", filledCount.toString()),
          _buildDataRow("Total Amount", "Rs ${totalFilledAmount.toStringAsFixed(2)}"),
          _buildDataRow("Total Paid", "Rs ${totalPaidFilled.toStringAsFixed(2)}"),
          _buildDataRow("Remaining", "Rs ${remainingFilled.toStringAsFixed(2)}"),
          pw.SizedBox(height: 7),

          // Expenses Section
          _buildSectionHeader("Today's Expenses"),
          _buildDataRow("Expense Count", expenseCount.toString()),
          _buildDataRow("Total Expenses", "Rs ${totalExpenses.toStringAsFixed(2)}"),
          pw.SizedBox(height: 7),

          // Bank Balances Section
          _buildSectionHeader("Bank Balances"),
          _buildDataRow("Total Bank Balance", "Rs ${bankBalance.toStringAsFixed(2)}"),
          pw.SizedBox(height: 7),

          // Purchases Section
          _buildSectionHeader("Today's Purchases"),
          _buildDataRow("Purchase Count", purchaseCount.toString()),
          _buildDataRow("Total Purchases", "Rs ${totalPurchases.toStringAsFixed(2)}"),

          // In both PDF methods, add:
          _buildSectionHeader("Cashbook Balance"),
          _buildDataRow("Remaining Cash", "Rs ${cashbookRemaining.toStringAsFixed(2)}"),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  static Future<void> generateAndSharePDF(
      BuildContext context, {
        required int invoiceCount,
        required double totalInvoiceAmount,
        required double totalPaidInvoice,
        required double remainingInvoice,
        required int filledCount,
        required double totalFilledAmount,
        required double totalPaidFilled,
        required double remainingFilled,
        required int expenseCount,
        required double totalExpenses,
        required double bankBalance,
        required int purchaseCount,
        required double totalPurchases,
        required double cashbookRemaining,


      }) async {
    final pdf = pw.Document();

    // Load logo image
    final logoBytes = await rootBundle.load('assets/images/logo.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Center(
            child: pw.Image(logoImage, height: 60),
          ),
          pw.Center(
            child: pw.Text(
              'Roznamcha Report',
              style: pw.TextStyle(
                fontSize: 26,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
          ),
          pw.SizedBox(height: 5),

          // Filled Section
          _buildSectionHeader("Today's Invoices"),
          _buildDataRow("Filled Count", filledCount.toString()),
          _buildDataRow("Total Amount", "Rs ${totalFilledAmount.toStringAsFixed(2)}"),
          _buildDataRow("Total Paid", "Rs ${totalPaidFilled.toStringAsFixed(2)}"),
          _buildDataRow("Remaining", "Rs ${remainingFilled.toStringAsFixed(2)}"),
          pw.SizedBox(height: 15),

          // Expenses Section
          _buildSectionHeader("Today's Expenses"),
          _buildDataRow("Expense Count", expenseCount.toString()),
          _buildDataRow("Total Expenses", "Rs ${totalExpenses.toStringAsFixed(2)}"),
          pw.SizedBox(height: 15),

          // Bank Balances Section
          _buildSectionHeader("Bank Balances"),
          _buildDataRow("Total Bank Balance", "Rs ${bankBalance.toStringAsFixed(2)}"),
          pw.SizedBox(height: 15),

          // Purchases Section
          _buildSectionHeader("Today's Purchases"),
          _buildDataRow("Purchase Count", purchaseCount.toString()),
          _buildDataRow("Total Purchases", "Rs ${totalPurchases.toStringAsFixed(2)}"),


          // In both PDF methods, add:
          _buildSectionHeader("Cashbook Balance"),
          _buildDataRow("Remaining Cash", "Rs ${cashbookRemaining.toStringAsFixed(2)}"),
        ],
      ),
    );

    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/roznamcha_report.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(filePath)], text: 'Here is today\'s Roznamcha report.');
  }

  // Helper method to build section headers
  static pw.Widget _buildSectionHeader(String title) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      padding: const pw.EdgeInsets.all(8),
      margin: const pw.EdgeInsets.symmetric(vertical: 10),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 20,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blue800,
        ),
      ),
    );
  }

  // Helper method to build data rows
  static pw.Widget _buildDataRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style:  pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          value,
          style:  pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

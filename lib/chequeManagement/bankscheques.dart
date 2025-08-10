import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../Provider/lanprovider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:ui' as ui;

class BankChequesPage extends StatefulWidget {
  final String bankId;
  final String bankName;

  const BankChequesPage({
    Key? key,
    required this.bankId,
    required this.bankName,
  }) : super(key: key);

  @override
  State<BankChequesPage> createState() => _BankChequesPageState();
}

class _BankChequesPageState extends State<BankChequesPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _cheques = [];
  bool _isLoading = true;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _fetchCheques();
  }

  Future<void> _deleteCheque(String chequeId) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    try {
      // Delete from global cheques path
      await _dbRef.child('cheques/$chequeId').remove().catchError((_) {});

      // Delete from bank-specific cheques path
      await _dbRef.child('banks/${widget.bankId}/cheques/$chequeId').remove();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(languageProvider.isEnglish
              ? 'Cheque deleted successfully'
              : 'چیک کامیابی سے حذف ہو گیا'),
        ),
      );

      // Refresh the cheques list
      await _fetchCheques();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(languageProvider.isEnglish
              ? 'Failed to delete cheque: $e'
              : 'چیک حذف کرنے میں ناکام: $e'),
        ),
      );
    }
  }

  // Future<void> _fetchCheques() async {
  //   try {
  //     final snapshot =
  //     await _dbRef.child('banks/${widget.bankId}/cheques').get();
  //
  //     if (snapshot.exists) {
  //       final data = Map<String, dynamic>.from(snapshot.value as Map);
  //       _cheques = data.entries.map((entry) {
  //         return {
  //           'id': entry.key,
  //           ...Map<String, dynamic>.from(entry.value),
  //         };
  //       }).toList();
  //
  //       _cheques.sort((a, b) {
  //         final dateA = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime(2000);
  //         final dateB = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime(2000);
  //         return dateB.compareTo(dateA);
  //       });
  //     }
  //   } catch (e) {
  //     print("Error fetching cheques: $e");
  //   } finally {
  //     setState(() => _isLoading = false);
  //   }
  // }

  Future<void> _fetchCheques() async {
    try {
      final snapshot = await _dbRef.child('banks/${widget.bankId}/cheques').get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        _cheques = data.entries.map((entry) {
          return {
            'id': entry.key,
            ...Map<String, dynamic>.from(entry.value),
          };
        }).toList();

        // Filter by chequeDate if range is selected
        if (_startDate != null && _endDate != null) {
          _cheques = _cheques.where((cheque) {
            final chequeDateStr = cheque['chequeDate'];
            if (chequeDateStr == null) return false;

            final chequeDate = DateTime.tryParse(chequeDateStr);
            if (chequeDate == null) return false;

            return chequeDate.isAtSameMomentAs(_startDate!) ||
                chequeDate.isAtSameMomentAs(_endDate!) ||
                (chequeDate.isAfter(_startDate!) && chequeDate.isBefore(_endDate!));
          }).toList();
        }

        // Sort by createdAt
        _cheques.sort((a, b) {
          final dateA = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime(2000);
          final dateB = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });
      }
    } catch (e) {
      print("Error fetching cheques: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }


  // Future<void> _updateChequeStatus(String chequeId, String newStatus) async {
  //   try {
  //     DatabaseEvent chequeSnapshot = await _dbRef.child('cheques/$chequeId').once();
  //
  //     if (!chequeSnapshot.snapshot.exists) {
  //       // Fallback: Try getting from bank path
  //       chequeSnapshot = await _dbRef.child('banks/${widget.bankId}/cheques/$chequeId').once();
  //
  //       if (!chequeSnapshot.snapshot.exists) {
  //         throw Exception("Cheque not found in both global and bank paths");
  //       }
  //     }
  //
  //     final cheque = Map<String, dynamic>.from(chequeSnapshot.snapshot.value as Map);
  //     final amount = (cheque['amount'] as num?)?.toDouble() ?? 0.0;
  //
  //     final now = DateTime.now().toIso8601String();
  //
  //     // Update in global if exists
  //     _dbRef.child('cheques/$chequeId').update({
  //       'status': newStatus,
  //       'updatedAt': now,
  //     }).catchError((_) {}); // Ignore if not found
  //
  //     // Update in bank
  //     await _dbRef.child('banks/${widget.bankId}/cheques/$chequeId').update({
  //       'status': newStatus,
  //       'updatedAt': now,
  //     });
  //
  //     print("Cheque status updated");
  //     // 🔄 Refresh cheques list to update the UI
  //     await _fetchCheques();
  //   } catch (e) {
  //     print("Error updating cheque status: $e");
  //   }
  // }
  Future<void> _updateChequeStatus(String chequeId, String newStatus) async {
    try {
      final now = DateTime.now().toIso8601String();

      // Get cheque data from bank path first
      final chequeSnapshot = await _dbRef.child('banks/${widget.bankId}/cheques/$chequeId').once();
      if (!chequeSnapshot.snapshot.exists) {
        throw Exception("Cheque not found in bank path");
      }

      final cheque = Map<String, dynamic>.from(chequeSnapshot.snapshot.value as Map);
      final amount = (cheque['amount'] as num?)?.toDouble() ?? 0.0;
      final customerId = cheque['customerId'];
      final description = cheque['description'] ?? 'Cheque Payment';
      final referenceNumber = cheque['chequeNumber'] ?? '';
      final chequeDate = DateTime.tryParse(cheque['chequeDate'] ?? '') ?? DateTime.now();
      final filledId = cheque['filledId'];

      // Update status in bank cheques path
      await _dbRef.child('banks/${widget.bankId}/cheques/$chequeId').update({
        'status': newStatus,
        'updatedAt': now,
      });

      // Update status in global cheques path (if exists)
      _dbRef.child('cheques/$chequeId').update({
        'status': newStatus,
        'updatedAt': now,
      }).catchError((_) {});

      // Update status in filled/chequePayments if filledId exists
      if (filledId != null) {
        await _dbRef.child('filled/$filledId/chequePayments/$chequeId').update({
          'status': newStatus,
          'updatedAt': now,
        });
      }

      // If status is cleared
      if (newStatus == 'cleared') {
        /// 1. Update ledger if customer exists
        if (customerId != null) {
          final ledgerRef = _dbRef.child('filledledger/$customerId');
          final balanceSnapshot = await ledgerRef.orderByChild('createdAt').limitToLast(1).once();
          double lastBalance = 0.0;

          if (balanceSnapshot.snapshot.exists) {
            final data = Map<String, dynamic>.from(balanceSnapshot.snapshot.value as Map);
            final lastTransaction = data.values.last;
            lastBalance = (lastTransaction['remainingBalance'] as num?)?.toDouble() ?? 0.0;
          }

          final newBalance = lastBalance - amount;

          await ledgerRef.push().set({
            'referenceNumber': referenceNumber,
            'description': description,
            'paymentMethod': 'Cheque',
            'debitAmount': amount,
            'remainingBalance': newBalance,
            'createdAt': chequeDate.toIso8601String(),
            'bankId': widget.bankId,
            'bankName': widget.bankName,
            'chequeNumber': referenceNumber,
            'chequeDate': chequeDate.toIso8601String(),
            'status': 'cleared',
          });
        }

        /// 2. Update bank balance
        final bankBalanceRef = _dbRef.child('banks/${widget.bankId}/balance');
        final currentBankBalance = (await bankBalanceRef.get()).value as num? ?? 0.0;
        await bankBalanceRef.set(currentBankBalance + amount);

        /// 3. Update cashbook entry if exists
        final cashbookQuery = await _dbRef.child('cashbook')
            .orderByChild('chequeNumber')
            .equalTo(referenceNumber)
            .once();

        if (cashbookQuery.snapshot.exists) {
          final cashbookData = Map<String, dynamic>.from(cashbookQuery.snapshot.value as Map);
          final cashbookEntry = cashbookData.entries.first;

          await _dbRef.child('cashbook/${cashbookEntry.key}').update({
            'isHeld': false,
            'status': 'cleared',
            'clearedDate': now,
          });
        }
      }

      // Refresh cheque list
      await _fetchCheques();

    } catch (e) {
      print("Error updating cheque status: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // Future<void> _updateChequeStatus(String chequeId, String newStatus) async {
  //   try {
  //     // Get cheque data from bank path first
  //     DatabaseEvent chequeSnapshot = await _dbRef.child('banks/${widget.bankId}/cheques/$chequeId').once();
  //
  //     if (!chequeSnapshot.snapshot.exists) {
  //       throw Exception("Cheque not found in bank path");
  //     }
  //
  //     final cheque = Map<String, dynamic>.from(chequeSnapshot.snapshot.value as Map);
  //     final amount = (cheque['amount'] as num?)?.toDouble() ?? 0.0;
  //     final customerId = cheque['customerId'];
  //     final description = cheque['description'] ?? 'Cheque Payment';
  //     final referenceNumber = cheque['chequeNumber'] ?? '';
  //     final chequeDate = DateTime.tryParse(cheque['chequeDate'] ?? '') ?? DateTime.now();
  //     final now = DateTime.now().toIso8601String();
  //
  //     // Update status in both paths
  //     await _dbRef.child('banks/${widget.bankId}/cheques/$chequeId').update({
  //       'status': newStatus,
  //       'updatedAt': now,
  //     });
  //
  //     // Also update in global cheques if exists
  //     _dbRef.child('cheques/$chequeId').update({
  //       'status': newStatus,
  //       'updatedAt': now,
  //     }).catchError((_) {});
  //
  //     // If status changed to cleared, update the ledger
  //     if (newStatus == 'cleared' && customerId != null) {
  //       // Get current balance
  //       final ledgerRef = _dbRef.child('filledledger/$customerId');
  //       final balanceSnapshot = await ledgerRef.orderByChild('createdAt').limitToLast(1).once();
  //       double lastBalance = 0.0;
  //
  //       if (balanceSnapshot.snapshot.exists) {
  //         final data = Map<String, dynamic>.from(balanceSnapshot.snapshot.value as Map);
  //         final lastTransaction = data.values.last;
  //         lastBalance = (lastTransaction['remainingBalance'] as num?)?.toDouble() ?? 0.0;
  //       }
  //
  //       // Calculate new balance
  //       final newBalance = lastBalance - amount;
  //
  //       // Now update the ledger
  //       await ledgerRef.push().set({
  //         'referenceNumber': referenceNumber,
  //         'description': description,
  //         'paymentMethod': 'Cheque',
  //         'debitAmount': amount,
  //         'remainingBalance': newBalance,
  //         'createdAt': chequeDate.toIso8601String(),
  //         'bankId': widget.bankId,
  //         'bankName': widget.bankName,
  //         'chequeNumber': referenceNumber,
  //         'chequeDate': chequeDate.toIso8601String(),
  //         'status': 'cleared',
  //       });
  //
  //       // Also update the cashbook entry if it exists
  //       final cashbookQuery = await _dbRef.child('cashbook')
  //           .orderByChild('chequeNumber')
  //           .equalTo(referenceNumber)
  //           .once();
  //
  //       if (cashbookQuery.snapshot.exists) {
  //         final cashbookData = Map<String, dynamic>.from(
  //             cashbookQuery.snapshot.value as Map
  //         );
  //         final cashbookEntry = cashbookData.entries.first;
  //
  //         await _dbRef.child('cashbook/${cashbookEntry.key}').update({
  //           'isHeld': false,
  //           'status': 'cleared',
  //           'clearedDate': now,
  //         });
  //       }
  //     }
  //
  //     // Refresh cheques list
  //     await _fetchCheques();
  //   } catch (e) {
  //     print("Error updating cheque status: $e");
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Error: $e')),
  //     );
  //   }
  // }

  Future<void> _printPdf() async {
    final pdf = await _buildChequePdf();
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> _sharePdf() async {
    final pdf = await _buildChequePdf();

    try {
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/cheques_report.pdf");
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: Provider.of<LanguageProvider>(context, listen: false).isEnglish
            ? 'Cheques Report'
            : 'چیکس رپورٹ',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing PDF: $e'),
        ),
      );
    }
  }

  Future<pw.Document> _buildChequePdf() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final pdf = pw.Document();

    final headers = [
      languageProvider.isEnglish ? 'Cheque No' : 'چیک نمبر',
      languageProvider.isEnglish ? 'Amount' : 'رقم',
      languageProvider.isEnglish ? 'Customer' : 'کسٹمر',
      languageProvider.isEnglish ? 'Date' : 'تاریخ',
      languageProvider.isEnglish ? 'Cheque Date' : 'چیک کی تاریخ',
      languageProvider.isEnglish ? 'Status' : 'حالت',
    ];

    List<pw.TableRow> rows = [];

    // Header row
    rows.add(
      pw.TableRow(
        children: headers.map((header) => pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(
            header,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        )).toList(),
      ),
    );

    for (var cheque in _cheques) {
      final date = DateTime.tryParse(cheque['createdAt'] ?? '') ?? DateTime(2000);
      final chequedate = DateTime.tryParse(cheque['chequeDate'] ?? '') ?? DateTime(2000);
      final formattedDate = DateFormat('yyyy-MM-dd').format(date);
      final formattedChequeDate = DateFormat('yyyy-MM-dd').format(chequedate);

      final customerName = cheque['customerName'] ?? 'N/A';
      final customerImage = await _createTexttoImage(customerName);

      rows.add(
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(cheque['chequeNumber'] ?? 'N/A'),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text((cheque['amount'] ?? 0.0).toStringAsFixed(2)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Image(customerImage, height: 25),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(formattedDate),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(formattedChequeDate),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(cheque['status'] ?? 'pending'),
            ),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(8), // 👈 Minimal margins (can go lower if needed)
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              '${widget.bankName} ${languageProvider.isEnglish ? "Cheques Report" : "چیکس رپورٹ"}',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Table(border: pw.TableBorder.all(), children: rows),
        ],
      ),
    );

    return pdf;
  }

  Future<pw.MemoryImage> _createTexttoImage(String text) async {
    const double scaleFactor = 1.5;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromPoints(
        const Offset(0, 0),
        const Offset(500 * scaleFactor, 50 * scaleFactor),
      ),
    );

    final paint = Paint()..color = Colors.black;
    final textStyle = const TextStyle(
      fontSize: 13 * scaleFactor,
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
    final img = await picture.toImage(
      (textPainter.width * scaleFactor).toInt(),
      (textPainter.height * scaleFactor).toInt(),
    );

    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    return pw.MemoryImage(buffer);
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _isLoading = true;
      });
      await _fetchCheques();
    }
  }



  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.bankName} ${languageProvider.isEnglish ? 'Cheques' : 'چیکس'}',
          style: TextStyle(color: Colors.white),
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
          ElevatedButton.icon(
            onPressed: _printPdf,
            icon: Icon(Icons.print),
            label: Text(
              Provider.of<LanguageProvider>(context).isEnglish ? 'Print PDF' : 'پرنٹ کریں',
            ),
          ),
          ElevatedButton.icon(
            onPressed: _sharePdf,
            icon: Icon(Icons.share),
            label: Text(
              Provider.of<LanguageProvider>(context).isEnglish ? 'Share PDF' : 'شیئر کریں',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _selectDateRange(context),
                  icon: Icon(Icons.date_range),
                  label: Text(languageProvider.isEnglish
                      ? 'Filter by Cheque Date'
                      : 'چیک کی تاریخ سے فلٹر کریں'),
                ),
                if (_startDate != null && _endDate != null) ...[
                  SizedBox(width: 12),
                  Text(
                    '${DateFormat('yyyy-MM-dd').format(_startDate!)} → ${DateFormat('yyyy-MM-dd').format(_endDate!)}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                        _fetchCheques();
                      });
                    },
                    icon: Icon(Icons.clear),
                    tooltip: 'Clear Filter',
                  ),
                ]
              ],
            ),
          ),
          Expanded(
            child: _cheques.isEmpty
                ? Center(
              child: Text(languageProvider.isEnglish
                  ? 'No cheques found'
                  : 'کوئی چیکس نہیں ملے'),
            )
                : ListView.builder(
              itemCount: _cheques.length,
              itemBuilder: (context, index) {
                final cheque = _cheques[index];
                return _buildChequeCard(cheque, languageProvider);
              },
            ),
          ),
        ],
      )
      ,

    );
  }

  Widget _buildChequeCard(
      Map<String, dynamic> cheque, LanguageProvider languageProvider) {
    final date = DateTime.tryParse(cheque['createdAt'] ?? '') ?? DateTime(2000);
    final chequedate = DateTime.tryParse(cheque['chequeDate'] ?? '') ?? DateTime(2000);
    final formattedDate = DateFormat('yyyy-MM-dd – HH:mm').format(date);
    final formattedchequeDate = DateFormat('yyyy-MM-dd').format(chequedate);
    final amount = (cheque['amount'] as num?)?.toDouble() ?? 0.0;
    final status = cheque['status'] ?? 'pending';
    final customer = cheque['customerName']?? 'N/A';

    // Set color based on status
    Color statusColor;
    switch (status) {
      case 'cleared':
        statusColor = Colors.green;
        break;
      case 'bounced':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      child: ListTile(
        title: Text(cheque['chequeNumber'] ?? 'N/A'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${languageProvider.isEnglish ? "Amount" : "رقم"}: ${amount.toStringAsFixed(2)}'),
            Text('${languageProvider.isEnglish ? "Customer Name" : "کسٹمر کا نام"}: ${customer}'),
            Text('${languageProvider.isEnglish ? "Cheque Date" : "چیک کی تاریخ"}: ${formattedchequeDate}'),
            Text('${languageProvider.isEnglish ? "Date" : "تاریخ"}: $formattedDate'),
            Text(
              '${languageProvider.isEnglish ? "Status" : "حالت"}: $status',
              style: TextStyle(color: statusColor),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              onSelected: (value) => _updateChequeStatus(cheque['id'] ?? '', value),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'pending',
                  child: Text(languageProvider.isEnglish
                      ? 'Mark as Pending'
                      : 'زیر التوا کریں'),
                ),
                PopupMenuItem(
                  value: 'cleared',
                  child: Text(languageProvider.isEnglish
                      ? 'Mark as Cleared'
                      : 'کلئیرڈ کریں'),
                ),
                PopupMenuItem(
                  value: 'bounced',
                  child: Text(languageProvider.isEnglish
                      ? 'Mark as Bounced'
                      : 'باؤنسڈ کریں'),
                ),
              ],
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => _showDeleteConfirmationDialog(cheque['id']),
            ),
          ],
        )
      ),

    );
  }

  Future<void> _showDeleteConfirmationDialog(String chequeId) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    return await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(languageProvider.isEnglish ? 'Delete Cheque' : 'چیک حذف کریں'),
          content: Text(languageProvider.isEnglish
              ? 'Are you sure you want to delete this cheque?'
              : 'کیا آپ واقعی اس چیک کو حذف کرنا چاہتے ہیں؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(true);
                await _deleteCheque(chequeId);
              },
              child: Text(
                languageProvider.isEnglish ? 'Delete' : 'حذف کریں',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

}

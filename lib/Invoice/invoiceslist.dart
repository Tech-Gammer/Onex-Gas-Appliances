import 'dart:convert';
import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../Provider/lanprovider.dart';
import 'Invoicepage.dart';
import '../Provider/invoice provider.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';


class InvoiceListPage extends StatefulWidget {
  @override
  _InvoiceListPageState createState() => _InvoiceListPageState();
}

class _InvoiceListPageState extends State<InvoiceListPage> {
  TextEditingController _searchController = TextEditingController();
  final TextEditingController _paymentController = TextEditingController();
  DateTimeRange? _selectedDateRange;
  List<Map<String, dynamic>> _filteredInvoices = [];
  String? _selectedBankId;
  String? _selectedBankName;
  // Scroll controller for ListView
  final ScrollController _scrollController = ScrollController();
  // Flag to prevent multiple requests
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {}); // Trigger rebuild on text change
    });
    // Add scroll listener for pagination
    _scrollController.addListener(_scrollListener);

    // Initial data load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
      invoiceProvider.resetPagination(); // Clear any previous data
      invoiceProvider.fetchInvoices(); // Fetch first page
    });
    // print(_filteredInvoices);
  }

  // Scroll listener to detect when user reaches bottom
  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoadingMore) {
      _loadMoreData();
    }
  }

  // Load more data when user scrolls to bottom
  Future<void> _loadMoreData() async {
    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);

    if (!invoiceProvider.isLoading && invoiceProvider.hasMoreData) {
      setState(() {
        _isLoadingMore = true;
      });

      await invoiceProvider.loadMoreInvoices();

      setState(() {
        _isLoadingMore = false;
        _filteredInvoices = _filterInvoices(invoiceProvider.invoices);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invoiceProvider = Provider.of<InvoiceProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: _buildAppBar(context, languageProvider, invoiceProvider),
      body: Column(
        children: [
          SearchAndFilterSection(
            searchController: _searchController,
            selectedDateRange: _selectedDateRange,
            onDateRangeSelected: (range) {
              setState(() {
                _selectedDateRange = range;
              });

              // When date filter changes, reset pagination
              final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
              invoiceProvider.resetPagination();
              invoiceProvider.fetchInvoices();
            },
            onClearDateFilter: () {
              setState(() {
                _selectedDateRange = null;
              });

              // When date filter is cleared, reset pagination
              final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
              invoiceProvider.resetPagination();
              invoiceProvider.fetchInvoices();
            },
            languageProvider: languageProvider,
          ),
          // Invoice List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                // Refresh data by resetting pagination and fetching first page
                final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
                invoiceProvider.resetPagination();
                await invoiceProvider.fetchInvoices();
                setState(() {
                  _filteredInvoices = _filterInvoices(invoiceProvider.invoices);
                });
              },
              child: Builder(
                builder: (context) {
                  _filteredInvoices = _filterInvoices(invoiceProvider.invoices);

                  if (invoiceProvider.isLoading && _filteredInvoices.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (_filteredInvoices.isEmpty) {
                    return Center(
                      child: Text(
                        languageProvider.isEnglish ? 'No Filled Found' : 'کوئی انوائس موجود نہیں',
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: InvoiceList(
                          scrollController: _scrollController,
                          filteredInvoice: _filteredInvoices,
                          languageProvider: languageProvider,
                          invoiceProvider: invoiceProvider,
                          onInvoiceTap: (invoice) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => InvoicePage(invoice: invoice),
                              ),
                            );
                          },
                          onInvoiceLongPress: (invoice) async {
                            await _showDeleteConfirmationDialog(
                              context,
                              invoice,
                              invoiceProvider,
                              languageProvider,
                            );
                          },
                          onPaymentPressed: (invoice) {
                            _showInvoicePaymentDialog(invoice, invoiceProvider, languageProvider);
                          },
                          onViewPayments: (invoice) => _showPaymentDetails(invoice),
                        ),
                      ),

                      // Loading indicator at the bottom
                      if (invoiceProvider.isLoading && _filteredInvoices.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(
                            child: SizedBox(
                              height: 30,
                              width: 30,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),

                      // No more data indicator
                      if (!invoiceProvider.hasMoreData && _filteredInvoices.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            languageProvider.isEnglish ? 'No more records' : 'مزید ریکارڈز نہیں ہیں',
                            style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

// Add to _InvoiceListPageState
  Future<void> _showFullScreenImage(Uint8List imageBytes)
  async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.memory(imageBytes, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
  // Build AppBar
  AppBar _buildAppBar(BuildContext context, LanguageProvider languageProvider, InvoiceProvider invoiceProvider) {
    return AppBar(
      title: Text(
        languageProvider.isEnglish ? 'Invoice List' : 'انوائس لسٹ',
        style: const TextStyle(color: Colors.white),
      ),
      centerTitle: true,
      backgroundColor: Colors.teal,
      actions: [
        IconButton(
          icon: const Icon(Icons.add, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => InvoicePage()),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.print, color: Colors.white),
          onPressed: _printInvoices,
        ),
      ],
    );
  }

  // Filter invoices based on search and date range
  List<Map<String, dynamic>> _filterInvoices(List<Map<String, dynamic>> invoices) {
    return invoices.where((invoice) {
      final searchQuery = _searchController.text.toLowerCase();
      final invoiceNumber = (invoice['invoiceNumber'] ?? '').toString().toLowerCase();
      final referenceNumber = (invoice['referenceNumber'] ?? '').toString().toLowerCase();
      final customerName = (invoice['customerName'] ?? '').toString().toLowerCase();
      final matchesSearch = invoiceNumber.contains(searchQuery) || customerName.contains(searchQuery) || referenceNumber.contains(searchQuery);

      if (_selectedDateRange != null) {
        final invoiceDateStr = invoice['createdAt'];
        DateTime? invoiceDate;
        try {
          invoiceDate = DateTime.tryParse(invoiceDateStr) ?? DateTime.fromMillisecondsSinceEpoch(int.parse(invoiceDateStr));
        } catch (e) {
          print('Error parsing date: $e');
          return false;
        }
        final isInDateRange = (invoiceDate.isAfter(_selectedDateRange!.start) ||
            invoiceDate.isAtSameMomentAs(_selectedDateRange!.start)) &&
            (invoiceDate.isBefore(_selectedDateRange!.end) ||
                invoiceDate.isAtSameMomentAs(_selectedDateRange!.end));
        return matchesSearch && isInDateRange;
      }
      return matchesSearch;
    }).toList();
  }

  // Show delete confirmation dialog
  Future<void> _showDeleteConfirmationDialog(
      BuildContext context,
      Map<String, dynamic> invoice,
      InvoiceProvider invoiceProvider,
      LanguageProvider languageProvider,
      )
  async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(languageProvider.isEnglish ? 'Delete Invoice' : 'انوائس ڈلیٹ کریں'),
          content: Text(languageProvider.isEnglish
              ? 'Are you sure you want to delete this invoice?'
              : 'کیاآپ واقعی اس انوائس کو ڈیلیٹ کرنا چاہتے ہیں'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(languageProvider.isEnglish ? 'Cancel' : 'ردکریں'),
            ),
            TextButton(
              onPressed: () async {
                await invoiceProvider.deleteInvoice(invoice['id']);
                Navigator.of(context).pop();
              },
              child: Text(languageProvider.isEnglish ? 'Delete' : 'ڈیلیٹ کریں'),
            ),
          ],
        );
      },
    );
  }

  double _parseToDouble(dynamic value) {
    if (value is int) {
      return value.toDouble();
    } else if (value is double) {
      return value;
    } else if (value is String) {
      return double.tryParse(value) ?? 0.0;
    } else {
      return 0.0;
    }
  }

  DateTime _parsePaymentDate(dynamic date) {
    if (date is String) {
      // If the date is a string, try parsing it directly
      return DateTime.tryParse(date) ?? DateTime.now();
    } else if (date is int) {
      // If the date is a timestamp (in milliseconds), convert it to DateTime
      return DateTime.fromMillisecondsSinceEpoch(date);
    } else if (date is DateTime) {
      // If the date is already a DateTime object, return it directly
      return date;
    } else {
      // Fallback to the current date if the format is unknown
      return DateTime.now();
    }
  }

  // Add to _InvoiceListPageState
  Future<void> _showPaymentDetails(Map<String, dynamic> invoice) async {
    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    try {
      final payments = await invoiceProvider.getInvoicePayments(invoice['id']);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(languageProvider.isEnglish ? 'Payment History' : 'ادائیگی کی تاریخ'),
          content: Container(
            width: double.maxFinite,
            child: payments.isEmpty
                ? Text(languageProvider.isEnglish
                ? 'No payments found'
                : 'کوئی ادائیگی نہیں ملی')
                : ListView.builder(
              shrinkWrap: true,
              itemCount: payments.length,
              itemBuilder: (context, index) {
                final payment = payments[index];
                Uint8List? imageBytes;
                if (payment['image'] != null) {
                  imageBytes = base64Decode(payment['image']);
                }

                return Card(
                  child: ListTile(
                    title: Text(
                      '${payment['method'] == 'Bank'
                          ? '${payment['bankName'] ?? 'Bank'}'
                          : payment['method']}: Rs ${payment['amount']}',
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Text(DateFormat('yyyy-MM-dd – HH:mm')
                        //     .format(payment['date'])),
                        // In payment history list
                        Text(DateFormat('yyyy-MM-dd – HH:mm')
                            .format(payment['date'])),
                        if (payment['description'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(payment['description']),
                          ),
                        if (imageBytes != null)
                          Column(
                            children: [
                              GestureDetector(
                                onTap: () => _showFullScreenImage(imageBytes!),
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Hero(
                                    tag: 'paymentImage$index',
                                    child: Image.memory(
                                      imageBytes,
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => _showFullScreenImage(imageBytes!),
                                child: Text(
                                  Provider.of<LanguageProvider>(context, listen: false)
                                      .isEnglish
                                      ? 'View Full Image'
                                      : 'مکمل تصویر دیکھیں',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // IconButton(
                        //   icon: Icon(Icons.edit),
                        //   onPressed: () => _showEditPaymentDialog(
                        //     context,
                        //     invoice['id'],
                        //     payment['key'], // Ensure the payment key is passed
                        //     payment['method'],
                        //     payment['amount'],
                        //     payment['description'],
                        //     imageBytes,
                        //     _pickImage, // Pass the _pickImage function
                        //   ),
                        // ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _showDeletePaymentConfirmationDialog(
                            context,
                            invoice['id'],
                            payment['key'], // Ensure the payment key is passed
                            payment['method'],
                            payment['amount'],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => _printPaymentHistoryPDF(payments, context),
              child: Text(languageProvider.isEnglish ? 'Print Payment History' : 'ادائیگی کی تاریخ پرنٹ کریں'),
            ),
            TextButton(
              child: Text(languageProvider.isEnglish ? 'Close' : 'بند کریں'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading payments: ${e.toString()}')),
      );
    }
  }  // Print invoices

  Future<void> _printPaymentHistoryPDF(List<Map<String, dynamic>> payments, BuildContext context) async {
    final pdf = pw.Document();
    // Load the image asset for the logo
    final ByteData bytes = await rootBundle.load('assets/images/logo.png');
    final buffer = bytes.buffer.asUint8List();
    final image = pw.MemoryImage(buffer);

    // Load the footer logo if different
    final ByteData footerBytes = await rootBundle.load('assets/images/devlogo.png');
    final footerBuffer = footerBytes.buffer.asUint8List();
    final footerLogo = pw.MemoryImage(footerBuffer);
    // Generate all description images asynchronously
    final List<List<dynamic>> tableData = await Future.wait(
      payments.map((payment) async {
        final paymentAmount = _parseToDouble(payment['amount']);
        final paymentDate = _parsePaymentDate(payment['date']);
        final description = payment['description'] ?? 'N/A';
        // DateFormat('yyyy-MM-dd – HH:mm').format(paymentDate);

        // Generate image from description text
        final descriptionImage = await _createTextImage(description);

        return [
          payment['method'],
          'Rs ${paymentAmount.toStringAsFixed(2)}',
          DateFormat('yyyy-MM-dd – HH:mm').format(paymentDate),
          pw.Image(descriptionImage), // Use the generated image
        ];
      }),
    );

    // Add a multi-page layout to handle multiple payments
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) => [
          // Header section
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(image, width: 80, height: 80), // Adjust logo size
              pw.Text('Payment History',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ],
          ),

          // Table with payment history
          pw.Table.fromTextArray(
            headers: ['Method', 'Amount', 'Date', 'Description'],
            // data: tableData,
            data: payments.map((payment) {
              return [
                payment['method'] == 'Bank'
                    ? 'Bank: ${payment['bankName'] ?? 'Bank'}'
                    : payment['method'],
                'Rs ${_parseToDouble(payment['amount']).toStringAsFixed(2)}',
                DateFormat('yyyy-MM-dd – HH:mm').format(_parsePaymentDate(payment['date'])),
                payment['description'] ?? 'N/A',
              ];
            }).toList(),
            border: pw.TableBorder.all(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 14, // Increased header font size
            ),
            cellStyle: const pw.TextStyle(
              fontSize: 12, // Increased cell font size from 10 to 12
            ),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.all(6),
          ),

          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.Spacer(),
          // Footer section
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(footerLogo, width: 20, height: 20), // Footer logo
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'Dev Valley Software House',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Contact: 0303-4889663',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
          ),
        ],
      ),
    );

    // Print the PDF
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Future<void> _printInvoices() async {
    final pdf = pw.Document();
    final headers = ['Invoice Number', 'Customer Name', 'Date', 'Grand Total', 'Remaining Amount'];
    final List<List<dynamic>> tableData = [];

    for (var invoice in _filteredInvoices) {
      final customerName = invoice['customerName'] ?? 'N/A';
      final customerNameImage = await _createTextImage(customerName);
      tableData.add([
        invoice['invoiceNumber'] ?? 'N/A',
        pw.Image(customerNameImage),
        invoice['createdAt'] ?? 'N/A',
        'Rs ${invoice['grandTotal']}',
        'Rs ${(invoice['grandTotal'] - invoice['debitAmount']).toStringAsFixed(2)}',
      ]);
    }

    // Load the image asset for the logo
    final ByteData bytes = await rootBundle.load('assets/images/logo.png');
    final buffer = bytes.buffer.asUint8List();
    final image = pw.MemoryImage(buffer);

    final ByteData footerBytes = await rootBundle.load('assets/images/devlogo.png');
    final footerBuffer = footerBytes.buffer.asUint8List();
    final footerLogo = pw.MemoryImage(footerBuffer);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(15), // Reduced margins for more content space
        header: (pw.Context context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Invoice List',
              style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
            ),
            pw.Column(
              children: [
                pw.Image(image, width: 70, height: 70, dpi: 1000), // Display the logo at the top
                pw.SizedBox(height: 10)
              ],
            )
          ],
        ),
        footer: (pw.Context context) => pw.Column(
          children: [
            pw.Divider(), // Adds a horizontal line above the footer content
            pw.SizedBox(height: 5), // Adds spacing between divider and footer content
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Image(footerLogo, width: 30, height: 30),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Dev Valley Software House',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'Contact: 0303-4889663',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        build: (pw.Context context) => [
          pw.Table.fromTextArray(
            headers: headers,
            data: tableData,
            border: pw.TableBorder.all(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.all(5), // Reduced cell padding
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
  // Create text image for PDF
  Future<pw.MemoryImage> _createTextImage(String text) async {
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
    const textStyle = TextStyle(
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

  Future<Uint8List?> _pickImage(BuildContext context) async {
    Uint8List? imageBytes;
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    if (kIsWeb) {
      // For web, use file_picker
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        imageBytes = result.files.first.bytes;
      }
    } else {
      // For mobile, show source selection dialog
      final ImagePicker _picker = ImagePicker();

      // Show dialog to choose camera or gallery
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(languageProvider.isEnglish ? 'Select Source' : 'ذریعہ منتخب کریں'),
          actions: [
            TextButton(
              child: Text(languageProvider.isEnglish ? 'Camera' : 'کیمرہ'),
              onPressed: () => Navigator.pop(context, ImageSource.camera),
            ),
            TextButton(
              child: Text(languageProvider.isEnglish ? 'Gallery' : 'گیلری'),
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      );

      if (source == null) return null; // User canceled

      XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        imageBytes = await file.readAsBytes();
      }
    }

    return imageBytes;
  }

  Future<void> _showInvoicePaymentDialog(
      Map<String, dynamic> invoice,
      InvoiceProvider invoiceProvider,
      LanguageProvider languageProvider,
      )
  async {
    String? selectedPaymentMethod;
    _paymentController.clear();
    bool _isPaymentButtonPressed = false;
    String? _description;
    Uint8List? _imageBytes;
    DateTime _selectedPaymentDate = DateTime.now();
    // Move these inside the dialog state
    String? _selectedBankId;
    String? _selectedBankName;

    Future<void> _selectBank(BuildContext context) async {
      final bankSnapshot = await FirebaseDatabase.instance.ref('banks').once();

      if (bankSnapshot.snapshot.value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(languageProvider.isEnglish
              ? 'No banks available'
              : 'کوئی بینک دستیاب نہیں')),
        );
        return;
      }

      final banks = bankSnapshot.snapshot.value as Map<dynamic, dynamic>;
      final bankList = banks.entries.map((e) {
        return {
          'id': e.key,
          'name': e.value['name'],
          'balance': e.value['balance'],
        };
      }).toList();

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(languageProvider.isEnglish ? 'Select Bank' : 'بینک منتخب کریں'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: bankList.length,
              itemBuilder: (context, index) {
                final bank = bankList[index];
                return ListTile(
                  title: Text(bank['name']),
                  subtitle: Text('${bank['balance']} Rs'),
                  onTap: () {
                    setState(() {
                      _selectedBankId = bank['id'];
                      _selectedBankName = bank['name'];
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ),
      );
    }


    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(languageProvider.isEnglish ? 'Pay Invoice' : 'انوائس کی رقم ادا کریں'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Add this widget to the payment dialog content
                    ListTile(
                      title: Text(languageProvider.isEnglish
                          ? 'Payment Date: ${DateFormat('yyyy-MM-dd – HH:mm').format(_selectedPaymentDate)}'
                          : 'ادائیگی کی تاریخ: ${DateFormat('yyyy-MM-dd – HH:mm').format(_selectedPaymentDate)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _selectedPaymentDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (pickedDate != null) {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_selectedPaymentDate),
                          );
                          if (pickedTime != null) {
                            setState(() {
                              _selectedPaymentDate = DateTime(
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
                    ),
                    DropdownButtonFormField<String>(
                      value: selectedPaymentMethod,
                      items: [
                        DropdownMenuItem(
                          value: 'Cash',
                          child: Text(languageProvider.isEnglish ? 'Cash' : 'نقدی'),
                        ),
                        DropdownMenuItem(
                          value: 'Online',
                          child: Text(languageProvider.isEnglish ? 'Online' : 'آن لائن'),
                        ),
                        DropdownMenuItem(
                          value: 'Check',
                          child: Text(languageProvider.isEnglish ? 'Check' : 'چیک'),
                        ),
                        DropdownMenuItem(
                          value: 'Bank',
                          child: Text(languageProvider.isEnglish ? 'Bank' : 'بینک'),
                        ),
                        DropdownMenuItem(
                          value: 'Slip',
                          child: Text(languageProvider.isEnglish ? 'Slip' : 'پرچی'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedPaymentMethod = value;
                          if (value != 'Bank') {
                            _selectedBankId = null;
                            _selectedBankName = null;
                          }
                        });
                      },
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish ? 'Select Payment Method' : 'ادائیگی کا طریقہ منتخب کریں',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    // Bank selection UI
                    if (selectedPaymentMethod == 'Bank')
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Card(
                          child: ListTile(
                            title: Text(_selectedBankName ??
                                (languageProvider.isEnglish
                                    ? 'Select Bank'
                                    : 'بینک منتخب کریں')),
                            trailing: const Icon(Icons.arrow_drop_down),
                            onTap: () => _selectBank(context),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _paymentController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish ? 'Enter Payment Amount' : 'رقم لکھیں',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (value) {
                        setState(() {
                          _description = value;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish ? 'Description' : 'تفصیل',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        Uint8List? imageBytes = await _pickImage(context);
                        if (imageBytes != null && imageBytes.isNotEmpty) {
                          print('Image selected with ${imageBytes.length} bytes'); // Debug log
                          setState(() {
                            _imageBytes = imageBytes;
                          });
                        } else {
                          print('No image selected or empty bytes'); // Debug log
                        }
                      },
                      child: Text(languageProvider.isEnglish ? 'Pick Image' : 'تصویر اپ لوڈ کریں'),
                    ),
                    // Display selected image
                    if (_imageBytes != null)
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        height: 100,
                        width: 100,
                        child: Image.memory(_imageBytes!), // Changed from DecorationImage to Image.memory
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(languageProvider.isEnglish ? 'Cancel' : 'انکار'),
                ),
                TextButton(
                  onPressed: _isPaymentButtonPressed
                      ? null
                      : () async {
                    setState(() {
                      _isPaymentButtonPressed = true;
                    });

                    if (selectedPaymentMethod == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(languageProvider.isEnglish
                              ? 'Please select a payment method.'
                              : 'براہ کرم ادائیگی کا طریقہ منتخب کریں۔'),
                        ),
                      );
                      setState(() {
                        _isPaymentButtonPressed = false;
                      });
                      return;
                    }

                    final amount = double.tryParse(_paymentController.text);
                    if (amount != null && amount > 0) {
                      await invoiceProvider.payInvoiceWithSeparateMethod(
                        context,
                        invoice['id'],
                        amount,
                        selectedPaymentMethod!,
                        description: _description,
                        imageBytes: _imageBytes,
                        paymentDate: _selectedPaymentDate, // Pass selected date
                        bankId: _selectedBankId,
                        bankName: _selectedBankName,
                      );
                      Navigator.of(context).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(languageProvider.isEnglish
                              ? 'Please enter a valid payment amount.'
                              : 'براہ کرم ایک درست رقم درج کریں۔'),
                        ),
                      );
                    }

                    setState(() {
                      _isPaymentButtonPressed = false;
                    });
                  },
                  child: Text(languageProvider.isEnglish ? 'Pay' : 'رقم ادا کریں'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

Future<void> _showDeletePaymentConfirmationDialog(
    BuildContext context,
    String invoiceId,
    String paymentKey,
    String paymentMethod,
    double paymentAmount,
    )
async {
  final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

  await showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(languageProvider.isEnglish ? 'Delete Payment' : 'ادائیگی ڈیلیٹ کریں'),
        content: Text(languageProvider.isEnglish
            ? 'Are you sure you want to delete this payment?'
            : 'کیا آپ واقعی اس ادائیگی کو ڈیلیٹ کرنا چاہتے ہیں؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(languageProvider.isEnglish ? 'Cancel' : 'رد کریں'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await Provider.of<InvoiceProvider>(context, listen: false).deletePaymentEntry(
                  context: context, // Pass the context here
                  invoiceId: invoiceId,
                  paymentKey: paymentKey,
                  paymentMethod: paymentMethod,
                  paymentAmount: paymentAmount,
                );
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment deleted successfully.')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete payment: ${e.toString()}')),
                );
              }
            },
            child: Text(languageProvider.isEnglish ? 'Delete' : 'ڈیلیٹ کریں'),
          ),
        ],
      );
    },
  );
}

class InvoiceList extends StatelessWidget {
  final ScrollController scrollController;
  final List<Map<String, dynamic>> filteredInvoice;
  final LanguageProvider languageProvider;
  final InvoiceProvider invoiceProvider;
  final Function(Map<String, dynamic>) onInvoiceTap;
  final Function(Map<String, dynamic>) onInvoiceLongPress;
  final Function(Map<String, dynamic>) onPaymentPressed;
  final Function(Map<String, dynamic>) onViewPayments;

  const InvoiceList({
    required this.scrollController,
    required this.filteredInvoice,
    required this.languageProvider,
    required this.invoiceProvider,
    required this.onInvoiceTap,
    required this.onInvoiceLongPress,
    required this.onPaymentPressed,
    required this.onViewPayments,

  });

  @override
  Widget build(BuildContext context) {

    // Add this helper method to calculate total weight
    String _getTotalWeight(List<dynamic> items) {
      double totalWeight = 0.0;
      for (var item in items) {
        totalWeight += (item['weight'] ?? 0.0).toDouble();
      }
      return totalWeight.toStringAsFixed(2);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWideScreen = constraints.maxWidth > 600;

        return ListView.builder(
          controller: scrollController, // Use the scroll controller for pagination
          itemCount: filteredInvoice.length,
          itemBuilder: (context, index) {
            final invoice = Map<String, dynamic>.from(filteredInvoice[index]);

            // Instead of casting directly, use:
            double grandTotal = (invoice['grandTotal'] ?? 0.0).toDouble();
            double debitAmount = (invoice['debitAmount'] ?? 0.0).toDouble();
            final remainingAmount = (grandTotal - debitAmount).toDouble();

            return Card(
              margin: EdgeInsets.symmetric(
                horizontal: isWideScreen ? 16.0 : 8.0,
                vertical: 4.0,
              ),
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                contentPadding: const EdgeInsets.all(8),
                title: Text(
                  '${languageProvider.isEnglish ? 'Invoice #' : 'انوائس نمبر'} ${invoice['referenceNumber']} ${invoice['numberType'] == 'timestamp' ? '(Legacy)' : ''}',
                  style: TextStyle(
                    fontSize: isWideScreen ? 18 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      '${languageProvider.isEnglish ? 'Customer' : 'کسٹمر'} ${invoice['customerName']}',
                      style: TextStyle(
                        fontSize: isWideScreen ? 16 : 14,
                      ),
                    ),
                    Text(
                      '${languageProvider.isEnglish ? 'Date' : 'تاریخ'}: ${invoice['createdAt']}',
                      style: TextStyle(
                        fontSize: isWideScreen ? 14 : 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    // Add this new Text widget to show the weight
                    Text(
                      '${languageProvider.isEnglish ? 'Weight' : 'وزن'}: ${_getTotalWeight(invoice['items'])}',
                      style: TextStyle(
                        fontSize: isWideScreen ? 14 : 12,
                      ),
                    ),
                    Text(
                      '${languageProvider.isEnglish ? 'Invoice #' : 'انوائس نمبر'} ${invoice['invoiceNumber']} ${invoice['numberType'] == 'timestamp' ? '(Legacy)' : ''}',
                      style: const TextStyle(
                        fontSize:12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${languageProvider.isEnglish ? 'Rs ' : ''}${grandTotal.toStringAsFixed(2)}${languageProvider.isEnglish ? '' : ' روپے'}',
                      style: TextStyle(
                        fontSize: isWideScreen ? 16 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${languageProvider.isEnglish ? 'Remaining: ' : 'بقیہ: '}${remainingAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: isWideScreen ? 14 : 12,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                onTap: () => onInvoiceTap(invoice),
                onLongPress: () => onInvoiceLongPress(invoice),
              ),
            );
          },
        );
      },
    );
  }
}

class SearchAndFilterSection extends StatelessWidget {
  final TextEditingController searchController;
  final DateTimeRange? selectedDateRange;
  final Function(DateTimeRange?) onDateRangeSelected;
  final VoidCallback onClearDateFilter;
  final LanguageProvider languageProvider;

  const SearchAndFilterSection({
    required this.searchController,
    required this.selectedDateRange,
    required this.onDateRangeSelected,
    required this.onClearDateFilter,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              labelText: languageProvider.isEnglish
                  ? 'Search by Invoice ID or Customer Name'
                  : 'انوائس آئی ڈی یا کسٹمر کے نام سے تلاش کریں',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => searchController.clear(),
              )
                  : null,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: ElevatedButton.icon(
            onPressed: () async {
              DateTimeRange? pickedDateRange = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2000),
                lastDate: DateTime(2101),
                initialDateRange: selectedDateRange,
              );
              if (pickedDateRange != null) {
                onDateRangeSelected(pickedDateRange);
              }
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white, backgroundColor: Colors.teal.shade400,
            ),
            icon: const Icon(Icons.date_range, color: Colors.white),
            label: Text(
              selectedDateRange == null
                  ? languageProvider.isEnglish ? 'Select Date' : 'ڈیٹ منتخب کریں'
                  : 'From: ${DateFormat('yyyy-MM-dd').format(selectedDateRange!.start)} - To: ${DateFormat('yyyy-MM-dd').format(selectedDateRange!.end)}',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: onClearDateFilter,
                child: Text(languageProvider.isEnglish ? 'Clear Date Filter' : 'انوائس لسٹ کا فلٹر ختم کریں'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white, backgroundColor: Colors.teal.shade400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


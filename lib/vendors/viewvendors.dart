import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import '../Provider/lanprovider.dart';
import '../bankmanagement/banknames.dart';
import 'addvendors.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'ledgerpage.dart';
import 'dart:convert';
import 'dart:ui' as ui;


class ViewVendorsPage extends StatefulWidget {
  const ViewVendorsPage({super.key});

  @override
  State<ViewVendorsPage> createState() => _ViewVendorsPageState();
}

class _ViewVendorsPageState extends State<ViewVendorsPage> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref("vendors");
  List<Map<String, dynamic>> _vendors = [];
  List<Map<String, dynamic>> _filteredVendors = [];
  bool _isLoading = true;
  TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _cachedBanks = [];

  @override
  void initState() {
    super.initState();
    _fetchVendors();
    _searchController.addListener(_filterVendors);
  }

  void _fetchVendors() {
    _databaseRef.onValue.listen((event) async {
      if (!mounted) return;

      final data = event.snapshot.value;

      if (data == null) {
        setState(() {
          _vendors = [];
          _filteredVendors = [];
          _isLoading = false;
        });
        return;
      }

      if (data is! Map<dynamic, dynamic>) {
        setState(() {
          _vendors = [];
          _filteredVendors = [];
          _isLoading = false;
        });
        return;
      }

      final List<Map<String, dynamic>> vendors = [];

      for (final entry in (data as Map<dynamic, dynamic>).entries) {
        // Get all payments for this vendor
        final paymentsSnapshot = await FirebaseDatabase.instance
            .ref('vendors/${entry.key}/payments')
            .get();

        double actualPaidAmount = 0.0;

        if (paymentsSnapshot.value != null) {
          final payments = paymentsSnapshot.value as Map<dynamic, dynamic>;

          // Calculate actual paid amount excluding pending cheques
          for (final payment in payments.values) {
            if (payment['method'] != 'Cheque' ||
                (payment['method'] == 'Cheque' && payment['status'] == 'cleared')) {
              actualPaidAmount += (payment['amount'] ?? 0.0).toDouble();
            }
          }
        }

        vendors.add({
          "id": entry.key.toString(),
          "name": entry.value["name"] ?? "Unknown Vendor",
          "paidAmount": actualPaidAmount,
          "openingBalance": (entry.value["openingBalance"] ?? 0.0).toDouble(),
          "openingBalanceDate": entry.value["openingBalanceDate"] ?? "Unknown Date",
          "description": entry.value["description"] ?? "",
        });
      }

      setState(() {
        _vendors = vendors;
        _filteredVendors = vendors;
        _isLoading = false;
      });
    }, onError: (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching vendors: $error')),
      );
    });
  }

  void _filterVendors() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredVendors = _vendors
          .where((vendor) =>
          vendor["name"].toLowerCase().contains(query)) // Filter by vendor name
          .toList();
    });
  }

  void _confirmDelete(String id) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(languageProvider.isEnglish
              ? "Confirm Delete"
              : "حذف کرنے کی تصدیق کریں"),
          content: Text(languageProvider.isEnglish
              ? "Are you sure you want to delete this vendor?"
              : "کیا آپ واقعی یہ فروش حذف کرنا چاہتے ہیں؟"),
          actions: <Widget>[
            TextButton(
              child: Text(languageProvider.isEnglish ? "Cancel" : "منسوخ کریں",
                  style: TextStyle(color: Colors.teal)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(languageProvider.isEnglish ? "Delete" : "حذف کریں",
                  style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _deleteVendor(id); // Proceed with deletion
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteVendor(String id) async {
    try {
      await _databaseRef.child(id).remove();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vendor deleted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting vendor: $e')),
      );
    }
  }

  void _editVendor(String id, String name) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    // Implement your edit vendor functionality here
    // This would navigate to the edit vendor page or pop-up dialog to edit the name
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController _editController = TextEditingController(text: name);
        return AlertDialog(
          title:  Text(
            languageProvider.isEnglish ? 'Edit Vendor' : 'وینڈر میں ترمیم کریں',
          ),
          content: TextField(
            controller: _editController,
            decoration:  InputDecoration(
              hintText: languageProvider.isEnglish ? 'Enter a new vendor name' : 'ایک نیا وینڈر کا نام درج کریں',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                String newName = _editController.text.trim();
                if (newName.isNotEmpty) {
                  _databaseRef.child(id).update({'name': newName});
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(
                      languageProvider.isEnglish ? 'Vendor updated successfully!' : 'وینڈر کامیابی کے ساتھ اپ ڈیٹ ہو گیا!',
                    )),
                  );
                }
              },
              child:  Text(
                languageProvider.isEnglish ? 'Save' : 'محفوظ کریں۔',
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:  Text(
                languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں۔',
              ),
            ),
          ],
        );
      },
    );
  }


  Future<String?> _pickImage() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final ImagePicker _picker = ImagePicker();
    Uint8List? imageBytes;

    // Show source selection dialog
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

    if (source == null) return null;

    // Capture image
    XFile? pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 50, // Reduce quality for compression
      maxWidth: 800,    // Limit dimensions
      maxHeight: 800,
    );

    if (pickedFile != null) {
      // Compress and convert to Base64
      imageBytes = await pickedFile.readAsBytes();
      return await _compressAndConvertToBase64(imageBytes);
    }
    return null;
  }

  Future<String> _compressAndConvertToBase64(Uint8List imageBytes) async {
    // First compression pass
    final codec = await ui.instantiateImageCodec(
      imageBytes,
      targetWidth: 400, // Further reduce size
      targetHeight: 400,
    );

    final frame = await codec.getNextFrame();
    final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);

    // Convert to Base64
    return base64Encode(byteData!.buffer.asUint8List());
  }


  Future<pw.MemoryImage> _createTextImage(String text) async {
    // Use default text for empty input
    final String displayText = text.isEmpty ? "N/A" : text;

    // Scale factor to increase resolution
    const double scaleFactor = 1.5;

    // Create a custom painter with the Urdu text
    final recorder = PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromPoints(
        Offset(0, 0),
        Offset(500 * scaleFactor, 50 * scaleFactor),
      ),
    );

    // Define text style with scaling
    final textStyle = TextStyle(
      fontSize: 12 * scaleFactor,
      fontFamily: 'JameelNoori', // Ensure this font is registered
      color: Colors.black,
      fontWeight: FontWeight.bold,
    );

    // Create the text span and text painter
    final textSpan = TextSpan(text: displayText, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.left, // Adjust as needed for alignment
      textDirection: TextDirection.rtl, // Use RTL for Urdu text
    );

    // Layout the text painter
    textPainter.layout();

    // Validate dimensions
    final double width = textPainter.width * scaleFactor;
    final double height = textPainter.height * scaleFactor;

    if (width <= 0 || height <= 0) {
      throw Exception("Invalid text dimensions: width=$width, height=$height");
    }

    // Paint the text onto the canvas
    textPainter.paint(canvas, Offset(0, 0));

    // Create an image from the canvas
    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());

    // Convert the image to PNG
    final byteData = await img.toByteData(format: ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    // Return the image as a MemoryImage
    return pw.MemoryImage(buffer);
  }

  Future<void> _generatePDF() async {
    final pdf = pw.Document();
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    // Generate images for vendor names
    final List<pw.MemoryImage> vendorNameImages = [];
    for (final vendor in _filteredVendors) {
      final image = await _createTextImage(vendor["name"]);
      vendorNameImages.add(image);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Text(
                languageProvider.isEnglish ? 'Vendors List' : 'فروشوں کی فہرست',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 30),
            ...List.generate(_filteredVendors.length, (index) {
              final vendor = _filteredVendors[index];
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Image(vendorNameImages[index]),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    '${languageProvider.isEnglish ? 'Opening Balance' : 'اوپننگ بیلنس'}: '
                        '${vendor["openingBalance"].toStringAsFixed(2)} Rs',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.Text(
                    '${languageProvider.isEnglish ? 'Opening Date' : 'تاریخ افتتاح'}: '
                        '${vendor["openingBalanceDate"]}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.Text(
                    '${languageProvider.isEnglish ? 'Paid Amount' : 'ادا شدہ رقم'}: '
                        '${vendor["paidAmount"].toStringAsFixed(2)} Rs',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Divider(),
                ],
              );
            }),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }


  void _showPaymentHistory(String vendorId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentHistoryPage(vendorId: vendorId),
      ),
    );
  }

  void _editOpeningBalance(String vendorId, double currentBalance) {
    TextEditingController _balanceController = TextEditingController(text: currentBalance.toString());
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:  Text(
              languageProvider.isEnglish ? 'Edit Opening Balance' : 'اوپننگ بیلنس میں ترمیم کریں۔'
          ),
          content: TextField(
            controller: _balanceController,
            keyboardType: TextInputType.number,
            decoration:  InputDecoration(
              labelText: languageProvider.isEnglish ? 'New Opening Balance' : 'نیا اوپننگ بیلنس'
              ,
              prefixIcon: Icon(Icons.account_balance),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                double newBalance = double.tryParse(_balanceController.text.trim()) ?? 0.0;

                if (newBalance >= 0) {
                  String currentDate = DateTime.now().toString(); // Capture current date
                  _databaseRef.child(vendorId).update({
                    'openingBalance': newBalance,
                    'openingBalanceDate': currentDate, // Save date in Firebase
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(
                        languageProvider.isEnglish ? 'Opening balance updated successfully!' : 'اوپننگ بیلنس کامیابی کے ساتھ اپ ڈیٹ ہو گیا!'
                    )),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(
                        languageProvider.isEnglish ? 'Please enter a valid balance.' : 'براہ کرم ایک درست بیلنس درج کریں۔'
                    )),
                  );
                }
              },
              child:  Text(
                  languageProvider.isEnglish ? 'Save' : 'محفوظ کریں۔'
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:  Text(
                  languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں۔'
              ),
            ),
          ],
        );
      },
    );
  }


  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                margin: EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Image.asset(
                    matchedBank.iconPath,
                    width: 40,
                    height: 40,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.account_balance, size: 40);
                    },
                  ),
                  title: Text(
                    bankName,
                    style: TextStyle(fontWeight: FontWeight.bold),
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

  void _payVendor(String vendorId, String vendorName) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final DatabaseReference vendorRef = FirebaseDatabase.instance.ref('vendors/$vendorId');

    // Variables for payment details
    String? selectedPaymentMethod;
    double paymentAmount = 0.0;
    String? description;
    Uint8List? imageBytes;
    DateTime paymentDate = DateTime.now();
    String? bankId;
    String? bankName;
    String? chequeNumber;
    DateTime? chequeDate;
    String? chequeBankId;
    String? chequeBankName;

    // Controllers
    TextEditingController amountController = TextEditingController();
    TextEditingController descriptionController = TextEditingController();
    TextEditingController chequeNumberController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(languageProvider.isEnglish ? 'Pay Vendor' : 'وینڈر کو ادائیگی کریں'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Payment amount
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish ? 'Amount' : 'رقم',
                      ),
                      onChanged: (value) {
                        paymentAmount = double.tryParse(value) ?? 0.0;
                      },
                    ),
                    const SizedBox(height: 10),

                    // Description
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish ? 'Description' : 'تفصیل',
                      ),
                      onChanged: (value) {
                        description = value;
                      },
                    ),
                    const SizedBox(height: 10),

                    // Payment date
                    ListTile(
                      title: Text(
                        languageProvider.isEnglish
                            ? 'Date: ${DateFormat('yyyy-MM-dd HH:mm').format(paymentDate)}'
                            : 'تاریخ: ${DateFormat('yyyy-MM-dd HH:mm').format(paymentDate)}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: paymentDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(paymentDate),
                          );
                          if (pickedTime != null) {
                            setState(() {
                              paymentDate = DateTime(
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
                    const SizedBox(height: 10),

                    // Payment method selection
                    DropdownButtonFormField<String>(
                      value: selectedPaymentMethod,
                      items: [
                        DropdownMenuItem(
                          value: 'Cash',
                          child: Text(languageProvider.isEnglish ? 'Cash' : 'نقد'),
                        ),
                        DropdownMenuItem(
                          value: 'Online',
                          child: Text(languageProvider.isEnglish ? 'Online' : 'آن لائن'),
                        ),
                        DropdownMenuItem(
                          value: 'Bank',
                          child: Text(languageProvider.isEnglish ? 'Bank' : 'بینک'),
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
                        setState(() {
                          selectedPaymentMethod = value;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish ? 'Payment Method' : 'ادائیگی کا طریقہ',
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Bank selection (for Bank and Cheque payments)
                    if (selectedPaymentMethod == 'Bank' || selectedPaymentMethod == 'Cheque')
                      Card(
                        child: ListTile(
                          title: Text(
                            bankName ?? (languageProvider.isEnglish ? 'Select Bank' : 'بینک منتخب کریں'),
                          ),
                          trailing: const Icon(Icons.arrow_drop_down),
                          onTap: () async {
                            final selectedBank = await _selectBank(context);
                            if (selectedBank != null) {
                              setState(() {
                                bankId = selectedBank['id'];
                                bankName = selectedBank['name'];
                                if (selectedPaymentMethod == 'Cheque') {
                                  chequeBankId = selectedBank['id'];
                                  chequeBankName = selectedBank['name'];
                                }
                              });
                            }
                          },
                        ),
                      ),

                    // Cheque details (for Cheque payments only)
                    if (selectedPaymentMethod == 'Cheque') ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: chequeNumberController,
                        decoration: InputDecoration(
                          labelText: languageProvider.isEnglish ? 'Cheque Number' : 'چیک نمبر',
                        ),
                        onChanged: (value) {
                          chequeNumber = value;
                        },
                      ),
                      const SizedBox(height: 10),
                      ListTile(
                        title: Text(
                          chequeDate == null
                              ? (languageProvider.isEnglish ? 'Select Cheque Date' : 'چیک کی تاریخ منتخب کریں')
                              : DateFormat('yyyy-MM-dd').format(chequeDate!),
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
                            setState(() {
                              chequeDate = pickedDate;
                            });
                          }
                        },
                      ),
                    ],

                    // Image upload
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () async {
                        final image = await _pickImage();
                        if (image != null) {
                          setState(() {
                            imageBytes = base64Decode(image);
                          });
                        }
                      },
                      child: Text(languageProvider.isEnglish ? 'Upload Receipt' : 'رسید اپ لوڈ کریں'),
                    ),
                    if (imageBytes != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: GestureDetector(
                          onTap: () => _showFullScreenImage(imageBytes!),
                          child: Image.memory(
                            imageBytes!,
                            height: 100,
                            width: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
                ),
                TextButton(
                  onPressed: () async {
                    if (selectedPaymentMethod == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(languageProvider.isEnglish
                            ? 'Please select a payment method'
                            : 'براہ کرم ادائیگی کا طریقہ منتخب کریں')),
                      );
                      return;
                    }

                    if (paymentAmount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(languageProvider.isEnglish
                            ? 'Please enter a valid amount'
                            : 'براہ کرم درست رقم درج کریں')),
                      );
                      return;
                    }

                    if (selectedPaymentMethod == 'Bank' && bankId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(languageProvider.isEnglish
                            ? 'Please select a bank'
                            : 'براہ کرم بینک منتخب کریں')),
                      );
                      return;
                    }

                    if (selectedPaymentMethod == 'Cheque') {
                      if (chequeBankId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(languageProvider.isEnglish
                              ? 'Please select a bank for the cheque'
                              : 'براہ کرم چیک کے لیے بینک منتخب کریں')),
                        );
                        return;
                      }

                      if (chequeNumber == null || chequeNumber!.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(languageProvider.isEnglish
                              ? 'Please enter cheque number'
                              : 'براہ کرم چیک نمبر درج کریں')),
                        );
                        return;
                      }

                      if (chequeDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(languageProvider.isEnglish
                              ? 'Please select cheque date'
                              : 'براہ کرم چیک کی تاریخ منتخب کریں')),
                        );
                        return;
                      }
                    }

                    try {
                      // Create payment data
                      final paymentData = {
                        'amount': paymentAmount,
                        'date': paymentDate.toIso8601String(),
                        'method': selectedPaymentMethod,
                        'description': description ?? '',
                        'vendorId': vendorId,
                        'vendorName': vendorName,
                        if (imageBytes != null) 'image': base64Encode(imageBytes!),
                      };

                      // Handle different payment methods
                      switch (selectedPaymentMethod) {
                        case 'Cash':
                          await _handleCashPayment(vendorRef, paymentData);
                          break;
                        case 'Online':
                          await _handleOnlinePayment(vendorRef, paymentData);
                          break;
                        case 'Bank':
                          await _handleBankPayment(
                            vendorRef,
                            paymentData,
                            bankId!,
                            bankName!,
                            paymentAmount,
                          );
                          break;
                        case 'Cheque':
                          await _handleChequePayment(
                            vendorRef,
                            paymentData,
                            chequeBankId!,
                            chequeBankName!,
                            chequeNumber!,
                            chequeDate!,
                            paymentAmount,
                          );
                          break;
                        case 'Slip':
                          await _handleSlipPayment(vendorRef, paymentData);
                          break;
                      }

                      // Update vendor's paid amount
                      await vendorRef.child('paidAmount')
                          .set(ServerValue.increment(paymentAmount));

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(languageProvider.isEnglish
                            ? 'Payment recorded successfully!'
                            : 'ادائیگی کامیابی سے ریکارڈ ہو گئی!')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(languageProvider.isEnglish
                            ? 'Error recording payment: $e'
                            : 'ادائیگی ریکارڈ کرنے میں خرابی: $e')),
                      );
                    }
                  },
                  child: Text(languageProvider.isEnglish ? 'Save' : 'محفوظ کریں'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleCashPayment(
      DatabaseReference vendorRef,
      Map<String, dynamic> paymentData,
      )
  async {
    // Add to cashbook
    final cashbookRef = FirebaseDatabase.instance.ref('cashbook').push();
    final cashbookEntry = {
      'amount': paymentData['amount'],
      'description': paymentData['description'] ?? 'Vendor Payment',
      'date': paymentData['date'],
      'type': 'cash_out',
      'vendorId': paymentData['vendorId'],
      'vendorName': paymentData['vendorName'],
    };
    await cashbookRef.set(cashbookEntry);

    // Add payment ID to payment data
    paymentData['cashbookId'] = cashbookRef.key;

    // Save payment to vendor's payments
    await vendorRef.child('payments').push().set(paymentData);
  }

  Future<void> _handleOnlinePayment(
      DatabaseReference vendorRef,
      Map<String, dynamic> paymentData,
      )
  async {
    // Save payment to vendor's payments
    await vendorRef.child('payments').push().set(paymentData);

    // You might want to add additional online payment processing here
  }

  Future<void> _handleBankPayment(
      DatabaseReference vendorRef,
      Map<String, dynamic> paymentData,
      String bankId,
      String bankName,
      double amount,
      )
  async {
    // Add to bank transactions
    final bankRef = FirebaseDatabase.instance.ref('banks/$bankId/transactions').push();
    final bankTransaction = {
      'amount': amount,
      'description': paymentData['description'] ?? 'Vendor Payment',
      'date': paymentData['date'],
      'type': 'cash_out',
      'vendorId': paymentData['vendorId'],
      'vendorName': paymentData['vendorName'],
    };
    await bankRef.set(bankTransaction);

    // Update bank balance
    final bankBalanceRef = FirebaseDatabase.instance.ref('banks/$bankId/balance');
    final currentBalance = (await bankBalanceRef.get()).value as num? ?? 0.0;
    await bankBalanceRef.set(currentBalance - amount);

    // Add bank info to payment data
    paymentData['bankId'] = bankId;
    paymentData['bankName'] = bankName;
    paymentData['bankTransactionId'] = bankRef.key;

    // Save payment to vendor's payments
    await vendorRef.child('payments').push().set(paymentData);
  }

  Future<void> _handleChequePayment(
      DatabaseReference vendorRef,
      Map<String, dynamic> paymentData,
      String bankId,
      String bankName,
      String chequeNumber,
      DateTime chequeDate,
      double amount,
      )
  async {
    // First save to vendorCheques node
    final chequeRef = FirebaseDatabase.instance.ref('vendorCheques').push();
    final chequeData = {
      'vendorId': paymentData['vendorId'],
      'vendorName': paymentData['vendorName'],
      'amount': amount,
      'chequeNumber': chequeNumber,
      'chequeDate': chequeDate.toIso8601String(),
      'bankId': bankId,
      'bankName': bankName,
      'status': 'pending', // Initial status is pending
      'dateIssued': DateTime.now().toIso8601String(),
      'description': paymentData['description'] ?? 'Vendor Payment',
      if (paymentData['image'] != null) 'image': paymentData['image'],
      'vendorPaymentId': '', // Will be filled when cheque is cleared
    };
    await chequeRef.set(chequeData);

    // Don't add to vendor payments yet - wait for cheque to clear
    // Just show success message
    Navigator.pop(context);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(languageProvider.isEnglish
          ? 'Cheque issued successfully! Payment will be recorded when cheque clears.'
          : 'چیک کامیابی سے جاری ہو گیا ہے! ادائیگی ریکارڈ کی جائے گی جب چیک کلئیر ہو جائے گا۔')),
    );
  }

  Future<void> _handleSlipPayment(
      DatabaseReference vendorRef,
      Map<String, dynamic> paymentData,
      )
  async {
    // Save payment to vendor's payments
    await vendorRef.child('payments').push().set(paymentData);

    // You might want to add additional slip payment processing here
  }

  Future<void> _showFullScreenImage(Uint8List imageBytes) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.memory(imageBytes),
        ),
      ),
    );
  }

  // @override
  // Widget build(BuildContext context) {
  //   final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
  //
  //
  //   return Scaffold(
  //     appBar: AppBar(
  //       title:  Text(
  //         languageProvider.isEnglish ? 'Vendors' : 'فروش',
  //         style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
  //       ),
  //       centerTitle: true,
  //       backgroundColor: Colors.blueAccent,
  //       actions: [
  //         IconButton(
  //           onPressed: () {
  //             Navigator.push(
  //               context,
  //               MaterialPageRoute(builder: (context) => const AddVendorPage()),
  //             );
  //           },
  //           icon: const Icon(
  //             Icons.add,
  //             color: Colors.white,
  //           ),
  //         ),
  //         IconButton(
  //           icon: const Icon(Icons.picture_as_pdf,color: Colors.white,),
  //           onPressed: _generatePDF, // Generate PDF when tapped
  //         ),
  //       ],
  //     ),
  //     body: Container(
  //       padding: const EdgeInsets.all(12.0),
  //       child: Column(
  //         children: [
  //           TextField(
  //             controller: _searchController,
  //             decoration:  InputDecoration(
  //               labelText: languageProvider.isEnglish ? 'Search Vendors' : 'دکانداروں کو تلاش کریں',
  //               prefixIcon: Icon(Icons.search),
  //               border: OutlineInputBorder(),
  //             ),
  //           ),
  //           const SizedBox(height: 16),
  //           _isLoading
  //               ? const Center(
  //             child: CircularProgressIndicator(),
  //           )
  //               : _filteredVendors.isEmpty
  //               ? Center(
  //             child: Text(
  //               languageProvider.isEnglish ? 'No vendors added yet' : 'ابھی تک کوئی وینڈر شامل نہیں کیا گیا۔',
  //               style: const TextStyle(fontSize: 16, color: Colors.white),
  //             ),
  //           )
  //               : Expanded(
  //             child: ListView.builder(
  //               itemCount: _filteredVendors.length,
  //               itemBuilder: (context, index) {
  //                 final vendor = _filteredVendors[index];
  //                 return Card(
  //                   shape: RoundedRectangleBorder(
  //                     borderRadius: BorderRadius.circular(12.0),
  //                   ),
  //                   elevation: 6,
  //                   margin: const EdgeInsets.symmetric(vertical: 8.0),
  //                   child: ListTile(
  //                     title: Text(
  //                       vendor["name"],
  //                       style: const TextStyle(
  //                         fontSize: 16,
  //                         fontWeight: FontWeight.bold,
  //                         color: Colors.deepPurple,
  //                       ),
  //                     ),
  //                     subtitle: Column(
  //                       crossAxisAlignment: CrossAxisAlignment.start,
  //                       children: [
  //                         Text(
  //                           '${languageProvider.isEnglish ? 'Vendor' : 'وینڈر'} #${index + 1}',
  //                           style: const TextStyle(fontSize: 14, color: Colors.grey),
  //                         ),
  //                         Text(
  //                           '${languageProvider.isEnglish ? 'Opening Balance' : 'اوپننگ بیلنس'}: ${vendor["openingBalance"].toStringAsFixed(2)} Rs',
  //                           style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
  //                         ),
  //                         Text(
  //                           '${languageProvider.isEnglish ? 'Paid' : 'ادائیگی'}: ${vendor["paidAmount"].toStringAsFixed(2)} Rs',
  //                           style: const TextStyle(fontWeight: FontWeight.bold),
  //                         ),
  //                         Row(
  //                           children: [
  //                             IconButton(
  //                               icon: const Icon(Icons.edit, color: Colors.orange),
  //                               onPressed: () => _editOpeningBalance(vendor["id"], vendor["openingBalance"]),
  //                             ),
  //                             IconButton(
  //                                 icon: const Icon(Icons.delete, color: Colors.red),
  //                                 // onPressed: () => _deleteVendor(vendor["id"]),
  //                                 onPressed: () => _confirmDelete(vendor["id"])
  //
  //                             ),
  //                           ],
  //                         )
  //                       ],
  //                     ),
  //                     onTap: () => _editVendor(vendor["id"], vendor["name"]),
  //                     trailing: SizedBox(
  //                       width: 170, // Adjust width as needed
  //                       child: Row(
  //                         mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Distribute icons properly
  //                         children: [
  //                           IconButton(
  //                             icon: const Icon(Icons.payment, color: Colors.green),
  //                             onPressed: () => _payVendor(vendor["id"], vendor["name"]),
  //                           ),
  //                           IconButton(
  //                             icon: const Icon(Icons.history, color: Colors.blue),
  //                             onPressed: () => _showPaymentHistory(vendor["id"]),
  //                           ),
  //                           // In the ListTile trailing section of ViewVendorsPage:
  //                           IconButton(
  //                             icon: const Icon(Icons.account_balance_wallet, color: Colors.purple),
  //                             onPressed: () => Navigator.push(
  //                               context,
  //                               MaterialPageRoute(
  //                                 builder: (context) => VendorLedgerPage(
  //                                   vendorId: vendor["id"],
  //                                   vendorName: vendor["name"],
  //                                 ),
  //                               ),
  //                             ),
  //                           ),
  //                         ],
  //                       ),
  //                     ),
  //
  //                   ),
  //                 );
  //               },
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.isEnglish ? 'Vendors' : 'فروش',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddVendorPage()),
              );
            },
            icon: const Icon(
              Icons.add,
              color: Colors.white,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: _generatePDF,
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
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: languageProvider.isEnglish ? 'Search Vendors' : 'دکانداروں کو تلاش کریں',
                prefixIcon: Icon(Icons.search, color: Color(0xFFFF8A65)),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFFF8A65)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFFF8A65)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _isLoading
                ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFFFF8A65)),
              ),
            )
                : _filteredVendors.isEmpty
                ? Center(
              child: Text(
                languageProvider.isEnglish
                    ? 'No vendors added yet'
                    : 'ابھی تک کوئی وینڈر شامل نہیں کیا گیا۔',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFFE65100), // Dark orange
                ),
              ),
            )
                : Expanded(
              child: ListView.builder(
                itemCount: _filteredVendors.length,
                itemBuilder: (context, index) {
                  final vendor = _filteredVendors[index];
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    elevation: 6,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      title: Text(
                        vendor["name"],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE65100), // Dark orange
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${languageProvider.isEnglish ? 'Vendor' : 'وینڈر'} #${index + 1}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            '${languageProvider.isEnglish ? 'Opening Balance' : 'اوپننگ بیلنس'}: ${vendor["openingBalance"].toStringAsFixed(2)} Rs',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF8A65),
                            ),
                          ),
                          Text(
                            '${languageProvider.isEnglish ? 'Paid' : 'ادائیگی'}: ${vendor["paidAmount"].toStringAsFixed(2)} Rs',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF8A65),
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: Color(0xFFFF8A65)),
                                onPressed: () => _editOpeningBalance(vendor["id"], vendor["openingBalance"]),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _confirmDelete(vendor["id"]),
                              ),
                            ],
                          )
                        ],
                      ),
                      onTap: () => _editVendor(vendor["id"], vendor["name"]),
                      trailing: SizedBox(
                        width: 170,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: Icon(Icons.payment, color: Color(0xFFFF8A65)),
                              onPressed: () => _payVendor(vendor["id"], vendor["name"]),
                            ),
                            IconButton(
                              icon: Icon(Icons.history, color: Color(0xFFFF8A65)),
                              onPressed: () => _showPaymentHistory(vendor["id"]),
                            ),
                            IconButton(
                              icon: Icon(Icons.account_balance_wallet, color: Color(0xFFFF8A65)),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VendorLedgerPage(
                                    vendorId: vendor["id"],
                                    vendorName: vendor["name"],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PaymentHistoryPage extends StatefulWidget {
  final String vendorId;

  const PaymentHistoryPage({super.key, required this.vendorId});

  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  late List<Map<String, dynamic>> payments;

  @override
  void initState() {
    super.initState();
    payments = [];
    _fetchPaymentHistory();
  }


  void _deletePayment(String paymentId, double amount) async {

    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    // Show confirmation dialog
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(languageProvider.isEnglish ? 'Confirm Delete' : 'حذف کی تصدیق کریں'),
          content: Text(languageProvider.isEnglish
              ? 'Are you sure you want to delete this payment?'
              : 'کیا آپ واقعی اس ادائیگی کو حذف کرنا چاہتے ہیں؟'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false); // Return false if "No" is pressed
              },
              child: Text(languageProvider.isEnglish ? 'No' : 'نہیں'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true); // Return true if "Yes" is pressed
              },
              child: Text(languageProvider.isEnglish ? 'Yes' : 'ہاں'),
            ),
          ],
        );
      },
    );

    // If the user confirms deletion, proceed with deleting the payment
    if (confirmDelete == true) {
      try {
        // Delete the payment from Firebase
        await FirebaseDatabase.instance
            .ref('vendors/${widget.vendorId}/payments/$paymentId')
            .remove();

        // Update the total paid amount by subtracting the deleted payment amount
        await FirebaseDatabase.instance
            .ref('vendors/${widget.vendorId}/paidAmount')
            .set(ServerValue.increment(-amount));

        // Refresh the payment list
        _fetchPaymentHistory();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content:Text(languageProvider.isEnglish ? 'Payment deleted successfully!' : 'ادائیگی کامیابی سے حذف ہو گئی!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(languageProvider.isEnglish ? 'Error deleting payment: $e' : 'ادائیگی حذف کرنے میں خرابی: $e')),
        );
      }
    }
  }

  @override
  Future<void> _fetchPaymentHistory() async {
    final DatabaseReference paymentsRef = FirebaseDatabase.instance
        .ref('vendors/${widget.vendorId}/payments');
    final snapshot = await paymentsRef.get();

    final data = snapshot.value as Map<dynamic, dynamic>?;
    if (data == null) {
      setState(() => payments = []);
      return;
    }

    setState(() {
      payments = data.entries.map((entry) {
        return {
          'id': entry.key,
          'amount': (entry.value['amount'] as num).toDouble(),
          'description': entry.value['description'],
          'date': entry.value['date'],
          'paymentMethod': entry.value['paymentMethod'] ?? 'Unknown',
          'imageBase64': entry.value['imageBase64'] ?? '', // Add this
        };
      }).toList();
    });
  }


  void _editPayment(String paymentId, double existingAmount, String existingDescription, String existingMethod) {
    TextEditingController amountController = TextEditingController(text: existingAmount.toString());
    TextEditingController descriptionController = TextEditingController(text: existingDescription);
    String selectedPaymentMethod = existingMethod;
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    String? _base64Image; // Add this

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(languageProvider.isEnglish ? 'Edit Payment' : 'ادائیگی میں ترمیم کریں'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration:  InputDecoration(
                    labelText: languageProvider.isEnglish ? 'Amount' : 'رقم',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  decoration:  InputDecoration(
                    labelText: languageProvider.isEnglish ? 'Description' : 'تفصیل',
                    prefixIcon: Icon(Icons.description),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedPaymentMethod,
                  decoration:  InputDecoration(
                    labelText: languageProvider.isEnglish ? 'Payment Method' : 'ادائیگی کا طریقہ',
                    prefixIcon: Icon(Icons.payment),
                  ),
                  items: [
                    languageProvider.isEnglish ? "Cash" : "نقد",
                    languageProvider.isEnglish ? "Online" : "آن لائن",
                    languageProvider.isEnglish ? "Check" : "چیک"
                  ].map((method) {
                    return DropdownMenuItem(
                      value: method,
                      child: Text(method),
                    );//s
                  }).toList(),
                  onChanged: (value) {
                    selectedPaymentMethod = value!;
                  },
                ),
                ElevatedButton(
                  onPressed: () async {
                    String? base64 = await _pickImage();
                    if (base64 != null) {
                      setState(() => _base64Image = base64);
                    }
                  },
                  child: Text(languageProvider.isEnglish ? 'Change Image' : 'تصویر تبدیل کریں'),
                ),
                if (_base64Image != null)
                  GestureDetector(
                    onTap: () => _showImagePreview(_base64Image!),
                    child: Image.memory(
                      base64Decode(_base64Image!),
                      height: 100,
                      width: 100,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                double newAmount = double.tryParse(amountController.text.trim()) ?? 0.0;
                String newDescription = descriptionController.text.trim();

                if (newAmount > 0) {
                  final difference = newAmount - existingAmount;

                  // FirebaseDatabase.instance
                  //     .ref('vendors/${widget.vendorId}/payments/$paymentId')
                  //     .update({
                  //   'amount': newAmount,
                  //   'description': newDescription,
                  //   'paymentMethod': selectedPaymentMethod,
                  // });
                  final updateData = {
                    'amount': newAmount,
                    'description': newDescription,
                    'paymentMethod': selectedPaymentMethod,
                  };

                  // Add image only if changed
                  if (_base64Image != null) {
                    updateData['imageBase64'] = _base64Image!;
                  }

                   FirebaseDatabase.instance
                      .ref('vendors/${widget.vendorId}/payments/$paymentId')
                      .update(updateData);

                  FirebaseDatabase.instance
                      .ref('vendors/${widget.vendorId}/paidAmount')
                      .set(ServerValue.increment(difference));
                  Navigator.pop(context);
                  _fetchPaymentHistory(); // Refresh the payment list
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(languageProvider.isEnglish ? 'Payment updated successfully!' : 'ادائیگی کامیابی سے اپ ڈیٹ ہو گئی!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(languageProvider.isEnglish ? 'Please enter a valid amount.' : 'براہ کرم درست رقم درج کریں۔')),
                  );
                }
              },
              child: Text(languageProvider.isEnglish ? 'Save' : 'محفوظ کریں'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
            ),
          ],
        );
      },
    );
  }

  void _showImagePreview(String base64Image) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.isEnglish ? 'Payment Receipt' : 'ادائیگی کی رسید'),
        content: InteractiveViewer(
          minScale: 0.1,
          maxScale: 4.0,
          child: Image.memory(base64Decode(base64Image)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(languageProvider.isEnglish ? 'Close' : 'بند کریں'),
          ),
        ],
      ),
    );
  }


  // Add this method to fix '_pickImage' error
  Future<String?> _pickImage() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final ImagePicker _picker = ImagePicker();
    Uint8List? imageBytes;

    // Capture image
    XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 800,
      maxHeight: 800,
    );

    if (pickedFile != null) {
      // Compress and convert to Base64
      imageBytes = await pickedFile.readAsBytes();
      return await _compressAndConvertToBase64(imageBytes);
    }
    return null;
  }

  // Add this helper method
  Future<String> _compressAndConvertToBase64(Uint8List imageBytes) async {
    final codec = await ui.instantiateImageCodec(
      imageBytes,
      targetWidth: 400,
      targetHeight: 400,
    );

    final frame = await codec.getNextFrame();
    final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    return base64Encode(byteData!.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(languageProvider.isEnglish ? 'Payment History' : 'ادائیگی کی تاریخ'),
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
      body: payments.isEmpty
          ?  Center(child: Text(
        languageProvider.isEnglish ? 'No payments recorded for this vendor.' : 'اس وینڈر کے لیے کوئی ادائیگی ریکارڈ نہیں کی گئی۔',
      ))
          : ListView.builder(
        itemCount: payments.length,
        itemBuilder: (context, index) {
          final payment = payments[index];
          // Fix 'hasImage' error by calculating it here
          final hasImage = payment['imageBase64'] != null &&
              payment['imageBase64'].isNotEmpty;

          return ListTile(
            leading: hasImage
                ? GestureDetector(
              onTap: () => _showImagePreview(payment['imageBase64']),
              child: Image.memory(
                base64Decode(payment['imageBase64']),
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              ),
            )
                : const Icon(Icons.receipt, size: 40),
            title: Text("${languageProvider.isEnglish ? 'Amount' : 'رقم'}: ${payment['amount']}Rs"),
            subtitle: Text(
                  "${languageProvider.isEnglish ? 'Description' : 'تفصیل'}: ${payment['description']}\n"
                  "${languageProvider.isEnglish ? 'Date' : 'تاریخ'}: ${payment['date']}\n"
                  "${languageProvider.isEnglish ? 'Payment Method' : 'ادائیگی کا طریقہ'}: ${payment['paymentMethod']}",
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.orange),
                  onPressed: () => _editPayment(
                    payment['id'],
                    payment['amount'],
                    payment['description'],
                    payment['paymentMethod'],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deletePayment(payment['id'], payment['amount']),
                ),
              ],
            ),
          );
        },
      ),
    );//s
  }
}

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../Models/itemModel.dart';
import '../Provider/customerprovider.dart';
import '../Provider/lanprovider.dart';

class QuotationPage extends StatefulWidget {
  final String? quotationId;
  final Map<dynamic, dynamic>? existingQuotation;

  const QuotationPage({
    super.key,
    this.quotationId,
    this.existingQuotation,
  });
  @override
  _QuotationPageState createState() => _QuotationPageState();
}

class _QuotationPageState extends State<QuotationPage> {
  List<Item> _items = [];
  String? _selectedCustomerName;
  String? _selectedCustomerId;
  double _discount = 0.0;
  TextEditingController _discountController = TextEditingController();
  List<Map<String, dynamic>> _quotationRows = [];
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  TextEditingController _referenceController = TextEditingController();
  TextEditingController _validityController = TextEditingController();
  TextEditingController _termsController = TextEditingController();
  Map<String, Map<String, double>> _customerItemPrices = {};

  @override
  void initState() {
    super.initState();
    _fetchItems();
    _fetchCustomers();

    // Initialize with 10 rows if empty
    if (_quotationRows.isEmpty) {
      for (int i = 0; i < 5; i++) {
        _quotationRows.add({
          'total': 0.0,
          'rate': 0.0,
          'qty': 0.0,
          'description': '',
          'itemName': '',
          'itemNameController': TextEditingController(),
          'rateController': TextEditingController(),
          'qtyController': TextEditingController(),
          'descriptionController': TextEditingController(),
        });
      }
    }

    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _validityController.text = '30';
    if (widget.existingQuotation != null) {
      _loadExistingQuotation();
    }


  }

  void _loadExistingQuotation() {
    final quotation = widget.existingQuotation!;
    final customer = quotation['customer'] as Map<dynamic, dynamic>;
    final items = quotation['items'] as List<dynamic>;

    setState(() {
      _selectedCustomerId = customer['id'];
      _selectedCustomerName = customer['name'];
      _dateController.text = quotation['date'];
      _referenceController.text = quotation['reference'];
      _validityController.text = quotation['validityDays'].toString();
      _termsController.text = quotation['terms'];
      _discount = quotation['discount'];
      _discountController.text = quotation['discount'].toString();

      // Clear the initial empty row
      _quotationRows.clear();

      // Add rows for each item
      for (var item in items) {
        final itemNameController = TextEditingController(
            text: item['itemName']);
        final rateController = TextEditingController(
            text: item['rate'].toString());
        final qtyController = TextEditingController(
            text: item['quantity'].toString());
        final descriptionController = TextEditingController(
            text: item['description']);

        _quotationRows.add({
          'itemName': item['itemName'],
          'description': item['description'],
          'qty': item['quantity'],
          'rate': item['rate'],
          'total': item['total'],
          'itemNameController': itemNameController,
          'rateController': rateController,
          'qtyController': qtyController,
          'descriptionController': descriptionController,
        });

        // Find the corresponding item in _items and set it as selected
        if (_items.isNotEmpty) {
          final matchingItem = _items.firstWhere(
                (i) => i.itemName == item['itemName'],
            orElse: () =>
                Item(
                  id: '',
                  itemName: item['itemName'],
                  costPrice: item['rate'].toDouble(),
                  salePrice: item['salerate'].toDouble(),
                  qtyOnHand: 0,
                ),
          );
          if (matchingItem.id.isNotEmpty) {
            // This ensures the autocomplete will show the selected item
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (itemNameController.text.isEmpty) {
                itemNameController.text = matchingItem.itemName;
              }
            });
          }
        }
      }
    });
  }

  Future<void> _fetchCustomers() async {
    final customerProvider = Provider.of<CustomerProvider>(
        context, listen: false);
    await customerProvider.fetchCustomers();
  }

  void _fetchCustomerPrices(String customerId) async {
    final DatabaseReference pricesRef = FirebaseDatabase.instance.ref().child(
        'items');
    final DatabaseEvent snapshot = await pricesRef.once();

    if (snapshot.snapshot.exists) {
      final Map<dynamic, dynamic> itemsMap = snapshot.snapshot.value as Map<
          dynamic,
          dynamic>;
      Map<String, Map<String, double>> prices = {};

      itemsMap.forEach((itemId, itemData) {
        final item = itemData as Map<dynamic, dynamic>;
        if (item['customerBasePrices'] != null) {
          final customerPrices = item['customerBasePrices'] as Map<
              dynamic,
              dynamic>;
          if (customerPrices.containsKey(customerId)) {
            final price = double.tryParse(
                customerPrices[customerId].toString()) ?? 0.0;
            if (!prices.containsKey(itemId)) {
              prices[itemId] = {};
            }
            prices[itemId]![customerId] = price;
          }
        }
      });

      setState(() {
        _customerItemPrices = prices;
      });
    }
  }

  Future<void> _fetchItems() async {
    try {
      print('Fetching items...');
      final DatabaseReference itemsRef = FirebaseDatabase.instance.ref().child(
          'items');
      final DatabaseEvent snapshot = await itemsRef.once();
      print('Snapshot exists: ${snapshot.snapshot.exists}');

      if (snapshot.snapshot.exists) {
        final Map<dynamic, dynamic> itemsMap = snapshot.snapshot.value as Map<
            dynamic,
            dynamic>;
        print('Items count: ${itemsMap.length}');

        setState(() {
          _items = itemsMap.entries.map((entry) {
            print('Processing item: ${entry.key}');
            return Item.fromMap(
                entry.value as Map<dynamic, dynamic>, entry.key as String);
          }).toList();
          print('Items loaded: ${_items.length}');
        });
      } else {
        print('No items found in snapshot');
        setState(() => _items = []);
      }
    } catch (e) {
      print('Error fetching items: $e');
      setState(() => _items = []);
    }
  }

  void _addNewRow() {
    setState(() {
      _quotationRows.add({
        'total': 0.0,
        'rate': 0.0,
        'qty': 0.0,
        'description': '',
        'itemNameController': TextEditingController(),
        'rateController': TextEditingController(),
        'qtyController': TextEditingController(),
        'descriptionController': TextEditingController(),
      });
    });
  }

  void _updateRow(int index, String field, dynamic value) {
    setState(() {
      _quotationRows[index][field] = value;
      if (field == 'rate' || field == 'qty') {
        double rate = _quotationRows[index]['rate'] ?? 0.0;
        double qty = _quotationRows[index]['qty'] ?? 0.0;
        _quotationRows[index]['total'] = rate * qty;
      }
    });
  }

  void _deleteRow(int index) {
    setState(() {
      final deletedRow = _quotationRows[index];
      deletedRow['itemNameController']?.dispose();
      deletedRow['rateController']?.dispose();
      deletedRow['qtyController']?.dispose();
      deletedRow['descriptionController']?.dispose();
      _quotationRows.removeAt(index);
    });
  }

  double _calculateSubtotal() {
    return _quotationRows.fold(0.0, (sum, row) => sum + (row['total'] ?? 0.0));
  }

  double _calculateGrandTotal() {
    double subtotal = _calculateSubtotal();
    return subtotal - _discount;
  }

  Future<Uint8List> _generateQuotationPDF() async {
    final pdf = pw.Document();
    final languageProvider = Provider.of<LanguageProvider>(
        context, listen: false);
    final customerProvider = Provider.of<CustomerProvider>(
        context, listen: false);

    if (_selectedCustomerId == null) {
      throw Exception("No customer selected");
    }

    final selectedCustomer = customerProvider.customers.firstWhere(
            (customer) => customer.id == _selectedCustomerId,
        orElse: () =>
            Customer(
                id: 'unknown', name: 'Unknown Customer', phone: '', address: '')
    );

    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('yyyy-MM-dd').format(now);
    final validityDays = int.tryParse(_validityController.text) ?? 30;
    final expiryDate = now.add(Duration(days: validityDays));
    final formattedExpiry = DateFormat('yyyy-MM-dd').format(expiryDate);

    // Load images
    final ByteData logoBytes = await rootBundle.load('assets/images/logo.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    // Filter out empty rows
    final nonEmptyRows = _quotationRows.where((row) {
      final itemName = row['itemNameController']?.text ?? '';
      final description = row['description'] ?? '';
      final qty = row['qty'] ?? 0.0;
      final rate = row['rate'] ?? 0.0;

      return itemName.isNotEmpty || description.isNotEmpty || qty > 0 || rate > 0;
    }).toList();

    // Create PDF
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(logoImage, width: 80, height: 80),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('QUOTATION', style: pw.TextStyle(
                          fontSize: 24, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Date: $formattedDate'),
                      pw.Text('Valid Until: $formattedExpiry'),
                      pw.Text('Ref: ${_referenceController.text}'),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),
              pw.Divider(),

              // Customer Info
              pw.Text('To:', style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text(selectedCustomer.name),
              if (selectedCustomer.address.isNotEmpty) pw.Text(
                  selectedCustomer.address),
              if (selectedCustomer.phone.isNotEmpty) pw.Text(
                  'Phone: ${selectedCustomer.phone}'),

              pw.SizedBox(height: 20),

              // Items Table
              pw.TableHelper.fromTextArray(
                headers: [
                  'Item Name',
                  'Description',
                  'Quantity',
                  'Unit Price',
                  'Total'
                ],
                data: nonEmptyRows.map((row) {
                  return [
                    row['itemNameController']?.text ?? '',
                    row['description'] ?? '',
                    (row['qty'] ?? 0).toString(),
                    (row['rate'] ?? 0.0).toStringAsFixed(2),
                    (row['total'] ?? 0.0).toStringAsFixed(2),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerRight,
                cellAlignments: {0: pw.Alignment.centerLeft},
              ),

              pw.SizedBox(height: 20),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text(
                              'Subtotal: ', style: pw.TextStyle(fontWeight: pw
                              .FontWeight.bold)),
                          pw.Text(_calculateSubtotal().toStringAsFixed(2)),
                        ],
                      ),
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text(
                              'Discount: ', style: pw.TextStyle(fontWeight: pw
                              .FontWeight.bold)),
                          pw.Text(_discount.toStringAsFixed(2)),
                        ],
                      ),
                      pw.Divider(),
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text('TOTAL: ',
                              style: pw.TextStyle(fontSize: 16, fontWeight: pw
                                  .FontWeight.bold)),
                          pw.Text(_calculateGrandTotal().toStringAsFixed(2),
                              style: const pw.TextStyle(fontSize: 16)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 30),

              // Terms & Conditions
              pw.Text('Terms & Conditions:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(_termsController.text),

              pw.SizedBox(height: 30),

              // Signature
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('Authorized Signature'),
                      pw.Container(
                        width: 150,
                        height: 2,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(width: 1),
                          ),
                        ),
                      ),
                      pw.Text('For ${selectedCustomer.name}'),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<void> _saveQuotation() async {
    final languageProvider = Provider.of<LanguageProvider>(
        context, listen: false);
    final customerProvider = Provider.of<CustomerProvider>(
        context, listen: false);

    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(languageProvider.isEnglish
            ? 'Please select a customer'
            : 'براہ کرم کسٹمر منتخب کریں')),
      );
      return;
    }

    if (_quotationRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(languageProvider.isEnglish
            ? 'Please add at least one item'
            : 'براہ کرم کم از کم ایک آئٹم شامل کریں')),
      );
      return;
    }

    try {
      // Get the selected customer details
      final selectedCustomer = customerProvider.customers.firstWhere(
              (customer) => customer.id == _selectedCustomerId,
          orElse: () =>
              Customer(id: 'unknown',
                  name: 'Unknown Customer',
                  phone: '',
                  address: '')
      );

      // Prepare the quotation data
      final quotationData = {
        'customer': {
          'id': _selectedCustomerId,
          'name': selectedCustomer.name,
          'phone': selectedCustomer.phone,
          'address': selectedCustomer.address,
        },
        'date': _dateController.text,
        'validityDays': int.tryParse(_validityController.text) ?? 30,
        'reference': _referenceController.text,
        'terms': _termsController.text,
        'subtotal': _calculateSubtotal(),
        'discount': _discount,
        'grandTotal': _calculateGrandTotal(),
        'updatedAt': ServerValue.timestamp,
        'items': _quotationRows.map((row) {
          return {
            'itemName': row['itemName'] ?? '',
            'description': row['description'] ?? '',
            'quantity': row['qty'] ?? 0.0,
            'rate': row['rate'] ?? 0.0,
            'total': row['total'] ?? 0.0,
          };
        }).toList(),
      };

      // Save to Firebase
      DatabaseReference ref;
      if (widget.quotationId != null) {
        // Update existing quotation
        ref = FirebaseDatabase.instance.ref().child('quotations').child(
            widget.quotationId!);
        await ref.update(quotationData);
      } else {
        // Create new quotation
        ref = FirebaseDatabase.instance.ref().child('quotations').push();
        quotationData['createdAt'] = ServerValue.timestamp;
        await ref.set(quotationData);
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(languageProvider.isEnglish
            ? 'Quotation saved successfully'
            : 'کوٹیشن کامیابی سے محفوظ ہو گئی')),
      );

      // Navigate back if editing
      if (widget.quotationId != null) {
        Navigator.pop(context);
      } else {
        // Clear the form if creating new
        _resetForm();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(languageProvider.isEnglish
            ? 'Error saving quotation: $e'
            : 'کوٹیشن محفوظ کرنے میں خرابی: $e')),
      );
    }
  }

  void _resetForm() {
    setState(() {
      _selectedCustomerId = null;
      _selectedCustomerName = null;
      _discount = 0.0;
      _discountController.clear();
      _referenceController.clear();
      _validityController.text = '30';
      _termsController.clear();
      _quotationRows = [{
        'total': 0.0,
        'rate': 0.0,
        'qty': 0.0,
        'description': '',
        'itemNameController': TextEditingController(),
        'rateController': TextEditingController(),
        'qtyController': TextEditingController(),
        'descriptionController': TextEditingController(),
      }
      ];
    });
  }


  @override
  void dispose() {
    for (var row in _quotationRows) {
      row['itemNameController']?.dispose();
      row['rateController']?.dispose();
      row['qtyController']?.dispose();
      row['descriptionController']?.dispose();
    }
    _discountController.dispose();
    _customerController.dispose();
    _dateController.dispose();
    _referenceController.dispose();
    _validityController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final screenWidth = MediaQuery
        .of(context)
        .size
        .width;
    final isWeb = screenWidth > 768;
    final isTablet = screenWidth > 480 && screenWidth <= 768;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(context, languageProvider),
      body: ResponsiveLayout(
        mobile: _buildMobileLayout(context, languageProvider),
        tablet: _buildTabletLayout(context, languageProvider),
        desktop: _buildDesktopLayout(context, languageProvider),
      ),
    );
  }

  Widget _buildItemsGallery(BuildContext context, LanguageProvider languageProvider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.image_search, color: Colors.pink[700], size: 24),
                SizedBox(width: 8),
                Text(
                  languageProvider.isEnglish ? 'Items Gallery' : 'آئٹمز کی گیلری',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.pink[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            // Remove Expanded and use SizedBox with fixed height
            SizedBox(
              height: 400, // Fixed height to avoid unbounded constraints
              child: ListView.builder(
                shrinkWrap: true,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final displayPrice = _selectedCustomerId != null
                      ? item.getPriceForCustomer(_selectedCustomerId)
                      : item.salePrice;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _addItemToQuotation(item),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              // Item Image
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.grey[200],
                                ),
                                child: item.imageBase64 != null && item.imageBase64!.isNotEmpty
                                    ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    base64Decode(item.imageBase64!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Center(child: Icon(Icons.broken_image));
                                    },
                                  ),
                                )
                                    : Center(
                                  child: Icon(
                                    Icons.inventory,
                                    size: 40,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.itemName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '${displayPrice.toStringAsFixed(2)} rs',
                                      style: TextStyle(
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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

  void _addItemToQuotation(Item item) {
    final displayPrice = _selectedCustomerId != null
        ? item.getPriceForCustomer(_selectedCustomerId)
        : item.salePrice;

    // Find the first empty row or add a new one
    int emptyRowIndex = _quotationRows.indexWhere((row) =>
    (row['itemName'] as String).isEmpty &&
        (row['qty'] as double) == 0.0);

    if (emptyRowIndex == -1) {
      emptyRowIndex = _quotationRows.length;
      _addNewRow();
    }

    setState(() {
      _quotationRows[emptyRowIndex]['itemName'] = item.itemName;
      _quotationRows[emptyRowIndex]['itemNameController'].text = item.itemName;
      _quotationRows[emptyRowIndex]['rate'] = displayPrice;
      _quotationRows[emptyRowIndex]['rateController'].text = displayPrice.toString();
      _quotationRows[emptyRowIndex]['description'] = item.itemName;
      _quotationRows[emptyRowIndex]['descriptionController'].text = item.itemName;
      _quotationRows[emptyRowIndex]['qty'] = 1.0;
      _quotationRows[emptyRowIndex]['qtyController'].text = '1';
      _quotationRows[emptyRowIndex]['total'] = displayPrice * 1.0;
    });
  }

  PreferredSizeWidget _buildAppBar(BuildContext context,
      LanguageProvider languageProvider) {
    return AppBar(
      elevation: 0,
      title: Text(
        languageProvider.isEnglish ? 'Create Quotation' : 'کوٹیشن بنائیں',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 18,
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
        _buildAppBarAction(
          icon: Icons.print_outlined,
          onPressed: () async {
            try {
              final bytes = await _generateQuotationPDF();
              await Printing.layoutPdf(onLayout: (_) => bytes);
            } catch (e) {
              _showSnackBar(context, 'Printing error: ${e.toString()}');
            }
          },
        ),
      ],
    );
  }

  Widget _buildAppBarAction(
      {required IconData icon, required VoidCallback onPressed}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Material(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context,
      LanguageProvider languageProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(context, languageProvider, isMobile: true),
          const SizedBox(height: 24),
          _buildCustomerSection(context, languageProvider),
          const SizedBox(height: 24),
          _buildItemsSection(context, languageProvider, isMobile: true),
          const SizedBox(height: 24),
          _buildDiscountSection(context, languageProvider),
          const SizedBox(height: 24),
          _buildTotalsSection(context, languageProvider),
          const SizedBox(height: 24),
          _buildTermsSection(context, languageProvider),
          const SizedBox(height: 32),
          _buildSaveButton(context, languageProvider),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context, LanguageProvider languageProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(context, languageProvider, isMobile: false),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _buildCustomerSection(context, languageProvider),
                    const SizedBox(height: 24),
                    _buildItemsSection(context, languageProvider, isMobile: false),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _buildDiscountSection(context, languageProvider),
                    const SizedBox(height: 24),
                    _buildTotalsSection(context, languageProvider),
                    const SizedBox(height: 24),
                    _buildTermsSection(context, languageProvider),
                    const SizedBox(height: 24),
                    _buildSaveButton(context, languageProvider),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildItemsGallery(context, languageProvider),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, LanguageProvider languageProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1400), // Increased max width
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderSection(context, languageProvider, isMobile: false),
              const SizedBox(height: 32),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        _buildCustomerSection(context, languageProvider),
                        const SizedBox(height: 32),
                        _buildItemsSection(context, languageProvider, isMobile: false),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: Column(
                      children: [
                        _buildDiscountSection(context, languageProvider),
                        const SizedBox(height: 24),
                        _buildTotalsSection(context, languageProvider),
                        const SizedBox(height: 24),
                        _buildTermsSection(context, languageProvider),
                        const SizedBox(height: 24),
                        _buildSaveButton(context, languageProvider),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: _buildItemsGallery(context, languageProvider),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context,
      LanguageProvider languageProvider, {required bool isMobile}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.orange[50]!, Colors.amber[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: Colors.orange[700], size: 24),
                const SizedBox(width: 8),
                Text(
                  languageProvider.isEnglish
                      ? 'Quotation Details'
                      : 'کوٹیشن کی تفصیلات',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (isMobile) ...[
              _buildTextField(
                controller: _referenceController,
                label: languageProvider.isEnglish
                    ? 'Reference Number'
                    : 'ریفرنس نمبر',
                icon: Icons.tag,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _dateController,
                label: languageProvider.isEnglish ? 'Date' : 'تاریخ',
                icon: Icons.calendar_today,
                readOnly: true,
                onTap: () => _selectDate(context),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _validityController,
                label: languageProvider.isEnglish
                    ? 'Validity (Days)'
                    : 'دورانیہ (دن)',
                icon: Icons.schedule,
                keyboardType: TextInputType.number,
              ),
            ] else
              ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _referenceController,
                        label: languageProvider.isEnglish
                            ? 'Reference Number'
                            : 'ریفرنس نمبر',
                        icon: Icons.tag,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _dateController,
                        label: languageProvider.isEnglish ? 'Date' : 'تاریخ',
                        icon: Icons.calendar_today,
                        readOnly: true,
                        onTap: () => _selectDate(context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _validityController,
                        label: languageProvider.isEnglish
                            ? 'Validity (Days)'
                            : 'دورانیہ (دن)',
                        icon: Icons.schedule,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerSection(BuildContext context,
      LanguageProvider languageProvider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_outline, color: Colors.blue[700], size: 24),
                const SizedBox(width: 8),
                Text(
                  languageProvider.isEnglish
                      ? 'Customer Information'
                      : 'کسٹمر کی معلومات',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Consumer<CustomerProvider>(
              builder: (context, customerProvider, _) {
                if (customerProvider.customers.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedCustomerId,
                    decoration: InputDecoration(
                      labelText: languageProvider.isEnglish
                          ? 'Select Customer'
                          : 'کسٹمر منتخب کریں',
                      prefixIcon: Icon(Icons.person, color: Colors.blue[600]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    items: customerProvider.customers.map((customer) {
                      return DropdownMenuItem<String>(
                        value: customer.id,
                        child: Text(customer.name),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedCustomerId = newValue;
                          _selectedCustomerName = customerProvider.customers
                              .firstWhere((customer) => customer.id == newValue)
                              .name;
                        });
                        _fetchCustomerPrices(newValue);
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return languageProvider.isEnglish
                            ? 'Please select a customer'
                            : 'براہ کرم کسٹمر منتخب کریں';
                      }
                      return null;
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection(BuildContext context, LanguageProvider languageProvider,
      {required bool isMobile})
  {


    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        color: Colors.green[700], size: 24),
                    const SizedBox(width: 8),
                    Text(
                      languageProvider.isEnglish ? 'Items' : 'آئٹمز',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[800],
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _addNewRow,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(languageProvider.isEnglish
                      ? 'Add Item' : 'آئٹم شامل کریں'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Table header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      languageProvider.isEnglish ? 'Item' : 'آئٹم',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      languageProvider.isEnglish ? 'Description' : 'تفصیل',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      languageProvider.isEnglish ? 'Qty' : 'مقدار',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      languageProvider.isEnglish ? 'Rate' : 'ریٹ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      languageProvider.isEnglish ? 'Total' : 'کل',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 40), // Space for delete button
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Items list
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _quotationRows.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Item Name (Autocomplete)
                    Expanded(
                      flex: 3,
                      child: CustomAutocomplete(
                        items: _items,
                        controller: _quotationRows[index]['itemNameController'],
                        onSelected: (Item selectedItem) {
                          final customerPrice = selectedItem.getPriceForCustomer(_selectedCustomerId);
                          setState(() {
                            _quotationRows[index]['itemName'] = selectedItem.itemName;
                            _quotationRows[index]['rate'] = customerPrice;
                            _quotationRows[index]['rateController'].text = customerPrice.toString();
                            _updateRow(index, 'rate', customerPrice);

                            if (_quotationRows[index]['description'].isEmpty) {
                              _quotationRows[index]['description'] = selectedItem.itemName;
                              _quotationRows[index]['descriptionController'].text = selectedItem.itemName;
                            }
                          });
                        },
                        selectedCustomerId: _selectedCustomerId,
                        allowManualEntry: true,
                      ),
                    ),

                    // Description
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: TextField(
                          controller: _quotationRows[index]['descriptionController'],
                          decoration: InputDecoration(
                            hintText: languageProvider.isEnglish ? 'Description' : 'تفصیل',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          maxLines: 1,
                          onChanged: (value) => _updateRow(index, 'description', value),
                        ),
                      ),
                    ),

                    // Quantity
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: TextField(
                          controller: _quotationRows[index]['qtyController'],
                          decoration: InputDecoration(
                            hintText: languageProvider.isEnglish ? 'Qty' : 'مقدار',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          onChanged: (value) => _updateRow(index, 'qty', double.tryParse(value) ?? 0.0),
                        ),
                      ),
                    ),

                    // Rate
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: TextField(
                          controller: _quotationRows[index]['rateController'],
                          decoration: InputDecoration(
                            hintText: languageProvider.isEnglish ? 'Rate' : 'ریٹ',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          onChanged: (value) => _updateRow(index, 'rate', double.tryParse(value) ?? 0.0),
                        ),
                      ),
                    ),

                    // Total
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: TextField(
                          controller: TextEditingController(
                            text: (_quotationRows[index]['total'] ?? 0.0).toStringAsFixed(2),
                          ),
                          decoration: InputDecoration(
                            hintText: languageProvider.isEnglish ? 'Total' : 'کل',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          readOnly: true,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                    // Delete button
                    SizedBox(
                      width: 40,
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        onPressed: () => _deleteRow(index),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Add more items button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _addNewRow,
                icon: const Icon(Icons.add, size: 16),
                label: Text(languageProvider.isEnglish ? 'Add More Items' : 'مزید آئٹمز شامل کریں'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountSection(BuildContext context,
      LanguageProvider languageProvider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.discount_outlined, color: Colors.purple[700],
                    size: 24),
                const SizedBox(width: 8),
                Text(
                  languageProvider.isEnglish ? 'Discount' : 'رعایت',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _discountController,
              label: languageProvider.isEnglish
                  ? 'Discount Amount'
                  : 'رعایت کی رقم',
              icon: Icons.money_off,
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  _discount = double.tryParse(value) ?? 0.0;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalsSection(BuildContext context,
      LanguageProvider languageProvider) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.indigo[50]!, Colors.blue[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.calculate_outlined, color: Colors.indigo[700],
                    size: 24),
                const SizedBox(width: 8),
                Text(
                  languageProvider.isEnglish ? 'Summary' : 'خلاصہ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTotalRow(
              languageProvider.isEnglish ? 'Subtotal:' : 'سب ٹوٹل:',
              _calculateSubtotal().toStringAsFixed(2),
            ),
            const SizedBox(height: 8),
            _buildTotalRow(
              languageProvider.isEnglish ? 'Discount:' : 'رعایت:',
              _discount.toStringAsFixed(2),
              color: Colors.red[600],
            ),
            const Divider(thickness: 2, height: 24),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.indigo[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: _buildTotalRow(
                languageProvider.isEnglish ? 'GRAND TOTAL:' : 'مجموعی کل:',
                _calculateGrandTotal().toStringAsFixed(2),
                isBold: true,
                fontSize: 18,
                color: Colors.indigo[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsSection
      (BuildContext context,
      LanguageProvider languageProvider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_outlined, color: Colors.teal[700],
                    size: 24),
                const SizedBox(width: 8),
                Text(
                  languageProvider.isEnglish
                      ? 'Terms & Conditions'
                      : 'شرائط و ضوابط',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.teal[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _termsController,
              decoration: InputDecoration(
                hintText: languageProvider.isEnglish
                    ? 'Enter terms and conditions...'
                    : 'شرائط و ضوابط درج کریں...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.teal[400]!, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    bool readOnly = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    Function(String)? onChanged,
    VoidCallback? onTap,
  })
  {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: Colors.grey[600]) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.orange, width: 2),
        ),
        filled: true,
        fillColor: readOnly ? Colors.grey[100] : Colors.grey[50],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {
    bool isBold = false,
    double fontSize = 14,
    Color? color,
  })
  {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            fontSize: fontSize,
            color: color,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: fontSize,
            color: color ?? Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(BuildContext context, LanguageProvider languageProvider) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed:_saveQuotation,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[300],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              widget.existingQuotation == null
                  ? (languageProvider.isEnglish ? 'Save Quotation' : ' محفوظ کریں')
                  : (languageProvider.isEnglish ? 'Update Quotation' : 'اپ ڈیٹ کریں'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

      ],
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

}

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget tablet;
  final Widget desktop;

  const ResponsiveLayout({
    Key? key,
    required this.mobile,
    required this.tablet,
    required this.desktop,
  }) : super(key: key);

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 650;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width < 1100 &&
          MediaQuery.of(context).size.width >= 650;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1100;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1100) {
          return desktop;
        } else if (constraints.maxWidth >= 650) {
          return tablet;
        } else {
          return mobile;
        }
      },
    );
  }
}


class CustomAutocomplete extends StatelessWidget {
  final List<Item> items;
  final TextEditingController controller;
  final Function(Item) onSelected;
  final String? selectedCustomerId;
  final bool allowManualEntry;

  const CustomAutocomplete({
    required this.items,
    required this.controller,
    required this.onSelected,
    required this.selectedCustomerId,
    this.allowManualEntry = true,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Item>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<Item>.empty();
        }
        return items.where((item) {
          return item.itemName.toLowerCase().contains(
            textEditingValue.text.toLowerCase(),
          );
        });
      },
      displayStringForOption: (Item item) => item.itemName,
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
        // Sync the parent controller with the autocomplete controller
        if (controller.text != textEditingController.text) {
          textEditingController.text = controller.text;
        }

        return TextField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Item',
            suffixIcon: IconButton(
              icon: Icon(Icons.search),
              onPressed: () => _showItemSearchDialog(context),
            ),
          ),
          onChanged: (value) {
            controller.text = value;
            if (allowManualEntry && value.isNotEmpty) {
              // Create a temporary item for manual entry
              onSelected(Item(
                id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
                itemName: value,
                costPrice: 0.0,
                salePrice: 0.0,
                qtyOnHand: 0,
              ));
            }
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Material(
          elevation: 4,
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: options.length,
            separatorBuilder: (context, index) => Divider(height: 1),
            itemBuilder: (context, index) {
              final option = options.elementAt(index);
              // Show customer price if customer is selected, otherwise show sale price
              final displayPrice = selectedCustomerId != null
                  ? option.getPriceForCustomer(selectedCustomerId)
                  : option.salePrice;

              final isSpecialPrice = selectedCustomerId != null &&
                  displayPrice != option.costPrice;

              return ListTile(
                title: Text(option.itemName),
                subtitle: isSpecialPrice
                    ? Text('Special Price for Customer')
                    : null,
                trailing: Text(
                  '${displayPrice.toStringAsFixed(2)}rs',
                  style: TextStyle(
                    fontWeight: isSpecialPrice ? FontWeight.bold : FontWeight.normal,
                    color: isSpecialPrice ? Colors.green : Colors.black,
                  ),
                ),
                onTap: () {
                  onSelected(option);
                  FocusManager.instance.primaryFocus?.unfocus();
                },
              );
            },
          ),
        );
      },
      onSelected: (Item selection) {
        // Use customer price if customer is selected, otherwise use sale price
        final selectedPrice = selectedCustomerId != null
            ? selection.getPriceForCustomer(selectedCustomerId)
            : selection.salePrice;

        controller.text = selection.itemName;
        onSelected(selection.copyWith(
          costPrice: selectedPrice,
          salePrice: selectedPrice,
        ));
      },
    );
  }

  void _showItemSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            width: double.maxFinite,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Search Items',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    // You can add search filtering here if needed
                  },
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      // Determine which price to show
                      final displayPrice = selectedCustomerId != null
                          ? item.getPriceForCustomer(selectedCustomerId)
                          : item.salePrice;

                      final isSpecialPrice = selectedCustomerId != null &&
                          displayPrice != item.costPrice;

                      return ListTile(
                        leading: GestureDetector(
                          onTap: () {
                            if (item.imageBase64 != null && item.imageBase64!.isNotEmpty) {
                              _showImagePreview(context, item.imageBase64!);
                            }
                          },
                          child: item.imageBase64 != null && item.imageBase64!.isNotEmpty
                              ? CircleAvatar(
                            backgroundImage: MemoryImage(base64Decode(item.imageBase64!)),
                            radius: 20,
                          )
                              : CircleAvatar(
                            backgroundColor: Colors.grey[200],
                            radius: 20,
                            child: Icon(Icons.inventory, size: 20),
                          ),
                        ),
                        title: Text(item.itemName),
                        subtitle: Text('${displayPrice.toStringAsFixed(2)}rs'),
                        trailing: ElevatedButton(
                          onPressed: () {
                            final selectedPrice = selectedCustomerId != null
                                ? item.getPriceForCustomer(selectedCustomerId)
                                : item.salePrice;

                            controller.text = item.itemName;
                            onSelected(item.copyWith(
                              costPrice: selectedPrice,
                              salePrice: selectedPrice,
                            ));
                            Navigator.pop(context);
                          },
                          child: Icon(Icons.add),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showImagePreview(BuildContext context, String base64Image) {
    try {
      final decodedImage = base64Decode(base64Image);

      showDialog(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints: BoxConstraints(maxHeight: 400, maxWidth: 400),
                padding: const EdgeInsets.all(12),
                child: Image.memory(
                  decodedImage,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text('Error loading image'),
                    );
                  },
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to preview image: $e')),
      );
    }
  }
}
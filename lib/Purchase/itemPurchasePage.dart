import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../Provider/lanprovider.dart';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';


class ItemPurchasePage extends StatefulWidget {
  final String? initialVendorId;
  final String? initialVendorName;
  final List<Map<String, dynamic>> initialItems;
  final bool isFromPurchaseOrder; // New flag to indicate if coming from purchase order
  final bool isEditMode; // Add this
  final String? purchaseKey; // Add this

  ItemPurchasePage({
    this.initialVendorId,
    this.initialVendorName,
    this.initialItems = const [],
    this.isFromPurchaseOrder = false, // Default to false
    this.isEditMode = false, // Default to false
    this.purchaseKey, // Can be null for new purchases

  });

  @override
  _ItemPurchasePageState createState() => _ItemPurchasePageState();
}

class _ItemPurchasePageState extends State<ItemPurchasePage> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDateTime;

  // Controllers
  late TextEditingController _vendorSearchController;

  bool _isLoadingItems = false;
  bool _isLoadingVendors = false;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _vendors = [];
  Map<String, dynamic>? _selectedVendor;

  // List to hold multiple purchase items - initialized with 5 empty items
  List<PurchaseItem> _purchaseItems = [];
  // BOM related
  List<Map<String, dynamic>> _bomComponents = [];
  Map<String, double> _wastageRecords = {};


  @override
  void initState() {
    super.initState();
    _selectedDateTime = DateTime.now();
    _vendorSearchController = TextEditingController();
    if (widget.initialItems.isNotEmpty) {
      _purchaseItems = widget.initialItems.map((item) {
        return PurchaseItem()
          ..itemNameController.text = item['itemName']?.toString() ?? ''
          ..quantityController.text = (item['quantity'] as num?)?.toString() ?? '0'
          ..priceController.text = (item['purchasePrice'] as num?)?.toString() ?? '0';
      }).toList();
    } else {
      // Default to 3 empty items if not from purchase order
      _purchaseItems = List.generate(3, (index) => PurchaseItem());
    }
    // Initialize vendor data
    if (widget.initialVendorId != null && widget.initialVendorName != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedVendor = {
              'key': widget.initialVendorId,
              'name': widget.initialVendorName,
            };
            _vendorSearchController.text = widget.initialVendorName!;
          });
        }
      });
    }
    fetchItems();
    fetchVendors();
  }

  @override
  void dispose() {
    _vendorSearchController.dispose();

    // Dispose all item controllers immediately since the widget is being disposed
    for (var item in _purchaseItems) {
      item.dispose();
    }

    super.dispose();
  }


  Future<Map<String, dynamic>?> fetchBomForItem(String itemName) async {
    final item = _items.firstWhere(
          (item) => item['itemName'].toLowerCase() == itemName.toLowerCase(),
      orElse: () => {},
    );

    if (item.isNotEmpty && item['isBOM'] == true) {
      return {
        'itemName': item['itemName'],
        'components': item['components'],
      };
    }
    return null;
  }

  Future<void> recordWastage(String itemName, double quantity, String purchaseId) async {
    final database = FirebaseDatabase.instance.ref();
    try {
      await database.child('wastage').push().set({
        'itemName': itemName,
        'quantity': quantity,
        'date': DateTime.now().toString(),
        'purchaseId': purchaseId,
        'type': 'production',
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error recording wastage: $e')),
        );
      }
    }
  }

  Future<Map<String, double>> checkBomComponentsForWastage(
      String itemName, double purchasedQty)
  async {
    final bom = await fetchBomForItem(itemName);
    Map<String, double> wastage = {};

    if (bom != null && bom['components'] != null) {
      final components = (bom['components'] as Map<dynamic, dynamic>).cast<String, dynamic>();

      for (var componentEntry in components.entries) {
        final componentName = componentEntry.key;
        final componentQty = (componentEntry.value as num).toDouble();

        // Calculate total component quantity needed
        final totalComponentQty = componentQty * purchasedQty;

        // Check current inventory
        final componentItem = _items.firstWhere(
              (item) => item['itemName'].toLowerCase() == componentName.toLowerCase(),
          orElse: () => {},
        );

        if (componentItem.isNotEmpty) {
          final currentQty = componentItem['qtyOnHand']?.toDouble() ?? 0.0;
          if (currentQty < totalComponentQty) {
            // Calculate wastage (negative quantity)
            final wastageQty = totalComponentQty - currentQty;
            wastage[componentName] = wastageQty;
          }
        }
      }
    }

    return wastage;
  }

  Future<void> fetchVendors() async {
    if (!mounted) return;
    setState(() => _isLoadingVendors = true);
    final database = FirebaseDatabase.instance.ref();
    try {
      final snapshot = await database.child('vendors').get();
      if (snapshot.exists && mounted) {
        final Map<dynamic, dynamic> vendorData = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _vendors = vendorData.entries.map((entry) => {
            'key': entry.key,
            'name': entry.value['name'] ?? '',
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching vendors: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingVendors = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDateTime && mounted) {
      setState(() {
        _selectedDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDateTime.hour,
          _selectedDateTime.minute,
        );
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDateTime = DateTime(
          _selectedDateTime.year,
          _selectedDateTime.month,
          _selectedDateTime.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  void addNewItem() {
    setState(() {
      _purchaseItems.add(PurchaseItem());
    });
  }

  void removeItem(int index) {
    if (_purchaseItems.length <= 1 || index < 0 || index >= _purchaseItems.length) return;

    final itemToRemove = _purchaseItems[index];

// Remove the item and trigger rebuild first
    setState(() {
      _purchaseItems = List.from(_purchaseItems)..removeAt(index);
    });

// Delay disposal slightly to ensure it's not during build
    Future.delayed(Duration(milliseconds: 100), () {
      if (mounted) itemToRemove.dispose();
    });

  }

  double calculateTotal() {
    double total = 0.0;
    for (var item in _purchaseItems) {
      final quantity = double.tryParse(item.quantityController.text) ?? 0.0;
      final price = double.tryParse(item.priceController.text) ?? 0.0;
      total += quantity * price;
    }
    return total;
  }

  void _clearForm() {
    if (!mounted) return;

    // First get references to all items to dispose
    final itemsToDispose = List<PurchaseItem>.from(_purchaseItems);

    // Reset form data
    setState(() {
      _purchaseItems = List.generate(3, (index) => PurchaseItem());
      _selectedVendor = null;
      _selectedDateTime = DateTime.now();
    });

    // Clear text controllers
    _vendorSearchController.clear();

    // Dispose the old controllers in the next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (var item in itemsToDispose) {
        item.dispose();
      }
    });
  }


  Widget tableHeader(String text) => Padding(
    padding: const EdgeInsets.all(8.0),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Color(0xFFE65100),
      ),
    ),
  );

  Future<Uint8List> _generatePdf(BuildContext context) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final total = calculateTotal();
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text(
                  widget.isFromPurchaseOrder
                      ? languageProvider.isEnglish ? 'Purchase Receipt' : 'رسید خرید'
                      : languageProvider.isEnglish ? 'Purchase Invoice' : 'انوائس خرید',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    languageProvider.isEnglish ? 'Vendor: ' : 'فروش: ',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(_selectedVendor?['name'] ?? ''),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    languageProvider.isEnglish ? 'Date: ' : 'تاریخ: ',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(dateFormat.format(_selectedDateTime)),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                context: context,
                border: pw.TableBorder.all(),
                headerDecoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#FF8A65'),
                ),
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                ),
                headers: [
                  languageProvider.isEnglish ? 'No.' : 'نمبر',
                  languageProvider.isEnglish ? 'Item Name' : 'آئٹم کا نام',
                  languageProvider.isEnglish ? 'Qty' : 'مقدار',
                  languageProvider.isEnglish ? 'Price' : 'قیمت',
                  languageProvider.isEnglish ? 'Total' : 'کل',
                ],
                data: _purchaseItems.where((item) =>
                item.itemNameController.text.isNotEmpty &&
                    item.quantityController.text.isNotEmpty &&
                    item.priceController.text.isNotEmpty).map((item) {
                  final quantity = double.tryParse(item.quantityController.text) ?? 0.0;
                  final price = double.tryParse(item.priceController.text) ?? 0.0;
                  final itemTotal = quantity * price;

                  return [
                    '${_purchaseItems.indexOf(item) + 1}',
                    item.itemNameController.text,
                    quantity.toStringAsFixed(2),
                    price.toStringAsFixed(2),
                    itemTotal.toStringAsFixed(2),
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    '${languageProvider.isEnglish ? 'Grand Total: ' : 'کل کل: '} ${total.toStringAsFixed(2)} PKR',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
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

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final total = calculateTotal();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditMode
              ? languageProvider.isEnglish ? 'Edit Purchase' : 'خریداری میں ترمیم کریں'
              : widget.isFromPurchaseOrder
              ? languageProvider.isEnglish ? 'Receive Items' : 'آئٹمز وصول کریں'
              : languageProvider.isEnglish ? 'Purchase Items' : 'آئٹمز خریداری',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
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
        centerTitle: true,
        actions: [
          IconButton(
              onPressed: () async {
                try {
                  final pdfBytes = await _generatePdf(context);
                  await Printing.layoutPdf(
                    onLayout: (format) => pdfBytes,
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        languageProvider.isEnglish
                            ? 'Error generating PDF: $e'
                            : 'PDF بنانے میں خرابی: $e',
                      ),
                    ),
                  );
                }
              },
              icon: Icon(Icons.print,color: Colors.white,))
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF3E0),
              Color(0xFFFFE0B2),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Vendor Field
                  Text(
                    languageProvider.isEnglish ? 'Search Vendor' : 'وینڈر تلاش کریں',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE65100),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Autocomplete<Map<String, dynamic>>(
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) return const Iterable.empty();
                      return _vendors.where((vendor) =>
                          vendor['name'].toLowerCase().contains(textEditingValue.text.toLowerCase()));
                    },
                    displayStringForOption: (vendor) => vendor['name'],
                    onSelected: (vendor) {
                      setState(() {
                        _selectedVendor = vendor;
                      });
                    },
                    fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                      _vendorSearchController = controller;
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: languageProvider.isEnglish ? 'Search Vendor' : 'وینڈر تلاش کریں',
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFFF8A65)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFFF8A65)),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
// Purchase Items Section
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                languageProvider.isEnglish ? 'Purchase Items' : 'خریداری کے آئٹمز',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE65100),
                                  fontSize: 16,
                                ),
                              ),
                              ElevatedButton(
                                onPressed: addNewItem,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFFFF8A65),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add, size: 16, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text(
                                      languageProvider.isEnglish ? 'Add Item' : 'آئٹم شامل کریں',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),

                          Table(
                            columnWidths: const {
                              0: FixedColumnWidth(40),
                              1: FlexColumnWidth(2),
                              2: FlexColumnWidth(1.5),
                              3: FlexColumnWidth(1.5),
                              4: FixedColumnWidth(40),
                            },
                            border: TableBorder.all(color: Colors.orange.shade100, width: 1),
                            children: [
                              // Header
                              TableRow(
                                decoration: BoxDecoration(color: Colors.orange.shade50),
                                children: [
                                  tableHeader('No.'),
                                  tableHeader(languageProvider.isEnglish ? 'Item Name' : 'آئٹم کا نام'),
                                  tableHeader(languageProvider.isEnglish ? 'Qty' : 'مقدار'),
                                  tableHeader(languageProvider.isEnglish ? 'Price' : 'قیمت'),
                                  SizedBox(),
                                ],
                              ),

                              // Item Rows
                              ..._purchaseItems.asMap().entries.map((entry) {
                                final index = entry.key;
                                final item = entry.value;

                                return TableRow(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ),

                                    // Autocomplete Item Name
                                    Padding(
                                      padding: const EdgeInsets.all(6.0),
                                      child: Autocomplete<Map<String, dynamic>>(
                                        initialValue: TextEditingValue(text: item.itemNameController.text),
                                        optionsBuilder: (textEditingValue) {
                                          if (textEditingValue.text.isEmpty) return const Iterable.empty();
                                          return _items
                                              .where((i) => i['itemName']
                                              .toLowerCase()
                                              .contains(textEditingValue.text.toLowerCase()))
                                              .cast<Map<String, dynamic>>();
                                        },
                                        displayStringForOption: (i) => i['itemName'],
                                        onSelected: (selectedItem) {
                                          setState(() {
                                            item.selectedItem = selectedItem;
                                            item.itemNameController.text = selectedItem['itemName'];
                                            item.priceController.text = selectedItem['costPrice'].toStringAsFixed(2);
                                          });
                                        },
                                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                          controller.text = item.itemNameController.text;
                                          return TextFormField(
                                            controller: controller,
                                            focusNode: focusNode,
                                            onChanged: (value) {
                                              item.itemNameController.text = value;
                                            },
                                            decoration: InputDecoration(
                                              isDense: true,
                                              border: OutlineInputBorder(),
                                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                              hintText: languageProvider.isEnglish
                                                  ? 'Enter item name'
                                                  : 'آئٹم کا نام درج کریں',
                                            ),
                                          );
                                        },
                                      ),
                                    ),

                                    // Quantity Field
                                    Padding(
                                      padding: const EdgeInsets.all(6.0),
                                      child: TextFormField(
                                        controller: item.quantityController,
                                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                                        onChanged: (_) => setState(() {}),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                        ),
                                      ),
                                    ),

                                    // Price Field
                                    Padding(
                                      padding: const EdgeInsets.all(6.0),
                                      child: TextFormField(
                                        controller: item.priceController,
                                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                                        onChanged: (_) => setState(() {}),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                        ),
                                      ),
                                    ),

                                    // Delete Icon
                                    Center(
                                      child: IconButton(
                                        icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                                        onPressed: _purchaseItems.length > 1 ? () => removeItem(index) : null,
                                        tooltip: 'Remove item',
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.calendar_today, size: 18, color: Colors.white),
                          label: Text(
                            languageProvider.isEnglish ? 'Select Date' : 'تاریخ منتخب کریں',
                            style: TextStyle(color: Colors.white),
                          ),
                          onPressed: () => _selectDate(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFFF8A65),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.access_time, size: 18, color: Colors.white),
                          label: Text(
                            languageProvider.isEnglish ? 'Select Time' : 'وقت منتخب کریں',
                            style: TextStyle(color: Colors.white),
                          ),
                          onPressed: () => _selectTime(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFFF8A65),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    languageProvider.isEnglish
                        ? 'Selected: ${DateFormat('yyyy-MM-dd HH:mm').format(_selectedDateTime)}'
                        : 'منتخب شدہ: ${DateFormat('yyyy-MM-dd HH:mm').format(_selectedDateTime)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFFE65100),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Grand Total Display
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Color(0xFFFF8A65)),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          languageProvider.isEnglish ? 'Grand Total:' : 'کل کل:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE65100),
                          ),
                        ),
                        Text(
                          '${total.toStringAsFixed(2)} PKR',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE65100),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),

                  // Save Purchase Button
                  Center(
                    child: ElevatedButton(
                      onPressed: savePurchase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFFF8A65),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 16,horizontal: 10),
                      ),
                      child: Text(
                        widget.isFromPurchaseOrder
                            ? languageProvider.isEnglish ? 'Receive Items' : 'آئٹمز وصول کریں'
                            : languageProvider.isEnglish ? 'Record Purchase' : 'خریداری ریکارڈ کریں',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<Map<String, Map<String, dynamic>>> getBomComponents(String itemName, double purchasedQty) async {
    final database = FirebaseDatabase.instance.ref();
    final snapshot = await database.child('items').orderByChild('itemName').equalTo(itemName).get();

    if (snapshot.exists) {
      final itemsData = snapshot.value as Map<dynamic, dynamic>;

      for (final itemEntry in itemsData.entries) {
        final item = itemEntry.value;
        if (item['itemName'] == itemName && item['isBOM'] == true) {
          final components = item['components'];

          if (components is List) {
            // Handle list format with component objects
            final componentMap = <String, Map<String, dynamic>>{};
            for (int i = 0; i < components.length; i++) {
              final component = components[i];
              if (component is Map && component['id'] != null) {
                final componentName = component['name']?.toString() ?? '';
                final componentId = component['id'].toString();
                final componentQty = (component['quantity'] as num?)?.toDouble() ?? 0.0;

                componentMap[componentId] = {
                  'name': componentName,
                  'quantity': componentQty * purchasedQty,
                  'unit': component['unit']?.toString() ?? '',
                };
              }
            }
            return componentMap;
          }
        }
      }
    }

    return {};
  }


  Future<void> savePurchase() async {
    if (!mounted) return;

    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    if (_formKey.currentState!.validate()) {
      if (_selectedVendor == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(languageProvider.isEnglish
              ? 'Please select a vendor'
              : 'براہ کرم فروش منتخب کریں')),
        );
        return;
      }

      List<PurchaseItem> validItems = _purchaseItems.where((purchaseItem) =>
      purchaseItem.itemNameController.text.isNotEmpty &&
          purchaseItem.quantityController.text.isNotEmpty &&
          purchaseItem.priceController.text.isNotEmpty).toList();

      if (validItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(languageProvider.isEnglish
              ? 'Please add at least one item'
              : 'براہ کرم کم از کم ایک آئٹم شامل کریں')),
        );
        return;
      }

      try {
        final database = FirebaseDatabase.instance.ref();
        String vendorKey = _selectedVendor!['key'];
        _wastageRecords.clear();

        final newPurchase = {
          'items': validItems.map((purchaseItem) => {
            'itemName': purchaseItem.itemNameController.text,
            'quantity': double.tryParse(purchaseItem.quantityController.text) ?? 0.0,
            'purchasePrice': double.tryParse(purchaseItem.priceController.text) ?? 0.0,
            'total': (double.tryParse(purchaseItem.quantityController.text) ?? 0.0) *
                (double.tryParse(purchaseItem.priceController.text) ?? 0.0),
            'isBOM': _items.any((item) =>
            item['itemName'].toLowerCase() ==
                purchaseItem.itemNameController.text.toLowerCase() &&
                item['isBOM'] == true),
          }).toList(),
          'vendorId': vendorKey,
          'vendorName': _selectedVendor!['name'],
          'grandTotal': calculateTotal(),
          'timestamp': _selectedDateTime.toString(),
          'type': 'credit',
          'hasBOM': validItems.any((purchaseItem) =>
              _items.any((inventoryItem) =>
              inventoryItem['itemName'].toLowerCase() ==
                  purchaseItem.itemNameController.text.toLowerCase() &&
                  inventoryItem['isBOM'] == true)),
        };

        final purchaseRef = database.child('purchases').push();
        final purchaseId = purchaseRef.key;
        await purchaseRef.set(newPurchase);

        final componentConsumptionRef = database.child('componentConsumption').child(purchaseId!);

        Map<String, Map<String, dynamic>> missingComponents = {};

        for (var purchaseItem in validItems) {
          String itemName = purchaseItem.itemNameController.text;
          double purchasedQty = double.tryParse(purchaseItem.quantityController.text) ?? 0.0;

          var existingItem = _items.firstWhere(
                (inventoryItem) =>
            inventoryItem['itemName'].toLowerCase() == itemName.toLowerCase(),
            orElse: () => {},
          );

          if (existingItem.isNotEmpty) {
            String itemKey = existingItem['key'];
            double currentQty = existingItem['qtyOnHand']?.toDouble() ?? 0.0;
            double purchasePrice = double.tryParse(purchaseItem.priceController.text) ?? 0.0;

            await database.child('items').child(itemKey).update({
              'qtyOnHand': currentQty + purchasedQty,
              'costPrice': purchasePrice,
            });

            // Handle BOM components more safely
            if (existingItem['isBOM'] == true) {
              dynamic componentsData = existingItem['components'];
              Map<String, dynamic> components = {};

              // Safely convert components data to a map
              if (componentsData is Map) {
                components = componentsData.cast<String, dynamic>();
              } else if (componentsData is List) {
                // Handle list format if needed
                for (int i = 0; i < componentsData.length; i += 2) {
                  if (i + 1 < componentsData.length) {
                    components[componentsData[i].toString()] = componentsData[i + 1];
                  }
                }
              }

              Map<String, dynamic> consumptionRecord = {
                'bomItemName': itemName,
                'bomItemKey': itemKey,
                'quantityProduced': purchasedQty,
                'timestamp': _selectedDateTime.toString(),
                'components': {},
              };

              for (var componentEntry in components.entries) {
                String componentName = componentEntry.key;
                double qtyPerUnit = 0.0;

                // Safely parse the quantity per unit
                if (componentEntry.value is num) {
                  qtyPerUnit = (componentEntry.value as num).toDouble();
                } else if (componentEntry.value is String) {
                  qtyPerUnit = double.tryParse(componentEntry.value as String) ?? 0.0;
                }

                double totalQtyRequired = qtyPerUnit * purchasedQty;

                var componentItem = _items.firstWhere(
                      (item) => item['itemName'].toLowerCase() == componentName.toLowerCase(),
                  orElse: () => {},
                );

                if (componentItem.isNotEmpty) {
                  String componentKey = componentItem['key'];
                  double currentQty = componentItem['qtyOnHand']?.toDouble() ?? 0.0;

                  if (currentQty < totalQtyRequired) {
                    missingComponents[componentKey] = {
                      'name': componentName,
                      'requiredQty': totalQtyRequired,
                      'availableQty': currentQty,
                      'unit': componentItem['unit'] ?? '',
                    };
                  }

                  consumptionRecord['components'][componentName] = {
                    'required': totalQtyRequired,
                    'used': currentQty >= totalQtyRequired ? totalQtyRequired : currentQty,
                    'remaining': currentQty >= totalQtyRequired
                        ? currentQty - totalQtyRequired
                        : 0.0,
                  };
                }
              }

              await componentConsumptionRef.set(consumptionRecord);
            }
          }
        }

        if (missingComponents.isNotEmpty) {
          bool proceed = await showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text(languageProvider.isEnglish
                    ? 'Insufficient Components'
                    : 'اجزاء کی کمی'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView(
                    shrinkWrap: true,
                    children: missingComponents.values.map((comp) {
                      return ListTile(
                        title: Text('${comp['name']} (${comp['unit']})'),
                        subtitle: Text(languageProvider.isEnglish
                            ? 'Required: ${comp['requiredQty']}, Available: ${comp['availableQty']}'
                            : 'درکار: ${comp['requiredQty']}, دستیاب: ${comp['availableQty']}'),
                      );
                    }).toList(),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(languageProvider.isEnglish ? 'Proceed Anyway' : 'پھر بھی جاری رکھیں'),
                  ),
                ],
              );
            },
          );

          if (!proceed) return;
        }

        // Deduct components (partial or full) and record consumption/wastage
        for (var purchaseItem in validItems) {
          String itemName = purchaseItem.itemNameController.text;
          double purchasedQty = double.tryParse(purchaseItem.quantityController.text) ?? 0.0;

          var existingItem = _items.firstWhere(
                (inventoryItem) =>
            inventoryItem['itemName'].toLowerCase() == itemName.toLowerCase(),
            orElse: () => {},
          );

          if (existingItem.isNotEmpty && existingItem['isBOM'] == true) {
            dynamic componentsData = existingItem['components'];
            Map<String, dynamic> components = {};

            if (componentsData is Map) {
              components = componentsData.cast<String, dynamic>();
            } else if (componentsData is List) {
              for (int i = 0; i < componentsData.length; i += 2) {
                if (i + 1 < componentsData.length) {
                  components[componentsData[i].toString()] = componentsData[i + 1];
                }
              }
            }

            for (var componentEntry in components.entries) {
              String componentName = componentEntry.key;
              double qtyPerUnit = 0.0;

              if (componentEntry.value is num) {
                qtyPerUnit = (componentEntry.value as num).toDouble();
              } else if (componentEntry.value is String) {
                qtyPerUnit = double.tryParse(componentEntry.value as String) ?? 0.0;
              }

              double totalQtyRequired = qtyPerUnit * purchasedQty;

              var componentItem = _items.firstWhere(
                    (item) => item['itemName'].toLowerCase() == componentName.toLowerCase(),
                orElse: () => {},
              );

              if (componentItem.isNotEmpty) {
                String componentKey = componentItem['key'];
                double currentQty = componentItem['qtyOnHand']?.toDouble() ?? 0.0;
                double qtyToDeduct = currentQty < totalQtyRequired ? currentQty : totalQtyRequired;

                await database.child('items').child(componentKey).update({
                  'qtyOnHand': currentQty - qtyToDeduct,
                });

                if (qtyToDeduct < totalQtyRequired) {
                  await database.child('wastage').push().set({
                    'itemName': componentName,
                    'quantity': totalQtyRequired - qtyToDeduct,
                    'date': DateTime.now().toString(),
                    'purchaseId': purchaseId,
                    'type': 'component_shortage',
                    'relatedBOM': itemName,
                  });
                }
              }
            }
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(languageProvider.isEnglish
                ? 'Purchase recorded successfully!'
                : 'خریداری کامیابی سے ریکارڈ ہو گئی!')),
          );
          _clearForm();
        }
      } catch (error) {
        print('Purchase error: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(languageProvider.isEnglish
                ? 'Failed to record purchase: ${error.toString()}'
                : 'خریداری ریکارڈ کرنے میں ناکامی: ${error.toString()}')),
          );
        }
      }
    }
  }


  Future<List<Map<String, dynamic>>> getComponentConsumptionHistory(String bomItemKey) async {
    final database = FirebaseDatabase.instance.ref();
    final snapshot = await database.child('componentConsumption')
        .orderByChild('bomItemKey')
        .equalTo(bomItemKey)
        .get();

    if (snapshot.exists) {
      Map<dynamic, dynamic> consumptionData = snapshot.value as Map<dynamic, dynamic>;
      return consumptionData.entries.map((entry) {
        // Convert the dynamic keys to String keys
        Map<String, dynamic> entryValue = {};
        if (entry.value is Map) {
          entryValue = (entry.value as Map).cast<String, dynamic>();
        }

        return {
          'key': entry.key.toString(), // Ensure key is String
          ...entryValue,
        };
      }).toList();
    }
    return [];
  }

  Future<void> fetchItems() async {
    if (!mounted) return;
    setState(() => _isLoadingItems = true);
    final database = FirebaseDatabase.instance.ref();
    try {
      final snapshot = await database.child('items').get();
      if (snapshot.exists && mounted) {
        dynamic itemData = snapshot.value;
        Map<dynamic, dynamic> itemsMap = {};

        // Handle both Map and List cases for items
        if (itemData is Map) {
          itemsMap = itemData;
        } else if (itemData is List) {
          // Convert list to map with index keys if we get a list
          itemsMap = {for (var i = 0; i < itemData.length; i++) i.toString(): itemData[i]};
        }

        setState(() {
          _items = itemsMap.entries.map((entry) {
            // Safely handle components data
            dynamic componentsData = entry.value['components'];
            Map<String, dynamic> componentsMap = {};

            if (componentsData != null) {
              if (componentsData is Map) {
                componentsMap = componentsData.cast<String, dynamic>();
              } else if (componentsData is List) {
                // Convert list to map if components is stored as a list
                // This assumes the list alternates between component name and quantity
                for (int i = 0; i < componentsData.length; i += 2) {
                  if (i + 1 < componentsData.length) {
                    componentsMap[componentsData[i].toString()] = componentsData[i + 1];
                  }
                }
              }
            }

            return {
              'key': entry.key,
              'itemName': entry.value['itemName']?.toString() ?? '',
              'costPrice': (entry.value['costPrice'] as num?)?.toDouble() ?? 0.0,
              'qtyOnHand': (entry.value['qtyOnHand'] as num?)?.toDouble() ?? 0.0,
              'isBOM': entry.value['isBOM'] == true,
              'components': componentsMap,
            };
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching items: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingItems = false);
      }
    }
  }

  void showComponentConsumption(String bomItemName, String bomItemKey) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final consumptionHistory = await getComponentConsumptionHistory(bomItemKey);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${languageProvider.isEnglish ? 'Component Consumption for' : 'اجزاء کی کھپت برائے'} $bomItemName'),
        content: SizedBox(
          width: double.maxFinite,
          child: consumptionHistory.isEmpty
              ? Text(languageProvider.isEnglish
              ? 'No consumption history found'
              : 'کوئی کھپت کی تاریخ دستیاب نہیں')
              : ListView.builder(
            shrinkWrap: true,
            itemCount: consumptionHistory.length,
            itemBuilder: (context, index) {
              final record = consumptionHistory[index];
              return ExpansionTile(
                title: Text(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(record['timestamp']))),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${languageProvider.isEnglish ? 'Quantity Produced' : 'تعداد پیدا ہوئی'}: ${record['quantityProduced']}'),
                        SizedBox(height: 10),
                        Text('${languageProvider.isEnglish ? 'Components Used' : 'استعمال شدہ اجزاء'}:'),
                        ...(record['components'] as Map).entries.map((component) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text('- ${component.key}: ${component.value['quantityUsed']}'),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
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


  Future<Map<String, dynamic>> checkBomFeasibility(String bomItemName, double quantity) async {
    final bomItem = _items.firstWhere(
          (item) => item['itemName'].toLowerCase() == bomItemName.toLowerCase(),
      orElse: () => {},
    );

    if (bomItem.isEmpty || bomItem['isBOM'] != true) {
      return {'feasible': true, 'missingComponents': {}};
    }

    Map<String, dynamic> components = bomItem['components'] ?? {};
    Map<String, dynamic> result = {
      'feasible': true,
      'missingComponents': {},
      'totalRequired': {},
    };

    for (var componentEntry in components.entries) {
      String componentName = componentEntry.key;
      double componentQtyPerUnit = (componentEntry.value as num).toDouble();
      double totalComponentQty = componentQtyPerUnit * quantity;

      var componentItem = _items.firstWhere(
            (item) => item['itemName'].toLowerCase() == componentName.toLowerCase(),
        orElse: () => {},
      );

      if (componentItem.isEmpty) {
        result['feasible'] = false;
        result['missingComponents'][componentName] = {
          'required': totalComponentQty,
          'available': 0.0,
          'shortage': totalComponentQty,
        };
      } else {
        double availableQty = componentItem['qtyOnHand']?.toDouble() ?? 0.0;
        result['totalRequired'][componentName] = totalComponentQty;

        if (availableQty < totalComponentQty) {
          result['feasible'] = false;
          result['missingComponents'][componentName] = {
            'required': totalComponentQty,
            'available': availableQty,
            'shortage': totalComponentQty - availableQty,
          };
        }
      }
    }

    return result;
  }


}

class PurchaseItem {
  late TextEditingController itemNameController;
  late TextEditingController quantityController;
  late TextEditingController priceController;
  Map<String, dynamic>? selectedItem;

  PurchaseItem() {
    itemNameController = TextEditingController();
    quantityController = TextEditingController();
    priceController = TextEditingController();
    selectedItem = null; // Explicitly initialize

  }

  void dispose() {
    itemNameController.dispose();
    quantityController.dispose();
    priceController.dispose();
  }
}
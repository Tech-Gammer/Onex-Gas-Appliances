import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../Provider/lanprovider.dart';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';


class PurchaseOrderPage extends StatefulWidget {
  final String? orderKey;

  PurchaseOrderPage({this.orderKey});

  @override
  _PurchaseOrderPageState createState() => _PurchaseOrderPageState();
}

class _PurchaseOrderPageState extends State<PurchaseOrderPage> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _orderDate;
  late DateTime _expectedDeliveryDate;

  // Controllers
  late TextEditingController _itemSearchController;
  late TextEditingController _vendorSearchController;
  String? _status = 'pending';

  bool _isLoadingItems = false;
  bool _isLoadingVendors = false;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _vendors = [];
  Map<String, dynamic>? _selectedVendor;
  bool _isLoadingOrder = false;
  // List to hold multiple order items
  List<PurchaseOrderItem> _orderItems = List.generate(3, (index) => PurchaseOrderItem());
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _orderDate = DateTime.now();
    _expectedDeliveryDate = DateTime.now().add(Duration(days: 7));
    _itemSearchController = TextEditingController();
    _vendorSearchController = TextEditingController();

    // Initialize with 3 empty items for new orders
    if (widget.orderKey == null) {
      _orderItems = List.generate(3, (index) => PurchaseOrderItem());
    }

    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      fetchItems(),
      fetchVendors(),
    ]);

    // Load existing order if editing - do this after items and vendors are loaded
    if (widget.orderKey != null) {
      await fetchPurchaseOrder();
    }
  }

  @override
  void dispose() {
    _itemSearchController.dispose();
    _vendorSearchController.dispose();
    _notesController.dispose();
    for (var item in _orderItems) {
      item.quantityController.dispose();
      item.priceController.dispose();
      item.searchController.dispose();
    }
    super.dispose();
  }

  Future<Uint8List> _generatePdf() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    final pdf = pw.Document();

    // Add a page with all the purchase order details
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          // Header
          pw.Header(
            level: 0,
            child: pw.Text(
              languageProvider.isEnglish ? 'Purchase Order' : 'خریداری کا آرڈر',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),

          // Vendor Information
          pw.SizedBox(height: 20),
          pw.Text(
            languageProvider.isEnglish ? 'Vendor Information' : 'فروش کی معلومات',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(_selectedVendor?['name'] ?? ''),
          if (_selectedVendor?['contact'] != null && _selectedVendor?['contact'].isNotEmpty)
            pw.Text(_selectedVendor?['contact'] ?? ''),

          // Order Dates
          pw.SizedBox(height: 20),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(languageProvider.isEnglish ? 'Order Date:' : 'آرڈر کی تاریخ:'),
                    pw.Text(DateFormat('yyyy-MM-dd').format(_orderDate)),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(languageProvider.isEnglish ? 'Expected Delivery:' : 'متوقع ترسیل:'),
                    pw.Text(DateFormat('yyyy-MM-dd').format(_expectedDeliveryDate)),
                  ],
                ),
              ),
            ],
          ),

          // Order Items Table
          pw.SizedBox(height: 20),
          pw.Text(
            languageProvider.isEnglish ? 'Order Items' : 'آرڈر آئٹمز',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
            context: context,
            border: pw.TableBorder.all(),
            headers: [
              languageProvider.isEnglish ? 'No.' : 'نمبر',
              languageProvider.isEnglish ? 'Item Name' : 'آئٹم کا نام',
              languageProvider.isEnglish ? 'Qty' : 'مقدار',
              languageProvider.isEnglish ? 'Price' : 'قیمت',
              languageProvider.isEnglish ? 'Total' : 'کل',
            ],
            data: _orderItems
                .where((item) => item.selectedItem != null)
                .map((item) {
              final quantity = double.tryParse(item.quantityController.text) ?? 0.0;
              final price = double.tryParse(item.priceController.text) ?? 0.0;
              final total = quantity * price;

              return [
                (_orderItems.indexOf(item) + 1).toString(),
                item.selectedItem?['itemName'] ?? '',
                quantity.toStringAsFixed(2),
                price.toStringAsFixed(2),
                total.toStringAsFixed(2),
              ];
            })
                .toList(),
          ),

          // Order Summary
          pw.SizedBox(height: 20),
          pw.Text(
            languageProvider.isEnglish ? 'Order Summary' : 'آرڈر کا خلاصہ',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(languageProvider.isEnglish ? 'Subtotal:' : 'ذیلی کل:'),
              pw.Text('${calculateTotal().toStringAsFixed(2)} PKR'),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                languageProvider.isEnglish ? 'Grand Total:' : 'کل کل:',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                '${calculateTotal().toStringAsFixed(2)} PKR',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),

          // Notes
          if (_notesController.text.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              languageProvider.isEnglish ? 'Notes' : 'نوٹس',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(_notesController.text),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  Future<void> fetchPurchaseOrder() async {
    setState(() => _isLoadingOrder = true);
    try {
      final snapshot = await FirebaseDatabase.instance.ref()
          .child('purchaseOrders')
          .child(widget.orderKey!)
          .get();

      if (snapshot.exists) {
        final orderData = snapshot.value as Map<dynamic, dynamic>;

        setState(() {
          // Handle potential null values with default values
          _orderDate = DateTime.parse(orderData['orderDate']?.toString() ?? DateTime.now().toString());
          _expectedDeliveryDate = DateTime.parse(orderData['expectedDeliveryDate']?.toString() ?? DateTime.now().add(Duration(days: 7)).toString());
          _status = orderData['status']?.toString() ?? 'pending';
          _notesController.text = orderData['notes']?.toString() ?? '';

          // Find and set the vendor
          final vendorId = orderData['vendorId']?.toString();
          if (vendorId != null) {
            _selectedVendor = _vendors.firstWhere(
                  (v) => v['key'] == vendorId,
              orElse: () => {
                'key': vendorId,
                'name': orderData['vendorName']?.toString() ?? 'Unknown Vendor',
                'contact': orderData['vendorContact']?.toString() ?? '',
              },
            );
          }

          // Set items - handle potential null items list
          final List<dynamic> items = (orderData['items'] as List<dynamic>?) ?? [];
          _orderItems = items.map((item) {
            final orderItem = PurchaseOrderItem();
            orderItem.selectedItem = {
              'key': item['itemId']?.toString() ?? '',
              'itemName': item['itemName']?.toString() ?? 'Unknown Item',
              'costPrice': (item['price'] as num?)?.toDouble() ?? 0.0,
              'qtyOnHand': 0.0, // Will be updated when items are loaded
            };
            orderItem.quantityController.text = (item['quantity']?.toString() ?? '0');
            orderItem.priceController.text = (item['price']?.toString() ?? '0');
            orderItem.searchController.text = orderItem.selectedItem!['itemName']; // Add this line
            return orderItem;
          }).toList();
        });
      }
    } finally {
      setState(() => _isLoadingOrder = false);
    }
  }

  Future<void> fetchItems() async {
    setState(() => _isLoadingItems = true);
    final database = FirebaseDatabase.instance.ref();
    try {
      final snapshot = await database.child('items').get();
      if (snapshot.exists) {
        final Map<dynamic, dynamic> itemData = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _items = itemData.entries.map((entry) => {
            'key': entry.key,
            'itemName': entry.value['itemName'],
            'costPrice': (entry.value['costPrice'] as num?)?.toDouble() ?? 0.0,
            'qtyOnHand': (entry.value['qtyOnHand'] as num?)?.toDouble() ?? 0.0,
          }).toList();

          // Update qtyOnHand for existing order items
          if (widget.orderKey != null) {
            for (var orderItem in _orderItems) {
              if (orderItem.selectedItem != null) {
                final item = _items.firstWhere(
                      (i) => i['key'] == orderItem.selectedItem!['key'],
                  orElse: () => {'qtyOnHand': 0.0},
                );
                orderItem.selectedItem!['qtyOnHand'] = item['qtyOnHand'];
              }
            }
          }
        });
      }
    } finally {
      setState(() => _isLoadingItems = false);
    }
  }

  Future<void> fetchVendors() async {
    setState(() => _isLoadingVendors = true);
    final database = FirebaseDatabase.instance.ref();
    try {
      final snapshot = await database.child('vendors').get();
      if (snapshot.exists) {
        final Map<dynamic, dynamic> vendorData = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _vendors = vendorData.entries.map((entry) => {
            'key': entry.key,
            'name': entry.value['name'],
            'contact': entry.value['contact'] ?? '',
          }).toList();

          // Update selected vendor if it exists
          if (_selectedVendor != null) {
            _selectedVendor = _vendors.firstWhere(
                  (v) => v['key'] == _selectedVendor!['key'],
              orElse: () => _selectedVendor!,
            );
          }
        });
      }
    } finally {
      setState(() => _isLoadingVendors = false);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isOrderDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isOrderDate ? _orderDate : _expectedDeliveryDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (picked != null) {
      setState(() {
        if (isOrderDate) {
          _orderDate = picked;
        } else {
          _expectedDeliveryDate = picked;
        }
      });
    }
  }

  void addNewItem() {
    setState(() {
      _orderItems.add(PurchaseOrderItem());
    });
  }

  void removeItem(int index) {
    setState(() {
      _orderItems[index].quantityController.dispose();
      _orderItems[index].priceController.dispose();
      _orderItems[index].searchController.dispose();
      _orderItems.removeAt(index);
    });
  }

  double calculateTotal() {
    double total = 0.0;
    for (var item in _orderItems) {
      if (item.selectedItem != null) {
        try {
          final quantity = double.tryParse(item.quantityController.text) ?? 0.0;
          final price = double.tryParse(item.priceController.text) ?? 0.0;
          total += quantity * price;
        } catch (e) {
          // Handle any parsing errors
          print('Error calculating total: $e');
        }
      }
    }
    return total;
  }

  void savePurchaseOrder() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedVendor == null || _selectedVendor?['key'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(languageProvider.isEnglish
              ? 'Please select a vendor'
              : 'براہ کرم فروش منتخب کریں')),
        );
        return;
      }

      // Filter and validate items
      final validItems = _orderItems.where((item) {
        return item.selectedItem != null &&
            item.selectedItem?['key'] != null &&
            item.quantityController.text.isNotEmpty &&
            item.priceController.text.isNotEmpty;
      }).toList();

      if (validItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(languageProvider.isEnglish
              ? 'Please add at least one valid item'
              : 'براہ کرم کم از کم ایک درست آئٹم شامل کریں')),
        );
        return;
      }

      try {
        final database = FirebaseDatabase.instance.ref();
        final vendorKey = _selectedVendor!['key'] as String;

        // Prepare items data with null checks
        final itemsData = validItems.map((item) {
          final quantity = double.tryParse(item.quantityController.text) ?? 0.0;
          final price = double.tryParse(item.priceController.text) ?? 0.0;

          return {
            'itemId': item.selectedItem!['key'] as String,
            'itemName': item.selectedItem!['itemName'] as String,
            'quantity': quantity,
            'price': price,
            'total': quantity * price,
          };
        }).toList();

        // Calculate grand total
        final grandTotal = itemsData.fold(0.0, (sum, item) => sum + (item['total'] as double));

        // Prepare order data
        final purchaseOrderData = {
          'items': itemsData,
          'vendorId': vendorKey,
          'vendorName': _selectedVendor?['name'] as String? ?? '',
          'vendorContact': _selectedVendor?['contact'] as String? ?? '',
          'grandTotal': grandTotal,
          'orderDate': _orderDate.toString(),
          'expectedDeliveryDate': _expectedDeliveryDate.toString(),
          'notes': _notesController.text,
          'status': _status ?? 'pending',
          'updatedAt': DateTime.now().toString(),
        };

        // Add createdAt for new orders
        if (widget.orderKey == null) {
          purchaseOrderData['createdAt'] = DateTime.now().toString();
        }

        // Save to Firebase
        if (widget.orderKey == null) {
          await database.child('purchaseOrders').push().set(purchaseOrderData);
        } else {
          await database.child('purchaseOrders').child(widget.orderKey!).update(purchaseOrderData);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(languageProvider.isEnglish
              ? 'Purchase order ${widget.orderKey == null ? 'created' : 'updated'} successfully!'
              : 'خریداری کا آرڈر ${widget.orderKey == null ? 'بن گیا' : 'اپ ڈیٹ ہو گیا'}!')),
        );

        Navigator.pop(context);
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${languageProvider.isEnglish
              ? 'Error saving order:'
              : 'آرڈر محفوظ کرنے میں خرابی:'} $error')),
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final total = calculateTotal();
    if (_isLoadingOrder) {
      return Scaffold(
        appBar: AppBar(
          title: Text(languageProvider.isEnglish ? 'Loading...' : 'لوڈ ہو رہا ہے...'),
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.orderKey == null
              ? languageProvider.isEnglish
              ? 'Create Purchase Order'
              : 'خریداری کا آرڈر بنائیں'
              : languageProvider.isEnglish
              ? 'Edit Purchase Order'
              : 'خریداری کا آرڈر ایڈٹ کریں',
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
          IconButton(onPressed: ()async{
            if (_selectedVendor == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(languageProvider.isEnglish
                    ? 'Please select a vendor first'
                    : 'براہ کرم پہلے فروش منتخب کریں')),
              );
              return;
            }

            final pdfBytes = await _generatePdf();
            await Printing.layoutPdf(
              onLayout: (PdfPageFormat format) async => pdfBytes,
            );
          }, icon: Icon(Icons.print,color: Colors.white,))
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
            child: ListView(
              children: [
                // Status Dropdown (only for editing)
                if (widget.orderKey != null) ...[
                  DropdownButtonFormField<String>(
                    value: _status,
                    items: [
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text(languageProvider.isEnglish ? 'Pending' : 'زیر التوا'),
                      ),
                      DropdownMenuItem(
                        value: 'fulfilled',
                        child: Text(languageProvider.isEnglish ? 'Fulfilled' : 'مکمل'),
                      ),
                      DropdownMenuItem(
                        value: 'cancelled',
                        child: Text(languageProvider.isEnglish ? 'Cancelled' : 'منسوخ'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _status = value;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: languageProvider.isEnglish ? 'Status' : 'حالت',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                ],

                // Vendor Information Section
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          languageProvider.isEnglish ? 'Vendor Information' : 'فروش کی معلومات',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE65100),
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 12),

                        // Search Vendor Field
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

                        if (_selectedVendor != null) ...[
                          SizedBox(height: 12),
                          Text(
                            languageProvider.isEnglish ? 'Selected Vendor:' : 'منتخب فروش:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(_selectedVendor!['name']),
                          if (_selectedVendor!['contact'] != null && _selectedVendor!['contact'].isNotEmpty)
                            Text(_selectedVendor!['contact']),
                        ],
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Order Dates Section
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          languageProvider.isEnglish ? 'Order Dates' : 'آرڈر کی تاریخ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE65100),
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(languageProvider.isEnglish ? 'Order Date' : 'آرڈر کی تاریخ'),
                                  SizedBox(height: 4),
                                  InkWell(
                                    onTap: () => _selectDate(context, true),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(DateFormat('yyyy-MM-dd').format(_orderDate)),
                                          Icon(Icons.calendar_today, size: 18),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(languageProvider.isEnglish ? 'Expected Delivery' : 'متوقع ترسیل'),
                                  SizedBox(height: 4),
                                  InkWell(
                                    onTap: () => _selectDate(context, false),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(DateFormat('yyyy-MM-dd').format(_expectedDeliveryDate)),
                                          Icon(Icons.calendar_today, size: 18),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Order Items Section
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
                              languageProvider.isEnglish ? 'Order Items' : 'آرڈر آئٹمز',
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
                            0: FixedColumnWidth(40), // Item #
                            1: FlexColumnWidth(2),   // Item Name
                            2: FlexColumnWidth(1.5), // Quantity
                            3: FlexColumnWidth(1.5), // Price
                            4: FixedColumnWidth(40), // Delete Icon
                          },
                          border: TableBorder.all(color: Colors.orange.shade100, width: 1),
                          children: [
                            // Header Row
                            TableRow(
                              decoration: BoxDecoration(color: Colors.orange.shade50),
                              children: [
                                tableHeader('No.'),
                                tableHeader(languageProvider.isEnglish ? 'Item Name' : 'آئٹم کا نام'),
                                tableHeader(languageProvider.isEnglish ? 'Qty' : 'مقدار'),
                                tableHeader(languageProvider.isEnglish ? 'Price' : 'قیمت'),
                                SizedBox(), // empty header for delete icon
                              ],
                            ),

                            // Item Rows
                            ..._orderItems.asMap().entries.map((entry) {
                              final index = entry.key;
                              final item = entry.value;

                              return TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),

                                  // Item Search Field
                                  Padding(
                                      padding: const EdgeInsets.all(6.0),
                                      child:
                                      // Autocomplete<Map<String, dynamic>>(
                                      //   optionsBuilder: (textEditingValue) {
                                      //     if (textEditingValue.text.isEmpty) return const Iterable.empty();
                                      //     return _items
                                      //         .where((i) => i['itemName']
                                      //         .toLowerCase()
                                      //         .contains(textEditingValue.text.toLowerCase()))
                                      //         .cast<Map<String, dynamic>>();
                                      //   },
                                      //   displayStringForOption: (i) => i['itemName'],
                                      //   onSelected: (selectedItem) {
                                      //     setState(() {
                                      //       item.selectedItem = selectedItem;
                                      //       item.searchController.text = selectedItem['itemName'];
                                      //       item.priceController.text = selectedItem['costPrice'].toStringAsFixed(2);
                                      //     });
                                      //   },
                                      //   fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                      //     // Make sure we're using the item's controller
                                      //     if (item.searchController != controller) {
                                      //       item.searchController = controller;
                                      //     }
                                      //     return TextFormField(
                                      //       controller: controller,
                                      //       focusNode: focusNode,
                                      //       decoration: const InputDecoration(
                                      //         isDense: true,
                                      //         border: OutlineInputBorder(),
                                      //         contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                      //       ),
                                      //     );
                                      //   },
                                      // )
                                      Autocomplete<Map<String, dynamic>>(
                                        initialValue: TextEditingValue(text: item.searchController.text),
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
                                            item.searchController.text = selectedItem['itemName'];
                                            item.priceController.text = selectedItem['costPrice'].toStringAsFixed(2);
                                          });
                                        },
                                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                          // Sync the controller with the item's controller
                                          controller.text = item.searchController.text;
                                          return TextFormField(
                                            controller: controller,
                                            focusNode: focusNode,
                                            onChanged: (value) {
                                              item.searchController.text = value;
                                            },
                                            decoration: const InputDecoration(
                                              isDense: true,
                                              border: OutlineInputBorder(),
                                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                            ),
                                          );
                                        },
                                      )

                                  ),

                                  // Quantity
                                  Padding(
                                    padding: const EdgeInsets.all(6.0),
                                    child: TextFormField(
                                      controller: item.quantityController,
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) {
                                        setState(() {}); // This will trigger a rebuild and update the total
                                      },
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                      ),
                                      validator: (value) {
                                        // Only validate if an item is selected
                                        if (item.selectedItem != null && (value == null || value.isEmpty)) {
                                          return languageProvider.isEnglish
                                              ? 'Enter qty'
                                              : 'مقدار درج کریں';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),

                                  // Price
                                  Padding(
                                    padding: const EdgeInsets.all(6.0),
                                    child: TextFormField(
                                      controller: item.priceController,
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) {
                                        setState(() {}); // This will trigger a rebuild and update the total
                                      },
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                      ),
                                      validator: (value) {
                                        // Only validate if an item is selected
                                        if (item.selectedItem != null && (value == null || value.isEmpty)) {
                                          return languageProvider.isEnglish
                                              ? 'Enter price'
                                              : 'قیمت درج کریں';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),

                                  // Delete icon
                                  Center(
                                    child: IconButton(
                                      icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                                      onPressed: () => removeItem(index),
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

                // Notes Section
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          languageProvider.isEnglish ? 'Notes' : 'نوٹس',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE65100),
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: languageProvider.isEnglish
                                ? 'Enter any additional notes...'
                                : 'کوئی اضافی نوٹس درج کریں...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Order Summary Section
                // Order Summary Section
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Text(
                          languageProvider.isEnglish ? 'Order Summary' : 'آرڈر کا خلاصہ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE65100),
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(languageProvider.isEnglish ? 'Subtotal:' : 'ذیلی کل:'),
                            Text('${calculateTotal().toStringAsFixed(2)} PKR'),
                          ],
                        ),

                        Divider(height: 24, thickness: 1),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              languageProvider.isEnglish ? 'Grand Total:' : 'کل کل:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${calculateTotal().toStringAsFixed(2)} PKR',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFFE65100),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),

                // Submit Button
                ElevatedButton(
                  onPressed: savePurchaseOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFF8A65),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    widget.orderKey == null
                        ? languageProvider.isEnglish
                        ? 'Create Purchase Order'
                        : 'خریداری کا آرڈر بنائیں'
                        : languageProvider.isEnglish
                        ? 'Update Purchase Order'
                        : 'خریداری کا آرڈر اپ ڈیٹ کریں',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PurchaseOrderItem {
  late TextEditingController searchController;
  late TextEditingController quantityController;
  late TextEditingController priceController;
  Map<String, dynamic>? selectedItem;

  PurchaseOrderItem() {
    searchController = TextEditingController();
    quantityController = TextEditingController();
    priceController = TextEditingController();
    selectedItem = null; // Explicitly initialize

  }
}
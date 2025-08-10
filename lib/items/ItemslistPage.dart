import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:onex_gas_appliances/items/stockreportpage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:ui' as ui;
import '../Provider/lanprovider.dart';
import '../Purchase/wastage recordpage.dart';
import 'AddItems.dart';
import 'editphysicalqty.dart';

class ItemsListPage extends StatefulWidget {
  @override
  _ItemsListPageState createState() => _ItemsListPageState();
}

class _ItemsListPageState extends State<ItemsListPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredItems = [];
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _selectedItem;
  List<Map<String, dynamic>> _itemTransactions = [];
  bool _isLoadingTransactions = false;
  String? _savedPdfPath;
  Uint8List? _pdfBytes;
  Map<String, String> customerIdNameMap = {};
  final Color _primaryColor = Color(0xFFFF8A65);
  final Color _secondaryColor = Color(0xFFFFB74D);
  final Color _backgroundColor = Colors.grey[50]!;
  final Color _cardColor = Colors.white;
  final Color _textColor = Colors.grey[800]!;

  Future<void> _fetchCustomerNames() async {
    final snapshot = await FirebaseDatabase.instance.ref('customers').get();

    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final Map<String, String> nameMap = {};

      data.forEach((key, value) {
        if (value is Map && value.containsKey('name')) {
          nameMap[key] = value['name'].toString();
        }
      });

      setState(() {
        customerIdNameMap = nameMap;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchItems();
    _fetchCustomerNames(); // <-- fetch customer names early
    _searchController.addListener(_searchItems);
  }

  Future<void> fetchItems() async {
    _database.child('items').onValue.listen((event) {
      final Map? data = event.snapshot.value as Map?;
      if (data != null) {
        final fetchedItems = data.entries.map<Map<String, dynamic>>((entry) {
          return {
            'key': entry.key,
            ...Map<String, dynamic>.from(entry.value as Map),
          };
        }).toList();

        setState(() {
          _items = fetchedItems;
          _filteredItems = fetchedItems;
        });
      }
    });
  }

  void _searchItems() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = _items.where((item) {
        String itemName = item['itemName']?.toString().toLowerCase() ?? '';
        return itemName.contains(query);
      }).toList();
    });
  }

  Future<pw.MemoryImage> _createTextImage(String text) async {
    // Use default text for empty input
    final String displayText = text.isEmpty ? "N/A" : text;

    // Scale factor to increase resolution
    const double scaleFactor = 1.5;

    // Create a custom painter with the Urdu text
    final recorder = ui.PictureRecorder();
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
      textDirection: ui.TextDirection.rtl, // Use RTL for Urdu text
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
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    // Return the image as a MemoryImage
    return pw.MemoryImage(buffer);
  }


  Future<void> _createPDFAndSave() async {
    final ByteData logoBytes = await rootBundle.load('assets/images/logo.png');
    final image = pw.MemoryImage(logoBytes.buffer.asUint8List());

    final pdf = pw.Document();
    List<pw.MemoryImage> descriptionImages = [];

    for (var row in _filteredItems) {
      final img = await _createTextImage(row['itemName']);
      descriptionImages.add(img);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(image, width: 100, height: 100),
              pw.Text('Items List', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['Item Name', 'Qty', 'Price', 'Unit', 'Customer Prices'],
            cellAlignment: pw.Alignment.centerLeft,
            data: _filteredItems.asMap().entries.map((entry) {
              int index = entry.key;
              var item = entry.value;

              // // Build customer prices string
              // String customerPrices = "";
              // if (item['customerBasePrices'] != null) {
              //   final prices = item['customerBasePrices'] as Map;
              //   customerPrices = prices.entries
              //       .map((e) => "${e.key}: ${e.value}")
              //       .join("\n");
              // }
              String customerPrices = "";
              if (item['customerBasePrices'] != null) {
                final prices = item['customerBasePrices'] as Map;
                customerPrices = prices.entries.map((e) {
                  final name = customerIdNameMap[e.key] ?? e.key; // fallback to ID
                  return "$name: ${e.value}";
                }).join("\n");
              }


              return [
                // pw.Image(descriptionImages[index], dpi: 100),
                item['itemName'].toString(),
                item['qtyOnHand'].toString(),
                item['salePrice'].toString(),
                item['unit'].toString(),
                customerPrices,
              ];
            }).toList(),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    _pdfBytes = bytes;

    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("PDF generated for web (use share button)")),
      );
    } else {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/items_list.pdf');
      await file.writeAsBytes(bytes);
      setState(() {
        _savedPdfPath = file.path;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("PDF saved to temporary folder")),
      );
    }
  }

  Future<void> _sharePDF() async {
    if (kIsWeb) {
      if (_pdfBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Generate PDF first")));
        return;
      }
      await Printing.sharePdf(bytes: _pdfBytes!, filename: 'items_list.pdf');
    } else {
      if (_savedPdfPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Generate PDF first")));
        return;
      }
      await Share.shareXFiles([XFile(_savedPdfPath!)], text: 'Items List PDF');
    }
  }


  void updateItem(Map<String, dynamic> item) {
    // Safely convert components to List<Map<String, dynamic>>
    List<Map<String, dynamic>>? components;
    if (item['components'] != null) {
      try {
        final rawComponents = item['components'];
        if (rawComponents is List) {
          components = rawComponents.map((component) {
            if (component is Map) {
              return Map<String, dynamic>.from(component);
            }
            return <String, dynamic>{};
          }).toList();
        }
      } catch (e) {
        print('Error converting components: $e');
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegisterItemPage(
          itemData: {
            'key': item['key'],
            'itemName': item['itemName'],
            'image': item['image'],
            'unit': item['unit'] ?? '',
            'costPrice': item['costPrice'] ?? 0.0,
            'salePrice': item['salePrice'] ?? 0.0,
            'qtyOnHand': item['qtyOnHand'] ?? 0,
            'vendor': item['vendor'] ?? '',
            'category': item['category'] ?? '',
            'weightPerBag': item['weightPerBag'] ?? 1.0,
            'customerBasePrices': item['customerBasePrices'] is Map
                ? Map<String, dynamic>.from(item['customerBasePrices'])
                : null,
            'isBOM': item['isBOM'] ?? false,
            'components': components, // Use the converted components
          },
        ),
      ),
    );
  }


  void _confirmDelete(String key) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(languageProvider.isEnglish
              ? "Confirm Delete"
              : "حذف کرنے کی تصدیق کریں"),
          content: Text(languageProvider.isEnglish
              ? "Are you sure you want to delete this item?"
              : "کیا آپ واقعی اس آئٹم کو حذف کرنا چاہتے ہیں؟"),
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
                deleteItem(key); // Proceed with deletion
              },
            ),
          ],
        );
      },
    );
  }

  void deleteItem(String key) {
    _database.child('items/$key').remove().then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Item deleted successfully!')),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete item: $error')),
      );
    });
  }


  Future<List<Map<String, dynamic>>> _fetchItemTransactions(String itemKey) async {
    final database = FirebaseDatabase.instance.ref();
    List<Map<String, dynamic>> transactions = [];

    try {
      // Fetch purchases containing this item
      final purchaseSnapshot = await database.child('purchases').get();
      if (purchaseSnapshot.exists) {
        final purchases = purchaseSnapshot.value as Map<dynamic, dynamic>;
        purchases.forEach((purchaseKey, purchaseData) {
          if (purchaseData['items'] != null) {
            final items = purchaseData['items'] as List;
            for (var item in items) {
              if (item['itemName'] == _selectedItem!['itemName']) {
                transactions.add({
                  'type': 'Purchase',
                  'purchaseId': purchaseKey,
                  'date': purchaseData['timestamp'],
                  'quantity': item['quantity'],
                  'price': item['purchasePrice'],
                  'vendor': purchaseData['vendorName'] ?? 'Unknown Vendor',
                  'total': (item['quantity'] as num).toDouble() *
                      (item['purchasePrice'] as num).toDouble(),
                });
              }
            }
          }
        });
      }

      // Sort by date (newest first)
      transactions.sort((a, b) => b['date'].compareTo(a['date']));
    } catch (e) {
      print('Error fetching transactions: $e');
    }

    return transactions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inventory Information'),
        actions: [
          IconButton(icon: Icon(Icons.picture_as_pdf), onPressed: _createPDFAndSave),
          IconButton(icon: Icon(Icons.share), onPressed: _sharePDF),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => StockReportPage()),
              );
            },
            icon: Icon(Icons.history, color: Colors.white),
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_backgroundColor.withOpacity(0.9), _backgroundColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Row(
          children: [
            /// Left Panel - Item List
            Expanded(
              flex: 2,
              child: Card(
                margin: EdgeInsets.all(8),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Search Item',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: _cardColor,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];
                          return Card(
                            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              title: Text(item['itemName'],
                                  style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
                              subtitle: Text("Price: ${item['salePrice']}",
                                  style: TextStyle(color: _textColor.withOpacity(0.7))),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit_note, color: Colors.blue),
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EditQtyPage(itemData: item),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _confirmDelete(item['key']),
                                  ),
                                ],
                              ),
                              // onTap: () {
                              //   setState(() {
                              //     _selectedItem = item;
                              //   });
                              // },
                              onTap: () async {
                                setState(() {
                                  _selectedItem = item;
                                  _isLoadingTransactions = true;
                                });

                                final transactions = await _fetchItemTransactions(item['key']);
                                setState(() {
                                  _itemTransactions = transactions.where((t) => t['type'] == 'Purchase').toList();
                                  _isLoadingTransactions = false;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            /// Center Panel - Item Detail
            Expanded(
              flex: 3,
              child: _selectedItem == null
                  ? Center(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text("Select an item to view details",
                        style: TextStyle(color: _textColor)),
                  ),
                ),
              )
                  : Card(
                margin: EdgeInsets.all(8),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Inventory Information",
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                            color: _primaryColor,
                                            fontWeight: FontWeight.bold)),
                                    if (_selectedItem!['isBOM'] == true)
                                      Chip(
                                        label: Text("BOM"),
                                        backgroundColor: Colors.blue[100],
                                      ),
                                    IconButton(
                                      icon: Icon(Icons.attach_money,
                                          color: _secondaryColor),
                                      onPressed: () =>
                                          _showCustomerRates(_selectedItem!),
                                    ),
                                  ],
                                ),
                                Divider(color: _primaryColor.withOpacity(0.3)),
                                SizedBox(height: 16),
                                _buildDetailRow("Item Name",
                                    _selectedItem!['itemName']?.toString() ?? 'N/A'),
                                if (_selectedItem!['isBOM'] != true) ...[
                                  // _buildDetailRow("Cost Price",
                                  //     _selectedItem!['costPrice']?.toString() ?? 'N/A'),
                                  _buildDetailRow("Unit",
                                      _selectedItem!['unit']?.toString() ?? 'N/A'),
                                  _buildDetailRow("Vendor",
                                      _selectedItem!['vendor']?.toString() ?? 'N/A'),
                                ],
                                _buildDetailRow("Sale Price",
                                    _selectedItem!['salePrice']?.toString() ?? 'N/A'),
                                // In your item details section, add this row:
                                _buildDetailRow(
                                    "Cost Price",
                                    _selectedItem!['isBOM'] == true
                                        ? "Components Based"
                                        : _selectedItem!['costPrice']?.toString() ?? 'N/A'
                                ),
                                _buildDetailRow(
                                    "Effective Cost",
                                    _calculateEffectiveCost(_selectedItem!).toStringAsFixed(2)
                                ),
                                _buildDetailRow("Quantity",
                                    _selectedItem!['qtyOnHand']?.toString() ?? 'N/A'),
                                _buildDetailRow("Category",
                                    _selectedItem!['category']?.toString() ?? 'N/A'),
                                if (_selectedItem!['isBOM'] == true) ...[
                                  SizedBox(height: 16),
                                  Text("Cost Breakdown:",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: _primaryColor)),
                                  SizedBox(height: 8),
                                  Column(
                                    children: _selectedItem!['components'].map<Widget>((component) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Text(component['name'] ?? 'Unnamed component'),
                                            ),
                                            Expanded(
                                              child: Text('${component['quantity']} ${component['unit']}'),
                                            ),
                                            Expanded(
                                              child: Text('@ ${component['price']}'),
                                            ),
                                            Expanded(
                                              child: Text(
                                                '${(component['price'] * component['quantity']).toStringAsFixed(2)}',
                                                textAlign: TextAlign.end,
                                                style: TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  Divider(),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            "Total Effective Cost:",
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            _calculateEffectiveCost(_selectedItem!).toStringAsFixed(2),
                                            textAlign: TextAlign.end,
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (_selectedItem!['isBOM'] == true) ...[
                                  SizedBox(height: 16),
                                  Text("Components:",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: _primaryColor)),
                                  SizedBox(height: 8),
                                  Container(
                                    height: 350,
                                    decoration: BoxDecoration(
                                      border:
                                      Border.all(color: Colors.grey[300]!),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: _selectedItem!['components'] == null
                                        ? Center(child: Text("No components"))
                                        : ListView.builder(
                                      padding: EdgeInsets.all(8),
                                      itemCount:
                                      _selectedItem!['components'].length,
                                      itemBuilder: (context, index) {
                                        final component =
                                        _selectedItem!['components']
                                        [index];
                                        return Card(
                                          margin: EdgeInsets.symmetric(
                                              vertical: 4),
                                          elevation: 2,
                                          child: ListTile(
                                            contentPadding:
                                            EdgeInsets.symmetric(
                                                horizontal: 12),
                                            title: Text(component['name'] ??
                                                'Unnamed component'),
                                            subtitle: Text(
                                                '${component['quantity']} ${component['unit']}'),
                                            trailing: Text(
                                                '${(component['price'] * component['quantity']).toStringAsFixed(2)} PKR'),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                                Spacer(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    SizedBox(width: 10),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _primaryColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: Text("Edit",
                                          style: TextStyle(color: Colors.white)),
                                      onPressed: () => updateItem(_selectedItem!),
                                    ),
                                    SizedBox(width: 10),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: Text("Delete",
                                          style: TextStyle(color: Colors.white)),
                                      onPressed: () =>
                                          _confirmDelete(_selectedItem!['key']),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            /// Right Panel (Optional) – Image, etc.
        Expanded(
          flex: 2,
          child: Card(
              margin: EdgeInsets.all(8),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  Text("Item Image",
                  style: TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18
                  )),
              SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  if (_selectedItem != null && _selectedItem!['image'] != null) {
                    _showImagePreview(context, _selectedItem!['image']);
                  }
                },
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        blurRadius: 5,
                        spreadRadius: 2,
                      )
                    ],
                    image: _selectedItem != null && _selectedItem!['image'] != null
                        ? DecorationImage(
                      image: MemoryImage(base64Decode(_selectedItem!['image'])),
                      fit: BoxFit.cover,
                    )
                        : null,
                  ),
                  child: Icon(Icons.image, size: 60, color: _secondaryColor),
                ),
              ),
              SizedBox(height: 20),
              if (_selectedItem != null) ...[
          _buildStatCard("Stock Value",
          "₹${(double.parse(_selectedItem!['qtyOnHand'].toString()) * double.parse(_selectedItem!['salePrice'].toString()))}"),
          SizedBox(height: 10),
          _buildStatCard("Profit Margin", ""), // Empty string since we calculate inside
          ],
          ],
        ),
      ),
    ),
          ],
        ),
      ),

      /// Bottom Panel – Transactions
      // bottomNavigationBar: Container(
      //   decoration: BoxDecoration(
      //     color: _cardColor,
      //     borderRadius: BorderRadius.only(
      //       topLeft: Radius.circular(12),
      //       topRight: Radius.circular(12),
      //     ),
      //     boxShadow: [
      //       BoxShadow(
      //         color: Colors.grey.withOpacity(0.2),
      //         blurRadius: 8,
      //         spreadRadius: 2,
      //       )
      //     ],
      //   ),
      //   padding: EdgeInsets.all(12),
      //   height: 250, // Increased height for more details
      //   child: Column(
      //     crossAxisAlignment: CrossAxisAlignment.start,
      //     children: [
      //       Row(
      //         children: [
      //           Text(
      //             "Purchase Reports",
      //             style: TextStyle(
      //               color: _primaryColor,
      //               fontWeight: FontWeight.bold,
      //               fontSize: 16,
      //             ),
      //           ),
      //           Spacer(),
      //           IconButton(
      //             onPressed: _showPurchaseReport,
      //             icon: Icon(Icons.details, color: _secondaryColor),
      //           )
      //         ],
      //       ),
      //       Divider(color: _primaryColor.withOpacity(0.3)),
      //       Expanded(
      //         child: _isLoadingTransactions
      //             ? Center(child: CircularProgressIndicator())
      //             : _itemTransactions.isEmpty
      //             ? Center(
      //           child: Text(
      //             "No purchase records for this item",
      //             style: TextStyle(color: _textColor.withOpacity(0.6)),
      //           ),
      //         )
      //             : ListView.builder(
      //           itemCount: min(3, _itemTransactions.length),
      //           itemBuilder: (context, index) {
      //             final txn = _itemTransactions[index];
      //             return Card(
      //               margin: EdgeInsets.symmetric(vertical: 4),
      //               child: ListTile(
      //                 contentPadding: EdgeInsets.symmetric(horizontal: 8),
      //                 leading: Icon(
      //                   Icons.shopping_cart,
      //                   color: Colors.green,
      //                 ),
      //                 title: Text(txn['vendor']),
      //                 subtitle: Column(
      //                   crossAxisAlignment: CrossAxisAlignment.start,
      //                   children: [
      //                     Text('${DateFormat('MMM dd, yyyy').format(DateTime.parse(txn['date']))}'),
      //                     Text('Qty: ${txn['quantity']} @ ${txn['price']}'),
      //                   ],
      //                 ),
      //                 trailing: Column(
      //                   mainAxisAlignment: MainAxisAlignment.center,
      //                   crossAxisAlignment: CrossAxisAlignment.end,
      //                   children: [
      //                     Text('${txn['total'].toStringAsFixed(2)} PKR'),
      //                     SizedBox(height: 4),
      //                     Text(
      //                       'View Details',
      //                       style: TextStyle(
      //                         color: Colors.blue,
      //                         fontSize: 10,
      //                       ),
      //                     ),
      //                   ],
      //                 ),
      //                 onTap: () => _showPurchaseDetails(txn),
      //               ),
      //             );
      //           },
      //         ),
      //       ),
      //     ],
      //   ),
      // ),


      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 2,
            )
          ],
        ),
        padding: EdgeInsets.all(12),
        height: 250,
        child: DefaultTabController(
          length: 3, // Changed from 2 to 3
          child: Column(
            children: [
              TabBar(
                labelColor: _primaryColor,
                unselectedLabelColor: _textColor.withOpacity(0.6),
                indicatorColor: _primaryColor,
                tabs: [
                  Tab(text: 'Purchases'),
                  Tab(text: 'BOM Builds'),
                  Tab(text: 'Sales'), // New tab
                ],
              ),
              Divider(color: _primaryColor.withOpacity(0.3)),
              Expanded(
                child: TabBarView(
                  children: [
                    // Purchase Reports Tab
                    _buildPurchaseReportsTab(),
                    // BOM Builds Tab
                    _buildBomBuildsTab(),
                    // Sales Tab
                    _buildSalesTab(), // New tab content
                  ],
                ),
              ),
            ],
          ),
        ),
      ),



      floatingActionButton: FloatingActionButton(
        backgroundColor: _primaryColor,
        child: Icon(Icons.add, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => RegisterItemPage()),
          ).then((_) => fetchItems());
        },
      ),
    );
  }

  Widget _buildSalesTab() {
    return FutureBuilder(
      future: _fetchItemSales(_selectedItem?['key']),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text("No sales records for this item"),
          );
        }

        final sales = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "Sales Reports",
                  style: TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Spacer(),
                IconButton(
                  onPressed: () => _showSalesReport(sales),
                  icon: Icon(Icons.details, color: _secondaryColor),
                )
              ],
            ),
            Divider(color: _primaryColor.withOpacity(0.3)),
            Expanded(
              child: ListView.builder(
                itemCount: min(3, sales.length),
                itemBuilder: (context, index) {
                  final sale = sales[index];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      leading: Icon(Icons.sell, color: Colors.blue),
                      title: Text(sale['customerName'] ?? 'Unknown Customer'),
                      subtitle: Text(DateFormat.yMMMd().add_jm()
                          .format(DateTime.fromMillisecondsSinceEpoch(sale['date']))),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${sale['quantity']} @ ${sale['price']}'),
                          Text('${sale['total'].toStringAsFixed(2)} PKR'),
                        ],
                      ),
                      onTap: () => _showSaleDetails(sale),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSaleDetails(Map<String, dynamic> sale) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Sale Details"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSaleDetailRow("Customer", sale['customerName'] ?? 'Unknown'),
              _buildSaleDetailRow("Date",
                  DateFormat.yMMMd().add_jm().format(
                      sale['date'] is int
                          ? DateTime.fromMillisecondsSinceEpoch(sale['date'])
                          : DateTime.parse(sale['date'])
                  )),
              _buildSaleDetailRow("Invoice #", sale['filledNumber'] ?? 'N/A'),
              _buildSaleDetailRow("Item", _selectedItem?['itemName'] ?? 'N/A'),
              _buildSaleDetailRow("Quantity", sale['quantity'].toString()),
              _buildSaleDetailRow("Price", sale['price'].toString()),
              _buildSaleDetailRow("Total", '${sale['total'].toStringAsFixed(2)} PKR'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              "$label:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(width: 10),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchItemSales(String? itemKey) async {
    if (itemKey == null) return [];

    final database = FirebaseDatabase.instance.ref();
    List<Map<String, dynamic>> sales = [];

    try {
      // Fetch sales containing this item
      final salesSnapshot = await database.child('filled').get();
      if (salesSnapshot.exists) {
        final allSales = salesSnapshot.value;

        // Handle both Map and List cases
        if (allSales is Map) {
          // Convert Map to list of entries
          allSales.forEach((saleKey, saleData) {
            _processSaleData(saleData, sales);
          });
        } else if (allSales is List) {
          // Process list of sales
          for (var saleData in allSales) {
            _processSaleData(saleData, sales);
          }
        }
      }

      // Sort by date (newest first)
      sales.sort((a, b) {
        dynamic dateA = a['date'];
        dynamic dateB = b['date'];

        DateTime dateTimeA = dateA is int
            ? DateTime.fromMillisecondsSinceEpoch(dateA)
            : DateTime.parse(dateA.toString());
        DateTime dateTimeB = dateB is int
            ? DateTime.fromMillisecondsSinceEpoch(dateB)
            : DateTime.parse(dateB.toString());

        return dateTimeB.compareTo(dateTimeA);
      });
    } catch (e) {
      print('Error fetching sales: $e');
    }

    return sales;
  }

  void _processSaleData(dynamic saleData, List<Map<String, dynamic>> sales) {
    try {
      // Convert saleData to Map if it isn't already
      final saleMap = saleData is Map ? Map<String, dynamic>.from(saleData) : {};

      // Check if this sale has items
      if (saleMap['items'] != null) {
        final items = saleMap['items'] is List
            ? saleMap['items']
            : [];

        // Find items that match our selected item
        for (var item in items) {
          if (item is Map && item['itemName'] == _selectedItem!['itemName']) {
            // Get customer name
            String customerName = 'Unknown Customer';
            if (saleMap['customerName'] != null) {
              customerName = saleMap['customerName'].toString();
            } else if (saleMap['customerId'] != null) {
              // Fallback to customerId if name not available
              customerName = "Customer ID: ${saleMap['customerId']}";
            }

            // Handle date parsing - support both int timestamps and string dates
            dynamic dateValue = saleMap['createdAt'] ?? saleMap['timestamp'];
            DateTime saleDate;

            if (dateValue is int) {
              saleDate = DateTime.fromMillisecondsSinceEpoch(dateValue);
            } else if (dateValue is String) {
              // Try parsing ISO string
              saleDate = DateTime.tryParse(dateValue) ?? DateTime.now();
            } else {
              saleDate = DateTime.now();
            }

            // Add to sales list
            sales.add({
              'type': 'Sale',
              'date': saleDate.millisecondsSinceEpoch, // Store as timestamp for consistency
              'quantity': item['qty'] ?? 0,
              'price': item['rate'] ?? 0,
              'customerName': customerName,
              'total': (item['total'] ?? (item['qty'] ?? 0) * (item['rate'] ?? 0)).toDouble(),
              'filledNumber': saleMap['filledNumber']?.toString() ?? '',
            });
          }
        }
      }
    } catch (e) {
      print('Error processing sale data: $e');
    }
  }

  void _showSalesReport(List<Map<String, dynamic>> sales) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "Sales Report: ${_selectedItem?['itemName']}",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: sales.length,
                itemBuilder: (context, index) {
                  final sale = sales[index];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      leading: Icon(Icons.sell, color: Colors.blue),
                      title: Text(sale['customerName'] ?? 'Unknown Customer'),
                      subtitle: Text(DateFormat.yMMMd().add_jm().format(
                          sale['date'] is int
                              ? DateTime.fromMillisecondsSinceEpoch(sale['date'])
                              : DateTime.parse(sale['date'])
                      )),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${sale['quantity']} @ ${sale['price']}'),
                          Text('${sale['total'].toStringAsFixed(2)} PKR'),
                        ],
                      ),
                      onTap: () => _showSaleDetails(sale),
                    ),
                  );
                },
              ),
            ),
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Total Sold:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  "${sales.fold(0.0, (sum, sale) => sum + (sale['quantity'] as num).toDouble()).toStringAsFixed(2)} units",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Total Revenue:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  "${sales.fold(0.0, (sum, sale) => sum + (sale['total'] as num).toDouble()).toStringAsFixed(2)} PKR",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper method for Purchase Reports tab
  Widget _buildPurchaseReportsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Purchase Reports",
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Spacer(),
            IconButton(
              onPressed: _showPurchaseReport,
              icon: Icon(Icons.details, color: _secondaryColor),
            )
          ],
        ),
        Divider(color: _primaryColor.withOpacity(0.3)),
        Expanded(
          child: _isLoadingTransactions
              ? Center(child: CircularProgressIndicator())
              : _itemTransactions.isEmpty
              ? Center(
            child: Text(
              "No purchase records for this item",
              style: TextStyle(color: _textColor.withOpacity(0.6)),
            ),
          )
              : ListView.builder(
            itemCount: min(3, _itemTransactions.length),
            itemBuilder: (context, index) {
              final txn = _itemTransactions[index];
              return Card(
                margin: EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  leading: Icon(
                    Icons.shopping_cart,
                    color: Colors.green,
                  ),
                  title: Text(txn['vendor']),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${DateFormat('MMM dd, yyyy').format(DateTime.parse(txn['date']))}'),
                      Text('Qty: ${txn['quantity']} @ ${txn['price']}'),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${txn['total'].toStringAsFixed(2)} PKR'),
                      SizedBox(height: 4),
                      Text(
                        'View Details',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  onTap: () => _showPurchaseDetails(txn),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

// Helper method for BOM Builds tab
  Widget _buildBomBuildsTab() {
    return FutureBuilder(
      future: _fetchBomBuilds(_selectedItem?['key']),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              "No BOM build records for this item",
              style: TextStyle(color: _textColor.withOpacity(0.6)),
            ),
          );
        }

        final builds = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "BOM Build History",
                  style: TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Spacer(),
                IconButton(
                  onPressed: () => _showBomBuildReport(builds),
                  icon: Icon(Icons.details, color: _secondaryColor),
                )
              ],
            ),
            Divider(color: _primaryColor.withOpacity(0.3)),
            Expanded(
              child: ListView.builder(
                itemCount: min(3, builds.length),
                itemBuilder: (context, index) {
                  final build = builds[index];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      leading: Icon(
                        Icons.build,
                        color: Colors.blue,
                      ),
                      title: Text('Built ${build['quantityBuilt']} units'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${DateFormat('MMM dd, yyyy').format(DateTime.fromMillisecondsSinceEpoch(build['timestamp']))}'),
                          if (build['components'] != null && build['components'].isNotEmpty)
                            Text('Used ${build['components'].length} components'),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          SizedBox(height: 4),
                          Text(
                            'View Details',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _showBomBuildDetails(build),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

// Fetch BOM build records for the item
  Future<List<Map<String, dynamic>>> _fetchBomBuilds(String? itemKey) async {
    if (itemKey == null) return [];

    final database = FirebaseDatabase.instance.ref();
    List<Map<String, dynamic>> builds = [];

    try {
      final snapshot = await database.child('buildTransactions')
          .orderByChild('bomItemKey')
          .equalTo(itemKey)
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final build = Map<String, dynamic>.from(value as Map<dynamic, dynamic>);
          build['key'] = key;
          builds.add(build);
        });

        // Sort by timestamp (newest first)
        builds.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
      }
    } catch (e) {
      print('Error fetching BOM builds: $e');
    }

    return builds;
  }

// Show detailed BOM build view
  void _showBomBuildDetails(Map<String, dynamic> build) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("BOM Build Details"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow("Item", build['bomItemName'] ?? 'N/A'),
              _buildDetailRow("Quantity Built", build['quantityBuilt'].toString()),
              _buildDetailRow("Date", DateFormat.yMMMd().add_jm().format(
                DateTime.fromMillisecondsSinceEpoch(build['timestamp']),
              ),
              ),

                  SizedBox(height: 16),
                  Text("Components Used:", style: TextStyle(fontWeight: FontWeight.bold)),
                  ...(build['components'] as List?)?.map<Widget>((component) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(component['name'] ?? 'Unknown')),
                      Expanded(child: Text('${component['quantityUsed']} ${component['unit']}')),
                    ],
                  ),
                );
              }) ?? [Text("No component data")],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close"),
          ),
        ],
      ),
    );
  }

// Show full BOM build report
  void _showBomBuildReport(List<Map<String, dynamic>> builds) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "BOM Build Report: ${_selectedItem?['itemName']}",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: builds.length,
                itemBuilder: (context, index) {
                  final build = builds[index];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      leading: Icon(Icons.build, color: Colors.blue),
                      title: Text('Built ${build['quantityBuilt']} units'),
                      subtitle: Text(DateFormat.yMMMd().add_jm()
                          .format(DateTime.fromMillisecondsSinceEpoch(build['timestamp']))),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${build['components']?.length ?? 0} components'),
                          Text(
                            'View',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _showBomBuildDetails(build),
                    ),
                  );
                },
              ),
            ),
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Total Built:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  "${builds.fold(0, (sum, build) => sum + (build['quantityBuilt'] as num).toInt())} units",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _calculateEffectiveCost(Map<String, dynamic> item) {
    if (item['isBOM'] == true && item['components'] != null) {
      // Calculate sum of all component costs
      double totalCost = 0.0;
      for (var component in item['components']) {
        double quantity = double.tryParse(component['quantity'].toString()) ?? 0;
        double price = double.tryParse(component['price'].toString()) ?? 0;
        totalCost += quantity * price;
      }
      return totalCost;
    } else {
      // For regular items, just return the cost price
      return double.tryParse(item['costPrice']?.toString() ?? '0') ?? 0;
    }
  }

  void _showPurchaseDetails(Map<String, dynamic> purchase) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Purchase Details"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPurchaseDetailRow("Date", DateFormat.yMMMd().add_jm().format(DateTime.parse(purchase['date']))),
              _buildPurchaseDetailRow("Vendor", purchase['vendor']),
              _buildPurchaseDetailRow("Item", _selectedItem?['itemName'] ?? ''),
              _buildPurchaseDetailRow("Quantity", purchase['quantity'].toString()),
              _buildPurchaseDetailRow("Price", purchase['price'].toString()),
              _buildPurchaseDetailRow("Total", '${purchase['total'].toStringAsFixed(2)} PKR'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              "$label:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(width: 10),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showPurchaseReport() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "Purchase Report: ${_selectedItem?['itemName']}",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _itemTransactions.length,
                itemBuilder: (context, index) {
                  final txn = _itemTransactions[index];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      leading: Icon(Icons.shopping_cart, color: Colors.green),
                      title: Text(txn['vendor']),
                      subtitle: Text(DateFormat.yMMMd().add_jm().format(DateTime.parse(txn['date']))),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${txn['quantity']} @ ${txn['price']}'),
                          Text('${txn['total'].toStringAsFixed(2)} PKR'),
                        ],
                      ),
                      onTap: () => _showPurchaseDetails(txn),
                    ),
                  );
                },
              ),
            ),
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Total Purchases:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  "${_calculateTotalPurchases().toStringAsFixed(2)} PKR",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _calculateTotalPurchases() {
    return _itemTransactions.fold(0.0, (sum, txn) => sum + (txn['total'] as double));
  }

  void _showImagePreview(BuildContext context, String imageBase64) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(20),
        child: Stack(
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: kIsWeb
                  ? Image.network('data:image/png;base64,$imageBase64')
                  : Image.memory(base64Decode(imageBase64)),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    // Calculate profit margin if this is the profit margin card
    if (title == "Profit Margin" && _selectedItem != null) {

      final effectiveCost = _calculateEffectiveCost(_selectedItem!);
      final salePrice = double.tryParse(_selectedItem!['salePrice']?.toString() ?? '0') ?? 0;

      double margin = 0;
      if (effectiveCost > 0) {
        margin = ((salePrice - effectiveCost) / effectiveCost) * 100;
      }

      value = '${margin.toStringAsFixed(1)}%';

      // Change color based on profitability
      Color textColor = margin >= 0 ? Colors.green : Colors.red;

      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            children: [
              Text(title,
                  style: TextStyle(
                      color: _textColor.withOpacity(0.7),
                      fontSize: 14
                  )),
              SizedBox(height: 5),
              Text(value,
                  style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18
                  )),
            ],
          ),
        ),
      );
    }

    // Default card for other stats
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Text(title,
                style: TextStyle(
                    color: _textColor.withOpacity(0.7),
                    fontSize: 14
                )),
            SizedBox(height: 5),
            Text(value,
                style: TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(
                    color: _textColor,
                    fontWeight: FontWeight.bold
                )),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(value.isNotEmpty ? value : 'N/A',
                style: TextStyle(
                  color: _textColor.withOpacity(0.8),
                )),
          ),
        ],
      ),
    );
  }

  void _showCustomerRates(Map<String, dynamic> item) {
    // Safely get and convert customerBasePrices
    final rawPrices = item['customerBasePrices'];
    final Map<String, dynamic> customerPrices = {};

    if (rawPrices != null) {
      try {
        // Convert from Map<dynamic, dynamic> to Map<String, dynamic>
        customerPrices.addAll(Map<String, dynamic>.from(rawPrices));
      } catch (e) {
        print('Error converting customer prices: $e');
      }
    }

    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${languageProvider.isEnglish ? 'Customer Prices for' : 'کسٹمر کی قیمتیں برائے'} ${item['itemName']}"),
        content: SizedBox(
          width: double.maxFinite,
          child: customerPrices.isEmpty
              ? Text(languageProvider.isEnglish
              ? "No custom prices set"
              : "کوئی مخصوص قیمتیں مقرر نہیں ہیں")
              : ListView.builder(
            shrinkWrap: true,
            itemCount: customerPrices.length,
            itemBuilder: (context, index) {
              final customerId = customerPrices.keys.elementAt(index);
              final price = customerPrices[customerId];
              return FutureBuilder(
                future: _getCustomerName(customerId.toString()), // Ensure customerId is String
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ListTile(
                      title: Text("Loading..."),
                    );
                  }
                  return ListTile(
                    title: Text("${snapshot.data ?? "Unknown Customer"}"),
                    trailing: Text("$price"),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(languageProvider.isEnglish ? "Close" : "بند کریں"),
          ),
        ],
      ),
    );
  }

  Future<String?> _getCustomerName(String customerId) async {
    final snapshot = await FirebaseDatabase.instance
        .ref()
        .child('customers/$customerId/name')
        .get();

    return snapshot.exists ? snapshot.value.toString() : null;
  }


}

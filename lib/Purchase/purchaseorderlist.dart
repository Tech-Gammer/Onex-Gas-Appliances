import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../Provider/lanprovider.dart';
import 'itemPurchasePage.dart';
import 'Purchase Order page.dart';

class PurchaseOrderListPage extends StatefulWidget {
  @override
  _PurchaseOrderListPageState createState() => _PurchaseOrderListPageState();
}

class _PurchaseOrderListPageState extends State<PurchaseOrderListPage> {
  List<Map<String, dynamic>> _purchaseOrders = [];
  bool _isLoading = true;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _fetchPurchaseOrders();
  }

  Future<void> _fetchPurchaseOrders() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _database.child('purchaseOrders').get();
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _purchaseOrders = data.entries.map((entry) {
            final order = entry.value as Map<dynamic, dynamic>;
            return {
              'key': entry.key,
              'vendorId': order['vendorId'],
              'vendorName': order['vendorName'] ?? 'Unknown Vendor',
              'grandTotal': (order['grandTotal'] as num?)?.toDouble() ?? 0.0,
              'orderDate': order['orderDate'] ?? '',
              'expectedDeliveryDate': order['expectedDeliveryDate'] ?? '',
              'status': order['status'] ?? 'pending',
              'items': order['items'] ?? [], // Include items in the order data
            };
          }).toList();

          // Sort by order date (newest first)
          _purchaseOrders.sort((a, b) =>
              (b['orderDate'] as String).compareTo(a['orderDate'] as String));
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToEditPage(String? orderKey) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PurchaseOrderPage(orderKey: orderKey),
      ),
    ).then((_) => _fetchPurchaseOrders());
  }

  // void _navigateToItemPurchasePage(Map<String, dynamic> order) async {
  //   try {
  //     // Fetch complete order details from Firebase
  //     final snapshot = await _database.child('purchaseOrders').child(order['key']).get();
  //
  //     if (snapshot.exists) {
  //       final completeOrder = snapshot.value as Map<dynamic, dynamic>;
  //
  //       print('Complete order data: $completeOrder'); // Debug print
  //       print('Order items: ${completeOrder['items']}'); // Debug print
  //
  //       // Debug: Print each item structure
  //       if (completeOrder['items'] != null) {
  //         final items = completeOrder['items'] as List;
  //         for (int i = 0; i < items.length; i++) {
  //           print('Item $i structure: ${items[i]}');
  //           print('Item $i keys: ${(items[i] as Map).keys.toList()}');
  //         }
  //       }
  //
  //       Navigator.push(
  //         context,
  //         MaterialPageRoute(
  //           builder: (context) => ItemPurchasePage(
  //             initialVendorId: completeOrder['vendorId'],
  //             initialVendorName: completeOrder['vendorName'] ?? order['vendorName'],
  //             initialItems: completeOrder['items'] != null
  //                 ? _mapOrderItems(completeOrder['items'] as List)
  //                 : [],
  //           ),
  //         ),
  //       ).then((_) => _fetchPurchaseOrders());
  //     } else {
  //       // If no complete data found, navigate with empty items
  //       Navigator.push(
  //         context,
  //         MaterialPageRoute(
  //           builder: (context) => ItemPurchasePage(
  //             initialVendorId: null,
  //             initialVendorName: order['vendorName'],
  //             initialItems: [],
  //           ),
  //         ),
  //       ).then((_) => _fetchPurchaseOrders());
  //     }
  //   } catch (error) {
  //     print('Error fetching order details: $error');
  //     // Navigate with available data as fallback
  //     Navigator.push(
  //       context,
  //       MaterialPageRoute(
  //         builder: (context) => ItemPurchasePage(
  //           initialVendorId: null,
  //           initialVendorName: order['vendorName'],
  //           initialItems: [],
  //         ),
  //       ),
  //     ).then((_) => _fetchPurchaseOrders());
  //   }
  // }
  void _navigateToItemPurchasePage(Map<String, dynamic> order) async {
    try {
      final snapshot = await _database.child('purchaseOrders').child(order['key']).get();

      if (snapshot.exists) {
        final completeOrder = snapshot.value as Map<dynamic, dynamic>;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ItemPurchasePage(
              initialVendorId: completeOrder['vendorId'],
              initialVendorName: completeOrder['vendorName'] ?? order['vendorName'],
              initialItems: completeOrder['items'] != null
                  ? _mapOrderItems(completeOrder['items'] as List)
                  : [],
              isFromPurchaseOrder: true, // Set this flag to true
            ),
          ),
        ).then((_) => _fetchPurchaseOrders());
      }
    } catch (error) {
      print('Error fetching order details: $error');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ItemPurchasePage(
            initialVendorId: null,
            initialVendorName: order['vendorName'],
            initialItems: [],
            isFromPurchaseOrder: true, // Set this flag to true
          ),
        ),
      ).then((_) => _fetchPurchaseOrders());
    }
  }


  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'fulfilled':
        color = Colors.green;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      case 'pending':
      default:
        color = Colors.orange;
    }

    return Chip(
      label: Text(
        status.toUpperCase(),
        style: TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  List<Map<String, dynamic>> _mapOrderItems(List<dynamic> items) {
    return items.map((item) {
      final itemMap = Map<String, dynamic>.from(item);

      // Map different possible field names to what ItemPurchasePage expects
      return {
        'itemId': itemMap['itemId'] ?? itemMap['itemKey'] ?? itemMap['id'],
        'quantity': itemMap['quantity'] ?? itemMap['qty'] ?? itemMap['amount'] ?? 0,
        'purchasePrice': itemMap['purchasePrice'] ?? itemMap['price'] ?? itemMap['cost'] ?? itemMap['unitPrice'] ?? 0,
        // Keep original fields as backup
        ...itemMap,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.isEnglish ? 'Purchase Orders' : 'خریداری کے آرڈرز',
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
            icon: Icon(Icons.add),
            onPressed: () => _navigateToEditPage(null),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchPurchaseOrders,
        child: _purchaseOrders.isEmpty
            ? Center(
          child: Text(
            languageProvider.isEnglish
                ? 'No purchase orders found'
                : 'کوئی خریداری کا آرڈر نہیں ملا',
          ),
        )
            : ListView.builder(
          itemCount: _purchaseOrders.length,
          itemBuilder: (context, index) {
            final order = _purchaseOrders[index];
            return Card(
              margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              elevation: 2,
              child: ListTile(
                title: Text(order['vendorName']),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${DateFormat('yyyy-MM-dd').format(DateTime.parse(order['orderDate']))}',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      '${languageProvider.isEnglish ? 'Total' : 'کل'}: ${order['grandTotal'].toStringAsFixed(2)} PKR',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // _buildStatusChip(order['status']),
                        if (order['expectedDeliveryDate'] != null)
                          Text(
                            DateFormat('MMM dd').format(
                                DateTime.parse(order['expectedDeliveryDate'])),
                            style: TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                    SizedBox(width: 8),
                    if (order['status'] == 'pending') // Only show button for pending orders
                      IconButton(
                        icon: Icon(Icons.add_shopping_cart, color: Colors.green),
                        onPressed: () => _navigateToItemPurchasePage(order),
                        tooltip: languageProvider.isEnglish
                            ? 'Add items to inventory'
                            : 'انوینٹری میں آئٹمز شامل کریں',
                      ),
                  ],
                ),
                onTap: () => _navigateToEditPage(order['key']),
              ),
            );
          },
        ),
      ),
    );
  }
}
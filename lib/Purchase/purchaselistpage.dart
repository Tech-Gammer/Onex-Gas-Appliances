
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../Provider/lanprovider.dart';
import 'BuildBOM.dart';
import 'itemPurchasePage.dart';


class PurchaseListPage extends StatefulWidget {
  @override
  State<PurchaseListPage> createState() => _PurchaseListPageState();
}

class _PurchaseListPageState extends State<PurchaseListPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _purchases = [];
  List<Map<String, dynamic>> _filteredPurchases = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPurchases();
  }

  // In PurchaseListPage, modify the editPurchase method:
  void editPurchase(Map<String, dynamic> purchase) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemPurchasePage(
          initialVendorId: purchase['vendorId'],
          initialVendorName: purchase['vendorName'],
          initialItems: List<Map<String, dynamic>>.from(purchase['items']),
          isEditMode: true, // Add this flag
          purchaseKey: purchase['key'], // Pass the purchase key for updating
        ),
      ),
    );
  }

  void fetchPurchases() {
    setState(() => _isLoading = true);
    FirebaseDatabase.instance.ref('purchases').onValue.listen((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> purchases = [];

        data.forEach((key, value) {
          final purchase = Map<String, dynamic>.from(value as Map<dynamic, dynamic>);
          purchase['key'] = key;

          // Handle items if they exist (assuming items is a List)
          if (purchase['items'] != null) {
            final items = List<Map<String, dynamic>>.from(
                (purchase['items'] as List<dynamic>).map(
                        (item) => Map<String, dynamic>.from(item as Map<dynamic, dynamic>)
                )
            );
            purchase['items'] = items;
          }

          purchases.add(purchase);
        });

        setState(() {
          _purchases = purchases;
          _filteredPurchases = purchases;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    }, onError: (error) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching purchases: $error')),
      );
    });
  }

  void searchPurchases(String query) {
    setState(() {
      _filteredPurchases = _purchases.where((purchase) {
        final vendorName = purchase['vendorName']?.toString().toLowerCase() ?? '';
        final items = purchase['items'] as List<Map<String, dynamic>>? ?? [];

        // Search in vendor name or any item name
        return vendorName.contains(query.toLowerCase()) ||
            items.any((item) =>
            item['itemName']?.toString().toLowerCase().contains(query.toLowerCase()) ?? false);
      }).toList();
    });
  }


  void deletePurchase(String key) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(languageProvider.isEnglish ? 'Confirm Delete' : 'حذف کی تصدیق کریں'),
          content: Text(languageProvider.isEnglish
              ? 'Are you sure you want to delete this purchase?'
              : 'کیا آپ واقعی اس خریداری کو حذف کرنا چاہتے ہیں؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(languageProvider.isEnglish ? 'No' : 'نہیں'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(languageProvider.isEnglish ? 'Yes' : 'ہاں'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await FirebaseDatabase.instance.ref('purchases/$key').remove();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(languageProvider.isEnglish
                ? 'Purchase deleted successfully'
                : 'خریداری کامیابی سے حذف ہو گئی'),
          ),
        );
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(languageProvider.isEnglish
                ? 'Failed to delete purchase: $error'
                : 'خریداری کو حذف کرنے میں ناکامی: $error'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.isEnglish ? 'Purchase List' : 'خریداری کی فہرست',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => BuildBomPage()),
              );
            },
            icon: Icon(Icons.build, color: Colors.white),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ItemPurchasePage()),
              );
            },
            icon: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: searchPurchases,
              decoration: InputDecoration(
                labelText: languageProvider.isEnglish
                    ? 'Search by Item or Vendor'
                    : 'آئٹم یا وینڈر کے ذریعہ تلاش کریں۔',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _filteredPurchases.isEmpty
                  ? Center(
                child: Text(languageProvider.isEnglish
                    ? 'No purchases found'
                    : 'کوئی خریداری نہیں ملی'),
              )
                  : ListView.builder(
                itemCount: _filteredPurchases.length,
                itemBuilder: (context, index) {
                  final purchase = _filteredPurchases[index];
                  final items = purchase['items'] as List<Map<String, dynamic>>? ?? [];
                  final timestamp = purchase['timestamp']?.toString();
                  final date = timestamp != null
                      ? dateFormat.format(DateTime.parse(timestamp))
                      : 'N/A';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ExpansionTile(
                      title: Text(
                        purchase['vendorName'] ?? 'Unknown Vendor',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('Total: ${purchase['grandTotal']?.toStringAsFixed(2) ?? '0.00'} PKR'),
                      trailing: Text(date),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              ...items.map((item) => ListTile(
                                title: Text(item['itemName'] ?? 'Unknown Item'),
                                subtitle: Text(
                                  'Qty: ${item['quantity']?.toStringAsFixed(2) ?? '0'}, '
                                      'Price: ${item['purchasePrice']?.toStringAsFixed(2) ?? '0.00'} PKR, '
                                      'Total: ${((item['quantity'] ?? 0) * (item['purchasePrice'] ?? 0)).toStringAsFixed(2)} PKR',
                                ),
                              )),
                              const Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => editPurchase(purchase),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => deletePurchase(purchase['key']),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
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
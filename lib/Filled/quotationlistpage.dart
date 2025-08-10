import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:intl/intl.dart';
import 'package:onex_gas_appliances/Filled/quotationpage.dart';
import 'package:provider/provider.dart';
import '../Provider/filled provider.dart';
import '../Provider/lanprovider.dart';
import 'Filledpage.dart';

class QuotationListPage extends StatefulWidget {
  const QuotationListPage({super.key});

  @override
  _QuotationListPageState createState() => _QuotationListPageState();
}

class _QuotationListPageState extends State<QuotationListPage> {
  final DatabaseReference _quotationsRef = FirebaseDatabase.instance.ref().child('quotations');
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _createFilledFromQuotation(BuildContext context, Map<dynamic, dynamic> quotation) async {
    // Add null check for quotation
    if (quotation == null) return;

    // Safe access with null checks
    final customer = (quotation['customer'] as Map?) ?? {};
    final items = (quotation['items'] as List?) ?? [];

    // Get the next filled number
    final filledProvider = Provider.of<FilledProvider>(context, listen: false);
    final filledNumber = (await filledProvider.getNextFilledNumber()).toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => filledpage(
          filled: {
            'customerId': customer['id']?.toString() ?? '',
            'customerName': customer['name']?.toString() ?? 'Unknown Customer',
            'referenceNumber': quotation['reference']?.toString() ?? '',
            'items': items.map((item) {
              return {
                'itemName': item['itemName']?.toString() ?? '',
                'description': item['description']?.toString() ?? '',
                'rate': (item['rate'] as num?)?.toDouble() ?? 0.0,
                'qty': (item['quantity'] as num?)?.toDouble() ?? 0.0,
                'total': (item['total'] as num?)?.toDouble() ?? 0.0,
              };
            }).toList(),
            'subtotal': (quotation['subtotal'] as num?)?.toDouble() ?? 0.0,
            'discount': (quotation['discount'] as num?)?.toDouble() ?? 0.0,
            'grandTotal': (quotation['grandTotal'] as num?)?.toDouble() ?? 0.0,
            'mazdoori': 0.0,
            'isFromQuotation': true,
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF8A65), Color(0xFFFFB74D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(languageProvider.isEnglish ? 'Quotations' : 'کوٹیشنز',style: TextStyle(color: Colors.white),),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add,color: Colors.white,),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const QuotationPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: languageProvider.isEnglish ? 'Search' : 'تلاش کریں',
                labelStyle: const TextStyle(color: Colors.orange),
                prefixIcon: const Icon(Icons.search, color: Colors.orange),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.orange, width: 2),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),
          Expanded(
            child: FirebaseAnimatedList(
              query: _quotationsRef,
              sort: (a, b) => b.key!.compareTo(a.key!),
              itemBuilder: (context, snapshot, animation, index) {
                final quotation = snapshot.value as Map<dynamic, dynamic>;
                final customer = quotation['customer'] as Map<dynamic, dynamic>;
                final date = quotation['date'] as String;
                final ref = quotation['reference'] as String;
                final grandTotal = quotation['grandTotal'] as double;

                final searchTerm = _searchController.text.toLowerCase();
                if (searchTerm.isNotEmpty &&
                    !customer['name'].toString().toLowerCase().contains(searchTerm) &&
                    !ref.toLowerCase().contains(searchTerm)) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.all(12),
                      title: Text(
                        customer['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('Ref: $ref'),
                          Text('Date: $date'),
                          Text('Total: ${NumberFormat.currency(symbol: '').format(grandTotal)}'),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.description, color: Colors.blue),
                            onPressed: () => _createFilledFromQuotation(context, quotation),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.teal),
                            onPressed: () {
                              _navigateToEditQuotation(context, snapshot.key!, quotation);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () {
                              _showDeleteDialog(context, snapshot.key!);
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        _showQuotationDetails(context, quotation);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToEditQuotation(BuildContext context, String quotationId, Map<dynamic, dynamic> quotation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuotationPage(
          quotationId: quotationId,
          existingQuotation: quotation,
        ),
      ),
    );
  }

  void _showQuotationDetails(BuildContext context, Map<dynamic, dynamic> quotation) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final customer = quotation['customer'] as Map<dynamic, dynamic>;
    final items = quotation['items'] as List<dynamic>;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(languageProvider.isEnglish ? 'Quotation Details' : 'کوٹیشن کی تفصیلات'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${languageProvider.isEnglish ? 'Customer' : 'کسٹمر'}: ${customer['name']}'),
                Text('${languageProvider.isEnglish ? 'Date' : 'تاریخ'}: ${quotation['date']}'),
                Text('${languageProvider.isEnglish ? 'Reference' : 'ریفرنس'}: ${quotation['reference']}'),
                const SizedBox(height: 16),
                Text(languageProvider.isEnglish ? 'Items:' : 'آئٹمز:', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Expanded(child: Text(item['itemName'])),
                        SizedBox(width: 50, child: Text(item['quantity'].toString())),
                        SizedBox(width: 80, child: Text(item['rate'].toStringAsFixed(2))),
                        SizedBox(width: 80, child: Text(item['total'].toStringAsFixed(2))),
                      ],
                    ),
                  );
                }).toList(),
                const Divider(),
                _buildTotalRow(languageProvider.isEnglish ? 'Subtotal:' : 'سب ٹوٹل:', quotation['subtotal']),
                _buildTotalRow(languageProvider.isEnglish ? 'Discount:' : 'رعایت:', quotation['discount']),
                _buildTotalRow(languageProvider.isEnglish ? 'TOTAL:' : 'مجموعی کل:', quotation['grandTotal'], isBold: true),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text(languageProvider.isEnglish ? 'Close' : 'بند کریں'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTotalRow(String label, double value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value.toStringAsFixed(2), style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String quotationId) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(languageProvider.isEnglish ? 'Delete Quotation' : 'کوٹیشن حذف کریں'),
          content: Text(languageProvider.isEnglish
              ? 'Are you sure you want to delete this quotation?'
              : 'کیا آپ واقعی اس کوٹیشن کو حذف کرنا چاہتے ہیں؟'),
          actions: [
            TextButton(
              child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text(languageProvider.isEnglish ? 'Delete' : 'حذف کریں', style: const TextStyle(color: Colors.red)),
              onPressed: () {
                _quotationsRef.child(quotationId).remove();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(languageProvider.isEnglish
                      ? 'Quotation deleted successfully'
                      : 'کوٹیشن کامیابی سے حذف ہو گئی')),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import '../Provider/lanprovider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CustomerItemPricesPage extends StatefulWidget {
  final String customerId;
  final String customerName;

  const CustomerItemPricesPage({
    required this.customerId,
    required this.customerName,
    Key? key,
  }) : super(key: key);

  @override
  _CustomerItemPricesPageState createState() => _CustomerItemPricesPageState();
}

class _CustomerItemPricesPageState extends State<CustomerItemPricesPage> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchItemsWithCustomerPrices();
  }

  Future<void> _fetchItemsWithCustomerPrices() async {
    setState(() => _isLoading = true);

    try {
      final DatabaseReference database = FirebaseDatabase.instance.ref();
      final snapshot = await database.child('items').get();

      if (snapshot.exists) {
        final Map<dynamic, dynamic> itemsData =
        snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> itemsList = [];

        itemsData.forEach((key, value) {
          final item = Map<String, dynamic>.from(value);
          item['key'] = key;

          if (item['customerBasePrices'] != null) {
            final prices = Map<String, dynamic>.from(item['customerBasePrices']);
            if (prices.containsKey(widget.customerId)) {
              final customerPrice = prices[widget.customerId] is int
                  ? (prices[widget.customerId] as int).toDouble()
                  : prices[widget.customerId] as double;

              itemsList.add({
                'itemName': item['itemName'],
                'defaultPrice': item['salePrice']?.toDouble() ?? 0.0,
                'customerPrice': customerPrice,
                'unit': item['unit'] ?? '',
                'image': item['image'],
              });
            }
          }

        });

        setState(() {
          _items = itemsList;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching items: $e')),
      );
    }
  }

  Future<void> _generateAndPrintPdf() async {
    final pdf = pw.Document();

    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                languageProvider.isEnglish
                    ? "${widget.customerName}'s Item Prices"
                    : "${widget.customerName} کی اشیاء کی قیمتیں",
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Table.fromTextArray(
              headers: [
                languageProvider.isEnglish ? 'Item' : 'آئٹم',
                languageProvider.isEnglish ? 'Unit' : 'یونٹ',
                languageProvider.isEnglish ? 'Price' : 'قیمت',
              ],
              data: _items.map((item) {
                final price = item['customerPrice'] > 0
                    ? item['customerPrice']
                    : item['defaultPrice'];
                return [
                  item['itemName'],
                  item['unit'],
                  '${price.toStringAsFixed(2)}rs',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: pw.TextStyle(fontSize: 10),
              headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.isEnglish
              ? '${widget.customerName}\'s Item Prices'
              : '${widget.customerName} کی اشیاء کی قیمتیں',
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
            icon: Icon(Icons.print,color: Colors.white,),
            onPressed: _generateAndPrintPdf,
            tooltip: languageProvider.isEnglish ? 'Print PDF' : 'پی ڈی ایف پرنٹ کریں',
          )
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? Center(
        child: Text(
          languageProvider.isEnglish
              ? 'No items found'
              : 'کوئی اشیاء نہیں ملیں',
        ),
      )
          : ListView.builder(
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return Card(
            margin:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: GestureDetector(
                onTap: () {
                  if (item['image'] != null) {
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                item['itemName'],
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Image.memory(
                              base64Decode(item['image']),
                              fit: BoxFit.contain,
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(languageProvider.isEnglish ? "Close" : "بند کریں"),
                            )
                          ],
                        ),
                      ),
                    );
                  }
                },
                child: item['image'] != null
                    ? CircleAvatar(
                  backgroundImage: MemoryImage(
                    base64Decode(item['image']),
                  ),
                )
                    : CircleAvatar(
                  child: Icon(Icons.shopping_bag),
                ),
              ),

              title: Text(item['itemName']),
              subtitle: Text(
                languageProvider.isEnglish
                    ? 'Unit: ${item['unit']}'
                    : 'یونٹ: ${item['unit']}',
              ),
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (item['customerPrice'] > 0)
                    Text(
                      '${item['customerPrice'].toStringAsFixed(2)}rs',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  if (item['customerPrice'] == 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${item['defaultPrice'].toStringAsFixed(2)}rs',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          languageProvider.isEnglish
                              ? 'Default'
                              : 'ڈیفالٹ',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

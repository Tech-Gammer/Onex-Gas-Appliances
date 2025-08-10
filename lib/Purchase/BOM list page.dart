import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../Provider/lanprovider.dart';
import 'BOM report page.dart';
import 'BuildBOM.dart';


class BomListPage extends StatefulWidget {
  @override
  _BomListPageState createState() => _BomListPageState();
}

class _BomListPageState extends State<BomListPage> {
  List<Map<String, dynamic>> _bomItems = [];
  bool _isLoading = true;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _fetchBomItems();
  }

  Future<void> _fetchBomItems() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _database.child('items').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> bomItems = [];

        data.forEach((key, value) {
          final item = Map<String, dynamic>.from(value as Map<dynamic, dynamic>);
          if (item['isBOM'] == true) {
            item['key'] = key;
            bomItems.add(item);
          }
        });

        setState(() {
          _bomItems = bomItems;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (error) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching BOM items: $error')),
      );
    }
  }

  void _navigateToBuildBom() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BuildBomPage()),
    ).then((_) => _fetchBomItems());
  }

  void _navigateToReports() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BomReportsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(languageProvider.isEnglish ? 'BOM List' : 'BOM فہرست'),
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
            icon: Icon(Icons.assessment),
            onPressed: _navigateToReports,
            tooltip: languageProvider.isEnglish ? 'Reports' : 'رپورٹس',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToBuildBom,
        backgroundColor: Color(0xFFFF8A65),
        child: Icon(Icons.build, color: Colors.white),
        tooltip: languageProvider.isEnglish ? 'Build BOM' : 'BOM بنائیں',
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _bomItems.isEmpty
          ? Center(
        child: Text(
          languageProvider.isEnglish
              ? 'No BOM items found'
              : 'کوئی BOM آئٹمز نہیں ملے',
          style: TextStyle(fontSize: 18),
        ),
      )
          : ListView.builder(
        itemCount: _bomItems.length,
        itemBuilder: (context, index) {
          final bomItem = _bomItems[index];
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ExpansionTile(
              title: Text(
                bomItem['itemName'],
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${languageProvider.isEnglish ? 'Qty:' : 'مقدار:'} ${bomItem['qtyOnHand']?.toString() ?? '0'}',
              ),
              children: [
                if (bomItem['components'] != null)
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          languageProvider.isEnglish
                              ? 'Components:'
                              : 'اجزاء:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        ...(bomItem['components'] as List).map<Widget>((component) {
                          return ListTile(
                            title: Text(component['name'] ?? ''),
                            subtitle: Text(
                              '${languageProvider.isEnglish ? 'Qty:' : 'مقدار:'} ${component['quantity']} ${component['unit'] ?? ''}',
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
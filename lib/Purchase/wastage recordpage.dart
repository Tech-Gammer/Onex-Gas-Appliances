import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../Provider/lanprovider.dart';

class WastageRecordsPage extends StatefulWidget {
  final String itemKey;
  final String itemName;

  const WastageRecordsPage({
    required this.itemKey,
    required this.itemName,
    Key? key,
  }) : super(key: key);

  @override
  _WastageRecordsPageState createState() => _WastageRecordsPageState();
}

class _WastageRecordsPageState extends State<WastageRecordsPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _wastageRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchWastageRecords();
  }

  Future<void> _fetchWastageRecords() async {
    try {
      final snapshot = await _database
          .child('wastage')
          .orderByChild('itemName')
          .equalTo(widget.itemName)
          .get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        setState(() {
          _wastageRecords = data.entries.map((entry) {
            return {
              'key': entry.key,
              ...Map<String, dynamic>.from(entry.value),
            };
          }).toList();
        });
      }
    } catch (e) {
      print('Error fetching wastage records: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final Color _primaryColor = Color(0xFFFF8A65);
    final Color _secondaryColor = Color(0xFFFFB74D);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.isEnglish
              ? 'Wastage Records - ${widget.itemName}'
              : 'ضائع شدہ ریکارڈز - ${widget.itemName}',
          style: TextStyle(color: Colors.white),
        ),
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
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _wastageRecords.isEmpty
          ? Center(
        child: Text(
          languageProvider.isEnglish
              ? 'No wastage records found'
              : 'کوئی ضائع شدہ ریکارڈز نہیں ملے',
          style: TextStyle(fontSize: 18),
        ),
      )
          : ListView.builder(
        itemCount: _wastageRecords.length,
        itemBuilder: (context, index) {
          final record = _wastageRecords[index];
          final date = DateTime.tryParse(record['date'] ?? '') ?? DateTime.now();
          final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(date);

          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 3,
            child: ListTile(
              title: Text(
                '${record['quantity']} ${languageProvider.isEnglish ? 'units' : 'اکائیوں'}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(formattedDate),
              trailing: Text(
                languageProvider.isEnglish
                    ? 'Purchase: ${record['purchaseId']?.toString().substring(0, 8) ?? 'N/A'}'
                    : 'خریداری: ${record['purchaseId']?.toString().substring(0, 8) ?? 'N/A'}',
              ),
              onTap: () {
                // Optionally show more details
              },
            ),
          );
        },
      ),
    );
  }
}
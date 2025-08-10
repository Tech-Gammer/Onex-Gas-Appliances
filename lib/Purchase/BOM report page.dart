import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../Provider/lanprovider.dart';

class BomReportsPage extends StatefulWidget {
  @override
  _BomReportsPageState createState() => _BomReportsPageState();
}

class _BomReportsPageState extends State<BomReportsPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _buildTransactions = [];
  bool _isLoading = true;
  DateTimeRange? _dateRange;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _fetchBuildTransactions();
  }

  Future<void> _fetchBuildTransactions() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _database.child('buildTransactions').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> transactions = [];

        data.forEach((key, value) {
          final transaction = Map<String, dynamic>.from(value as Map<dynamic, dynamic>);
          transaction['key'] = key;
          transactions.add(transaction);
        });

        // Sort by timestamp (newest first)
        transactions.sort((a, b) {
          final aTime = _parseTimestamp(a['timestamp']);
          final bTime = _parseTimestamp(b['timestamp']);
          return bTime.compareTo(aTime);
        });

        setState(() {
          _buildTransactions = transactions;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (error) {
      print(error);
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching build transactions: $error')),
      );
    }
  }

  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();

    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    } else if (timestamp is String) {
      return DateTime.tryParse(timestamp) ?? DateTime.now();
    } else if (timestamp is num) {
      return DateTime.fromMillisecondsSinceEpoch((timestamp * 1000).toInt());
    }
    return DateTime.now();
  }


  Future<void> _selectDateRange(BuildContext context) async {
    final initialDateRange = _dateRange ?? DateTimeRange(
      start: DateTime.now().subtract(Duration(days: 7)),
      end: DateTime.now(),
    );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: initialDateRange,
    );

    if (picked != null) {
      setState(() => _dateRange = picked);
      _filterTransactions();
    }
  }

  void _filterTransactions() {
    if (_dateRange == null) return;

    setState(() => _isLoading = true);
    try {
      final filtered = _buildTransactions.where((transaction) {
        final date = _parseTimestamp(transaction['timestamp']);
        return date.isAfter(_dateRange!.start) && date.isBefore(_dateRange!.end);
      }).toList();

      setState(() {
        _buildTransactions = filtered;
        _isLoading = false;
      });
    } catch (error) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error filtering transactions: $error')),
      );
    }
  }

  void _clearFilters() {
    setState(() {
      _dateRange = null;
    });
    _fetchBuildTransactions();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(languageProvider.isEnglish ? 'BOM Reports' : 'BOM رپورٹس'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF8A65), Color(0xFFFFB74D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.date_range),
                    label: Text(
                      _dateRange == null
                          ? languageProvider.isEnglish
                          ? 'Select Date Range'
                          : 'تاریخ کی حد منتخب کریں'
                          : '${_dateFormat.format(_dateRange!.start)} - ${_dateFormat.format(_dateRange!.end)}',
                    ),
                    onPressed: () => _selectDateRange(context),
                  ),
                ),
                if (_dateRange != null)
                  IconButton(
                    icon: Icon(Icons.clear),
                    onPressed: _clearFilters,
                    tooltip: languageProvider.isEnglish
                        ? 'Clear filters'
                        : 'فلٹرز صاف کریں',
                  ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _buildTransactions.isEmpty
                ? Center(
              child: Text(
                languageProvider.isEnglish
                    ? 'No build transactions found'
                    : 'کوئی تعمیر لین دین نہیں ملا',
                style: TextStyle(fontSize: 18),
              ),
            )
                : ListView.builder(
              itemCount: _buildTransactions.length,
              itemBuilder: (context, index) {
                final transaction = _buildTransactions[index];
                final date = _parseTimestamp(transaction['timestamp']);

                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ExpansionTile(
                    title: Text(transaction['bomItemName'] ?? ''),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_dateFormat.format(date)}'),
                        Text(
                          '${languageProvider.isEnglish ? 'Qty:' : 'مقدار:'} ${transaction['quantityBuilt']}',
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              languageProvider.isEnglish
                                  ? 'Components Used:'
                                  : 'استعمال شدہ اجزاء:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            ...(transaction['components'] as List).map<Widget>((component) {
                              final quantityUsed = num.tryParse(component['quantityUsed'].toString()) ?? 0;
                              return ListTile(
                                title: Text(component['name'] ?? ''),
                                subtitle: Text(
                                  '${languageProvider.isEnglish ? 'Qty:' : 'مقدار:'} $quantityUsed ${component['unit'] ?? ''}',
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
          ),
        ],
      ),
    );
  }
}
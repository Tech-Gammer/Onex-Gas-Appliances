import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class StockReportPage extends StatefulWidget {
  @override
  _StockReportPageState createState() => _StockReportPageState();
}

class _StockReportPageState extends State<StockReportPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _adjustments = [];
  List<Map<String, dynamic>> _filteredAdjustments = [];

  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _fetchAdjustments();
  }

  void _fetchAdjustments() async {
    final snapshot = await _database.child('qtyAdjustments').get();
    if (snapshot.exists) {
      final Map<dynamic, dynamic> adjustmentsData = snapshot.value as Map;
      final List<Map<String, dynamic>> adjustmentsList = [];

      adjustmentsData.forEach((itemKey, adjustments) {
        adjustments.forEach((adjustmentKey, adjustment) {
          adjustmentsList.add({
            'itemName': adjustment['itemName'],
            'oldQty': adjustment['oldQty'],
            'newQty': adjustment['newQty'],
            'date': adjustment['date'],
            'adjustedBy': adjustment['adjustedBy'],
          });
        });
      });

      setState(() {
        _adjustments = adjustmentsList;
        _applyFilters(); // Initial filter
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredAdjustments = _adjustments.where((adjustment) {
        final nameMatch = adjustment['itemName']
            .toString()
            .toLowerCase()
            .contains(_searchQuery.toLowerCase());

        final dateMatch = _selectedDateRange == null
            ? true
            : _isWithinRange(adjustment['date']);

        return nameMatch && dateMatch;
      }).toList();
    });
  }

  bool _isWithinRange(String dateStr) {
    try {
      final date = DateFormat('yyyy-MM-dd').parse(dateStr);
      return date.isAfter(_selectedDateRange!.start.subtract(Duration(days: 1))) &&
          date.isBefore(_selectedDateRange!.end.add(Duration(days: 1)));
    } catch (_) {
      return false;
    }
  }

  void _pickDateRange() async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
      _applyFilters();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Stock Adjustment Report', style: TextStyle(color: Colors.white)),
        centerTitle: true,
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
          // Search Bar and Filter Button
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Search Item',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      _searchQuery = value;
                      _applyFilters();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.date_range),
                  onPressed: _pickDateRange,
                  tooltip: 'Filter by date',
                ),
              ],
            ),
          ),

          // List of Adjustments
          Expanded(
            child: _filteredAdjustments.isEmpty
                ? Center(child: Text('No matching adjustments found.'))
                : ListView.builder(
              itemCount: _filteredAdjustments.length,
              itemBuilder: (context, index) {
                final adjustment = _filteredAdjustments[index];
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  child: ListTile(
                    title: Text(adjustment['itemName']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Old Qty: ${adjustment['oldQty']}'),
                        Text('New Qty: ${adjustment['newQty']}'),
                        Text('Date: ${adjustment['date']}'),
                        // Text('Adjusted By: ${adjustment['adjustedBy']}'),
                      ],
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
}

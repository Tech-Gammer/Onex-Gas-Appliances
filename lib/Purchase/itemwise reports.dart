import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../Provider/lanprovider.dart';

class ItemWiseReportPage extends StatefulWidget {
  @override
  _ItemWiseReportPageState createState() => _ItemWiseReportPageState();
}

class _ItemWiseReportPageState extends State<ItemWiseReportPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // UI Elements
  final TextEditingController _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedReportType = 'All';
  String? _selectedItemKey;

  // Data
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredReports = [];
  Map<String, String> _customerIdNameMap = {};
  bool _isLoading = false;
  bool _reportGenerated = false;

  // Colors
  final Color _primaryColor = Color(0xFFFF8A65);
  final Color _secondaryColor = Color(0xFFFFB74D);
  final Color _backgroundColor = Colors.grey[50]!;
  final Color _cardColor = Colors.white;
  final Color _textColor = Colors.grey[800]!;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _searchController.addListener(_filterReports);
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    await _fetchItems();
    await _fetchCustomerNames();
    setState(() => _isLoading = false);
  }

  Future<void> _fetchItems() async {
    try {
      final snapshot = await _database.child('items').get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final items = data.entries.map<Map<String, dynamic>>((entry) {
          return {
            'key': entry.key,
            ...Map<String, dynamic>.from(entry.value as Map),
          };
        }).toList();

        setState(() {
          _items = items;
        });
      }
    } catch (e) {
      print('Error fetching items: $e');
    }
  }

  Future<void> _fetchCustomerNames() async {
    try {
      final snapshot = await _database.child('customers').get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final Map<String, String> nameMap = {};

        data.forEach((key, value) {
          if (value is Map && value.containsKey('name')) {
            nameMap[key] = value['name'].toString();
          }
        });

        setState(() {
          _customerIdNameMap = nameMap;
        });
      }
    } catch (e) {
      print('Error fetching customer names: $e');
    }
  }

  Future<void> _generateReport() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _reportGenerated = false;
    });

    List<Map<String, dynamic>> allReports = [];

    // Fetch Purchase Reports
    await _fetchPurchaseReports(allReports);

    // Fetch Sales Reports
    await _fetchSalesReports(allReports);

    // Fetch BOM Build Reports
    await _fetchBomReports(allReports);

    // Sort by date (newest first)
    allReports.sort((a, b) {
      final dateA = a['date'] as DateTime;
      final dateB = b['date'] as DateTime;
      return dateB.compareTo(dateA);
    });

    setState(() {
      _filteredReports = allReports;
      _isLoading = false;
      _reportGenerated = true;
    });

    // Apply filters after generating the report
    _filterReports();
  }

  Future<void> _fetchPurchaseReports(List<Map<String, dynamic>> reports) async {
    try {
      final snapshot = await _database.child('purchases').get();
      if (snapshot.exists) {
        final purchases = snapshot.value as Map<dynamic, dynamic>;

        purchases.forEach((purchaseKey, purchaseData) {
          if (purchaseData['items'] != null) {
            final items = purchaseData['items'] as List;
            for (var item in items) {
              reports.add({
                'type': 'Purchase',
                'reportType': 'Purchase',
                'itemName': item['itemName'],
                'itemKey': _getItemKeyByName(item['itemName']),
                'date': DateTime.parse(purchaseData['timestamp']),
                'quantity': (item['quantity'] as num).toDouble(),
                'price': (item['purchasePrice'] as num).toDouble(),
                'total': (item['quantity'] as num).toDouble() *
                    (item['purchasePrice'] as num).toDouble(),
                'vendor': purchaseData['vendorName'] ?? 'Unknown Vendor',
                'purchaseId': purchaseKey,
                'unit': item['unit'] ?? '',
              });
            }
          }
        });
      }
    } catch (e) {
      print('Error fetching purchase reports: $e');
    }
  }

  Future<void> _fetchSalesReports(List<Map<String, dynamic>> reports) async {
    try {
      final snapshot = await _database.child('filled').get();
      if (snapshot.exists) {
        final allSales = snapshot.value;

        if (allSales is Map) {
          allSales.forEach((saleKey, saleData) {
            _processSaleData(saleData, reports);
          });
        } else if (allSales is List) {
          for (var saleData in allSales) {
            _processSaleData(saleData, reports);
          }
        }
      }
    } catch (e) {
      print('Error fetching sales reports: $e');
    }
  }

  void _processSaleData(dynamic saleData, List<Map<String, dynamic>> reports) {
    try {
      final saleMap = saleData is Map ? Map<String, dynamic>.from(saleData) : {};

      if (saleMap['items'] != null) {
        final items = saleMap['items'] is List ? saleMap['items'] : [];

        for (var item in items) {
          if (item is Map) {
            String customerName = 'Unknown Customer';
            if (saleMap['customerName'] != null) {
              customerName = saleMap['customerName'].toString();
            } else if (saleMap['customerId'] != null) {
              customerName = _customerIdNameMap[saleMap['customerId']] ??
                  "Customer ID: ${saleMap['customerId']}";
            }

            dynamic dateValue = saleMap['createdAt'] ?? saleMap['timestamp'];
            DateTime saleDate;

            if (dateValue is int) {
              saleDate = DateTime.fromMillisecondsSinceEpoch(dateValue);
            } else if (dateValue is String) {
              saleDate = DateTime.tryParse(dateValue) ?? DateTime.now();
            } else {
              saleDate = DateTime.now();
            }

            reports.add({
              'type': 'Sale',
              'reportType': 'Sales',
              'itemName': item['itemName'],
              'itemKey': _getItemKeyByName(item['itemName']),
              'date': saleDate,
              'quantity': (item['qty'] ?? 0).toDouble(),
              'price': (item['rate'] ?? 0).toDouble(),
              'total': (item['total'] ?? (item['qty'] ?? 0) * (item['rate'] ?? 0)).toDouble(),
              'customerName': customerName,
              'filledNumber': saleMap['filledNumber']?.toString() ?? '',
              'unit': item['unit'] ?? '',
            });
          }
        }
      }
    } catch (e) {
      print('Error processing sale data: $e');
    }
  }

  Future<void> _fetchBomReports(List<Map<String, dynamic>> reports) async {
    try {
      final snapshot = await _database.child('buildTransactions').get();
      if (snapshot.exists) {
        final builds = snapshot.value as Map<dynamic, dynamic>;

        builds.forEach((buildKey, buildData) {
          final build = Map<String, dynamic>.from(buildData as Map<dynamic, dynamic>);

          reports.add({
            'type': 'BOM Build',
            'reportType': 'BOM',
            'itemName': build['bomItemName'],
            'itemKey': build['bomItemKey'],
            'date': DateTime.fromMillisecondsSinceEpoch(build['timestamp']),
            'quantity': (build['quantityBuilt'] as num).toDouble(),
            'price': 0.0, // BOM builds don't have a direct price
            'total': 0.0, // Calculate from components if needed
            'components': build['components'],
            'buildId': buildKey,
            'unit': build['unit'] ?? 'units',
          });
        });
      }
    } catch (e) {
      print('Error fetching BOM reports: $e');
    }
  }

  String? _getItemKeyByName(String itemName) {
    try {
      final item = _items.firstWhere((item) => item['itemName'] == itemName);
      return item['key'];
    } catch (e) {
      return null;
    }
  }

  void _filterReports() {
    if (!_reportGenerated) return;

    List<Map<String, dynamic>> filtered = List.from(_filteredReports);

    // Filter by report type
    if (_selectedReportType != 'All') {
      filtered = filtered.where((report) =>
      report['reportType'] == _selectedReportType).toList();
    }

    // Filter by selected item
    if (_selectedItemKey != null) {
      filtered = filtered.where((report) =>
      report['itemKey'] == _selectedItemKey).toList();
    }

    // Filter by search term
    if (_searchController.text.isNotEmpty) {
      String searchTerm = _searchController.text.toLowerCase();
      filtered = filtered.where((report) =>
          report['itemName'].toString().toLowerCase().contains(searchTerm)).toList();
    }

    // Filter by date range
    if (_startDate != null && _endDate != null) {
      filtered = filtered.where((report) {
        final reportDate = report['date'] as DateTime;
        return reportDate.isAfter(_startDate!.subtract(Duration(days: 1))) &&
            reportDate.isBefore(_endDate!.add(Duration(days: 1)));
      }).toList();
    }

    setState(() {
      _filteredReports = filtered;
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _filterReports();
    }
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _filterReports();
  }

  Future<void> _exportToPDF() async {
    if (!_reportGenerated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please generate the report first')),
      );
      return;
    }

    try {
      final ByteData logoBytes = await rootBundle.load('assets/images/logo.png');
      final image = pw.MemoryImage(logoBytes.buffer.asUint8List());

      final pdf = pw.Document();

      // Calculate totals
      double totalQuantity = 0;
      double totalValue = 0;
      Map<String, int> typeCounts = {'Purchase': 0, 'Sale': 0, 'BOM Build': 0};

      for (var report in _filteredReports) {
        totalQuantity += report['quantity'];
        totalValue += report['total'];
        typeCounts[report['type']] = (typeCounts[report['type']] ?? 0) + 1;
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Image(image, width: 80, height: 80),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Item-wise Report',
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Report Type: $_selectedReportType'),
                    if (_startDate != null && _endDate != null)
                      pw.Text('Period: ${DateFormat.yMMMd().format(_startDate!)} - ${DateFormat.yMMMd().format(_endDate!)}'),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Summary
            pw.Container(
              padding: pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Summary', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Records: ${_filteredReports.length}'),
                      pw.Text('Total Value: ${totalValue.toStringAsFixed(2)} PKR'),
                    ],
                  ),
                  pw.SizedBox(height: 5),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Purchases: ${typeCounts['Purchase']}'),
                      pw.Text('Sales: ${typeCounts['Sale']}'),
                      pw.Text('BOM Builds: ${typeCounts['BOM Build']}'),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Data Table
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Type', 'Item', 'Qty', 'Price', 'Total', 'Details'],
              cellAlignment: pw.Alignment.centerLeft,
              data: _filteredReports.map((report) {
                return [
                  DateFormat.yMMMd().format(report['date']),
                  report['type'],
                  report['itemName'],
                  report['quantity'].toStringAsFixed(2),
                  report['price'].toStringAsFixed(2),
                  report['total'].toStringAsFixed(2),
                  _getReportDetails(report),
                ];
              }).toList(),
            ),
          ],
        ),
      );

      final bytes = await pdf.save();

      if (kIsWeb) {
        await Printing.sharePdf(bytes: bytes, filename: 'itemwise_report.pdf');
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/itemwise_report.pdf');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(file.path)], text: 'Item-wise Report');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report exported successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting report: $e')),
      );
    }
  }

  String _getReportDetails(Map<String, dynamic> report) {
    switch (report['type']) {
      case 'Purchase':
        return report['vendor'] ?? '';
      case 'Sale':
        return report['customerName'] ?? '';
      case 'BOM Build':
        return 'Built ${report['quantity']} units';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(languageProvider.isEnglish ? 'Item-wise Reports' : 'آئٹم وار رپورٹس'),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf),
            onPressed: _exportToPDF,
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
        child: Column(
          children: [
            // Filters Section
            Card(
              margin: EdgeInsets.all(8),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    // First Row - Report Type and Item Selection
                    Row(
                      children: [
                        // Report Type Dropdown
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                languageProvider.isEnglish ? 'Report Type' : 'رپورٹ کی قسم',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _selectedReportType,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                items: ['All', 'Purchase', 'Sales', 'BOM'].map((type) {
                                  return DropdownMenuItem(
                                    value: type,
                                    child: Text(type),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedReportType = value!;
                                  });
                                  _filterReports();
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 16),
                        // Item Selection Dropdown
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                languageProvider.isEnglish ? 'Select Item (Optional)' : 'آئٹم منتخب کریں (اختیاری)',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _selectedItemKey,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  hintText: languageProvider.isEnglish ? 'All Items' : 'تمام آئٹمز',
                                ),
                                items: [
                                  DropdownMenuItem<String>(
                                    value: null,
                                    child: Text(languageProvider.isEnglish ? 'All Items' : 'تمام آئٹمز'),
                                  ),
                                  ..._items.map((item) {
                                    return DropdownMenuItem<String>(
                                      value: item['key'],
                                      child: Text(item['itemName'] ?? 'Unknown Item'),
                                    );
                                  }).toList(),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedItemKey = value;
                                  });
                                  _filterReports();
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    // Second Row - Search and Date Range
                    Row(
                      children: [
                        // Search Field
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              labelText: languageProvider.isEnglish ? 'Search by Item Name' : 'آئٹم نام سے تلاش کریں',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        // Date Range Picker
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                languageProvider.isEnglish ? 'Date Range' : 'تاریخ کی حد',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: Icon(Icons.date_range),
                                      label: Text(
                                        _startDate != null && _endDate != null
                                            ? '${DateFormat.yMMMd().format(_startDate!)} - ${DateFormat.yMMMd().format(_endDate!)}'
                                            : (languageProvider.isEnglish ? 'Select Dates' : 'تاریخ منتخب کریں'),
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      onPressed: _selectDateRange,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _primaryColor,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_startDate != null && _endDate != null)
                                    IconButton(
                                      icon: Icon(Icons.clear),
                                      onPressed: _clearDateRange,
                                      tooltip: languageProvider.isEnglish ? 'Clear Dates' : 'تاریخ صاف کریں',
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    // Generate Report Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.refresh),
                        label: Text(languageProvider.isEnglish ? 'Generate Report' : 'رپورٹ تیار کریں'),
                        onPressed: _generateReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Summary Cards
            if (_reportGenerated && _filteredReports.isNotEmpty)
              Container(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    _buildSummaryCard(
                      languageProvider.isEnglish ? 'Total Records' : 'کل ریکارڈز',
                      _filteredReports.length.toString(),
                      Icons.list_alt,
                      Colors.blue,
                    ),
                    _buildSummaryCard(
                      languageProvider.isEnglish ? 'Total Value' : 'کل قیمت',
                      '${_filteredReports.fold(0.0, (sum, report) => sum + report['total']).toStringAsFixed(0)} PKR',
                      Icons.attach_money,
                      Colors.green,
                    ),
                    _buildSummaryCard(
                      languageProvider.isEnglish ? 'Purchases' : 'خریداری',
                      _filteredReports.where((r) => r['type'] == 'Purchase').length.toString(),
                      Icons.shopping_cart,
                      Colors.orange,
                    ),
                    _buildSummaryCard(
                      languageProvider.isEnglish ? 'Sales' : 'فروخت',
                      _filteredReports.where((r) => r['type'] == 'Sale').length.toString(),
                      Icons.sell,
                      Colors.purple,
                    ),
                  ],
                ),
              ),

            // Reports List
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : !_reportGenerated
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.assignment, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      languageProvider.isEnglish
                          ? 'Click "Generate Report" to view data'
                          : 'ڈیٹا دیکھنے کے لیے "رپورٹ تیار کریں" پر کلک کریں',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              )
                  : _filteredReports.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      languageProvider.isEnglish
                          ? 'No reports found with current filters'
                          : 'موجودہ فلٹرز کے ساتھ کوئی رپورٹ نہیں ملی',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              )
                  : Card(
                margin: EdgeInsets.all(8),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  itemCount: _filteredReports.length,
                  itemBuilder: (context, index) {
                    final report = _filteredReports[index];
                    return _buildReportTile(report, languageProvider);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 150,
      margin: EdgeInsets.only(right: 8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: _textColor.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportTile(Map<String, dynamic> report, LanguageProvider languageProvider) {
    Color typeColor;
    IconData typeIcon;

    switch (report['type']) {
      case 'Purchase':
        typeColor = Colors.green;
        typeIcon = Icons.shopping_cart;
        break;
      case 'Sale':
        typeColor = Colors.blue;
        typeIcon = Icons.sell;
        break;
      case 'BOM Build':
        typeColor = Colors.orange;
        typeIcon = Icons.build;
        break;
      default:
        typeColor = Colors.grey;
        typeIcon = Icons.help;
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: typeColor.withOpacity(0.1),
          child: Icon(typeIcon, color: typeColor),
        ),
        title: Text(
          report['itemName'] ?? 'Unknown Item',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${report['type']} - ${DateFormat.yMMMd().format(report['date'])}'),
            Text('Qty: ${report['quantity'].toStringAsFixed(2)} ${report['unit'] ?? ''}'),
            if (report['type'] != 'BOM Build')
              Text('Price: ${report['price'].toStringAsFixed(2)} PKR'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (report['type'] != 'BOM Build')
              Text(
                '${report['total'].toStringAsFixed(2)} PKR',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: typeColor,
                ),
              ),
            Text(
              _getReportDetails(report),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        onTap: () => _showReportDetails(report, languageProvider),
      ),
    );
  }

  void _showReportDetails(Map<String, dynamic> report, LanguageProvider languageProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${report['type']} ${languageProvider.isEnglish ? "Details" : "تفصیلات"}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(
                languageProvider.isEnglish ? 'Item' : 'آئٹم',
                report['itemName'] ?? 'N/A',
              ),
              _buildDetailRow(
                languageProvider.isEnglish ? 'Type' : 'قسم',
                report['type'],
              ),
              _buildDetailRow(
                languageProvider.isEnglish ? 'Date' : 'تاریخ',
                DateFormat.yMMMd().add_jm().format(report['date']),
              ),
              _buildDetailRow(
                languageProvider.isEnglish ? 'Quantity' : 'مقدار',
                '${report['quantity'].toStringAsFixed(2)} ${report['unit'] ?? ''}',
              ),
              if (report['type'] != 'BOM Build')
                _buildDetailRow(
                  languageProvider.isEnglish ? 'Price' : 'قیمت',
                  '${report['price'].toStringAsFixed(2)} PKR',
                ),
              if (report['type'] != 'BOM Build')
                _buildDetailRow(
                  languageProvider.isEnglish ? 'Total' : 'کل',
                  '${report['total'].toStringAsFixed(2)} PKR',
                ),

              // Type-specific details
              if (report['type'] == 'Purchase') ...[
                _buildDetailRow(
                  languageProvider.isEnglish ? 'Vendor' : 'فروشندہ',
                  report['vendor'] ?? 'N/A',
                ),
                _buildDetailRow(
                  languageProvider.isEnglish ? 'Purchase ID' : 'خریداری آئی ڈی',
                  report['purchaseId'] ?? 'N/A',
                ),
              ],

              if (report['type'] == 'Sale') ...[
                _buildDetailRow(
                  languageProvider.isEnglish ? 'Customer' : 'کسٹمر',
                  report['customerName'] ?? 'N/A',
                ),
                _buildDetailRow(
                  languageProvider.isEnglish ? 'Invoice #' : 'انوائس نمبر',
                  report['filledNumber'] ?? 'N/A',
                ),
              ],

              if (report['type'] == 'BOM Build') ...[
                _buildDetailRow(
                  languageProvider.isEnglish ? 'Build ID' : 'بلڈ آئی ڈی',
                  report['buildId'] ?? 'N/A',
                ),
                if (report['components'] != null) ...[
                  SizedBox(height: 16),
                  Text(
                    languageProvider.isEnglish ? 'Components Used:' : 'استعمال شدہ اجزاء:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  ...((report['components'] as List?) ?? []).map<Widget>((component) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(component['name'] ?? 'Unknown'),
                          ),
                          Expanded(
                            child: Text('${component['quantityUsed']} ${component['unit'] ?? ''}'),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(languageProvider.isEnglish ? 'Close' : 'بند کریں'),
          ),
        ],
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
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(width: 10),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
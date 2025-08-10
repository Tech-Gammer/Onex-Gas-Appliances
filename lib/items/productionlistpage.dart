import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../Provider/lanprovider.dart';

class ProductionListPage extends StatefulWidget {
  @override
  _ProductionListPageState createState() => _ProductionListPageState();
}

class _ProductionListPageState extends State<ProductionListPage> {
  List<Map<String, dynamic>> _productions = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProductions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProductions() async {
    setState(() => _isLoading = true);
    try {
      final database = FirebaseDatabase.instance.ref();
      final snapshot = await database.child('production').get();

      if (snapshot.exists) {
        final Map<dynamic, dynamic> productionData = snapshot.value as Map<dynamic, dynamic>;
        final List<Map<String, dynamic>> productions = [];

        productionData.forEach((key, value) {
          // Handle nested structure
          final inputItem = value['inputItem'] ?? {};
          final outputItem = value['outputItem'] ?? {};

          productions.add({
            'key': key,
            'inputItemId': inputItem['id'] ?? '',
            'inputItemName': inputItem['name'] ?? 'Unknown Input',
            'inputQty': _parseToDouble(inputItem['quantity']) ?? 0.0,
            'outputItemId': outputItem['id'] ?? '',
            'outputItemName': outputItem['name'] ?? 'Unknown Output',
            'outputQty': _parseToDouble(outputItem['quantity']) ?? 0.0,
            'wastageQty': _parseToDouble(value['wastage']) ?? 0.0,
            'timestamp': value['timestamp'] ?? '',
          });
        });

        // Sort by timestamp (newest first)
        productions.sort((a, b) {
          try {
            DateTime dateA = DateTime.parse(a['timestamp']);
            DateTime dateB = DateTime.parse(b['timestamp']);
            return dateB.compareTo(dateA);
          } catch (e) {
            return 0;
          }
        });

        setState(() {
          _productions = productions;
        });
      } else {
        setState(() => _productions = []);
      }
    } catch (e) {
      print('Error fetching productions: $e');
      _showErrorSnackBar('Error loading productions: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredProductions {
    if (_searchQuery.isEmpty) return _productions;

    return _productions.where((production) {
      final inputName = production['inputItemName'].toLowerCase();
      final outputName = production['outputItemName'].toLowerCase();
      final query = _searchQuery.toLowerCase();

      return inputName.contains(query) || outputName.contains(query);
    }).toList();
  }

  Future<void> _deleteProduction(Map<String, dynamic> production) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            languageProvider.isEnglish ? 'Delete Production' : 'پروڈکشن ڈیلیٹ کریں',
            style: TextStyle(color: Color(0xFFE65100)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  languageProvider.isEnglish
                      ? 'Are you sure you want to delete this production record?'
                      : 'کیا آپ واقعی اس پروڈکشن ریکارڈ کو ڈیلیٹ کرنا چاہتے ہیں؟'
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      languageProvider.isEnglish ? 'This will:' : 'یہ کرے گا:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('• ${languageProvider.isEnglish ? 'Restore' : 'بحالی'} ${production['inputItemName']}: +${production['inputQty'].toStringAsFixed(2)} kg'),
                    Text('• ${languageProvider.isEnglish ? 'Remove' : 'ہٹا دیں'} ${production['outputItemName']}: -${production['outputQty'].toStringAsFixed(2)} kg'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                languageProvider.isEnglish ? 'Cancel' : 'منسوخ',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: Text(
                languageProvider.isEnglish ? 'Delete' : 'ڈیلیٹ',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _performDelete(production);
    }
  }

  Future<void> _performDelete(Map<String, dynamic> production) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    try {
      final database = FirebaseDatabase.instance.ref();
      final String productionKey = production['key'];
      final String inputItemId = production['inputItemId'];
      final String outputItemId = production['outputItemId'];
      final double inputQty = production['inputQty'];
      final double outputQty = production['outputQty'];

      // Start a transaction-like operation

      // 1. Restore input item quantity (add back what was used)
      if (inputItemId.isNotEmpty && inputQty > 0) {
        final inputRef = database.child('items').child(inputItemId);
        final inputSnapshot = await inputRef.get();

        if (inputSnapshot.exists) {
          final currentInputQty = _parseToDouble(inputSnapshot.child('qtyOnHand').value) ?? 0.0;
          final newInputQty = currentInputQty + inputQty;
          await inputRef.update({'qtyOnHand': newInputQty});
          print('Restored input item $inputItemId: $currentInputQty + $inputQty = $newInputQty');
        }
      }

      // 2. Reduce output item quantity (subtract what was produced)
      if (outputItemId.isNotEmpty && outputQty > 0) {
        final outputRef = database.child('items').child(outputItemId);
        final outputSnapshot = await outputRef.get();

        if (outputSnapshot.exists) {
          final currentOutputQty = _parseToDouble(outputSnapshot.child('qtyOnHand').value) ?? 0.0;
          final newOutputQty = (currentOutputQty - outputQty).clamp(0.0, double.infinity);
          await outputRef.update({'qtyOnHand': newOutputQty});
          print('Reduced output item $outputItemId: $currentOutputQty - $outputQty = $newOutputQty');

          // Warn if this creates negative stock (clamped to 0)
          if (currentOutputQty < outputQty) {
            _showWarningSnackBar(
                languageProvider.isEnglish
                    ? 'Warning: Output quantity was insufficient. Set to 0.'
                    : 'انتباہ: آؤٹ پٹ کی مقدار ناکافی تھی۔ صفر پر سیٹ کر دیا گیا۔'
            );
          }
        }
      }

      // 3. Delete the production record
      await database.child('production').child(productionKey).remove();

      // 4. Refresh the list
      await _fetchProductions();

      _showSuccessSnackBar(
          languageProvider.isEnglish
              ? 'Production deleted and quantities restored successfully!'
              : 'پروڈکشن ڈیلیٹ ہو گئی اور مقداریں بحال ہو گئیں!'
      );

    } catch (e) {
      print('Error deleting production: $e');
      _showErrorSnackBar(
          languageProvider.isEnglish
              ? 'Error deleting production: $e'
              : 'پروڈکشن ڈیلیٹ کرنے میں خرابی: $e'
      );
    }
  }

  double? _parseToDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
      duration: Duration(seconds: 3),
    ));
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      duration: Duration(seconds: 4),
    ));
  }

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.orange,
      duration: Duration(seconds: 4),
    ));
  }

  String _formatDate(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      return DateFormat('MMM dd, yyyy\nhh:mm a').format(date);
    } catch (e) {
      return timestamp;
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.isEnglish ? 'Production Records' : 'پروڈکشن ریکارڈز',
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
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchProductions,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF3E0),
              Color(0xFFFFE0B2),
            ],
          ),
        ),
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: languageProvider.isEnglish
                      ? 'Search by item name...'
                      : 'آئٹم کے نام سے تلاش کریں...',
                  prefixIcon: Icon(Icons.search, color: Color(0xFFFF8A65)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Color(0xFFFF8A65)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Color(0xFFFF8A65), width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),

            // Productions List
            Expanded(
              child: _isLoading
                  ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF8A65)),
                ),
              )
                  : _filteredProductions.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.production_quantity_limits,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 16),
                    Text(
                      languageProvider.isEnglish
                          ? 'No production records found'
                          : 'کوئی پروڈکشن ریکارڈ نہیں ملا',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
                  : RefreshIndicator(
                onRefresh: _fetchProductions,
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredProductions.length,
                  itemBuilder: (context, index) {
                    final production = _filteredProductions[index];
                    return _buildProductionCard(production, languageProvider);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductionCard(Map<String, dynamic> production, LanguageProvider languageProvider) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFFFF8E1)],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with date and delete button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDate(production['timestamp']),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red[400], size: 20),
                    onPressed: () => _deleteProduction(production),
                    constraints: BoxConstraints(),
                    padding: EdgeInsets.all(8),
                  ),
                ],
              ),

              Divider(color: Color(0xFFFF8A65).withOpacity(0.3)),

              // Input Section
              _buildSectionHeader(
                languageProvider.isEnglish ? 'INPUT' : 'ان پٹ',
                Icons.input,
                Colors.blue[600]!,
              ),
              SizedBox(height: 8),
              _buildItemRow(
                production['inputItemName'],
                production['inputQty'],
                'kg',
                languageProvider,
                Colors.blue[50]!,
              ),

              SizedBox(height: 12),

              // Output Section
              _buildSectionHeader(
                languageProvider.isEnglish ? 'OUTPUT' : 'آؤٹ پٹ',
                Icons.output,
                Colors.green[600]!,
              ),
              SizedBox(height: 8),
              _buildItemRow(
                production['outputItemName'],
                production['outputQty'],
                'kg',
                languageProvider,
                Colors.green[50]!,
              ),

              // Wastage Section (if any)
              if (production['wastageQty'] > 0) ...[
                SizedBox(height: 12),
                _buildSectionHeader(
                  languageProvider.isEnglish ? 'WASTAGE' : 'فالتو',
                  Icons.warning,
                  Colors.red[600]!,
                ),
                SizedBox(height: 8),
                _buildItemRow(
                  languageProvider.isEnglish ? 'Wasted Material' : 'فالتو مواد',
                  production['wastageQty'],
                  'kg',
                  languageProvider,
                  Colors.red[50]!,
                ),
              ],

              // Efficiency Indicator
              SizedBox(height: 12),
              _buildEfficiencyIndicator(production, languageProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildItemRow(String itemName, double quantity, String unit, LanguageProvider languageProvider, Color backgroundColor) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              itemName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '${quantity.toStringAsFixed(2)} $unit',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE65100),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEfficiencyIndicator(Map<String, dynamic> production, LanguageProvider languageProvider) {
    final double inputQty = production['inputQty'];
    final double outputQty = production['outputQty'];
    final double wastageQty = production['wastageQty'];
    final double efficiency = inputQty > 0 ? (outputQty / inputQty) * 100 : 0;

    Color efficiencyColor;
    String efficiencyText;

    if (efficiency >= 90) {
      efficiencyColor = Colors.green;
      efficiencyText = languageProvider.isEnglish ? 'Excellent' : 'بہترین';
    } else if (efficiency >= 80) {
      efficiencyColor = Colors.orange;
      efficiencyText = languageProvider.isEnglish ? 'Good' : 'اچھا';
    } else {
      efficiencyColor = Colors.red;
      efficiencyText = languageProvider.isEnglish ? 'Poor' : 'کمزور';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: efficiencyColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: efficiencyColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            languageProvider.isEnglish ? 'Efficiency:' : 'کارکردگی:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: efficiencyColor,
            ),
          ),
          Text(
            '${efficiency.toStringAsFixed(1)}% ($efficiencyText)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: efficiencyColor,
            ),
          ),
        ],
      ),
    );
  }
}
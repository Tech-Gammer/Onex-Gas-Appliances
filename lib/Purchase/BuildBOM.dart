import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../Provider/lanprovider.dart';
import 'BOM list page.dart';

class BuildBomPage extends StatefulWidget {
  @override
  _BuildBomPageState createState() => _BuildBomPageState();
}

class _BuildBomPageState extends State<BuildBomPage> {
  final _formKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _bomItems = [];
  Map<String, dynamic>? _selectedItem;
  TextEditingController _quantityController = TextEditingController(text: '1');
  bool _isLoading = true;
  bool _isBuilding = false;

  @override
  void initState() {
    super.initState();
    _quantityController.addListener(() {
      setState(() {}); // Rebuild when quantity changes
    });
    fetchItems();
  }


  Future<void> fetchItems() async {
    setState(() => _isLoading = true);
    final database = FirebaseDatabase.instance.ref();
    try {
      final snapshot = await database.child('items').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> items = [];

        data.forEach((key, value) {
          final item = Map<String, dynamic>.from(value as Map<dynamic, dynamic>);
          item['key'] = key;

          // Check if item is a BOM (has components)
          if (item['isBOM'] == true && item['components'] != null) {
            _bomItems.add(item);
          }

          items.add(item);
        });

        setState(() {
          _items = items;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (error) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching items: $error')),
      );
    }
  }

  Future<void> buildBom() async {
    if (!_formKey.currentState!.validate() || _selectedItem == null) return;

    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final quantity = double.tryParse(_quantityController.text) ?? 1.0;

    setState(() => _isBuilding = true);

    try {
      final database = FirebaseDatabase.instance.ref();

      // Get components - filter out any null or incomplete entries
      final components = (_selectedItem!['components'] as List?)
          ?.where((c) => c is Map && c['id'] != null && c['name'] != null)
          .cast<Map<dynamic, dynamic>>()
          .toList() ?? [];

      if (components.isEmpty) {
        throw languageProvider.isEnglish
            ? 'Selected BOM has no valid components'
            : 'منتخب BOM میں کوئی درست اجزاء نہیں ہیں';
      }

      // Validate all components exist and have enough quantity
      final Map<String, dynamic> updates = {};
      final List<Map<String, dynamic>> usedComponents = [];

      for (var component in components) {
        final componentId = component['id'].toString();
        final componentName = component['name'].toString();
        final componentQtyPerUnit = (component['quantity'] is num)
            ? (component['quantity'] as num).toDouble()
            : 0.0;
        final totalQtyNeeded = componentQtyPerUnit * quantity;

        // Find component in inventory
        final componentItem = _items.firstWhere(
              (item) => item['key'] == componentId,
          orElse: () => {},
        );

        if (componentItem.isEmpty) {
          throw languageProvider.isEnglish
              ? 'Component not found: $componentName'
              : 'جزو نہیں ملا: $componentName';
        }

        // Check quantity (using qtyOnHand or qtyOmiand based on your actual DB field)
        final currentQty = (componentItem['qtyOnHand'] ?? componentItem['qtyOmiand'])?.toDouble() ?? 0.0;
        if (currentQty < totalQtyNeeded) {
          throw languageProvider.isEnglish
              ? 'Not enough $componentName (available: $currentQty, needed: $totalQtyNeeded)'
              : 'کافی نہیں $componentName (دستیاب: $currentQty, درکار: $totalQtyNeeded)';
        }

        // Prepare deduction
        final newQty = currentQty - totalQtyNeeded;
        updates['items/${componentItem['key']}/qtyOnHand'] = newQty;

        // Record used component for transaction
        usedComponents.add({
          'id': componentId,
          'name': componentName,
          'quantityUsed': totalQtyNeeded,
          'unit': component['unit'] ?? '',
        });
      }

      // Update the BOM item quantity
      final builtItemKey = _selectedItem!['key'];
      final currentBuiltQty = (_selectedItem!['qtyOnHand'] ?? _selectedItem!['qtyOmiand'])?.toDouble() ?? 0.0;
      updates['items/$builtItemKey/qtyOnHand'] = currentBuiltQty + quantity;

      // Record the build transaction
      final buildRecord = {
        'bomItemKey': builtItemKey,
        'bomItemName': _selectedItem!['itemName'],
        'quantityBuilt': quantity,
        'timestamp': ServerValue.timestamp,
        'components': usedComponents,
      };

      final newBuildRef = database.child('buildTransactions').push();
      updates['buildTransactions/${newBuildRef.key}'] = buildRecord;

      // Execute all updates atomically
      await database.update(updates);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${languageProvider.isEnglish ? 'Successfully built' : 'کامیابی سے بنایا گیا'} '
                '${_selectedItem!['itemName']} (x$quantity)',
          ),
        ),
      );

      // Refresh data
      await fetchItems();
      _formKey.currentState?.reset();
      setState(() {
        _selectedItem = null;
        _quantityController.text = '1';
      });
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${languageProvider.isEnglish ? 'Build failed' : 'تعمیر ناکام ہوئی'}: $error',
          ),
        ),
      );
    } finally {
      setState(() => _isBuilding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(languageProvider.isEnglish ? 'Build BOM' : 'BOM بنائیں'),
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
            icon: Icon(Icons.list),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => BomListPage()),
              );
            },
            tooltip: languageProvider.isEnglish ? 'BOM List' : 'BOM فہرست',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                languageProvider.isEnglish ? 'Select BOM Item' : 'BOM آئٹم منتخب کریں',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              DropdownButtonFormField<Map<String, dynamic>>(
                value: _selectedItem,
                items: _bomItems.map((item) {
                  return DropdownMenuItem<Map<String, dynamic>>(
                    value: item,
                    child: Text(item['itemName']),
                  );
                }).toList(),
                onChanged: (item) {
                  setState(() => _selectedItem = item);
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: languageProvider.isEnglish
                      ? 'Select an item to build'
                      : 'بنانے کے لیے ایک آئٹم منتخب کریں',
                ),
                validator: (value) => value == null
                    ? languageProvider.isEnglish
                    ? 'Please select an item'
                    : 'براہ کرم ایک آئٹم منتخب کریں'
                    : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: languageProvider.isEnglish ? 'Quantity' : 'مقدار',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return languageProvider.isEnglish
                        ? 'Please enter quantity'
                        : 'براہ کرم مقدار درج کریں';
                  }
                  if (double.tryParse(value) == null || double.parse(value) <= 0) {
                    return languageProvider.isEnglish
                        ? 'Please enter a valid quantity'
                        : 'براہ کرم ایک درست مقدار درج کریں';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24),
              if (_selectedItem != null) ...[
                Text(
                  languageProvider.isEnglish ? 'Required Components:' : 'مطلوبہ اجزاء:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                ...(_selectedItem!['components'] as List).map<Widget>((component) {
                  final componentName = component['name'].toString();
                  final qtyPerUnit = (component['quantity'] ?? 0) as num;
                  final totalQty = qtyPerUnit.toDouble() * (double.tryParse(_quantityController.text) ?? 1);


                  final componentItem = _items.firstWhere(
                        (item) => item['itemName'] == componentName,
                    orElse: () => {},
                  );

                  final availableQty = componentItem.isNotEmpty
                      ? componentItem['qtyOnHand']?.toDouble() ?? 0.0
                      : 0.0;
                  final hasEnough = availableQty >= totalQty;

                  return ListTile(
                    title: Text(componentName),
                    subtitle: Text('$qtyPerUnit × ${_quantityController.text} = $totalQty'),
                    trailing: Text(
                      'Available: $availableQty',
                      style: TextStyle(
                        color: hasEnough ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
                SizedBox(height: 16),
              ],
              Center(
                child: ElevatedButton(
                  onPressed: _isBuilding ? null : buildBom,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFF8A65),
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: _isBuilding
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                    languageProvider.isEnglish ? 'Build Item' : 'آئٹم بنائیں',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

}
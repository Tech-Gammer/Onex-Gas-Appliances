import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class ProductionPage extends StatefulWidget {
  final Map<String, dynamic> inputItem;

  ProductionPage({required this.inputItem});

  @override
  _ProductionPageState createState() => _ProductionPageState();
}

class _ProductionPageState extends State<ProductionPage> {
  final TextEditingController _outputController = TextEditingController();
  final TextEditingController _wastageController = TextEditingController();
  // final TextEditingController _outputItemSearchController = TextEditingController();
  late TextEditingController _outputItemSearchController;

  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _outputItems = [];
  Map<String, dynamic>? _selectedOutputItem;
  bool _isLoadingOutputItems = false;

  @override
  void initState() {
    super.initState();
    _outputItemSearchController = TextEditingController();
    _fetchOutputItems();
  }


  Future<void> _fetchOutputItems() async {
    setState(() => _isLoadingOutputItems = true);
    try {
      final snapshot = await FirebaseDatabase.instance.ref('items').get();
      if (snapshot.exists) {
        final Map<dynamic, dynamic> itemsData = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _outputItems = itemsData.entries.map((entry) => {
            'key': entry.key,
            'itemName': entry.value['itemName'],
            'qtyOnHand': (entry.value['qtyOnHand'] as num?)?.toDouble() ?? 0.0,
            'costPrice': (entry.value['costPrice'] as num?)?.toDouble() ?? 0.0,
          }).toList();
        });
      }
    } catch (e) {
      print('Error fetching output items: $e');
    } finally {
      setState(() => _isLoadingOutputItems = false);
    }
  }

  void _saveProduction() async {
    if (_formKey.currentState!.validate() && _selectedOutputItem != null) {
      try {
        // Input item details
        final inputItemKey = widget.inputItem['key']?.toString() ?? '';
        final inputItemName = widget.inputItem['itemName']?.toString() ?? 'Unknown Item';
        final inputQty = double.tryParse(widget.inputItem['usedQty']?.toString() ?? '0') ?? 0.0;
        final purchasePrice = double.tryParse(widget.inputItem['purchasePrice']?.toString() ?? '0') ?? 0.0;
        final vendorId = widget.inputItem['vendorId']?.toString() ?? '';
        final vendorName = widget.inputItem['vendorName']?.toString() ?? 'Unknown Vendor';

        // Output item details
        final outputItemKey = _selectedOutputItem!['key']?.toString() ?? '';
        final outputItemName = _selectedOutputItem!['itemName']?.toString() ?? 'Unknown Output Item';

        // Production quantities
        final outputQty = double.tryParse(_outputController.text) ?? 0.0;
        final wastageQty = double.tryParse(_wastageController.text) ?? 0.0;
        final totalProduced = outputQty + wastageQty;

        // Validations
        if (inputItemKey.isEmpty || outputItemKey.isEmpty) {
          _showErrorSnackBar("Invalid item selection");
          return;
        }

        if (inputQty <= 0) {
          _showErrorSnackBar("Invalid input quantity");
          return;
        }

        if (totalProduced > inputQty) {
          _showErrorSnackBar("Output + Wastage cannot exceed Input Quantity");
          return;
        }

        final db = FirebaseDatabase.instance.ref();
        final timestamp = DateTime.now().toString();

        // 1. Save production record with all details
        final productionRecord = {
          "inputItem": {
            "id": inputItemKey,
            "name": inputItemName,
            "quantity": inputQty,
            "purchasePrice": purchasePrice,
            "vendorId": vendorId,
            "vendorName": vendorName,
          },
          "outputItem": {
            "id": outputItemKey,
            "name": outputItemName,
            "quantity": outputQty,
          },
          "wastage": wastageQty,
          "timestamp": timestamp,
          "efficiency": (outputQty / inputQty) * 100, // Efficiency percentage
        };

        await db.child('production').push().set(productionRecord);

        // 2. Update input item quantity (deduct used quantity)
        final inputRef = db.child('items').child(inputItemKey);
        final inputSnapshot = await inputRef.get();

        if (inputSnapshot.exists) {
          final currentInputQty = double.tryParse(inputSnapshot.child('qtyOnHand').value.toString()) ?? 0.0;
          final newInputQty = currentInputQty - inputQty;

          if (newInputQty < 0) {
            _showErrorSnackBar("Insufficient quantity in inventory");
            return;
          }

          await inputRef.update({'qtyOnHand': newInputQty});
        }

        // 3. Update output item quantity (add produced quantity)
        final outputRef = db.child('items').child(outputItemKey);
        final outputSnapshot = await outputRef.get();

        if (outputSnapshot.exists) {
          final currentOutputQty = double.tryParse(outputSnapshot.child('qtyOnHand').value.toString()) ?? 0.0;
          final newOutputQty = currentOutputQty + outputQty;

          await outputRef.update({'qtyOnHand': newOutputQty});
        } else {
          // If output item doesn't exist, create it
          await outputRef.set({
            'itemName': outputItemName,
            'qtyOnHand': outputQty,
            'costPrice': 0.0, // You might calculate this based on input costs
          });
        }

        // 4. Save wastage record if any
        if (wastageQty > 0) {
          await db.child('wastage').push().set({
            "inputItemId": inputItemKey,
            "inputItemName": inputItemName,
            "quantity": wastageQty,
            "outputItemId": outputItemKey,
            "outputItemName": outputItemName,
            "timestamp": timestamp,
            "relatedProduction": productionRecord,
          });
        }

        _showSuccessSnackBar("Production recorded successfully!");
        Navigator.pop(context);
      } catch (e) {
        print('Error in saveProduction: $e');
        _showErrorSnackBar("Error saving production: $e");
      }
    } else if (_selectedOutputItem == null) {
      _showErrorSnackBar("Please select an output item");
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final itemName = widget.inputItem['itemName']?.toString() ?? 'Unknown Item';
    final usedQty = double.tryParse(widget.inputItem['usedQty']?.toString() ?? '0') ?? 0.0;
    final purchasePrice = double.tryParse(widget.inputItem['purchasePrice']?.toString() ?? '0') ?? 0.0;
    final vendorName = widget.inputItem['vendorName']?.toString() ?? 'Unknown Vendor';

    return Scaffold(
      appBar: AppBar(
        title: Text('Production'),
        backgroundColor: Color(0xFFFF8A65),
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
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Text(
                      "Input Item Details:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFFE65100),
                      ),
                      ),
                      SizedBox(height: 8),
                      Text("Item: $itemName"),
                      Text("Quantity: ${usedQty.toStringAsFixed(2)} kg"),
                      Text("Purchase Price: ${purchasePrice.toStringAsFixed(2)} PKR/kg"),
                      Text("Vendor: $vendorName"),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  "Select Output Item:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE65100),
                  ),
                ),
                SizedBox(height: 8),
                _isLoadingOutputItems
                    ? Center(child: CircularProgressIndicator())
                    : Autocomplete<Map<String, dynamic>>(
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) return const Iterable.empty();
                    return _outputItems.where((item) =>
                        item['itemName'].toLowerCase().contains(textEditingValue.text.toLowerCase()));
                  },
                  displayStringForOption: (item) => item['itemName'],
                  onSelected: (item) {
                    setState(() {
                      _selectedOutputItem = item;
                    });
                  },
                  fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                    _outputItemSearchController = controller;
                    return TextFormField(
                      controller: controller, // use local controller here
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: "Search Output Item",
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFFF8A65)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFFF8A65)),
                        ),
                      ),
                      validator: (value) {
                        if (_selectedOutputItem == null) {
                          return "Please select an output item";
                        }
                        return null;
                      },
                    );
                  },
                ),
                SizedBox(height: 16),
                if (_selectedOutputItem != null) ...[
                  Text(
                    "Selected Output: ${_selectedOutputItem!['itemName']}",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Current Stock: ${_selectedOutputItem!['qtyOnHand'].toStringAsFixed(2)} kg",
                  ),
                  SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _outputController,
                  decoration: InputDecoration(
                    labelText: "Output Quantity (kg)",
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFFF8A65)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFFF8A65)),
                    ),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Please enter output quantity";
                    }
                    final qty = double.tryParse(value);
                    if (qty == null || qty < 0) {
                      return "Please enter a valid quantity";
                    }
                    if (usedQty > 0 && qty > usedQty) {
                      return "Output cannot exceed input quantity";
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _wastageController,
                  decoration: InputDecoration(
                    labelText: "Wastage Quantity (kg)",
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFFF8A65)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFFF8A65)),
                    ),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Please enter wastage quantity (0 if none)";
                    }
                    final qty = double.tryParse(value);
                    if (qty == null || qty < 0) {
                      return "Please enter a valid quantity";
                    }

                    final outputQty = double.tryParse(_outputController.text) ?? 0.0;
                    if (usedQty > 0 && (outputQty + qty) > usedQty) {
                      return "Output + Wastage cannot exceed input quantity";
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saveProduction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFF8A65),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    "Record Production",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
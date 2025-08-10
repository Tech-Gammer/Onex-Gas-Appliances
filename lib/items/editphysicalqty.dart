import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'itemslistpage.dart';

class EditQtyPage extends StatefulWidget {
  final Map<String, dynamic> itemData;

  EditQtyPage({required this.itemData});

  @override
  _EditQtyPageState createState() => _EditQtyPageState();
}

class _EditQtyPageState extends State<EditQtyPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _qtyController;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(
        text: widget.itemData['qtyOnHand']?.toString() ?? '0'
    );
  }

  void _updateQuantity() async {
    if (_formKey.currentState!.validate()) {
      final DatabaseReference database = FirebaseDatabase.instance.ref();
      final int? newQty = int.tryParse(_qtyController.text);

      if (newQty == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter a valid quantity')),
        );
        return;
      }

      try {
        final int oldQty = widget.itemData['qtyOnHand'] ?? 0;

        // Update the item's quantity
        await database.child('items/${widget.itemData['key']}').update({
          'qtyOnHand': newQty,
        });

        // Log the adjustment in qtyAdjustments
        final adjustmentRef = database.child('qtyAdjustments/${widget.itemData['key']}').push();
        await adjustmentRef.set({
          'itemName': widget.itemData['itemName'],
          'oldQty': oldQty,
          'newQty': newQty,
          'date': DateTime.now().toIso8601String(),
          'adjustedBy': 'User', // Replace with actual user if you have authentication
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Quantity updated successfully!')),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ItemsListPage()),
        );
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update quantity: $error')),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Update Quantity', style: TextStyle(color: Colors.white)),
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _qtyController,
                    decoration: InputDecoration(
                      labelText: 'New Quantity',
                      labelStyle: TextStyle(color: Colors.blue),
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the new quantity';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _updateQuantity,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      minimumSize: Size(double.infinity, 50),
                    ),
                    child: Text('Update Quantity',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
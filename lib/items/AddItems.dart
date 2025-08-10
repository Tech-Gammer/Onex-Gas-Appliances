import 'dart:convert';
import 'dart:io';
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../Provider/lanprovider.dart';

class RegisterItemPage extends StatefulWidget {
  final Map<String, dynamic>? itemData;

  RegisterItemPage({this.itemData});

  @override
  _RegisterItemPageState createState() => _RegisterItemPageState();
}

class _RegisterItemPageState extends State<RegisterItemPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  String? _imageBase64;
  html.File? _webImageFile;

  // Mode selection
  bool _isBOM = false;

  // Controllers for both modes
  late TextEditingController _itemNameController;
  late TextEditingController _costPriceController;
  late TextEditingController _salePriceController;
  late TextEditingController _qtyOnHandController;
  late TextEditingController _weightPerBagController;
  final TextEditingController _vendorsearchController = TextEditingController();
  final TextEditingController _unitSearchController = TextEditingController();
  final TextEditingController _categorySearchController = TextEditingController();
  final TextEditingController _customerSearchController = TextEditingController();
  final TextEditingController _bomItemSearchController = TextEditingController();

  // Dropdown values
  String? _selectedUnit;
  String? _selectedVendor;
  String? _selectedCategory;

  // Lists for dropdowns
  List<String> _units = ['Kg', 'Pcs', 'Bag'];
  List<String> _vendors = [];
  List<String> _categories = [];
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _items = []; // For BOM components

  // State management
  bool _isLoadingVendors = false;
  bool _isLoadingCustomers = false;
  bool _isLoadingItems = false;
  List<String> _filteredVendors = [];
  List<String> _filteredCategories = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  List<Map<String, dynamic>> _filteredItems = [];

  // BOM related
  List<Map<String, dynamic>> _bomComponents = [];
  final TextEditingController _componentQtyController = TextEditingController();

  // Customer prices
  Map<String, double> _customerBasePrices = {};
  List<Map<String, dynamic>> _customerPricesList = [];

  double get totalCost {
    return _bomComponents.fold(0.0, (sum, item) => sum + (item['price'] * item['quantity']));
  }

  @override
  void initState() {
    super.initState();



    _itemNameController = TextEditingController(text: widget.itemData?['itemName'] ?? '');
    _costPriceController = TextEditingController(text: widget.itemData?['costPrice']?.toString() ?? '');
    _salePriceController = TextEditingController(text: widget.itemData?['salePrice']?.toString() ?? '');
    _qtyOnHandController = TextEditingController(text: widget.itemData?['qtyOnHand']?.toString() ?? '');
    _weightPerBagController = TextEditingController(text: widget.itemData?['weightPerBag']?.toString() ?? '');

    // Add listeners for price per kg calculation
    _salePriceController.addListener(_calculatePricePerKg);
    _weightPerBagController.addListener(_calculatePricePerKg);

    _selectedUnit = widget.itemData?['unit'];
    _selectedVendor = widget.itemData?['vendor'];
    _selectedCategory = widget.itemData?['category'];

    // Initialize customer prices
    if (widget.itemData != null) {
      final prices = widget.itemData!['customerBasePrices'];
      if (prices != null) {
        _customerBasePrices = Map<String, double>.from(prices.map(
              (key, value) => MapEntry(key.toString(), value.toDouble()),
        ));
      }

      // Initialize BOM components if editing a BOM
      if (widget.itemData!['isBOM'] == true) {
        _isBOM = true;
        final rawComponents = widget.itemData!['components'];
        if (rawComponents != null && rawComponents is List) {
          _bomComponents = rawComponents.map((component) {
            if (component is Map) {
              return Map<String, dynamic>.from(component);
            }
            return <String, dynamic>{};
          }).toList();
        }
      }
    }

    // Listeners
    _vendorsearchController.addListener(() => _filterVendors(_vendorsearchController.text));
    _categorySearchController.addListener(() => _filterCategories(_categorySearchController.text));
    _customerSearchController.addListener(() => _filterCustomers(_customerSearchController.text));
    _bomItemSearchController.addListener(() => _filterItems(_bomItemSearchController.text));

    fetchDropdownData();
    fetchItems(); // Load items for BOM components

    // Load existing image if editing
    if (widget.itemData != null && widget.itemData!['image'] != null) {
      _imageBase64 = widget.itemData!['image'];
    }
  }

  Future<void> fetchItems() async {
    setState(() => _isLoadingItems = true);
    try {
      final DatabaseReference database = FirebaseDatabase.instance.ref();
      final snapshot = await database.child('items').get();

      if (snapshot.exists) {
        final Map<dynamic, dynamic> itemData = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _items = itemData.entries.map((entry) {
            return {
              'id': entry.key,
              'name': entry.value['itemName'] as String,
              'unit': entry.value['unit'] ?? '',
              'price': entry.value['salePrice'] ?? 0.0,
            };
          }).toList();
          _filteredItems = List.from(_items);
        });
      }
    } catch (e) {
      print('Error fetching items: $e');
    } finally {
      setState(() => _isLoadingItems = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      if (kIsWeb) {
        final html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
        uploadInput.accept = 'image/*';
        uploadInput.click();

        uploadInput.onChange.listen((e) {
          final files = uploadInput.files;
          if (files != null && files.isNotEmpty) {
            final file = files[0];
            final reader = html.FileReader();

            reader.onLoadEnd.listen((e) {
              setState(() {
                _webImageFile = file;
                _imageBase64 = reader.result.toString().split(',').last;
              });
            });

            reader.readAsDataUrl(file);
          }
        });
      } else {
        final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
        if (pickedFile != null) {
          final bytes = await File(pickedFile.path).readAsBytes();
          setState(() {
            _imageFile = pickedFile;
            _imageBase64 = base64Encode(bytes);
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  void _removeImage() {
    setState(() {
      _imageFile = null;
      _imageBase64 = null;
    });
  }

  Future<void> _fetchCustomers() async {
    setState(() => _isLoadingCustomers = true);
    try {
      final DatabaseReference database = FirebaseDatabase.instance.ref();
      final snapshot = await database.child('customers').get();

      if (snapshot.exists) {
        final Map<dynamic, dynamic> customerData = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _customers = customerData.entries.map((entry) => {
            'id': entry.key,
            'name': entry.value['name'] as String,
            'phone': entry.value['phone'] ?? '',
            'email': entry.value['email'] ?? '',
          }).toList();
          _filteredCustomers = List.from(_customers);
        });
        _updateCustomerPricesList();
      }
    } catch (e) {
      print('Error fetching customers: $e');
    } finally {
      setState(() => _isLoadingCustomers = false);
    }
  }

  void _filterVendors(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredVendors = List.from(_vendors);
      } else {
        _filteredVendors = _vendors
            .where((vendor) => vendor.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _filterCategories(String query) {
    setState(() {
      _filteredCategories = query.isEmpty
          ? List.from(_categories)
          : _categories.where((category) => category.toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  void _filterCustomers(String query) {
    setState(() {
      _filteredCustomers = query.isEmpty
          ? List.from(_customers)
          : _customers.where((customer) =>
          customer['name'].toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  void _filterItems(String query) {
    setState(() {
      _filteredItems = query.isEmpty
          ? List.from(_items)
          : _items.where((item) =>
          item['name'].toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  void _updateCustomerPricesList() {
    setState(() {
      if (_customerBasePrices.isEmpty) {
        _customerPricesList.clear();
        return;
      }

      _customerPricesList = _customerBasePrices.entries.map((entry) {
        String customerId = entry.key;
        double price = entry.value;

        // Find customer name - handle case where customer might not exist
        String customerName = 'Unknown Customer';
        try {
          final customer = _customers.firstWhere(
                (c) => c['id'] == customerId,
          );
          customerName = customer['name'] ?? 'Unknown Customer';
        } catch (e) {
          // Customer not found in the list
          print('Customer not found for ID: $customerId');
        }

        return {
          'customerId': customerId,
          'customerName': customerName,
          'price': price,
        };
      }).toList();
    });
  }

  Future<void> fetchDropdownData() async {
    final DatabaseReference database = FirebaseDatabase.instance.ref();

    // Fetch units
    database.child('units').onValue.listen((event) {
      final Map? data = event.snapshot.value as Map?;
      if (data != null) {
        setState(() {
          _units = data.values
              .map<String>((value) => (value as Map)['name']?.toString() ?? '')
              .toList();
        });
      }
    });

    // Fetch vendors
    setState(() => _isLoadingVendors = true);
    try {
      final snapshot = await database.child('vendors').get();
      if (snapshot.exists) {
        final Map<dynamic, dynamic> vendorData = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _vendors = vendorData.entries.map((entry) => entry.value['name'] as String).toList();
          _filteredVendors = List.from(_vendors);
        });
      }
    } catch (e) {
      print('Error fetching vendors: $e');
    } finally {
      setState(() => _isLoadingVendors = false);
    }

    // Fetch categories
    database.child('category').onValue.listen((event) {
      final Map? data = event.snapshot.value as Map?;
      if (data != null) {
        setState(() {
          _categories = data.values
              .map<String>((value) => (value as Map)['name']?.toString() ?? '')
              .toList();
          _filteredCategories = List.from(_categories);
        });
      }
    });

    await _fetchCustomers();
  }

  void _addCustomerPrice(String customerId, String customerName, double price) {
    setState(() {
      _customerBasePrices[customerId] = price;
      _customerSearchController.clear();
      _filteredCustomers = List.from(_customers);
    });

    if (_customers.isNotEmpty) {
      _updateCustomerPricesList();
    } else {
      setState(() {
        _customerPricesList.add({
          'customerId': customerId,
          'customerName': customerName,
          'price': price,
        });
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Price added for $customerName: ${price.toStringAsFixed(2)}rs')),
    );
  }

  void _removeCustomerPrice(String customerId) {
    print('Before removal - customerBasePrices: $_customerBasePrices');
    print('Before removal - customerPricesList length: ${_customerPricesList.length}');
    setState(() {
      // Remove from the base prices map
      _customerBasePrices.remove(customerId);

      // Also remove directly from the display list to ensure immediate UI update
      _customerPricesList.removeWhere((customer) => customer['customerId'] == customerId);
    });

    print('After removal - customerBasePrices: $_customerBasePrices');
    print('After removal - customerPricesList length: ${_customerPricesList.length}');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Customer price removed successfully')),
    );
  }

  void _addBomComponent(Map<String, dynamic> item, double quantity) {
    setState(() {
      _bomComponents.add({
        'id': item['id'],
        'name': item['name'],
        'unit': item['unit'],
        'quantity': quantity,
        'price': item['price'],
      });
      _bomItemSearchController.clear();
      _filteredItems = List.from(_items);
    });
  }

  void _removeBomComponent(int index) {
    setState(() {
      _bomComponents.removeAt(index);
    });
  }


  void _showAddCustomerPriceDialog(String customerId, String customerName) {
    TextEditingController priceController = TextEditingController();
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(languageProvider.isEnglish
              ? 'Set Price for $customerName'
              : '$customerName کے لیے قیمت مقرر کریں'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isBOM) ...[
                Text('BOM Components Total: ${totalCost.toStringAsFixed(2)} PKR'),
                SizedBox(height: 8),
              ],
              Text(
                _isBOM
                    ? (languageProvider.isEnglish
                    ? 'Enter final price for this customer'
                    : 'اس کسٹمر کے لیے حتمی قیمت درج کریں')
                    : (languageProvider.isEnglish
                    ? 'Enter price for this customer'
                    : 'اس کسٹمر کے لیے قیمت درج کریں'),
              ),
              TextFormField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: languageProvider.isEnglish ? 'Price (PKR)' : 'قیمت (روپے)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ'),
            ),
            TextButton(
              onPressed: () {
                double? price = double.tryParse(priceController.text);
                if (price != null && price > 0) {
                  _addCustomerPrice(customerId, customerName, price);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(languageProvider.isEnglish
                        ? 'Please enter a valid positive price'
                        : 'براہ کرم ایک درست مثبت قیمت درج کریں')),
                  );
                }
              },
              child: Text(languageProvider.isEnglish ? 'Add' : 'شامل کریں'),
            ),
          ],
        );
      },
    );
  }

  void _showAddBomComponentDialog(Map<String, dynamic> item) {
    TextEditingController qtyController = TextEditingController();
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(languageProvider.isEnglish ? 'Add ${item['name']}' : '${item['name']} شامل کریں'),
          content: TextFormField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: languageProvider.isEnglish ? 'Quantity' : 'مقدار',
              hintText: languageProvider.isEnglish ? 'Enter quantity' : 'مقدار درج کریں',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ'),
            ),
            TextButton(
              onPressed: () {
                double? qty = double.tryParse(qtyController.text);
                // if (qty != null && qty > 0) {
                if (qty != null) {  // Removed the qty > 0 check to allow negatives
                  _addBomComponent(item, qty);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(languageProvider.isEnglish ? 'Please enter a valid quantity' : 'براہ کرم درست مقدار درج کریں')),
                  );
                }
              },
              child: Text(languageProvider.isEnglish ? 'Add' : 'شامل کریں'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> checkIfItemExists(String itemName) async {
    final DatabaseReference database = FirebaseDatabase.instance.ref();
    final snapshot = await database.child('items').get();

    if (snapshot.exists && snapshot.value is Map) {
      Map<dynamic, dynamic> items = snapshot.value as Map<dynamic, dynamic>;
      for (var key in items.keys) {
        if (items[key]['itemName'].toString().toLowerCase() == itemName.toLowerCase()) {
          return true;
        }
      }
    }
    return false;
  }

  void _clearFormFields() {
    setState(() {
      _itemNameController.clear();
      _costPriceController.clear();
      _salePriceController.clear();
      _qtyOnHandController.clear();
      _weightPerBagController.clear();
      _selectedUnit = null;
      _selectedVendor = null;
      _selectedCategory = null;
      _customerBasePrices.clear();
      _customerPricesList.clear();
      _bomComponents.clear();
    });
  }

  void saveOrUpdateItem() async {
    if (_formKey.currentState!.validate()) {
      final itemName = _itemNameController.text;

      if (widget.itemData == null) {
        bool itemExists = await checkIfItemExists(itemName);
        if (itemExists) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Item with this name already exists!')),
          );
          return;
        }
      }

      final DatabaseReference database = FirebaseDatabase.instance.ref();
      final double weightPerBag = double.tryParse(_weightPerBagController.text) ?? 1;
      final double pricePerBag = double.tryParse(_salePriceController.text) ?? 0.0;
      final double pricePerKg = pricePerBag / weightPerBag;

      // Calculate total cost for BOM
      double totalCost = 0.0;
      if (_isBOM) {
        for (var component in _bomComponents) {
          totalCost += (component['price'] * component['quantity']);
        }
      }

      Map<String, double> customerPrices = Map.from(_customerBasePrices);


      final newItem = {
        'itemName': itemName,
        'unit': _selectedUnit,
        'costPrice': _isBOM ? totalCost : (double.tryParse(_costPriceController.text) ?? 0.0),
        'salePrice': pricePerBag,
        'pricePerKg': pricePerKg,
        'weightPerBag': weightPerBag,
        'qtyOnHand': int.tryParse(_qtyOnHandController.text) ?? 0,
        'vendor': _selectedVendor,
        'category': _selectedCategory,
        'customerBasePrices': customerPrices,
        'image': _imageBase64,
        'isBOM': _isBOM,
        'components': _isBOM ? _bomComponents : null,
        'createdAt': ServerValue.timestamp,
      };

      if (widget.itemData == null) {
        database.child('items').push().set(newItem).then((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Item registered successfully!')),
          );
          _clearFormFields();
        }).catchError((error) {
          print(error);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to register item: $error')),
          );
        });
      } else {
        database.child('items/${widget.itemData!['key']}').set(newItem).then((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Item updated successfully!')),
          );
        }).catchError((error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update item: $error')),
          );
        });
      }
    }
  }

  Widget _buildImagePreview() {
    if (_imageBase64 != null) {
      return Stack(
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: kIsWeb
                    ? Image.network('data:image/png;base64,$_imageBase64').image
                    : MemoryImage(base64Decode(_imageBase64!)),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.red),
              onPressed: _removeImage,
            ),
          ),
        ],
      );
    } else {
      return Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.image, size: 50, color: Colors.grey),
      );
    }
  }

  Widget _buildBomComponentsList() {
    if (_bomComponents.isEmpty) {
      return Center(
        child: Text(
          'No components added yet',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: _bomComponents.length,
      itemBuilder: (context, index) {
        final component = _bomComponents[index];
        final isDeduction = component['quantity'] < 0;

        return Card(
          margin: EdgeInsets.symmetric(vertical: 4),
          color: isDeduction ? Colors.red[50] : null,
          child: ListTile(
            title: Text(component['name']),
            subtitle: Text('${component['quantity']} ${component['unit']}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(component['price'] * component['quantity']).toStringAsFixed(2)} PKR',
                  style: TextStyle(
                    color: isDeduction ? Colors.red : null,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeBomComponent(index),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    double additions = _bomComponents.where((c) => c['quantity'] > 0)
        .fold(0.0, (sum, item) => sum + (item['price'] * item['quantity']));
    double deductions = _bomComponents.where((c) => c['quantity'] < 0)
        .fold(0.0, (sum, item) => sum + (item['price'] * item['quantity']).abs());


    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.isEnglish
              ? (_isBOM ? 'Create BOM' : 'Register Item')
              : (_isBOM ? 'BOM بنائیں' : 'آئٹم ایڈ کریں'),
          style: TextStyle(color: Colors.white),
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
          if (widget.itemData == null) // Only show toggle when creating new item
            IconButton(
              icon: Icon(_isBOM ? Icons.inventory : Icons.assignment),
              tooltip: _isBOM
                  ? (languageProvider.isEnglish ? 'Switch to Item' : 'آئٹم پر سوئچ کریں')
                  : (languageProvider.isEnglish ? 'Switch to BOM' : 'BOM پر سوئچ کریں'),
              onPressed: () {
                setState(() {
                  _isBOM = !_isBOM;
                  if (!_isBOM) {
                    _bomComponents.clear();
                  }
                });
              },
            ),
        ],
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
              child: ListView(
                children: [
                  // Mode indicator
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isBOM ? Colors.blue[50] : Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isBOM ? Colors.blue : Colors.orange,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isBOM ? Icons.inventory : Icons.shopping_bag,
                          color: _isBOM ? Colors.blue : Colors.orange,
                        ),
                        SizedBox(width: 8),
                        Text(
                          _isBOM
                              ? (languageProvider.isEnglish ? 'Creating a Bill of Materials' : 'بل آف میٹیریلز بنانا')
                              : (languageProvider.isEnglish ? 'Registering a Single Item' : 'ایک آئٹم رجسٹر کرنا'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isBOM ? Colors.blue : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),

                  // Image Upload Section
                  Column(
                    children: [
                      Text(
                        languageProvider.isEnglish ? 'Item Image' : 'آئٹم کی تصویر',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      _buildImagePreview(),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _pickImage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          languageProvider.isEnglish ? 'Upload Image' : 'تصویر اپ لوڈ کریں',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),

                  // Common fields for both modes
                  TextFormField(
                    controller: _itemNameController,
                    decoration: InputDecoration(
                      labelText: languageProvider.isEnglish
                          ? (_isBOM ? 'BOM Name' : 'Item Name')
                          : (_isBOM ? 'BOM کا نام' : 'آئٹم کا نام'),
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.orange),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return languageProvider.isEnglish
                            ? 'Please enter the name'
                            : 'براہ کرم نام درج کریں۔';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  // BOM-specific fields
                  if (_isBOM) ...[
                    // BOM Components Section
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              languageProvider.isEnglish ? 'BOM Components' : 'BOM اجزاء',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 10),

                            // Item Search for BOM
                            if (_isLoadingItems)
                              Center(child: CircularProgressIndicator())
                            else if (_items.isNotEmpty)
                              Column(
                                children: [
                                  TextField(
                                    controller: _bomItemSearchController,
                                    decoration: InputDecoration(
                                      hintText: languageProvider.isEnglish
                                          ? 'Search items to add...'
                                          : 'آئٹمز کو شامل کرنے کے لیے تلاش کریں...',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      prefixIcon: Icon(Icons.search),
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  if (_bomItemSearchController.text.isNotEmpty)
                                    Container(
                                      height: 150,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ListView.builder(
                                        itemCount: _filteredItems.length,
                                        itemBuilder: (context, index) {
                                          final item = _filteredItems[index];
                                          return ListTile(
                                            title: Text(item['name']),
                                            subtitle: Text('${item['price']} PKR/${item['unit']}'),
                                            trailing: Icon(Icons.add, color: Colors.green),
                                            onTap: () => _showAddBomComponentDialog(item),
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              ),

                            SizedBox(height: 20),
                            Text(
                              languageProvider.isEnglish
                                  ? 'Added Components (${_bomComponents.length})'
                                  : 'شامل کردہ اجزاء (${_bomComponents.length})',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 10),
                            _buildBomComponentsList(),
                            SizedBox(height: 10),
                            if (_bomComponents.isNotEmpty) ...[
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    languageProvider.isEnglish
                                        ? 'Total Estimated Cost: ${totalCost.toStringAsFixed(2)} PKR'
                                        : 'کل تخمینہ لاگت: ${totalCost.toStringAsFixed(2)} روپے',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    languageProvider.isEnglish
                                        ? '(Additions: ${additions.toStringAsFixed(2)} PKR, Deductions: ${deductions.toStringAsFixed(2)} PKR)'
                                        : '(اضافے: ${additions.toStringAsFixed(2)} روپے, کٹوتیاں: ${deductions.toStringAsFixed(2)} روپے)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                  ],
                  // Item-specific fields (shown when not in BOM mode)
                  if (!_isBOM) ...[
                    DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish ? 'Unit' : 'یونٹ',
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.orange),
                        ),
                      ),
                      items: _units.map((unit) {
                        return DropdownMenuItem(
                          value: unit,
                          child: Text(unit),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedUnit = value;
                        });
                      },
                      validator: (value) => value == null
                          ? (languageProvider.isEnglish ? 'Please select a unit' : 'براہ کرم ایک یونٹ منتخب کریں۔')
                          : null,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _costPriceController,
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish ? 'Cost Price' : 'لاگت کی قیمت',
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.orange),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 16),
                  ],

                  // Common fields for both modes
                  TextFormField(
                    controller: _salePriceController,
                    decoration: InputDecoration(
                      labelText: languageProvider.isEnglish ? 'Sale Price' : 'فروخت کی قیمت',
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.orange),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return languageProvider.isEnglish
                            ? 'Please enter the sale price'
                            : 'براہ کرم فروخت کی قیمت درج کریں';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _weightPerBagController,
                    decoration: InputDecoration(
                      labelText: languageProvider.isEnglish
                          ? (_isBOM ? 'Package Weight (kg)' : 'Weight per Bag (kg)')
                          : (_isBOM ? 'پیکیج وزن (کلوگرام)' : 'فی بیگ وزن (کلوگرام)'),
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.orange),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return languageProvider.isEnglish
                            ? 'Enter weight'
                            : 'وزن درج کریں';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  Text(
                    languageProvider.isEnglish
                        ? 'Per KG Price: ${( (double.tryParse(_salePriceController.text) ?? 0) / (double.tryParse(_weightPerBagController.text) ?? 1) ).toStringAsFixed(2)} PKR'
                        : 'فی کلو قیمت: ${( (double.tryParse(_salePriceController.text) ?? 0) / (double.tryParse(_weightPerBagController.text) ?? 1) ).toStringAsFixed(2)} روپے',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.orange[300],
                    ),
                  ),

                  SizedBox(height: 16),
                  TextFormField(
                    controller: _qtyOnHandController,
                    decoration: InputDecoration(
                      labelText: languageProvider.isEnglish ? 'Quantity on Hand' : 'موجود مقدار',
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.orange),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    readOnly: widget.itemData != null,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return languageProvider.isEnglish
                            ? 'Please enter the quantity'
                            : 'براہ کرم مقدار درج کریں';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  // Vendor Selection (only for items)
                  if (!_isBOM) ...[
                    if (_isLoadingVendors)
                      Center(child: CircularProgressIndicator())
                    else if (_vendors.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            languageProvider.isEnglish ? 'Search Vendor' : 'وینڈر تلاش کریں',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 10),
                          TextField(
                            controller: _vendorsearchController,
                            decoration: InputDecoration(
                              hintText: languageProvider.isEnglish
                                  ? 'Type to search vendors...'
                                  : 'وینڈرز کو تلاش کرنے کے لیے ٹائپ کریں...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              prefixIcon: Icon(Icons.search),
                            ),
                          ),
                          SizedBox(height: 10),
                          if (_vendorsearchController.text.isNotEmpty)
                            Container(
                              height: 200,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListView.builder(
                                itemCount: _filteredVendors.length,
                                itemBuilder: (context, index) {
                                  final vendor = _filteredVendors[index];
                                  return ListTile(
                                    title: Text(vendor),
                                    onTap: () {
                                      setState(() {
                                        _selectedVendor = vendor;
                                        _vendorsearchController.clear();
                                        _filteredVendors = List.from(_vendors);
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(
                                            '${languageProvider.isEnglish ? 'Selected Vendor: ' : 'منتخب فروش: '}$vendor')),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          SizedBox(height: 20),
                          if (_selectedVendor != null)
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.orange[300]),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${languageProvider.isEnglish ? 'Selected Vendor: ' : 'منتخب فروش: '}$_selectedVendor',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.orange[300],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    SizedBox(height: 20),
                  ],

                  // Category Selection
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        languageProvider.isEnglish ? 'Category' : 'قسم',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: _categorySearchController,
                        decoration: InputDecoration(
                          hintText: languageProvider.isEnglish
                              ? 'Search categories...'
                              : 'اقسام تلاش کریں...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      SizedBox(height: 10),
                      if (_categorySearchController.text.isNotEmpty)
                        Container(
                          height: 150,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.builder(
                            itemCount: _filteredCategories.length,
                            itemBuilder: (context, index) {
                              final category = _filteredCategories[index];
                              return ListTile(
                                title: Text(category),
                                onTap: () {
                                  setState(() {
                                    _selectedCategory = category;
                                    _categorySearchController.clear();
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      SizedBox(height: 10),
                      if (_selectedCategory != null)
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.orange[300]),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${languageProvider.isEnglish ? 'Selected Category: ' : 'منتخب قسم: '}$_selectedCategory',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.orange[300],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 20),

                  // // Customer Base Prices Section (only for items)
                  // if (!_isBOM) ...[
                  //   Card(
                  //     elevation: 4,
                  //     shape: RoundedRectangleBorder(
                  //       borderRadius: BorderRadius.circular(12),
                  //     ),
                  //     child: Padding(
                  //       padding: const EdgeInsets.all(16.0),
                  //       child: Column(
                  //         crossAxisAlignment: CrossAxisAlignment.start,
                  //         children: [
                  //           Text(
                  //             languageProvider.isEnglish
                  //                 ? 'Customer Base Prices'
                  //                 : 'کسٹمر کی بنیادی قیمتیں',
                  //             style: TextStyle(
                  //               fontSize: 18,
                  //               fontWeight: FontWeight.bold,
                  //             ),
                  //           ),
                  //           SizedBox(height: 10),
                  //
                  //           if (_isLoadingCustomers)
                  //             Center(child: CircularProgressIndicator())
                  //           else if (_customers.isNotEmpty)
                  //             Column(
                  //               children: [
                  //                 TextField(
                  //                   controller: _customerSearchController,
                  //                   decoration: InputDecoration(
                  //                     hintText: languageProvider.isEnglish
                  //                         ? 'Search customers...'
                  //                         : 'کسٹمرز تلاش کریں...',
                  //                     border: OutlineInputBorder(
                  //                       borderRadius: BorderRadius.circular(8),
                  //                     ),
                  //                     prefixIcon: Icon(Icons.search),
                  //                   ),
                  //                 ),
                  //                 SizedBox(height: 10),
                  //                 if (_customerSearchController.text.isNotEmpty)
                  //                   Container(
                  //                     height: 150,
                  //                     decoration: BoxDecoration(
                  //                       border: Border.all(color: Colors.grey),
                  //                       borderRadius: BorderRadius.circular(8),
                  //                     ),
                  //                     child: ListView.builder(
                  //                       itemCount: _filteredCustomers.length,
                  //                       itemBuilder: (context, index) {
                  //                         final customer = _filteredCustomers[index];
                  //                         final isAlreadyAdded = _customerBasePrices.containsKey(customer['id']);
                  //                         return ListTile(
                  //                           title: Text(customer['name']),
                  //                           subtitle: Text(customer['phone'] ?? ''),
                  //                           trailing: isAlreadyAdded
                  //                               ? Icon(Icons.check, color: Colors.green)
                  //                               : Icon(Icons.add, color: Colors.orange[300]),
                  //                           onTap: isAlreadyAdded
                  //                               ? null
                  //                               : () => _showAddCustomerPriceDialog(
                  //                               customer['id'],
                  //                               customer['name']
                  //                           ),
                  //                         );
                  //                       },
                  //                     ),
                  //                   ),
                  //               ],
                  //             ),
                  //
                  //           SizedBox(height: 20),
                  //
                  //           if (_customerPricesList.isNotEmpty) ...[
                  //             Text(
                  //               languageProvider.isEnglish
                  //                   ? 'Added Customer Prices:'
                  //                   : 'شامل کردہ کسٹمر کی قیمتیں:',
                  //               style: TextStyle(
                  //                 fontSize: 16,
                  //                 fontWeight: FontWeight.bold,
                  //               ),
                  //             ),
                  //             SizedBox(height: 10),
                  //             ListView.builder(
                  //               shrinkWrap: true,
                  //               physics: NeverScrollableScrollPhysics(),
                  //               itemCount: _customerPricesList.length,
                  //               itemBuilder: (context, index) {
                  //                 final customerPrice = _customerPricesList[index];
                  //                 return Card(
                  //                   margin: EdgeInsets.symmetric(vertical: 4),
                  //                   child: ListTile(
                  //                     title: Text(customerPrice['customerName']),
                  //                     subtitle: Text(
                  //                         '${languageProvider.isEnglish ? 'Price: ' : 'قیمت: '}${customerPrice['price'].toStringAsFixed(2)}rs'),
                  //                     trailing: IconButton(
                  //                       icon: Icon(Icons.delete, color: Colors.red),
                  //                       onPressed: () => _removeCustomerPrice(customerPrice['customerId']),
                  //                     ),
                  //                   ),
                  //                 );
                  //               },
                  //             ),
                  //           ] else if (_customerBasePrices.isNotEmpty && _customers.isEmpty)
                  //             Center(
                  //               child: Text(
                  //                 languageProvider.isEnglish
                  //                     ? 'Loading customer information...'
                  //                     : 'کسٹمر کی معلومات لوڈ ہو رہی ہیں...',
                  //                 style: TextStyle(color: Colors.grey[600]),
                  //               ),
                  //             ),
                  //         ],
                  //       ),
                  //     ),
                  //   ),
                  //   SizedBox(height: 20),
                  // ],
                  // // Customer wise prices for BOM
                  // if (_isBOM && _customerPricesList.isNotEmpty) ...[
                  //   Column(
                  //     crossAxisAlignment: CrossAxisAlignment.start,
                  //     children: [
                  //       Text(
                  //         'Customer Prices for this BOM:',
                  //         style: TextStyle(fontWeight: FontWeight.bold),
                  //       ),
                  //       SizedBox(height: 8),
                  //       ..._customerPricesList.map((customerPrice) =>
                  //           ListTile(
                  //             title: Text(customerPrice['customerName']),
                  //             subtitle: Text('Price: ${customerPrice['price'].toStringAsFixed(2)} PKR'),
                  //           )
                  //       ).toList(),
                  //     ],
                  //   ),
                  // ],

                  // Save button

                  // Customer Base Prices Section (for both items and BOM)
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            languageProvider.isEnglish
                                ? 'Customer Specific Prices'
                                : 'کسٹمر کے لیے مخصوص قیمتیں',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 10),

                          if (_isLoadingCustomers)
                            Center(child: CircularProgressIndicator())
                          else if (_customers.isNotEmpty)
                            Column(
                              children: [
                                TextField(
                                  controller: _customerSearchController,
                                  decoration: InputDecoration(
                                    hintText: languageProvider.isEnglish
                                        ? 'Search customers...'
                                        : 'کسٹمرز تلاش کریں...',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    prefixIcon: Icon(Icons.search),
                                  ),
                                ),
                                SizedBox(height: 10),
                                if (_customerSearchController.text.isNotEmpty)
                                  Container(
                                    height: 150,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ListView.builder(
                                      itemCount: _filteredCustomers.length,
                                      itemBuilder: (context, index) {
                                        final customer = _filteredCustomers[index];
                                        final isAlreadyAdded = _customerBasePrices.containsKey(customer['id']);
                                        return ListTile(
                                          title: Text(customer['name']),
                                          subtitle: Text(customer['phone'] ?? ''),
                                          trailing: isAlreadyAdded
                                              ? Icon(Icons.check, color: Colors.green)
                                              : Icon(Icons.add, color: Colors.orange[300]),
                                          onTap: isAlreadyAdded
                                              ? null
                                              : () => _showAddCustomerPriceDialog(
                                              customer['id'],
                                              customer['name']
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),

                          SizedBox(height: 20),

                          if (_customerPricesList.isNotEmpty) ...[
                            Text(
                              languageProvider.isEnglish
                                  ? 'Added Customer Prices:'
                                  : 'شامل کردہ کسٹمر کی قیمتیں:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 10),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: _customerPricesList.length,
                              itemBuilder: (context, index) {
                                final customerPrice = _customerPricesList[index];
                                return Card(
                                  margin: EdgeInsets.symmetric(vertical: 4),
                                  child: ListTile(
                                    title: Text(customerPrice['customerName']),
                                    subtitle: Text(
                                        '${languageProvider.isEnglish ? 'Price: ' : 'قیمت: '}${customerPrice['price'].toStringAsFixed(2)} PKR'),
                                    trailing: IconButton(
                                      icon: Icon(Icons.delete, color: Colors.red),
                                      onPressed: () {
                                        // Confirm before deleting
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text(languageProvider.isEnglish
                                                ? 'Confirm Removal'
                                                : 'تصدیق کریں'),
                                            content: Text(languageProvider.isEnglish
                                                ? 'Remove price for ${customerPrice['customerName']}?'
                                                : 'کیا آپ ${customerPrice['customerName']} کے لیے قیمت ختم کرنا چاہتے ہیں؟'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ'),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  _removeCustomerPrice(customerPrice['customerId']);
                                                  Navigator.pop(context);
                                                },
                                                child: Text(languageProvider.isEnglish ? 'Remove' : 'ختم کریں'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ] else if (_customerBasePrices.isNotEmpty && _customers.isEmpty)
                            Center(
                              child: Text(
                                languageProvider.isEnglish
                                    ? 'Loading customer information...'
                                    : 'کسٹمر کی معلومات لوڈ ہو رہی ہیں...',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: saveOrUpdateItem,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      languageProvider.isEnglish
                          ? (widget.itemData == null
                          ? (_isBOM ? 'Create BOM' : 'Register Item')
                          : 'Update')
                          : (widget.itemData == null
                          ? (_isBOM ? 'BOM بنائیں' : 'آئٹم ایڈ کریں')
                          : 'اپ ڈیٹ کریں'),
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _costPriceController.dispose();
    _salePriceController.dispose();
    _qtyOnHandController.dispose();
    _weightPerBagController.dispose();
    _vendorsearchController.dispose();
    _unitSearchController.dispose();
    _categorySearchController.dispose();
    _customerSearchController.dispose();
    _bomItemSearchController.dispose();
    _componentQtyController.dispose();
    _salePriceController.removeListener(_calculatePricePerKg);
    _weightPerBagController.removeListener(_calculatePricePerKg);
    super.dispose();
  }

  void _calculatePricePerKg() {
    final salePrice = double.tryParse(_salePriceController.text) ?? 0;
    final weight = double.tryParse(_weightPerBagController.text) ?? 1;

    // Avoid division by zero
    final pricePerKg = weight > 0 ? salePrice / weight : 0;

    // Update the UI by calling setState
    setState(() {
      // The price per kg is already displayed in the UI through the Text widget
      // so we just need to trigger a rebuild
    });
  }

}
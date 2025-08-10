import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../Models/cashbookModel.dart';
import '../Models/itemModel.dart';
import 'package:firebase_storage/firebase_storage.dart';



class InvoiceProvider with ChangeNotifier {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _invoices = [];
  List<Item> _items = []; // Initialize the _items list
  List<Item> get items => _items; // Add a getter for _items
  List<Map<String, dynamic>> get invoices => _invoices;
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool _hasMoreData = true;
  bool get hasMoreData => _hasMoreData;
  int _lastLoadedIndex = 0;
  String? _lastKey;
  // Page size for pagination
  final int _pageSize = 20;
  final FirebaseStorage _storage = FirebaseStorage.instance;



  String _imageToBase64(Uint8List imageBytes) {
    return base64Encode(imageBytes);
  }

  Uint8List _base64ToImage(String base64String) {
    return base64Decode(base64String);
  }

  Future<String> _uploadImage(Uint8List imageBytes, String invoiceId) async {
    try {
      final ref = _storage.ref()
          .child('payment_images')
          .child(invoiceId)
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      final uploadTask = ref.putData(imageBytes);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Error uploading image: $e");
      throw Exception("Image upload failed");
    }
  }

  Future<void> _deleteImage(String? imageUrl) async {
    if (imageUrl == null) return;
    try {
      await _storage.refFromURL(imageUrl).delete();
    } catch (e) {
      print("Error deleting image: $e");
    }
  }

  Future<void> fetchInvoices({int limit = 20, String? lastKey}) async   {
    try {
      _isLoading = true;
      notifyListeners();

      Query query = _db.child('invoices')
          .orderByChild('createdAt')
          .limitToLast(limit);

      if (lastKey != null) {
        // Get the last invoice to use its createdAt value for pagination
        final lastInvoiceSnapshot = await _db.child('invoices').child(lastKey).get();
        if (lastInvoiceSnapshot.exists) {
          final lastInvoice = lastInvoiceSnapshot.value as Map<dynamic, dynamic>;
          // print(lastInvoice);
          final lastCreatedAt = lastInvoice['createdAt'];
          query = query.endBefore(lastCreatedAt);
        }
      }

      final snapshot = await query.get();
      print(snapshot);

      if (snapshot.exists) {
        // Clear existing data only on first load
        if (lastKey == null) {
          print(_invoices);
          _invoices.clear();
        }

        // Handle the response which could be a Map or a List
        if (snapshot.value is Map) {
          final Map<dynamic, dynamic> values = snapshot.value as Map<dynamic, dynamic>;
          _processInvoiceData(values);

          if (values.isNotEmpty) {
            _lastKey = values.keys.last.toString();
            _hasMoreData = values.length >= limit;
          }
        }
        else if (snapshot.value is List) {
          // Handle list response (possibly an array in Firebase)
          final List<dynamic> values = snapshot.value as List<dynamic>;
          print(values);

          // Convert list to map with indices as keys
          final Map<dynamic, dynamic> valuesMap = {};
          for (int i = 0; i < values.length; i++) {
            if (values[i] != null) {
              valuesMap[i.toString()] = values[i];
            }
          }

          if (valuesMap.isNotEmpty) {
            _processInvoiceData(valuesMap);
            _lastKey = valuesMap.keys.last.toString();
            _hasMoreData = valuesMap.length >= limit;
          }
        }
      }

      notifyListeners();
    } catch (e) {
      print('Error fetching invoices: ${e.toString()}');
      throw Exception('Failed to fetch invoices: ${e.toString()}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

// You should also update the _processInvoiceData method to handle empty or null entries
  void _processInvoiceData(Map<dynamic, dynamic> values) {
    // Skip null or empty values
    if (values.isEmpty) return;

    List<MapEntry<dynamic, dynamic>> sortedEntries = values.entries
        .where((entry) => entry.value != null) // Filter out null entries
        .toList()
      ..sort((a, b) {
        dynamic dateA = a.value['createdAt'];
        dynamic dateB = b.value['createdAt'];

        // Handle null dates
        if (dateA == null) return 1;
        if (dateB == null) return -1;

        // Sort in descending order (newest first)
        return _parseDateTime(dateB).compareTo(_parseDateTime(dateA));
      });

    for (var entry in sortedEntries) {
      _processInvoiceEntry(entry.key.toString(), entry.value);
    }
  }

// Also update the loadMoreInvoices method with similar changes
  Future<void> loadMoreInvoices() async {
    if (_isLoading || !_hasMoreData) return;

    try {
      _isLoading = true;
      notifyListeners();

      // Get the createdAt value of the last item in the list
      String? lastCreatedAt;
      if (_invoices.isNotEmpty) {
        lastCreatedAt = _invoices.last['createdAt'];
      } else {
        _hasMoreData = false;
        _isLoading = false;
        notifyListeners();
        return;
      }

      Query query = _db.child('invoices')
          .orderByChild('createdAt')
          .endBefore(lastCreatedAt)
          .limitToLast(_pageSize);

      final snapshot = await query.get();

      if (snapshot.exists) {
        // Handle different return types from Firebase
        if (snapshot.value is Map) {
          Map<dynamic, dynamic> values = snapshot.value as Map<dynamic, dynamic>;
          _processPaginatedData(values);
        }
        else if (snapshot.value is List) {
          final List<dynamic> values = snapshot.value as List<dynamic>;

          // Convert list to map with indices as keys
          final Map<dynamic, dynamic> valuesMap = {};
          for (int i = 0; i < values.length; i++) {
            if (values[i] != null) {
              valuesMap[i.toString()] = values[i];
            }
          }

          _processPaginatedData(valuesMap);
        }
      } else {
        _hasMoreData = false;
      }
    } catch (e) {
      print('Error loading more invoices: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

// Helper method to process paginated data
  void _processPaginatedData(Map<dynamic, dynamic> values) {
    if (values.isEmpty) {
      _hasMoreData = false;
      return;
    }

    // Process data without adding duplicates
    List<String> existingIds = _invoices.map((item) => item['id'].toString()).toList();

    List<MapEntry<dynamic, dynamic>> sortedEntries = values.entries
        .where((entry) => entry.value != null) // Filter out null entries
        .toList()
      ..sort((a, b) {
        dynamic dateA = a.value['createdAt'];
        dynamic dateB = b.value['createdAt'];

        // Handle null dates
        if (dateA == null) return 1;
        if (dateB == null) return -1;

        // Sort in descending order (newest first)
        return _parseDateTime(dateB).compareTo(_parseDateTime(dateA));
      });

    bool addedNewItems = false;

    for (var entry in sortedEntries) {
      String key = entry.key.toString();
      // Only add items that aren't already in the list
      if (!existingIds.contains(key)) {
        _processInvoiceEntry(key, entry.value);
        addedNewItems = true;
      }
    }

    // Only update pagination variables if we actually added new items
    if (addedNewItems) {
      _hasMoreData = values.length >= _pageSize;
    } else {
      _hasMoreData = false;
    }
  }

  // Clear all loaded data and reset pagination
  void resetPagination() {
    _invoices = [];
    _hasMoreData = true;
    _lastLoadedIndex = 0;
    _lastKey = null;
    notifyListeners();
  }

  DateTime _parseDateTime(dynamic dateValue) {
    if (dateValue is String) return DateTime.parse(dateValue);
    if (dateValue is int) return DateTime.fromMillisecondsSinceEpoch(dateValue);
    return DateTime.now();
  }

  Future<int> getNextInvoiceNumber() async {
    final counterRef = _db.child('invoiceCounter');
    final transactionResult = await counterRef.runTransaction((currentData) {
      int currentCount = (currentData ?? 0) as int;
      currentCount++;
      return Transaction.success(currentCount);
    });

    if (transactionResult.committed) {
      return transactionResult.snapshot!.value as int;
    } else {
      throw Exception('Failed to increment invoice counter.');
    }
  }

  bool _isTimestampNumber(String number) {
    // Only consider numbers longer than 10 digits as timestamps
    return number.length > 10 && int.tryParse(number) != null;
  }

  Future<void> saveInvoice({
    required String invoiceId, // Accepts the invoice ID (instead of using push)
    required String invoiceNumber, // Can be timestamp or sequential
    required String customerId,
    required String customerName, // Accept the customer name as a parameter
    required double subtotal,
    required double discount,
    required double mazdoori, // Add this parameter
    required double grandTotal,
    required String paymentType,
    required String referenceNumber, // Add this
    String? paymentMethod, // For instant payments
    required String createdAt, // Add this parameter

    required List<Map<String, dynamic>> items,
  })
  async {
    try {
      final cleanedItems = items.map((item) {
        return {
          'itemName': item['itemName'],
          'rate': item['rate'] ?? 0.0,
          'qty': item['qty'] ?? 0.0,
          'weight': item['weight'] ?? 0.0,
          'description': item['description'] ?? '',
          'total': item['total'],
        };
      }).toList();

      final invoiceData = {
        'referenceNumber': referenceNumber, // Add this
        'invoiceNumber': invoiceNumber,
        'customerId': customerId,
        'customerName': customerName, // Save customer name here
        'subtotal': subtotal,
        'discount': discount,
        'grandTotal': grandTotal,
        'paymentType': paymentType,
        'paymentMethod': paymentMethod ?? '',
        'items': cleanedItems,
        'mazdoori': mazdoori, // Add this line
        'createdAt': createdAt, // Use the provided date
        'numberType': _isTimestampNumber(invoiceNumber) ? 'timestamp' : 'sequential',

      };
      // Save the invoice at the specified invoiceId path
      await _db.child('invoices').child(invoiceId).set(invoiceData);
      print('invoice saved');
      // Now update the ledger for this customer
      await _updateCustomerLedger(
        referenceNumber: referenceNumber,
        customerId,
        creditAmount: grandTotal, // The invoice total as a credit
        debitAmount: 0.0, // No payment yet
        remainingBalance: grandTotal, // Full amount due initially
        invoiceNumber: invoiceNumber,
      );
    } catch (e) {
      throw Exception('Failed to save invoice: $e');
    }
  }

  Future<Map<String, dynamic>?> getInvoiceById(String invoiceId) async {
    try {
      final snapshot = await _db.child('invoices').child(invoiceId).get();
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch invoice: $e');
    }
  }

  Future<void> updateInvoice({
    required String invoiceId,
    required String invoiceNumber,
    required String customerId,
    required String customerName,
    required double subtotal,
    required double discount,
    required double grandTotal,
    required double mazdoori, // Add this parameter
    required String paymentType,
    String? paymentMethod,
    required String referenceNumber, // Add this
    required List<Map<String, dynamic>> items,
    required String createdAt,
  })
  async {
    try {
      // Fetch the old invoice data
      final oldInvoice = await getInvoiceById(invoiceId);
      if (oldInvoice == null) {
        throw Exception('Invoice not found.');
      }
      final isTimestamp = oldInvoice['numberType'] == 'timestamp';

      // Get the old grand total
      final double oldGrandTotal = (oldInvoice['grandTotal'] as num).toDouble();

      // Calculate the difference between the old and new grand totals
      final double difference = grandTotal - oldGrandTotal;

      final cleanedItems = items.map((item) {
        return {
          'itemName': item['itemName'],
          'rate': item['rate'] ?? 0.0,
          'qty': item['qty'] ?? 0.0,
          'weight': item['weight'] ?? 0.0,
          'description': item['description'] ?? '',
          'total': item['total'],

        };
      }).toList();

      // Prepare the updated invoice data
      final invoiceData = {
        'referenceNumber': referenceNumber, // Add this
        'invoiceNumber': invoiceNumber,
        'customerId': customerId,
        'customerName': customerName,
        'mazdoori': mazdoori, // Add this line
        'subtotal': subtotal,
        'discount': discount,
        'grandTotal': grandTotal,
        'paymentType': paymentType,
        'paymentMethod': paymentMethod ?? '',
        'items': cleanedItems,
        'updatedAt': DateTime.now().toIso8601String(),
        'createdAt': createdAt,
        'numberType': isTimestamp ? 'timestamp' : 'sequential',

      };

      // Update the invoice in the database
      await _db.child('invoices').child(invoiceId).update(invoiceData);

      // Step 1: Find the existing ledger entry for this invoice
      final customerLedgerRef = _db.child('ledger').child(customerId);
      final query = customerLedgerRef.orderByChild('invoiceNumber').equalTo(invoiceNumber);
      final snapshot = await query.get();

      if (snapshot.exists) {
        final Map<dynamic, dynamic> entries = snapshot.value as Map<dynamic, dynamic>;
        if (entries.isNotEmpty) {
          String entryKey = entries.keys.first;
          Map<String, dynamic> entry = Map<String, dynamic>.from(entries[entryKey]);

          // Step 2: Update the existing entry with the difference
          double currentCredit = (entry['creditAmount'] as num).toDouble();
          double newCredit = currentCredit + difference;

          double currentRemaining = (entry['remainingBalance'] as num).toDouble();
          double newRemaining = currentRemaining + difference;

          await customerLedgerRef.child(entryKey).update({
            'creditAmount': newCredit,
            'remainingBalance': newRemaining,
          });
        }
      }

      // Update the stock (qtyOnHand) for each item
      for (var item in items) {
        final itemName = item['itemName'];
        if (itemName == null || itemName.isEmpty) continue;

        // Find the item in the _items list
        final dbItem = _items.firstWhere(
              (i) => i.itemName == itemName,
          orElse: () => Item(id: '', itemName: '', costPrice: 0.0, qtyOnHand: 0.0,salePrice: 0.0),
        );

        if (dbItem.id.isNotEmpty) {
          final String itemId = dbItem.id;
          final double currentQty = dbItem.qtyOnHand;
          final double newWeight = item['weight'] ?? 0.0; // Use 'weight' instead of 'qty'
          final double initialWeight = item['initialWeight'] ?? 0.0; // Ensure this is 'initialWeight'

          // Calculate the difference between the initial quantity and the new quantity
          double delta = initialWeight - newWeight;

          // Update the qtyOnHand in the database
          double updatedQty = currentQty + delta;

          await _db.child('items/$itemId').update({'qtyOnHand': updatedQty});
        }
      }

      // Refresh the invoice list
      await fetchInvoices();

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to update invoice: $e');
    }
  }

  void _processInvoiceEntry(String key, dynamic value) {
    if (value is! Map<dynamic, dynamic>) return;

    final invoiceData = Map<String, dynamic>.from(value);

    // Helper function to safely parse dates
    DateTime parseDateTime(dynamic dateValue) {
      try {
        if (dateValue is String) return DateTime.parse(dateValue);
        if (dateValue is int) return DateTime.fromMillisecondsSinceEpoch(dateValue);
        if (dateValue is DateTime) return dateValue;
      } catch (e) {
        print("Error parsing date: $e");
      }
      return DateTime.now();
    }

    // Helper function to safely parse numeric values
    // double parseDouble(dynamic value) {
    //   if (value == null) return 0.0;
    //   if (value is num) return value.toDouble();
    //   if (value is String) return double.tryParse(value) ?? 0.0;
    //   return 0.0;
    // }
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) {
        // Handle currency formats or commas if necessary
        return double.tryParse(value.replaceAll(',', '')) ?? 0.0;
      }
      return 0.0;
    }

    // Safely process items list
    List<Map<String, dynamic>> processItems(dynamic itemsData) {
      if (itemsData is List) {
        return itemsData.map<Map<String, dynamic>>((item) {
          if (item is Map<dynamic, dynamic>) {
            return {
              'itemName': item['itemName']?.toString() ?? '',
              'rate': parseDouble(item['rate']),
              'qty': parseDouble(item['qty']),
              'weight': parseDouble(item['weight']),
              'description': item['description']?.toString() ?? '',
              'total': parseDouble(item['total']),
            };
          }
          return {};
        }).toList();
      }
      return [];
    }

    _invoices.add({
      'id': key,
      'invoiceNumber': invoiceData['invoiceNumber']?.toString() ?? 'N/A',
      'customerId': invoiceData['customerId']?.toString() ?? '',
      'customerName': invoiceData['customerName']?.toString() ?? 'N/A',
      'subtotal': parseDouble(invoiceData['subtotal']),
      'discount': parseDouble(invoiceData['discount']),
      'grandTotal': parseDouble(invoiceData['grandTotal']),
      'paymentType': invoiceData['paymentType']?.toString() ?? '',
      'paymentMethod': invoiceData['paymentMethod']?.toString() ?? '',
      'cashPaidAmount': parseDouble(invoiceData['cashPaidAmount']),
      'mazdoori': parseDouble(invoiceData['mazdoori'] ?? 0.0), // Add this line
      'onlinePaidAmount': parseDouble(invoiceData['onlinePaidAmount']),
      'checkPaidAmount': parseDouble(invoiceData['checkPaidAmount'] ?? 0.0),
      'slipPaidAmount': parseDouble(invoiceData['slipPaidAmount'] ?? 0.0),
      'debitAmount': parseDouble(invoiceData['debitAmount']),
      'debitAt': invoiceData['debitAt']?.toString() ?? '',
      'items': processItems(invoiceData['items']),
      'createdAt': parseDateTime(invoiceData['createdAt']).toIso8601String(),
      'remainingBalance': parseDouble(invoiceData['remainingBalance']),
      'referenceNumber': invoiceData['referenceNumber']?.toString() ?? '',
    });
  }

  Future<void> deleteInvoice(String invoiceId) async {
    try {
      // Fetch the invoice to identify related customer and invoice number
      final invoice = _invoices.firstWhere((inv) => inv['id'] == invoiceId);

      if (invoice == null) {
        throw Exception("Invoice not found.");
      }

      final customerId = invoice['customerId'] as String;
      final invoiceNumber = invoice['invoiceNumber'] as String;

      // Get the items from the invoice
      final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(invoice['items']);

      // Reverse the qtyOnHand deduction for each item
      // for (var item in items) {
      //   final itemName = item['itemName'] as String;
      //   final weight = (item['weight'] as num).toDouble(); // Get the weight from the invoice
      //
      //   // Fetch the item from the database
      //   final itemSnapshot = await _db.child('items').orderByChild('itemName').equalTo(itemName).get();
      //
      //   if (itemSnapshot.exists) {
      //     final itemData = itemSnapshot.value as Map<dynamic, dynamic>;
      //     final itemKey = itemData.keys.first;
      //     final currentItem = itemData[itemKey] as Map<dynamic, dynamic>;
      //
      //     // Get the current qtyOnHand
      //     double currentQtyOnHand = (currentItem['qtyOnHand'] as num).toDouble();
      //
      //     // Add back the weight to qtyOnHand
      //     double updatedQtyOnHand = currentQtyOnHand + weight;
      //
      //     // Update the item in the database
      //     await _db.child('items').child(itemKey).update({'qtyOnHand': updatedQtyOnHand});
      //   }
      // }
      for (var item in items) {
        final itemName = item['itemName'] as String;
        final weight = _parseToDouble(item['weight']); // Use helper function

        final itemSnapshot = await _db.child('items').orderByChild('itemName').equalTo(itemName).get();

        if (itemSnapshot.exists) {
          final itemData = itemSnapshot.value as Map<dynamic, dynamic>;
          final itemKey = itemData.keys.first;
          final currentItem = itemData[itemKey] as Map<dynamic, dynamic>;

          // NULL-SAFE ACCESS: Use helper function for qtyOnHand
          double currentQtyOnHand = _parseToDouble(currentItem['qtyOnHand']);

          double updatedQtyOnHand = currentQtyOnHand + weight;

          await _db.child('items').child(itemKey).update({'qtyOnHand': updatedQtyOnHand});
        }
      }

      // Delete the invoice from the database
      await _db.child('invoices').child(invoiceId).remove();

      // Delete associated ledger entries
      final customerLedgerRef = _db.child('ledger').child(customerId);

      // Find all ledger entries related to this invoice
      final snapshot = await customerLedgerRef.orderByChild('invoiceNumber').equalTo(invoiceNumber).get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        for (var entryKey in data.keys) {
          await customerLedgerRef.child(entryKey).remove();
        }
      }

      // Refresh the invoices list after deletion
      await fetchInvoices();

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to delete invoice and ledger entries: $e');
    }
  }

  Future<void> _updateCustomerLedger(
      String customerId, {
        required double creditAmount,
        required double debitAmount,
        required double remainingBalance,
        required String invoiceNumber,
        required String referenceNumber,
        String? paymentMethod, // Add paymentMethod parameter
        String? bankName,
      })
  async {
    try {
      final customerLedgerRef = _db.child('ledger').child(customerId);

      // Fetch the last ledger entry to calculate the new remaining balance
      final snapshot = await customerLedgerRef.orderByChild('createdAt').limitToLast(1).get();

      double lastRemainingBalance = 0.0;
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final lastTransaction = data.values.first;

        // Ensure lastRemainingBalance is safely converted to double
        lastRemainingBalance = (lastTransaction['remainingBalance'] as num?)?.toDouble() ?? 0.0;
      }

      // Calculate the new remaining balance
      final newRemainingBalance = lastRemainingBalance + creditAmount - debitAmount;

      // Ledger data to be saved
      final ledgerData = {
        'referenceNumber':referenceNumber,
        'invoiceNumber': invoiceNumber,
        'creditAmount': creditAmount,
        'debitAmount': debitAmount,
        'remainingBalance': newRemainingBalance, // Updated balance
        'createdAt': DateTime.now().toIso8601String(),
        if (paymentMethod != null) 'paymentMethod': paymentMethod, // Add paymentMethod to ledger
        if (bankName != null) 'bankName': bankName,


      };

      await customerLedgerRef.push().set(ledgerData);
    } catch (e) {
      throw Exception('Failed to update customer ledger: $e');
    }
  }

  List<Map<String, dynamic>> getInvoicesByPaymentMethod(String paymentMethod) {
    return _invoices.where((invoice) {
      final method = invoice['paymentMethod'] ?? '';
      return method.toLowerCase() == paymentMethod.toLowerCase();
    }).toList();
  }

  double _parseToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }

  Future<void> payInvoiceWithSeparateMethod(
      BuildContext context,
      String invoiceId,
      double paymentAmount,
      String paymentMethod, {
        String? description,
        Uint8List? imageBytes,
        required DateTime paymentDate,
        String? bankId,
        String? bankName,
        String? chequeNumber,
        DateTime? chequeDate,
        String? chequeBankId,
        String? chequeBankName,
      })
  async {
    // String? imageUrl;
    String? imageBase64;

    try {
      // Upload image first
      // if (imageBytes != null) {
      //   imageUrl = await _uploadImage(imageBytes, invoiceId);
      // }
      if (imageBytes != null) {
        imageBase64 = _imageToBase64(imageBytes);
      }

      // Fetch the current invoice data from the database
      final invoiceSnapshot = await _db.child('invoices').child(invoiceId).get();
      if (!invoiceSnapshot.exists) {
        throw Exception("Invoice not found.");
      }

      final invoice = Map<String, dynamic>.from(invoiceSnapshot.value as Map);

      // Prepare payment data with bank/cheque information
      final paymentData = {
        'amount': paymentAmount,
        'date': paymentDate.toIso8601String(),
        'paymentMethod': paymentMethod,
        'description': description,
        // 'imageUrl': imageUrl,
        if (imageBase64 != null) 'image': imageBase64, // Store as Base64

        if (paymentMethod == 'Bank' && bankId != null) 'bankId': bankId,
        if (paymentMethod == 'Bank' && bankName != null) 'bankName': bankName,
        if (paymentMethod == 'Check' && chequeNumber != null) 'chequeNumber': chequeNumber,
        if (paymentMethod == 'Check' && chequeDate != null) 'chequeDate': chequeDate.toIso8601String(),
        if (paymentMethod == 'Check' && chequeBankId != null) 'chequeBankId': chequeBankId,
        if (paymentMethod == 'Check' && chequeBankName != null) 'chequeBankName': chequeBankName,
      };

      // Determine the payment reference based on payment method
      DatabaseReference paymentRef;
      switch (paymentMethod) {
        case 'Cash':
          paymentRef = _db.child('invoices').child(invoiceId).child('cashPayments').push();
          break;
        case 'Online':
          paymentRef = _db.child('invoices').child(invoiceId).child('onlinePayments').push();
          break;
        case 'Check':
          paymentRef = _db.child('invoices').child(invoiceId).child('checkPayments').push();
          break;
        case 'Bank':
          paymentRef = _db.child('invoices').child(invoiceId).child('bankPayments').push();
          break;
        case 'Slip':
          paymentRef = _db.child('invoices').child(invoiceId).child('slipPayments').push();
          break;
        default:
          throw Exception("Invalid payment method.");
      }

      // Save the payment data
      await paymentRef.set(paymentData);

      // Update the invoice with new payment amounts
      final currentDebit = _parseToDouble(invoice['debitAmount']);
      final updatedDebit = currentDebit + paymentAmount;

      await _db.child('invoices').child(invoiceId).update({
        'debitAmount': updatedDebit,
        if (paymentMethod == 'Cash') 'cashPaidAmount': (_parseToDouble(invoice['cashPaidAmount']) + paymentAmount),
        if (paymentMethod == 'Online') 'onlinePaidAmount': (_parseToDouble(invoice['onlinePaidAmount']) + paymentAmount),
        if (paymentMethod == 'Check') 'checkPaidAmount': (_parseToDouble(invoice['checkPaidAmount'] ?? 0.0) + paymentAmount),
        if (paymentMethod == 'Bank') 'bankPaidAmount': (_parseToDouble(invoice['bankPaidAmount'] ?? 0.0) + paymentAmount),
        if (paymentMethod == 'Slip') 'slipPaidAmount': (_parseToDouble(invoice['slipPaidAmount'] ?? 0.0) + paymentAmount),
      });

      // Update the ledger
      await _updateCustomerLedger(
        invoice['customerId'],
        creditAmount: 0.0,
        debitAmount: paymentAmount,
        remainingBalance: _parseToDouble(invoice['grandTotal']) - updatedDebit,
        invoiceNumber: invoice['invoiceNumber'],
        referenceNumber: invoice['referenceNumber'],
        paymentMethod: paymentMethod,
        bankName: paymentMethod == 'Bank' ? bankName :
        paymentMethod == 'Check' ? chequeBankName : null,
      );

      // For cheque payments, save to the bank's cheques node
      if (paymentMethod == 'Check' && chequeBankId != null) {
        final bankChequesRef = _db.child('banks/$chequeBankId/cheques');
        final chequeData = {
          'invoiceId': invoiceId,
          'invoiceNumber': invoice['invoiceNumber'],
          'customerId': invoice['customerId'],
          'customerName': invoice['customerName'],
          'amount': paymentAmount,
          'chequeNumber': chequeNumber,
          'chequeDate': chequeDate?.toIso8601String(),
          'status': 'pending',
          'createdAt': DateTime.now().toIso8601String(),
        };
        await bankChequesRef.push().set(chequeData);
      }

      // For bank payments, record the transaction
      if (paymentMethod == 'Bank' && bankId != null) {
        final bankTransactionsRef = _db.child('banks/$bankId/transactions');
        await bankTransactionsRef.push().set({
          'amount': paymentAmount,
          'description': description ?? 'Invoice Payment: ${invoice['invoiceNumber']}',
          'type': 'cash_in',
          'timestamp': paymentDate.millisecondsSinceEpoch,
          'invoiceId': invoiceId,
          'bankName': bankName,
        });

        // Update bank balance
        final bankBalanceRef = _db.child('banks/$bankId/balance');
        final currentBalance = (await bankBalanceRef.get()).value as num? ?? 0.0;
        await bankBalanceRef.set(currentBalance + paymentAmount);
      }

      // Refresh the invoices list
      await fetchInvoices();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment of Rs. $paymentAmount recorded successfully as $paymentMethod.')),
      );
    } catch (e) {
      // Delete image if upload succeeded but payment failed
      // if (imageUrl != null) await _deleteImage(imageUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save payment: ${e.toString()}')),
      );
      throw Exception('Failed to save payment: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getInvoicePayments(String invoiceId) async {
    try {
      List<Map<String, dynamic>> payments = [];
      final invoiceRef = _db.child('invoices').child(invoiceId);

      Future<void> fetchPayments(String method) async {
        DataSnapshot snapshot = await invoiceRef.child('${method}Payments').get();
        if (snapshot.exists) {
          Map<dynamic, dynamic> methodPayments = snapshot.value as Map<dynamic, dynamic>;
          methodPayments.forEach((key, value) {
            final paymentData = Map<String, dynamic>.from(value);
            // Convert 'amount' to double explicitly
            paymentData['amount'] = (paymentData['amount'] as num).toDouble();
            // Handle Base64 image if present
            if (paymentData['image'] != null) {
              paymentData['imageBytes'] = _base64ToImage(paymentData['image']);
            }
            payments.add({
              'method': method,
              ...paymentData,
              'date': DateTime.parse(value['date']),
              // Include bank name for bank and cheque payments
              'bankName': method == 'Bank' ? value['bankName'] :
              method == 'Check' ? value['chequeBankName'] : null,
            });
          });
        }
      }

      await fetchPayments('cash');
      await fetchPayments('online');
      await fetchPayments('check');
      await fetchPayments('bank'); // Add this line
      await fetchPayments('slip'); // Add this line for slip payments

      payments.sort((a, b) => b['date'].compareTo(a['date']));
      return payments;
    } catch (e) {
      throw Exception('Failed to fetch payments: $e');
    }
  }

  Future<void> deletePaymentEntry({
    required BuildContext context,
    required String invoiceId,
    required String paymentKey,
    required String paymentMethod,
    required double paymentAmount,
  })
  async {
    try {
      final invoiceRef = _db.child('invoices').child(invoiceId);
      print("📌 Fetching payment data for method: $paymentMethod and key: $paymentKey");

      // Step 1: Fetch payment data before deleting it
      final paymentSnapshot = await invoiceRef.child('${paymentMethod}Payments').child(paymentKey).get();


      if (!paymentSnapshot.exists) {
        print("❌ Error: Payment entry not found in ${paymentMethod}Payments");
        throw Exception("Payment not found.");
      }

      final paymentData = Map<String, dynamic>.from(paymentSnapshot.value as Map);
      print("✅ Payment data found: $paymentData");


      if (paymentMethod.toLowerCase() == 'cash') {
        final cashbookEntryId = paymentData['cashbookEntryId'];
        if (cashbookEntryId != null && cashbookEntryId.isNotEmpty) {
          print('Deleting cashbook entry: $cashbookEntryId');
          await _db.child('cashbook').child(cashbookEntryId).remove();
        } else {
          print('Warning: cashbookEntryId is missing for cash payment.');
        }
      }

      // Step 2: Handle Bank Payment - Delete specific bank transaction using unique ID
      if (paymentMethod.toLowerCase() == 'bank') {
        String? bankId = paymentData['bankId']?.toString();
        String? transactionId = paymentData['transactionId']?.toString();

        print("🏦 Bank Payment detected. bankId: $bankId, transactionId: $transactionId");

        if (bankId == null || bankId.isEmpty) {
          print("❌ Error: Bank ID is missing!");
          throw Exception("Bank ID is missing in the payment record.");
        }

        if (transactionId == null || transactionId.isEmpty) {
          print("🔍 Searching for transaction in the bank node...");
          final bankTransactionsRef = _db.child('banks/$bankId/transactions');
          final transactionSnapshot = await bankTransactionsRef.orderByChild('invoiceId').equalTo(invoiceId).get();

          if (transactionSnapshot.exists) {
            final transactions = Map<String, dynamic>.from(transactionSnapshot.value as Map);
            for (var key in transactions.keys) {
              final transaction = Map<String, dynamic>.from(transactions[key]);
              if (transaction['amount'] == paymentAmount) {
                transactionId = key;
                print("✅ Found matching bank transaction ID: $transactionId");
                break;
              }
            }
          }
        }

        if (transactionId == null) {
          print("❌ Error: Unable to find transaction ID for this payment.");
          throw Exception("Transaction ID not found for this bank payment.");
        }

        final bankTransactionRef = _db.child('banks/$bankId/transactions/$transactionId');
        final transactionSnapshot = await bankTransactionRef.get();

        if (transactionSnapshot.exists) {
          final transactionData = Map<String, dynamic>.from(transactionSnapshot.value as Map);
          final transactionAmount = (transactionData['amount'] as num).toDouble();

          print("🗑️ Deleting bank transaction: $transactionData");
          await bankTransactionRef.remove();
          print("✅ Transaction deleted successfully.");

          // Update bank balance
          final bankBalanceRef = _db.child('banks/$bankId/balance');
          final currentBalance = (await bankBalanceRef.get()).value as num? ?? 0.0;
          final updatedBalance = (currentBalance - transactionAmount).clamp(0.0, double.infinity);

          print("💰 Updating bank balance from $currentBalance to $updatedBalance");
          await bankBalanceRef.set(updatedBalance);
        } else {
          print("❌ Error: Bank transaction not found for deletion.");
        }
      }

      // Step 3: Remove the payment entry from the invoice
      print("🗑️ Removing payment entry from: ${paymentMethod}Payments with key: $paymentKey");
      await invoiceRef.child('${paymentMethod}Payments').child(paymentKey).remove();

      // Step 4: Fetch the invoice data
      final invoiceSnapshot = await invoiceRef.get();
      if (!invoiceSnapshot.exists) {
        throw Exception("Invoice not found.");
      }

      final invoice = Map<String, dynamic>.from(invoiceSnapshot.value as Map);
      final customerId = invoice['customerId']?.toString() ?? '';
      final invoiceNumber = invoice['invoiceNumber']?.toString() ?? '';

      print("📄 Invoice details retrieved: customerId = $customerId, invoiceNumber = $invoiceNumber");

      // Step 5: Get current payment amounts
      double currentCashPaid = _parseToDouble(invoice['cashPaidAmount']);
      double currentOnlinePaid = _parseToDouble(invoice['onlinePaidAmount']);
      double currentCheckPaid = _parseToDouble(invoice['checkPaidAmount']);
      double currentSlipPaid = _parseToDouble(invoice['slipPaidAmount'] ?? 0.0);
      double currentBankPaid = _parseToDouble(invoice['bankPaidAmount'] ?? 0.0);
      double currentDebit = _parseToDouble(invoice['debitAmount']);

      print("💰 Current Payment Amounts -> Cash: $currentCashPaid, Online: $currentOnlinePaid, Check: $currentCheckPaid, Bank: $currentBankPaid, Slip: $currentSlipPaid, Debit: $currentDebit");

      // Deduct the payment amount from the respective payment method
      switch (paymentMethod.toLowerCase()) {
        case 'cash':
          currentCashPaid = (currentCashPaid - paymentAmount).clamp(0.0, double.infinity);
          break;
        case 'online':
          currentOnlinePaid = (currentOnlinePaid - paymentAmount).clamp(0.0, double.infinity);
          break;
        case 'check':
          currentCheckPaid = (currentCheckPaid - paymentAmount).clamp(0.0, double.infinity);
          break;
        case 'bank':
          currentBankPaid = (currentBankPaid - paymentAmount).clamp(0.0, double.infinity);
          break;
        case 'slip':
          currentSlipPaid = (currentSlipPaid - paymentAmount).clamp(0.0, double.infinity);
          break;
        default:
          throw Exception("Invalid payment method.");
      }

      final updatedDebit = (currentDebit - paymentAmount).clamp(0.0, double.infinity);
      print("🔄 Updating invoice with new values...");

      await invoiceRef.update({
        'cashPaidAmount': currentCashPaid,
        'onlinePaidAmount': currentOnlinePaid,
        'checkPaidAmount': currentCheckPaid,
        'bankPaidAmount': currentBankPaid,
        'slipPaidAmount': currentSlipPaid,
        'debitAmount': updatedDebit,
      });

      print("✅ Invoice updated successfully.");

      // Step 6: Fetch latest ledger entry for the customer
      final customerLedgerRef = _db.child('ledger').child(customerId);
      final ledgerSnapshot = await customerLedgerRef.orderByChild('createdAt').limitToLast(1).get();

      if (ledgerSnapshot.exists) {
        final ledgerData = ledgerSnapshot.value as Map<dynamic, dynamic>;
        final latestEntryKey = ledgerData.keys.first;
        final latestEntry = Map<String, dynamic>.from(ledgerData[latestEntryKey]);

        double currentRemainingBalance = _parseToDouble(latestEntry['remainingBalance']);
        double updatedRemainingBalance = currentRemainingBalance + paymentAmount;
        print("🔄 Updating ledger balance to: $updatedRemainingBalance");

        await customerLedgerRef.child(latestEntryKey).update({
          'remainingBalance': updatedRemainingBalance,
        });
      }

      // Step 7: Delete ledger entry for the payment
      final paymentLedgerSnapshot = await customerLedgerRef.orderByChild('invoiceNumber').equalTo(invoiceNumber).get();

      if (paymentLedgerSnapshot.exists) {
        final paymentLedgerData = paymentLedgerSnapshot.value as Map<dynamic, dynamic>;
        for (var entryKey in paymentLedgerData.keys) {
          final entry = Map<String, dynamic>.from(paymentLedgerData[entryKey]);
          if (_parseToDouble(entry['debitAmount']) == paymentAmount) {
            await customerLedgerRef.child(entryKey).remove();
            break;
          }
        }
      }

      print("🔄 Refreshing invoices list...");
      await fetchInvoices();
      print("✅ Payment deletion successful.");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment deleted successfully.')),
      );
      Navigator.pop(context);

    } catch (e) {
      print("❌ Error deleting payment: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete payment: ${e.toString()}')),
      );
    }
  }

  Future<void> editPaymentEntry({
    required String invoiceId,
    required String paymentKey,
    required String paymentMethod,
    required double oldPaymentAmount,
    required double newPaymentAmount,
    required String newDescription,
    required Uint8List? newImageBytes,
  })
  async {
    try {
      final invoiceRef = _db.child('invoices').child(invoiceId);

      // Step 1: Update the payment entry in the invoice
      final updatedPaymentData = {
        'amount': newPaymentAmount,
        'date': DateTime.now().toIso8601String(),
        'paymentMethod': paymentMethod,
        'description': newDescription,
      };

      // if (newImageBytes != null) {
      //   updatedPaymentData['image'] = base64Encode(newImageBytes);
      // }

      await invoiceRef.child('${paymentMethod}Payments').child(paymentKey).update(updatedPaymentData);

      // Step 2: Update the debitAmount in the invoice
      final invoiceSnapshot = await invoiceRef.get();
      if (invoiceSnapshot.exists) {
        final invoice = Map<String, dynamic>.from(invoiceSnapshot.value as Map);
        final currentDebit = _parseToDouble(invoice['debitAmount']);
        final updatedDebit = currentDebit - oldPaymentAmount + newPaymentAmount;

        await invoiceRef.update({
          'debitAmount': updatedDebit,
        });

        // Step 3: Update the customer ledger
        final customerId = invoice['customerId'];
        final invoiceNumber = invoice['invoiceNumber'];
        final referenceNumber = invoice['referenceNumber'];
        final grandTotal = _parseToDouble(invoice['grandTotal']);

        await _updateCustomerLedger(
          customerId,
          creditAmount: 0.0,
          debitAmount: newPaymentAmount - oldPaymentAmount, // Adjust the ledger
          remainingBalance: grandTotal - updatedDebit,
          invoiceNumber: invoiceNumber,
          referenceNumber:referenceNumber,
        );
      }

      // Refresh the invoices list
      await fetchInvoices();
    } catch (e) {
      throw Exception('Failed to edit payment entry: $e');
    }
  }

  List<Map<String, dynamic>> getTodaysInvoices() {
    final today = DateTime.now();
    // final startOfDay = DateTime(today.year, today.month, today.day - 1); // Include yesterday
    final startOfDay = DateTime(today.year, today.month, today.day ); // Include yesterdays

    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    return _invoices.where((invoice) {
      final invoiceDate = DateTime.tryParse(invoice['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(int.parse(invoice['createdAt']));
      return invoiceDate.isAfter(startOfDay) && invoiceDate.isBefore(endOfDay);
    }).toList();
  }

  double getTotalAmount(List<Map<String, dynamic>> invoices) {
    return invoices.fold(0.0, (sum, invoice) => sum + (invoice['grandTotal'] ?? 0.0));
  }

  double getTotalPaidAmount(List<Map<String, dynamic>> invoices) {
    return invoices.fold(0.0, (sum, invoice) => sum + (invoice['debitAmount'] ?? 0.0));
  }

  Future<void> addCashBookEntry({
    required String description,
    required double amount,
    required DateTime dateTime,
    required String type,
  })
  async {
    try {
      final entry = CashbookEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        description: description,
        amount: amount,
        dateTime: dateTime,
        type: type,
      );

      await FirebaseDatabase.instance
          .ref()
          .child('cashbook')
          .child(entry.id!)
          .set(entry.toJson());
    } catch (e) {
      print("Error adding cash book entry: $e");
      rethrow;
    }
  }


}
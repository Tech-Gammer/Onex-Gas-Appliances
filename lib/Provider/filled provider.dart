import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import '../Models/cashbookModel.dart';
import '../Models/itemModel.dart';

class FilledProvider with ChangeNotifier {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _filled = [];
  List<Item> _items = []; // Initialize the _items list
  List<Item> get items => _items; // Add a getter for _items
  List<Map<String, dynamic>> get filled => _filled;
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool _hasMoreData = true;
  bool get hasMoreData => _hasMoreData;
  int _lastLoadedIndex = 0;
  String? _lastKey;
  // Page size for pagination
  final int _pageSize = 20;
  String? _selectedChequeBankId;
  String? _selectedChequeBankName;
  TextEditingController _chequeNumberController = TextEditingController();
  DateTime? _selectedChequeDate;

  // Clear all loaded data and reset pagination
  void resetPagination() {
    _filled = [];
    _hasMoreData = true;
    _lastLoadedIndex = 0;
    _lastKey = null;
    notifyListeners();
  }

  Future<void> fetchFilled() async {
    try {
      _isLoading = true;
      notifyListeners();

      _filled.clear();

      final snapshot = await _db.child('filled')
          .orderByChild('createdAt')
          .limitToLast(_pageSize)
          .get();

      // Add explicit null check
      if (!snapshot.exists || snapshot.value == null) {
        _hasMoreData = false;
        return;
      }

      _processFilledData(snapshot.value!);
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to fetch filled: ${e.toString()}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  void _processFilledData(dynamic data) {
    if (data == null) return;

    List<MapEntry<dynamic, dynamic>> entries = [];

    if (data is Map<dynamic, dynamic>) {
      entries = data.entries.toList();
    } else if (data is List<dynamic>) {
      entries = data.asMap().entries.map((entry) {
        return MapEntry(entry.key.toString(), entry.value);
      }).toList();
    }

    // Add null check for entry values
    entries = entries.where((entry) => entry.value != null).toList();

    entries.sort((a, b) {
      final dateA = _parseDateTime(a.value['createdAt']);
      final dateB = _parseDateTime(b.value['createdAt']);
      return dateB.compareTo(dateA);
    });

    for (var entry in entries) {
      if (entry.value != null) {
        _processFilledEntry(entry.key.toString(), entry.value);
      }
    }
  }

  DateTime _parseDateTime(dynamic dateValue) {
    if (dateValue is String) return DateTime.parse(dateValue);
    if (dateValue is int) return DateTime.fromMillisecondsSinceEpoch(dateValue);
    return DateTime.now();
  }


  // Load next page
  Future<void> loadMoreFilled() async {
    if (_isLoading || !_hasMoreData) return;

    try {
      _isLoading = true;
      notifyListeners();

      final lastCreatedAt = _filled.isNotEmpty
          ? _filled.last['createdAt']
          : null;

      if (lastCreatedAt == null) {
        _hasMoreData = false;
        return;
      }

      final snapshot = await _db.child('filled')
          .orderByChild('createdAt')
          .endBefore(lastCreatedAt)
          .limitToLast(_pageSize)
          .get();

      // Add null check
      if (!snapshot.exists || snapshot.value == null) {
        _hasMoreData = false;
        return;
      }

      _processFilledData(snapshot.value!);
      notifyListeners();
    } catch (e) {
      print('Error loading more filled: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  Future<int> getNextFilledNumber() async {
    final counterRef = _db.child('filledCounter');
    final transactionResult = await counterRef.runTransaction((currentData) {
      int currentCount = (currentData ?? 0) as int;
      currentCount++;
      return Transaction.success(currentCount);
    });

    if (transactionResult.committed) {
      return transactionResult.snapshot!.value as int;
    } else {
      throw Exception('Failed to increment filled counter.');
    }
  }


  bool _isTimestampNumber(String number) {
    // Only consider numbers longer than 10 digits as timestamps
    return number.length > 10 && int.tryParse(number) != null;
  }



  Future<void> saveFilled({
    required String filledId, // Accepts the filled ID (instead of using push)
    required String filledNumber, // Can be timestamp or sequential
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
      if (filledId.isEmpty || filledNumber.isEmpty) {
        throw Exception('Filled ID and number cannot be empty');
      }
      final cleanedItems = items.map((item) {
        return {
          'itemName': item['itemName'],
          'rate': item['rate'] ?? 0.0,
          'qty': item['qty'] ?? 0.0,
          'description': item['description'] ?? '',
          'total': item['total'],
        };
      }).toList();

      final filledData = {
        'referenceNumber': referenceNumber, // Add this
        'filledNumber': filledNumber,
        'customerId': customerId,
        'customerName': customerName, // Save customer name here
        'subtotal': subtotal,
        'discount': discount,
        'grandTotal': grandTotal,
        'paymentType': paymentType,
        'paymentMethod': paymentMethod ?? '',
        'items': cleanedItems,
        'createdAt': createdAt, // Use the provided date
        'mazdoori': mazdoori, // Add this line
        'numberType': _isTimestampNumber(filledNumber) ? 'timestamp' : 'sequential',

      };
      // Save the filled at the specified filledId path
      await _db.child('filled').child(filledId).set(filledData);
      print('filled saved');
      // Now update the ledger for this customer
      await _updateCustomerLedger(
        referenceNumber: referenceNumber,
        customerId,
        creditAmount: grandTotal, // The filled total as a credit
        debitAmount: 0.0, // No payment yet
        remainingBalance: grandTotal, // Full amount due initially
        filledNumber: filledNumber,
      );
    } catch (e) {
      throw Exception('Failed to save filled: $e');
    }
  }

  Future<Map<String, dynamic>?> getFilledById(String filledId) async {
    try {
      final snapshot = await _db.child('filled').child(filledId).get();
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch filled: $e');

    }
  }

  Future<void> updateFilled({
    required String filledId,
    required String filledNumber,
    required String customerId,
    required String customerName,
    required double subtotal,
    required double discount,
    required double mazdoori, // Add this parameter
    required double grandTotal,
    required String paymentType,
    String? paymentMethod,
    required String referenceNumber, // Add this
    required List<Map<String, dynamic>> items,
    required String createdAt,
  })
  async {
    try {
      // Fetch the old filled data
      final oldfilled = await getFilledById(filledId);
      if (oldfilled == null) {
        throw Exception('Filled not found.');
      }
      final isTimestamp = oldfilled['numberType'] == 'timestamp';

      // Get the old grand total
      final double oldGrandTotal = (oldfilled['grandTotal'] as num).toDouble();

      // Calculate the difference between the old and new grand totals
      final double difference = grandTotal - oldGrandTotal;

      final cleanedItems = items.map((item) {
        return {
          'itemName': item['itemName'],
          'rate': item['rate'] ?? 0.0,
          'qty': item['qty'] ?? 0.0,
          'description': item['description'] ?? '',
          'total': item['total'],

        };
      }).toList();

      // Prepare the updated filled data
      final filledData = {
        'referenceNumber': referenceNumber, // Add this
        'filledNumber': filledNumber,
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

      // Update the filled in the database
      await _db.child('filled').child(filledId).update(filledData);

      // Step 1: Find the existing ledger entry for this filled
      final customerLedgerRef = _db.child('filledledger').child(customerId);
      final query = customerLedgerRef.orderByChild('filledNumber').equalTo(filledNumber);
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
          final double newQty = item['qty'] ?? 0.0; // Use 'qty' instead of 'qty'
          final double initialQty = item['initialQty'] ?? 0.0; // Ensure this is 'initialQty'

          // Calculate the difference between the initial quantity and the new quantity
          double delta = initialQty - newQty;

          // Update the qtyOnHand in the database
          double updatedQty = currentQty + delta;

          await _db.child('items/$itemId').update({'qtyOnHand': updatedQty});
        }
      }

      // Refresh the filled list
      await fetchFilled();

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to update filled: $e');
    }
  }


  void _processFilledEntry(String key, dynamic value) {
    // Add null check for value
    if (value == null) return;

    if (value is! Map<dynamic, dynamic>) return;

    final filledData = Map<String, dynamic>.from(value);

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
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
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
              'description': item['description']?.toString() ?? '',
              'total': parseDouble(item['total']),
            };
          }
          return {};
        }).toList();
      }
      return [];
    }

    _filled.add({
      'id': key,
      'filledNumber': filledData['filledNumber']?.toString() ?? 'N/A',
      'customerId': filledData['customerId']?.toString() ?? '',
      'customerName': filledData['customerName']?.toString() ?? 'N/A',
      'subtotal': parseDouble(filledData['subtotal']),
      'discount': parseDouble(filledData['discount']),
      'mazdoori': parseDouble(filledData['mazdoori'] ?? 0.0), // Add this line
      'grandTotal': parseDouble(filledData['grandTotal']),
      'paymentType': filledData['paymentType']?.toString() ?? '',
      'paymentMethod': filledData['paymentMethod']?.toString() ?? '',
      'cashPaidAmount': parseDouble(filledData['cashPaidAmount']),
      'onlinePaidAmount': parseDouble(filledData['onlinePaidAmount']),
      'chequePaidAmount': parseDouble(filledData['chequePaidAmount'] ?? 0.0),
      'slipPaidAmount': parseDouble(filledData['slipPaidAmount'] ?? 0.0),
      'debitAmount': parseDouble(filledData['debitAmount']),
      'debitAt': filledData['debitAt']?.toString() ?? '',
      'items': processItems(filledData['items']),
      'createdAt': parseDateTime(filledData['createdAt']).toIso8601String(),
      'remainingBalance': parseDouble(filledData['remainingBalance']),
      'referenceNumber': filledData['referenceNumber']?.toString() ?? '',
    });
  }



  Future<void> deleteFilled(String filledId) async {
    try {
      // Fetch the filled to identify related customer and filled number
      final filled = _filled.firstWhere((inv) => inv['id'] == filledId);

      if (filled == null) {
        throw Exception("Filled not found.");
      }

      final customerId = filled['customerId'] as String;
      final filledNumber = filled['filledNumber'] as String;

      // Get the items from the filled
      final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(filled['items']);

      // Reverse the qtyOnHand deduction for each item
      for (var item in items) {
        final itemName = item['itemName'] as String;
        final qty = (item['qty'] as num).toDouble(); // Get the qty from the filled

        // Fetch the item from the database
        final itemSnapshot = await _db.child('items').orderByChild('itemName').equalTo(itemName).get();

        if (itemSnapshot.exists) {
          final itemData = itemSnapshot.value as Map<dynamic, dynamic>;
          final itemKey = itemData.keys.first;
          final currentItem = itemData[itemKey] as Map<dynamic, dynamic>;

          // Get the current qtyOnHand
          double currentQtyOnHand = (currentItem['qtyOnHand'] as num).toDouble();

          // Add back the qty to qtyOnHand
          double updatedQtyOnHand = currentQtyOnHand + qty;

          // Update the item in the database
          await _db.child('items').child(itemKey).update({'qtyOnHand': updatedQtyOnHand});
        }
      }

      // Delete the filled from the database
      await _db.child('filled').child(filledId).remove();

      // Delete associated ledger entries
      final customerLedgerRef = _db.child('filledledger').child(customerId);

      // Find all ledger entries related to this filled
      final snapshot = await customerLedgerRef.orderByChild('filledNumber').equalTo(filledNumber).get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        for (var entryKey in data.keys) {
          await customerLedgerRef.child(entryKey).remove();
        }
      }

      // Refresh the filled list after deletion
      await fetchFilled();

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to delete filled and ledger entries: $e');
    }
  }

  Future<void> _updateCustomerLedger(
      String customerId, {
        required double creditAmount,
        required double debitAmount,
        required double remainingBalance,
        required String filledNumber,
        required String referenceNumber,
        String? bankId,
        String? bankName,
        String? paymentMethod,
      })
  async {
    try {
      final customerLedgerRef = _db.child('filledledger').child(customerId);

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
        'filledNumber': filledNumber,
        'creditAmount': creditAmount,
        'debitAmount': debitAmount,
        'remainingBalance': newRemainingBalance, // Updated balance
        'createdAt': DateTime.now().toIso8601String(),
        'paymentMethod': paymentMethod, // Add payment method
        // Include bank info if this is a bank payment
        // if (paymentMethod == 'Bank') ...{
        //   'bankId': bankId,
        //   'bankName': bankName,
        // },
        // Include bank info for both bank and cheque payments
        if (bankId != null) 'bankId': bankId,
        if (bankName != null) 'bankName': bankName,
      };

      await customerLedgerRef.push().set(ledgerData);
    } catch (e) {
      throw Exception('Failed to update customer ledger: $e');
    }
  }


  List<Map<String, dynamic>> getFilledByPaymentMethod(String paymentMethod) {
    return _filled.where((filled) {
      final method = filled['paymentMethod'] ?? '';
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

  Future<List<Map<String, dynamic>>> getChequesByBank(String bankId) async {
    final snapshot = await _db.child('cheques')
        .orderByChild('bankId')
        .equalTo(bankId)
        .get();
    try {
      // final snapshot = await _db.child('cheques')
      //     .orderByChild('bankId')
      //     .equalTo(bankId)
      //     .get();

      if (!snapshot.exists) return [];

      final cheques = <Map<String, dynamic>>[];
      final data = snapshot.value as Map<dynamic, dynamic>;

      data.forEach((key, value) {
        cheques.add({
          'id': key,
          ...Map<String, dynamic>.from(value),
        });
      });

      // Sort by date (newest first)
      cheques.sort((a, b) {
        final dateA = DateTime.parse(a['createdAt']);
        final dateB = DateTime.parse(b['createdAt']);
        return dateB.compareTo(dateA);
      });

      return cheques;
    } catch (e) {
      throw Exception('Failed to fetch cheques: $e');
    }
  }

  Future<void> updateChequeStatus({
    required String chequeId,
    required String status,
    String? bankId,
  })
  async {
    await _db.child('cheques').child(chequeId).update({
      'status': status,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    if (status == 'cleared' && bankId != null) {
      // Update bank balance
      final chequeSnapshot = await _db.child('cheques').child(chequeId).get();
      if (chequeSnapshot.exists) {
        final cheque = Map<String, dynamic>.from(chequeSnapshot.value as Map);
        final amount = (cheque['amount'] as num).toDouble();

        final bankBalanceRef = _db.child('banks/$bankId/balance');
        final currentBalance = (await bankBalanceRef.get()).value as num? ?? 0.0;
        await bankBalanceRef.set(currentBalance + amount);
      }
    }
  }

  Future<List<Map<String, dynamic>>> getAllCheques() async {
    try {
      final snapshot = await _db.child('cheques').get();


      if (!snapshot.exists) return [];

      final cheques = <Map<String, dynamic>>[];
      final data = snapshot.value as Map<dynamic, dynamic>;

      data.forEach((key, value) {
        cheques.add({
          'id': key,
          ...Map<String, dynamic>.from(value),
        });
      });

      // Sort by date (newest first)
      cheques.sort((a, b) {
        final dateA = DateTime.parse(a['createdAt']);
        final dateB = DateTime.parse(b['createdAt']);
        return dateB.compareTo(dateA);
      });

      return cheques;
    } catch (e) {
      throw Exception('Failed to fetch cheques: $e');
    }
  }

//   Future<void> payFilledWithSeparateMethod(
//       BuildContext context,
//       String filledId,
//       double paymentAmount,
//       String paymentMethod, {
//         String? description,
//         Uint8List? imageBytes,
//         required DateTime paymentDate,
//         String? bankId,
//         String? bankName,
//         String? chequeNumber,
//         DateTime? chequeDate,
//         String? chequeBankId,
//         String? chequeBankName,
//       })
//   async {
//     try {
//       // Fetch the current filled data from the database
//       final filledSnapshot = await _db.child('filled').child(filledId).get();
//       if (!filledSnapshot.exists) {
//         throw Exception("Filled not found.");
//       }
//
//       final filled = Map<String, dynamic>.from(filledSnapshot.value as Map);
//
//       // Handle bank transactions
//       if (paymentMethod == 'Bank' && bankId != null && bankName != null) {
//         final bankRef = _db.child('banks/$bankId/transactions');
//         final transactionData = {
//           'amount': paymentAmount,
//           'description': description ?? 'Filled Payment: ${filled['referenceNumber']}',
//           'type': 'cash_in',
//           'timestamp': paymentDate.millisecondsSinceEpoch,
//           'filledId': filledId,
//           'bankName': bankName,
//         };
//         await bankRef.push().set(transactionData);
//
//         // Update bank balance
//         final bankBalanceRef = _db.child('banks/$bankId/balance');
//         final currentBalance = (await bankBalanceRef.get()).value as num? ?? 0.0;
//         await bankBalanceRef.set(currentBalance + paymentAmount);
//       }
//
//       // Retrieve and parse all necessary values
//       final remainingBalance = _parseToDouble(filled['remainingBalance']);
//       final currentCashPaid = _parseToDouble(filled['cashPaidAmount']);
//       final currentOnlinePaid = _parseToDouble(filled['onlinePaidAmount']);
//       final grandTotal = _parseToDouble(filled['grandTotal']);
//       final currentSlipPaid = _parseToDouble(filled['slipPaidAmount'] ?? 0.0);
//       final currentBankPaid = _parseToDouble(filled['bankPaidAmount'] ?? 0.0);
//       final currentChequePaid = _parseToDouble(filled['chequePaidAmount'] ?? 0.0);
//
//       // Calculate the total paid so far
//       final totalPaid = currentCashPaid + currentOnlinePaid + currentChequePaid + currentSlipPaid + currentBankPaid;
//
//       // Initialize updated payment amounts
//       double updatedCashPaid = currentCashPaid;
//       double updatedOnlinePaid = currentOnlinePaid;
//       double updatedChequePaid = currentChequePaid;
//       double updatedSlipPaid = currentSlipPaid;
//       double updatedBankPaid = currentBankPaid;
//
//       // Create a payment object to store in the database
//       final paymentData = {
//         'amount': paymentAmount,
//         'date': paymentDate.toIso8601String(),
//         'method': paymentMethod,
//         'description': description,
//         // Include bank info for bank payments
//         if (paymentMethod == 'Bank') ...{
//           'bankId': bankId,
//           'bankName': bankName,
//         },
//         // Include cheque info for cheque payments
//         if (paymentMethod == 'Cheque') ...{
//           'chequeNumber': chequeNumber,
//           'chequeDate': chequeDate?.toIso8601String(),
//           'bankId': chequeBankId,
//           'bankName': chequeBankName,
//         },
//       };
//
//       // Handle cash payments
//       if (paymentMethod == 'Cash') {
//         final cashbookEntryRef = _db.child('cashbook').push();
//         final cashbookEntryId = cashbookEntryRef.key!;
//
//         final cashbookEntry = CashbookEntry(
//           id: cashbookEntryId,
//           description: description ?? 'Filled Payment ${filled['referenceNumber']}',
//           amount: paymentAmount,
//           dateTime: paymentDate,
//           type: 'cash_in',
//         );
//
//         await cashbookEntryRef.set(cashbookEntry.toJson());
//         paymentData['cashbookEntryId'] = cashbookEntryId;
//       }
//
//       // Handle cheque payments
// // Handle cheque payments
//       if (paymentMethod == 'Cheque') {
//         if (chequeBankId == null || chequeBankName == null) {
//           throw Exception("Bank not selected for cheque payment");
//         }
//         if (chequeNumber == null || chequeNumber.isEmpty) {
//           throw Exception("Cheque number is required");
//         }
//         if (chequeDate == null) {
//           throw Exception("Cheque date is required");
//         }
//
//         // Save cheque under the selected bank
//         final bankChequesRef = _db.child('banks/$chequeBankId/cheques');
//         final chequeData = {
//           'filledId': filledId,
//           'filledNumber': filled['filledNumber'],
//           'customerId': filled['customerId'],
//           'customerName': filled['customerName'],
//           'amount': paymentAmount,
//           'chequeNumber': chequeNumber,
//           'chequeDate': chequeDate.toIso8601String(),
//           'status': 'pending',
//           'createdAt': DateTime.now().toIso8601String(),
//           'bankName': chequeBankName,
//         };
//
//         final newChequeRef = bankChequesRef.push();
//         await newChequeRef.set(chequeData);
//
//         // Update paymentData with cheque information including bank name
//         paymentData.addAll({
//           'chequeTransactionId': newChequeRef.key,
//           'bankId': chequeBankId,
//           'bankName': chequeBankName,  // Make sure to include bank name here
//           'chequeNumber': chequeNumber,
//           'chequeDate': chequeDate.toIso8601String(),
//         });
//       }
//       // If an image is provided, encode it to base64
//       if (imageBytes != null) {
//         paymentData['image'] = base64Encode(imageBytes);
//       }
//
//       // Determine the payment reference based on payment method
//       DatabaseReference paymentRef;
//       switch (paymentMethod) {
//         case 'Cash':
//           updatedCashPaid += paymentAmount;
//           paymentRef = _db.child('filled').child(filledId).child('cashPayments').push();
//           break;
//         case 'Online':
//           updatedOnlinePaid += paymentAmount;
//           paymentRef = _db.child('filled').child(filledId).child('onlinePayments').push();
//           break;
//         case 'Cheque':
//           updatedChequePaid += paymentAmount;
//           paymentRef = _db.child('filled').child(filledId).child('chequePayments').push();
//           break;
//         case 'Bank':
//           updatedBankPaid += paymentAmount;
//           paymentRef = _db.child('filled').child(filledId).child('bankPayments').push();
//           break;
//         case 'Slip':
//           updatedSlipPaid += paymentAmount;
//           paymentRef = _db.child('filled').child(filledId).child('slipPayments').push();
//           break;
//         default:
//           throw Exception("Invalid payment method.");
//       }
//
//       // Add the payment key to the payment data
//       paymentData['key'] = paymentRef.key;
//
//       // Save the payment data
//       await paymentRef.set(paymentData);
//
//       // Update the filled with new payment amounts
//       final updatedDebit = _parseToDouble(filled['debitAmount']) + paymentAmount;
//       final debitAt = DateTime.now().toIso8601String();
//
//       await _db.child('filled').child(filledId).update({
//         'cashPaidAmount': updatedCashPaid,
//         'onlinePaidAmount': updatedOnlinePaid,
//         'chequePaidAmount': updatedChequePaid,
//         'bankPaidAmount': updatedBankPaid,
//         'slipPaidAmount': updatedSlipPaid,
//         'debitAmount': updatedDebit,
//         'debitAt': debitAt,
//       });
//
//       // Update the local state
//       final filledIndex = _filled.indexWhere((inv) => inv['id'] == filledId);
//       if (filledIndex != -1) {
//         _filled[filledIndex]['cashPaidAmount'] = updatedCashPaid;
//         _filled[filledIndex]['onlinePaidAmount'] = updatedOnlinePaid;
//         _filled[filledIndex]['chequePaidAmount'] = updatedChequePaid;
//         _filled[filledIndex]['bankPaidAmount'] = updatedBankPaid;
//         _filled[filledIndex]['slipPaidAmount'] = updatedSlipPaid;
//         _filled[filledIndex]['debitAmount'] = updatedDebit;
//         _filled[filledIndex]['debitAt'] = debitAt;
//         notifyListeners();
//       }
//
//       // Update the ledger with the calculated remaining balance
//       await _updateCustomerLedger(
//         filled['customerId'],
//         creditAmount: 0.0,
//         debitAmount: paymentAmount,
//         remainingBalance: grandTotal - updatedDebit,
//         filledNumber: filled['filledNumber'],
//         referenceNumber: filled['referenceNumber'],
//         paymentMethod: paymentMethod,
//         bankId: paymentMethod == 'Bank' ? bankId : (paymentMethod == 'Cheque' ? chequeBankId : null),
//         bankName: paymentMethod == 'Bank' ? bankName : (paymentMethod == 'Cheque' ? chequeBankName : null),
//       );
//
//       // Refresh the filled list
//       await fetchFilled();
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Payment of Rs. $paymentAmount recorded successfully as $paymentMethod.')),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to save payment: ${e.toString()}')),
//       );
//       throw Exception('Failed to save payment: $e');
//     }
//   }

  // Future<List<Map<String, dynamic>>> getFilledPayments(String filledId) async {
  //   try {
  //     List<Map<String, dynamic>> payments = [];
  //     final filledRef = _db.child('filled').child(filledId);
  //
  //     Future<void> fetchPayments(String method) async {
  //       DataSnapshot snapshot = await filledRef.child('${method}Payments').get();
  //       if (snapshot.exists) {
  //         Map<dynamic, dynamic> methodPayments = snapshot.value as Map<dynamic, dynamic>;
  //         methodPayments.forEach((key, value) {
  //           final paymentData = Map<String, dynamic>.from(value);
  //           // Convert 'amount' to double explicitly
  //           paymentData['amount'] = (paymentData['amount'] as num).toDouble();
  //           payments.add({
  //             'method': method,
  //             ...paymentData,
  //             'date': DateTime.parse(value['date']),
  //           });
  //         });
  //       }
  //     }
  //
  //     await fetchPayments('cash');
  //     await fetchPayments('online');
  //     await fetchPayments('cheque');
  //     await fetchPayments('bank'); // Add this line
  //     await fetchPayments('slip'); // Add this line for slip payments
  //
  //     payments.sort((a, b) => b['date'].compareTo(a['date']));
  //     return payments;
  //   } catch (e) {
  //     throw Exception('Failed to fetch payments: $e');
  //   }
  // }

  Future<void> payFilledWithSeparateMethod(
      BuildContext context,
      String filledId,
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
      }) async {
    try {
      // Fetch the current filled data
      final filledSnapshot = await _db.child('filled').child(filledId).get();
      if (!filledSnapshot.exists) throw Exception("Filled not found.");

      final filled = Map<String, dynamic>.from(filledSnapshot.value as Map);

      // Handle Bank transaction
      if (paymentMethod == 'Bank' && bankId != null && bankName != null) {
        final bankRef = _db.child('banks/$bankId/transactions');
        final transactionData = {
          'amount': paymentAmount,
          'description': description ?? 'Filled Payment: ${filled['referenceNumber']}',
          'type': 'cash_in',
          'timestamp': paymentDate.millisecondsSinceEpoch,
          'filledId': filledId,
          'bankName': bankName,
        };
        await bankRef.push().set(transactionData);

        // Update bank balance
        final bankBalanceRef = _db.child('banks/$bankId/balance');
        final currentBalance = (await bankBalanceRef.get()).value as num? ?? 0.0;
        await bankBalanceRef.set(currentBalance + paymentAmount);
      }

      // Parse all paid amounts
      final remainingBalance = _parseToDouble(filled['remainingBalance']);
      final currentCashPaid = _parseToDouble(filled['cashPaidAmount']);
      final currentOnlinePaid = _parseToDouble(filled['onlinePaidAmount']);
      final grandTotal = _parseToDouble(filled['grandTotal']);
      final currentSlipPaid = _parseToDouble(filled['slipPaidAmount'] ?? 0.0);
      final currentBankPaid = _parseToDouble(filled['bankPaidAmount'] ?? 0.0);
      final currentChequePaid = _parseToDouble(filled['chequePaidAmount'] ?? 0.0);

      double updatedCashPaid = currentCashPaid;
      double updatedOnlinePaid = currentOnlinePaid;
      double updatedChequePaid = currentChequePaid;
      double updatedSlipPaid = currentSlipPaid;
      double updatedBankPaid = currentBankPaid;

      final paymentData = {
        'amount': paymentAmount,
        'date': paymentDate.toIso8601String(),
        'method': paymentMethod,
        'description': description,
        if (paymentMethod == 'Bank') ...{
          'bankId': bankId,
          'bankName': bankName,
        },
        if (paymentMethod == 'Cheque') ...{
          'chequeNumber': chequeNumber,
          'chequeDate': chequeDate?.toIso8601String(),
          'bankId': chequeBankId,
          'bankName': chequeBankName,
        },
      };

      // Handle cash payments
      if (paymentMethod == 'Cash') {
        final cashbookEntryRef = _db.child('cashbook').push();
        final cashbookEntryId = cashbookEntryRef.key!;
        final cashbookEntry = CashbookEntry(
          id: cashbookEntryId,
          description: description ?? 'Filled Payment ${filled['referenceNumber']}',
          amount: paymentAmount,
          dateTime: paymentDate,
          type: 'cash_in',
        );
        await cashbookEntryRef.set(cashbookEntry.toJson());
        paymentData['cashbookEntryId'] = cashbookEntryId;
      }

      // Handle cheque payments (improved logic)
      DatabaseReference paymentRef;
      if (paymentMethod == 'Cheque') {
        if (chequeBankId == null || chequeBankName == null) {
          throw Exception("Bank not selected for cheque payment");
        }
        if (chequeNumber == null || chequeNumber.isEmpty) {
          throw Exception("Cheque number is required");
        }
        if (chequeDate == null) {
          throw Exception("Cheque date is required");
        }

        final commonKey = _db.child('bankCheques').push().key;

        final chequeData = {
          'filledId': filledId,
          'filledNumber': filled['filledNumber'],
          'customerId': filled['customerId'],
          'customerName': filled['customerName'],
          'amount': paymentAmount,
          'chequeNumber': chequeNumber,
          'chequeDate': chequeDate.toIso8601String(),
          'status': 'pending',
          'createdAt': DateTime.now().toIso8601String(),
          'bankName': chequeBankName,
        };

        // Save to banks/.../cheques/commonKey
        await _db.child('banks/$chequeBankId/cheques/$commonKey').set(chequeData);

        // Add cheque details to paymentData
        paymentData.addAll({
          'chequeId': commonKey,
          'bankId': chequeBankId,
          'bankName': chequeBankName,
          'chequeNumber': chequeNumber,
          'chequeDate': chequeDate.toIso8601String(),
          'status': 'pending',
        });

        // Save to filled/.../chequePayments/commonKey
        paymentRef = _db.child('filled').child(filledId).child('chequePayments').child(commonKey!);
        updatedChequePaid += paymentAmount;
      } else {
        switch (paymentMethod) {
          case 'Cash':
            updatedCashPaid += paymentAmount;
            paymentRef = _db.child('filled').child(filledId).child('cashPayments').push();
            break;
          case 'Online':
            updatedOnlinePaid += paymentAmount;
            paymentRef = _db.child('filled').child(filledId).child('onlinePayments').push();
            break;
          case 'Bank':
            updatedBankPaid += paymentAmount;
            paymentRef = _db.child('filled').child(filledId).child('bankPayments').push();
            break;
          case 'Slip':
            updatedSlipPaid += paymentAmount;
            paymentRef = _db.child('filled').child(filledId).child('slipPayments').push();
            break;
          default:
            throw Exception("Invalid payment method.");
        }
      }

      // Add key to paymentData
      paymentData['key'] = paymentRef.key;

      // Optional image
      if (imageBytes != null) {
        paymentData['image'] = base64Encode(imageBytes);
      }

      // Save payment record
      await paymentRef.set(paymentData);

      // Update filled amounts
      final updatedDebit = _parseToDouble(filled['debitAmount']) + paymentAmount;
      final debitAt = DateTime.now().toIso8601String();

      await _db.child('filled').child(filledId).update({
        'cashPaidAmount': updatedCashPaid,
        'onlinePaidAmount': updatedOnlinePaid,
        'chequePaidAmount': updatedChequePaid,
        'bankPaidAmount': updatedBankPaid,
        'slipPaidAmount': updatedSlipPaid,
        'debitAmount': updatedDebit,
        'debitAt': debitAt,
      });

      // Update local cache
      final filledIndex = _filled.indexWhere((inv) => inv['id'] == filledId);
      if (filledIndex != -1) {
        _filled[filledIndex]['cashPaidAmount'] = updatedCashPaid;
        _filled[filledIndex]['onlinePaidAmount'] = updatedOnlinePaid;
        _filled[filledIndex]['chequePaidAmount'] = updatedChequePaid;
        _filled[filledIndex]['bankPaidAmount'] = updatedBankPaid;
        _filled[filledIndex]['slipPaidAmount'] = updatedSlipPaid;
        _filled[filledIndex]['debitAmount'] = updatedDebit;
        _filled[filledIndex]['debitAt'] = debitAt;
        notifyListeners();
      }

      // Update ledger
      await _updateCustomerLedger(
        filled['customerId'],
        creditAmount: 0.0,
        debitAmount: paymentAmount,
        remainingBalance: grandTotal - updatedDebit,
        filledNumber: filled['filledNumber'],
        referenceNumber: filled['referenceNumber'],
        paymentMethod: paymentMethod,
        bankId: paymentMethod == 'Bank' ? bankId : (paymentMethod == 'Cheque' ? chequeBankId : null),
        bankName: paymentMethod == 'Bank' ? bankName : (paymentMethod == 'Cheque' ? chequeBankName : null),
      );

      await fetchFilled();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment of Rs. $paymentAmount recorded successfully as $paymentMethod.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save payment: ${e.toString()}')),
      );
      throw Exception('Failed to save payment: $e');
    }
  }


  // Future<List<Map<String, dynamic>>> getFilledPayments(String filledId) async {
  //   try {
  //     List<Map<String, dynamic>> payments = [];
  //     final filledRef = _db.child('filled').child(filledId);
  //
  //     Future<void> fetchPayments(String method) async {
  //       DataSnapshot snapshot = await filledRef.child('${method}Payments').get();
  //       if (snapshot.exists) {
  //         Map<dynamic, dynamic> methodPayments = snapshot.value as Map<dynamic, dynamic>;
  //         methodPayments.forEach((key, value) {
  //           final paymentData = Map<String, dynamic>.from(value);
  //
  //           // Skip cheque payments that aren't cleared
  //           if (method == 'cheque' && (paymentData['status'] == 'pending' || paymentData['status'] == 'bounced')) {
  //             return;
  //           }
  //
  //
  //           paymentData['amount'] = (paymentData['amount'] as num).toDouble();
  //           payments.add({
  //             'method': method,
  //             ...paymentData,
  //             'date': DateTime.parse(value['date']),
  //           });
  //         });
  //       }
  //     }
  //
  //     await fetchPayments('cash');
  //     await fetchPayments('online');
  //     await fetchPayments('cheque');
  //     await fetchPayments('bank');
  //     await fetchPayments('slip');
  //
  //     payments.sort((a, b) => b['date'].compareTo(a['date']));
  //     return payments;
  //   } catch (e) {
  //     throw Exception('Failed to fetch payments: $e');
  //   }
  // }

  Future<List<Map<String, dynamic>>> getFilledPayments(String filledId) async {
    try {
      List<Map<String, dynamic>> payments = [];
      final filledRef = _db.child('filled').child(filledId);

      Future<void> fetchPayments(String method) async {
        DataSnapshot snapshot = await filledRef.child('${method}Payments').get();
        if (!snapshot.exists) return;

        final methodPayments = Map<dynamic, dynamic>.from(snapshot.value as Map);
        for (var entry in methodPayments.entries) {
          final paymentKey = entry.key;
          final paymentData = Map<String, dynamic>.from(entry.value);

          // Special handling for cheque: fetch latest status from bank
          if (method == 'cheque') {
            final bankId = paymentData['bankId'];
            if (bankId != null) {
              final chequeSnapshot = await _db
                  .child('banks/$bankId/cheques/$paymentKey')
                  .get();
              if (chequeSnapshot.exists) {
                final chequeData = Map<String, dynamic>.from(chequeSnapshot.value as Map);
                paymentData['status'] = chequeData['status'] ?? 'pending';
              }
            }

            // Skip if cheque is pending or bounced
            if (paymentData['status'] == 'pending' || paymentData['status'] == 'bounced') {
              continue;
            }
          }

          paymentData['amount'] = (paymentData['amount'] as num).toDouble();

          payments.add({
            'method': method,
            'key': paymentKey,
            ...paymentData,
            'date': DateTime.parse(paymentData['date']),
          });
        }
      }

      await fetchPayments('cash');
      await fetchPayments('online');
      await fetchPayments('bank');
      await fetchPayments('slip');
      await fetchPayments('cheque'); // Cheque is called last because of async nested call

      payments.sort((a, b) => b['date'].compareTo(a['date']));
      return payments;
    } catch (e) {
      throw Exception('Failed to fetch payments: $e');
    }
  }




  Future<void> deletePaymentEntry({
    required BuildContext context,
    required String filledId,
    required String paymentKey,
    required String paymentMethod,
    required double paymentAmount,
  })
  async {
    try {
      final filledRef = _db.child('filled').child(filledId);
      print("📌 Fetching payment data for method: $paymentMethod and key: $paymentKey");

      // Step 1: Fetch payment data before deleting it
      final paymentSnapshot = await filledRef.child('${paymentMethod}Payments').child(paymentKey).get();

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
      // Inside deletePaymentEntry
      if (paymentMethod.toLowerCase() == 'cheque') {
        final chequeTransactionId = paymentData['chequeTransactionId'];
        final bankId = paymentData['bankId'];

        if (bankId != null && chequeTransactionId != null) {
          await _db.child('banks/$bankId/cheques/$chequeTransactionId').remove();
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
          final transactionSnapshot = await bankTransactionsRef.orderByChild('filledId').equalTo(filledId).get();

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

      // Step 3: Remove the payment entry from the filled
      print("🗑️ Removing payment entry from: ${paymentMethod}Payments with key: $paymentKey");
      await filledRef.child('${paymentMethod}Payments').child(paymentKey).remove();

      // Step 4: Fetch the filled data
      final filledSnapshot = await filledRef.get();
      if (!filledSnapshot.exists) {
        throw Exception("Filled not found.");
      }

      final filled = Map<String, dynamic>.from(filledSnapshot.value as Map);
      final customerId = filled['customerId']?.toString() ?? '';
      final filledNumber = filled['filledNumber']?.toString() ?? '';

      print("📄 Filled details retrieved: customerId = $customerId, filledNumber = $filledNumber");

      // Step 5: Get current payment amounts
      double currentCashPaid = _parseToDouble(filled['cashPaidAmount']);
      double currentOnlinePaid = _parseToDouble(filled['onlinePaidAmount']);
      double currentChequePaid = _parseToDouble(filled['chequePaidAmount'] ?? 0.0);
      double currentSlipPaid = _parseToDouble(filled['slipPaidAmount'] ?? 0.0);
      double currentBankPaid = _parseToDouble(filled['bankPaidAmount'] ?? 0.0);
      double currentDebit = _parseToDouble(filled['debitAmount']);

      print("💰 Current Payment Amounts -> Cash: $currentCashPaid, Online: $currentOnlinePaid, Cheque: $currentChequePaid, Bank: $currentBankPaid, Slip: $currentSlipPaid, Debit: $currentDebit");

      // Deduct the payment amount from the respective payment method
      switch (paymentMethod.toLowerCase()) {
        case 'cash':
          currentCashPaid = (currentCashPaid - paymentAmount).clamp(0.0, double.infinity);
          break;
        case 'online':
          currentOnlinePaid = (currentOnlinePaid - paymentAmount).clamp(0.0, double.infinity);
          break;
        case 'cheque':
          currentChequePaid = (currentChequePaid - paymentAmount).clamp(0.0, double.infinity);
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
      print("🔄 Updating filled with new values...");

      await filledRef.update({
        'cashPaidAmount': currentCashPaid,
        'onlinePaidAmount': currentOnlinePaid,
        'chequePaidAmount': currentChequePaid,
        'bankPaidAmount': currentBankPaid,
        'slipPaidAmount': currentSlipPaid,
        'debitAmount': updatedDebit,
      });

      print("✅ Filled updated successfully.");

      // Step 6: Fetch latest ledger entry for the customer
      final customerLedgerRef = _db.child('filledledger').child(customerId);
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
      final paymentLedgerSnapshot = await customerLedgerRef.orderByChild('filledNumber').equalTo(filledNumber).get();

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

      print("🔄 Refreshing filled list...");
      await fetchFilled();
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
    required String filledId,
    required String paymentKey,
    required String paymentMethod,
    required double oldPaymentAmount,
    required double newPaymentAmount,
    required String newDescription,
    required Uint8List? newImageBytes,
    String? newBankId,
    String? newBankName,
    String? newChequeNumber,
    DateTime? newChequeDate,
    String? newChequeBankId,
    String? newChequeBankName,
  }) async {
    try {
      final filledRef = _db.child('filled').child(filledId);

      // Step 1: Update the payment entry in the filled
      final updatedPaymentData = {
        'amount': newPaymentAmount,
        'date': DateTime.now().toIso8601String(),
        'method': paymentMethod,
        'description': newDescription,
      };

      // Add bank info if this is a bank payment
      if (paymentMethod == 'Bank' && newBankId != null && newBankName != null) {
        updatedPaymentData['bankId'] = newBankId;
        updatedPaymentData['bankName'] = newBankName;
      }

      // Add cheque info if this is a cheque payment
      if (paymentMethod == 'Cheque') {
        if (newChequeNumber != null) {
          updatedPaymentData['chequeNumber'] = newChequeNumber;
        }
        if (newChequeDate != null) {
          updatedPaymentData['chequeDate'] = newChequeDate.toIso8601String();
        }
        if (newChequeBankId != null) {
          updatedPaymentData['bankId'] = newChequeBankId;
        }
        if (newChequeBankName != null) {
          updatedPaymentData['bankName'] = newChequeBankName;
        }
      }

      if (newImageBytes != null) {
        updatedPaymentData['image'] = base64Encode(newImageBytes);
      }

      await filledRef.child('${paymentMethod}Payments').child(paymentKey).update(updatedPaymentData);

      // Step 2: Update the debitAmount in the filled
      final filledSnapshot = await filledRef.get();
      if (filledSnapshot.exists) {
        final filled = Map<String, dynamic>.from(filledSnapshot.value as Map);
        final currentDebit = _parseToDouble(filled['debitAmount']);
        final updatedDebit = currentDebit - oldPaymentAmount + newPaymentAmount;

        await filledRef.update({
          'debitAmount': updatedDebit,
        });

        // Step 3: Find and update the corresponding ledger entry
        final customerId = filled['customerId'];
        final filledNumber = filled['filledNumber'];
        final referenceNumber = filled['referenceNumber'];
        final grandTotal = _parseToDouble(filled['grandTotal']);

        final customerLedgerRef = _db.child('filledledger').child(customerId);
        final ledgerQuery = await customerLedgerRef
            .orderByChild('filledNumber')
            .equalTo(filledNumber)
            .get();

        if (ledgerQuery.exists) {
          final ledgerData = ledgerQuery.value as Map<dynamic, dynamic>;
          for (var entryKey in ledgerData.keys) {
            final entry = Map<String, dynamic>.from(ledgerData[entryKey]);
            // Find the entry that matches this payment amount (or other identifying info)
            if ((entry['debitAmount'] as num).toDouble() == oldPaymentAmount) {
              // Update the ledger entry
              await customerLedgerRef.child(entryKey).update({
                'debitAmount': newPaymentAmount,
                'remainingBalance': grandTotal - updatedDebit,
                'paymentMethod': paymentMethod,
                if (paymentMethod == 'Bank') ...{
                  'bankId': newBankId,
                  'bankName': newBankName,
                },
                if (paymentMethod == 'Cheque') ...{
                  'chequeNumber': newChequeNumber,
                  'chequeDate': newChequeDate?.toIso8601String(),
                  'bankId': newChequeBankId,
                  'bankName': newChequeBankName,
                },
              });
              break;
            }
          }
        }

        // Step 4: Update subsequent ledger entries if needed
        await _updateSubsequentLedgerEntries(
          customerId: customerId,
          filledNumber: filledNumber,
          amountDifference: newPaymentAmount - oldPaymentAmount,
        );
      }

      // Refresh the filled list
      await fetchFilled();
    } catch (e) {
      throw Exception('Failed to edit payment entry: $e');
    }
  }

  Future<void> _updateSubsequentLedgerEntries({
    required String customerId,
    required String filledNumber,
    required double amountDifference,
  }) async {
    try {
      final customerLedgerRef = _db.child('filledledger').child(customerId);
      final snapshot = await customerLedgerRef.orderByChild('createdAt').get();

      if (snapshot.exists) {
        final entries = Map<dynamic, dynamic>.from(snapshot.value as Map);
        bool foundTarget = false;
        final sortedKeys = entries.keys.toList()
          ..sort((a, b) => (entries[a]['createdAt'] as String)
              .compareTo(entries[b]['createdAt'] as String));

        for (var key in sortedKeys) {
          final entry = Map<String, dynamic>.from(entries[key]);

          if (entry['filledNumber'] == filledNumber) {
            foundTarget = true;
            continue;
          }

          if (foundTarget) {
            final currentBalance = (entry['remainingBalance'] as num).toDouble();
            await customerLedgerRef.child(key).update({
              'remainingBalance': currentBalance + amountDifference,
            });
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to update subsequent ledger entries: $e');
    }
  }

  List<Map<String, dynamic>> getTodaysFilled() {
    final today = DateTime.now();
    // final startOfDay = DateTime(today.year, today.month, today.day - 1); // Include yesterday
    final startOfDay = DateTime(today.year, today.month, today.day ); // Include yesterdays

    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    return _filled.where((filled) {
      final filledDate = DateTime.tryParse(filled['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(int.parse(filled['createdAt']));
      return filledDate.isAfter(startOfDay) && filledDate.isBefore(endOfDay);
    }).toList();
  }

  double getTotalAmountfilled(List<Map<String, dynamic>> filled) {
    return filled.fold(0.0, (sum, filled) => sum + (filled['grandTotal'] ?? 0.0));
  }

  double getTotalPaidAmountfilled(List<Map<String, dynamic>> filled) {
    return filled.fold(0.0, (sum, filled) => sum + (filled['debitAmount'] ?? 0.0));
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
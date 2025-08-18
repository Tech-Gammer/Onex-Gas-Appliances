import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;

class FilledCustomerReportProvider with ChangeNotifier {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  bool isLoading = false;
  String error = '';
  Map<String, dynamic> report = {};
  double openingBalance = 0.0;
  Set<String> expandedTransactions = {};
  Map<String, List<Map<String, dynamic>>> invoiceItems = {};
  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  DateTimeRange? _dateRangeFilter;
  DateTimeRange? get dateRangeFilter => _dateRangeFilter;
  bool get isFiltered => _dateRangeFilter != null;
  // Fixed getter to return proper transactions list
  List<Map<String, dynamic>> get transactions =>
      _dateRangeFilter == null ? _allTransactions : _filteredTransactions;

  void setDateRangeFilter(DateTimeRange? range) {
    _dateRangeFilter = range;
    if (range != null) {
      _applyDateFilter(range);
    } else {
      // When clearing filter, use all transactions
      _filteredTransactions.clear();
      _calculateReport(_allTransactions);
    }
    notifyListeners();
  }

  // Replace your _applyDateFilter method in FilledCustomerReportProvider with this:

  void _applyDateFilter(DateTimeRange range) {
    print('Applying date filter from ${range.start} to ${range.end}');

    // Filter transactions by date range
    _filteredTransactions = _allTransactions.where((transaction) {
      // Use the 'date' field which should contain the createdAt value
      final dateValue = transaction['date'] ?? transaction['createdAt'];
      final date = _parseFirebaseDate(dateValue);

      if (date == null) {
        print('Skipping transaction with invalid date: $dateValue');
        return false;
      }

      // Convert date to start of day for proper comparison
      final transactionDate = DateTime(date.year, date.month, date.day);
      final rangeStart = DateTime(range.start.year, range.start.month, range.start.day);
      final rangeEnd = DateTime(range.end.year, range.end.month, range.end.day);

      // FIXED: Use proper date range comparison
      final isInRange = (transactionDate.isAtSameMomentAs(rangeStart) ||
          transactionDate.isAtSameMomentAs(rangeEnd) ||
          (transactionDate.isAfter(rangeStart) && transactionDate.isBefore(rangeEnd)));

      print('Transaction ${transaction['referenceNumber']} on $transactionDate - in range: $isInRange');
      return isInRange;
    }).toList();

    print('Found ${_filteredTransactions.length} matching transactions out of ${_allTransactions.length} total');

    // Sort filtered transactions by date
    _filteredTransactions.sort((a, b) {
      final dateA = _parseFirebaseDate(a['date'] ?? a['createdAt']) ?? DateTime(2000);
      final dateB = _parseFirebaseDate(b['date'] ?? b['createdAt']) ?? DateTime(2000);
      return dateA.compareTo(dateB);
    });

    // Recalculate balances for filtered transactions
    _recalculateBalancesForFiltered();

    // Update report with filtered data
    _calculateReport(_filteredTransactions);
  }

// Also, update your _parseFirebaseDate method to handle more date formats:
  DateTime? _parseFirebaseDate(dynamic dateValue) {
    if (dateValue == null) return null;

    try {
      if (dateValue is String) {
        // Remove any extra whitespace
        String cleanDate = dateValue.trim();

        // Handle different string formats
        if (cleanDate.contains('T')) {
          // ISO format: 2024-01-15T10:30:00.000Z or 2024-01-15T10:30:00
          return DateTime.parse(cleanDate);
        } else if (cleanDate.contains('-')) {
          // Date format: 2024-01-15 or 2024-01-15 10:30:00
          if (cleanDate.contains(' ')) {
            // Has time component
            return DateTime.parse(cleanDate);
          } else {
            // Date only, add time to make it parseable
            return DateTime.parse('$cleanDate 00:00:00');
          }
        } else if (cleanDate.contains('/')) {
          // Handle dd/MM/yyyy or MM/dd/yyyy format
          final parts = cleanDate.split('/');
          if (parts.length == 3) {
            try {
              // Try dd/MM/yyyy format first (more common in many regions)
              return DateTime(
                int.parse(parts[2]), // year
                int.parse(parts[1]), // month
                int.parse(parts[0]), // day
              );
            } catch (e) {
              try {
                // Try MM/dd/yyyy format
                return DateTime(
                  int.parse(parts[2]), // year
                  int.parse(parts[0]), // month
                  int.parse(parts[1]), // day
                );
              } catch (e) {
                print('Could not parse date with / format: $cleanDate');
              }
            }
          }
        }

        // Try to parse as timestamp string
        final timestamp = int.tryParse(cleanDate);
        if (timestamp != null) {
          // Check if it's in milliseconds or seconds
          if (timestamp > 1000000000000) {
            return DateTime.fromMillisecondsSinceEpoch(timestamp);
          } else {
            return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
          }
        }

      } else if (dateValue is int) {
        // Timestamp - check if it's in milliseconds or seconds
        if (dateValue > 1000000000000) {
          return DateTime.fromMillisecondsSinceEpoch(dateValue);
        } else {
          return DateTime.fromMillisecondsSinceEpoch(dateValue * 1000);
        }
      } else if (dateValue is double) {
        // Handle double timestamp
        final timestamp = dateValue.toInt();
        if (timestamp > 1000000000000) {
          return DateTime.fromMillisecondsSinceEpoch(timestamp);
        } else {
          return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
        }
      } else if (dateValue is Map && dateValue.containsKey('_seconds')) {
        // Firestore Timestamp format
        final seconds = dateValue['_seconds'] as int;
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    } catch (e) {
      print('Error parsing date "$dateValue": $e');
    }

    print('Could not parse date: $dateValue (type: ${dateValue.runtimeType})');
    return null;
  }

  void _recalculateBalancesForFiltered() {
    if (_filteredTransactions.isEmpty) return;

    // Find the balance before the first filtered transaction
    double startingBalance = openingBalance;

    if (_filteredTransactions.isNotEmpty) {
      final firstFilteredDate = _parseFirebaseDate(_filteredTransactions.first['date'] ?? _filteredTransactions.first['createdAt']);

      if (firstFilteredDate != null) {
        // Calculate balance up to the first filtered transaction
        for (var transaction in _allTransactions) {
          final transactionDate = _parseFirebaseDate(transaction['date'] ?? transaction['createdAt']);
          if (transactionDate != null && transactionDate.isBefore(firstFilteredDate)) {
            final debit = (transaction['debit'] ?? 0.0).toDouble();
            final credit = (transaction['credit'] ?? 0.0).toDouble();
            startingBalance = startingBalance + credit - debit;
          }
        }
      }
    }

    // Recalculate running balance for filtered transactions
    double runningBalance = startingBalance;
    for (int i = 0; i < _filteredTransactions.length; i++) {
      final debit = (_filteredTransactions[i]['debit'] ?? 0.0).toDouble();
      final credit = (_filteredTransactions[i]['credit'] ?? 0.0).toDouble();
      runningBalance = runningBalance + credit - debit;
      _filteredTransactions[i]['balance'] = runningBalance;
    }
  }

  void _calculateReport(List<Map<String, dynamic>> transactionsList) {
    double totalDebit = 0.0;
    double totalCredit = openingBalance; // Include opening balance
    double finalBalance = openingBalance;

    for (var transaction in transactionsList) {
      final debit = (transaction['debit'] ?? 0.0).toDouble();
      final credit = (transaction['credit'] ?? 0.0).toDouble();

      totalDebit += debit;
      totalCredit += credit;
    }

    // Calculate final balance
    if (transactionsList.isNotEmpty) {
      finalBalance = transactionsList.last['balance'] ?? openingBalance;
    }

    report = {
      'debit': totalDebit,
      'credit': totalCredit - openingBalance, // Subtract opening balance for display
      'balance': finalBalance,
      'openingBalance': openingBalance,
    };
  }

  void toggleTransactionExpansion(String transactionKey) {
    if (expandedTransactions.contains(transactionKey)) {
      expandedTransactions.remove(transactionKey);
    } else {
      expandedTransactions.add(transactionKey);
      // Load invoice items if not already loaded
      if (!invoiceItems.containsKey(transactionKey)) {
        loadInvoiceItems(transactionKey);
      }
    }
    notifyListeners();
  }

  Future<void> loadInvoiceItems(String transactionKey) async {
    try {
      print('Loading invoice items for transaction: $transactionKey');

      // First, get the transaction data to find the filledId
      final ledgerSnapshot = await _db.child('filledledger').get();

      String? filledId;
      Map<String, dynamic>? transactionData;

      if (ledgerSnapshot.exists) {
        final ledgerData = Map<String, dynamic>.from(ledgerSnapshot.value as Map);

        // Search through all customers for the transaction
        for (var customerEntry in ledgerData.entries) {
          if (customerEntry.value is Map) {
            final customerTransactions = Map<String, dynamic>.from(customerEntry.value as Map);

            if (customerTransactions.containsKey(transactionKey)) {
              transactionData = Map<String, dynamic>.from(customerTransactions[transactionKey] as Map);

              // Try to get filledId from various possible fields
              filledId = transactionData['filledId']?.toString() ??
                  transactionData['referenceNumber']?.toString() ??
                  transactionData['filledNumber']?.toString();

              print('Found transaction, filledId: $filledId');
              print('Transaction data: $transactionData');
              break;
            }
          }
        }
      }

      List<Map<String, dynamic>> items = [];

      if (filledId != null) {
        // Try to load items from the filled node using the filledId
        print('Trying to load items from filled/$filledId/items');
        var itemsSnapshot = await _db.child('filled/$filledId/items').get();

        if (itemsSnapshot.exists) {
          items = await _processItemsData(itemsSnapshot.value);
          print('Found ${items.length} items using filledId');
        } else {
          // Check if the filled record exists at all
          final filledSnapshot = await _db.child('filled/$filledId').get();
          if (filledSnapshot.exists) {
            final filledData = Map<String, dynamic>.from(filledSnapshot.value as Map);
            print('Found filled record, keys: ${filledData.keys.toList()}');

            if (filledData.containsKey('items')) {
              items = await _processItemsData(filledData['items']);
              print('Found ${items.length} items in filled record');
            }
          } else {
            print('No filled record found for filledId: $filledId');
            // Search through all filled records to find a match
            items = await _searchAllFilledRecords(transactionData);
          }
        }
      } else {
        print('No filledId found, searching all filled records...');
        items = await _searchAllFilledRecords(transactionData);
      }

      invoiceItems[transactionKey] = items;
      print('Final result: ${items.length} items loaded for transaction $transactionKey');
      notifyListeners();

    } catch (e) {
      print('Error loading invoice items: $e');
      invoiceItems[transactionKey] = [];
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> _searchAllFilledRecords(Map<String, dynamic>? transactionData) async {
    try {
      print('Searching all filled records...');
      final allFilledSnapshot = await _db.child('filled').get();

      if (!allFilledSnapshot.exists) {
        print('No filled records found');
        return [];
      }

      // Handle both Map and List data structures
      dynamic allFilledData = allFilledSnapshot.value;
      Map<String, dynamic> allFilled = {};

      if (allFilledData is Map) {
        allFilled = Map<String, dynamic>.from(allFilledData);
      } else if (allFilledData is List) {
        // Convert list to map with index-based keys if needed
        allFilled = {for (var i = 0; i < allFilledData.length; i++) i.toString(): allFilledData[i]};
      } else {
        print('Unexpected data type: ${allFilledData.runtimeType}');
        return [];
      }

      print('Found ${allFilled.keys.length} filled records: ${allFilled.keys.toList()}');

      if (transactionData != null) {
        final transactionDate = transactionData['createdAt']?.toString();
        final customerName = transactionData['customerName']?.toString();
        final grandTotal = transactionData['creditAmount']?.toString() ??
            transactionData['grandTotal']?.toString();

        print('Looking for match with date: $transactionDate, customer: $customerName, total: $grandTotal');

        // Search through all filled records for a match
        for (var filledEntry in allFilled.entries) {
          try {
            // Ensure the value is a Map
            dynamic filledValue = filledEntry.value;
            Map<String, dynamic> filledData = {};

            if (filledValue is Map) {
              filledData = Map<String, dynamic>.from(filledValue);
            } else {
              print('Skipping non-map entry: ${filledEntry.key}');
              continue;
            }

            final filledDate = filledData['createdAt']?.toString();
            final filledCustomer = filledData['customerName']?.toString();
            final filledTotal = filledData['grandTotal']?.toString();

            print('Checking filled/${filledEntry.key}: date=$filledDate, customer=$filledCustomer, total=$filledTotal');

            // Try to match by multiple criteria
            bool dateMatch = transactionDate != null && filledDate != null &&
                transactionDate.substring(0, 10) == filledDate.substring(0, 10);
            bool customerMatch = customerName != null && filledCustomer != null &&
                customerName.toLowerCase() == filledCustomer.toLowerCase();
            bool totalMatch = grandTotal != null && filledTotal != null && grandTotal == filledTotal;

            if ((dateMatch && customerMatch) || (dateMatch && totalMatch) || (customerMatch && totalMatch)) {
              print('Found potential match at filled/${filledEntry.key}');

              if (filledData.containsKey('items')) {
                final items = await _processItemsData(filledData['items']);
                print('Found ${items.length} items in matched record');
                return items;
              }
            }
          } catch (e) {
            print('Error processing filled entry ${filledEntry.key}: $e');
            continue;
          }
        }
      }

      print('No matching filled record found');
      return [];

    } catch (e) {
      print('Error searching filled records: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _processItemsData(dynamic itemsData) async {
    List<Map<String, dynamic>> items = [];

    print('Processing items data type: ${itemsData.runtimeType}');

    try {
      if (itemsData == null) {
        return items;
      }

      if (itemsData is Map) {
        // Handle map structure (Firebase realtime database)
        items = (itemsData as Map<dynamic, dynamic>).entries.map((entry) {
          try {
            dynamic entryValue = entry.value;
            Map<String, dynamic> itemData = {};

            if (entryValue is Map) {
              itemData = Map<String, dynamic>.from(entryValue);
            } else {
              print('Skipping non-map item entry');
              return {
                'itemName': 'Unknown Item',
                'quantity': 0.0,
                'price': 0.0,
                'total': 0.0,
              };
            }

            return {
              'itemName': itemData['itemName']?.toString() ??
                  itemData['description']?.toString() ?? 'Unknown Item',
              'quantity': _parseDouble(itemData['qty'] ?? itemData['quantity'] ?? 0),
              'price': _parseDouble(itemData['rate'] ?? itemData['price'] ?? 0),
              'total': _parseDouble(itemData['total'] ?? 0),
            };
          } catch (e) {
            print('Error processing item entry: $e');
            return {
              'itemName': 'Unknown Item',
              'quantity': 0.0,
              'price': 0.0,
              'total': 0.0,
            };
          }
        }).toList();
      } else if (itemsData is List) {
        // Handle array structure
        items = (itemsData as List<dynamic>).map((item) {
          try {
            Map<String, dynamic> itemMap = {};

            if (item is Map) {
              itemMap = Map<String, dynamic>.from(item);
            } else {
              print('Skipping non-map item in list');
              return {
                'itemName': 'Unknown Item',
                'quantity': 0.0,
                'price': 0.0,
                'total': 0.0,
              };
            }

            return {
              'itemName': itemMap['itemName']?.toString() ??
                  itemMap['description']?.toString() ?? 'Unknown Item',
              'quantity': _parseDouble(itemMap['qty'] ?? itemMap['quantity'] ?? 0),
              'price': _parseDouble(itemMap['rate'] ?? itemMap['price'] ?? 0),
              'total': _parseDouble(itemMap['total'] ?? 0),
            };
          } catch (e) {
            print('Error processing list item: $e');
            return {
              'itemName': 'Unknown Item',
              'quantity': 0.0,
              'price': 0.0,
              'total': 0.0,
            };
          }
        }).toList();
      } else {
        print('Unsupported items data type: ${itemsData.runtimeType}');
      }
    } catch (e) {
      print('Error in _processItemsData: $e');
    }

    return items;
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  Future<void> fetchCustomerReport(String customerId) async {
    try {
      isLoading = true;
      error = '';
      notifyListeners();

      report = {};
      _allTransactions = [];
      _filteredTransactions = [];
      expandedTransactions.clear();
      invoiceItems.clear();

      // Fetch opening balance first
      await fetchOpeningBalance(customerId);

      final snapshot = await _db.child('filledledger/$customerId').once();

      if (snapshot.snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.snapshot.value as Map);

        List<Map<String, dynamic>> tempTransactions = [];

        for (var entry in data.entries) {
          final transaction = Map<String, dynamic>.from(entry.value);

          final paymentMethod = transaction['paymentMethod']?.toString().toLowerCase();
          final status = transaction['status']?.toString().toLowerCase();

          // Skip uncleared cheques
          if (paymentMethod == 'cheque' && status != 'cleared') continue;

          final debit = (transaction['debitAmount'] ?? 0.0).toDouble();
          final credit = (transaction['creditAmount'] ?? 0.0).toDouble();

          // Store the original createdAt value and also create a standardized date field
          final originalDate = transaction['createdAt'];
          final parsedDate = _parseFirebaseDate(originalDate);
          final dateString = parsedDate != null ? parsedDate.toIso8601String() : originalDate?.toString() ?? '';

          tempTransactions.add({
            'id': entry.key,
            'key': entry.key,
            'date': dateString, // Standardized date format
            'originalDate': originalDate, // Keep original for debugging
            'details': transaction['details'] ?? '',
            'filledNumber': transaction['filledNumber'] ?? '',
            'referenceNumber': transaction['referenceNumber'] ?? '',
            'filledId': transaction['filledId'] ?? transaction['referenceNumber'] ?? '',
            'bankName': transaction['bankName'] ?? '',
            'paymentMethod': paymentMethod ?? '',
            'debit': debit,
            'credit': credit,
            'balance': 0.0,
          });
        }

        // Sort transactions by date (ascending)
        tempTransactions.sort((a, b) {
          final dateA = _parseFirebaseDate(a['date']) ?? DateTime(2000);
          final dateB = _parseFirebaseDate(b['date']) ?? DateTime(2000);
          return dateA.compareTo(dateB);
        });

        // Calculate running balance after sorting
        double runningBalance = openingBalance;
        for (int i = 0; i < tempTransactions.length; i++) {
          final debit = tempTransactions[i]['debit'] as double;
          final credit = tempTransactions[i]['credit'] as double;
          runningBalance = runningBalance + credit - debit;
          tempTransactions[i]['balance'] = runningBalance;
        }

        _allTransactions = tempTransactions;

        // Apply current date filter if exists
        if (_dateRangeFilter != null) {
          _applyDateFilter(_dateRangeFilter!);
        } else {
          _calculateReport(_allTransactions);
        }
      } else {
        report = {
          'debit': 0.0,
          'credit': 0.0,
          'balance': openingBalance,
          'openingBalance': openingBalance,
        };
      }
    } catch (e) {
      error = 'Failed to fetch customer report: $e';
      report = {
        'debit': 0.0,
        'credit': 0.0,
        'balance': openingBalance,
        'openingBalance': openingBalance,
      };
      _allTransactions = [];
      _filteredTransactions = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchOpeningBalance(String customerId) async {
    try {
      final snapshot = await _db.child('customers/$customerId/openingBalance').once();
      if (snapshot.snapshot.exists && snapshot.snapshot.value != null) {
        openingBalance = (snapshot.snapshot.value as num).toDouble();
      } else {
        openingBalance = 0.0;
      }
    } catch (e) {
      print('Error fetching opening balance: $e');
      openingBalance = 0.0;
    }
  }
}
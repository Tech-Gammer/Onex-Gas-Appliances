import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:onex_gas_appliances/Customer/paymenthistorypage.dart';
import 'package:provider/provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../Provider/customerprovider.dart';
import '../Provider/filled provider.dart';
import '../Provider/lanprovider.dart';
import '../bankmanagement/banknames.dart';
import 'addcustomers.dart';
import 'customerratelistpage.dart';

class CustomerList extends StatefulWidget {
  @override
  _CustomerListState createState() => _CustomerListState();
}

class _CustomerListState extends State<CustomerList> {
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  Map<String, double> _customerBalances = {};
  Map<String, Map<String, dynamic>> _ledgerCache = {}; // Cache for ledger data
  TextEditingController _paymentAmountController = TextEditingController();
  String? _selectedPaymentMethod;
  String? _paymentDescription;
  DateTime _selectedPaymentDate = DateTime.now();
  String? _selectedBankId;
  String? _selectedBankName;
  TextEditingController _chequeNumberController = TextEditingController();
  DateTime? _selectedChequeDate;
  Uint8List? _paymentImage;
  List<Map<String, dynamic>> _cachedBanks = [];
  ScrollController _scrollController = ScrollController(); // Add this

  @override
  void initState() {
    super.initState();
    _loadCustomerBalances();
  }

  Future<void> _loadCustomerBalances() async {
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    final customers = customerProvider.customers;

    List<Future<void>> fetchFutures = customers.map((customer) async {
      final filledBalance = await _getRemainingFillesBalance(customer.id);
      _customerBalances[customer.id] = filledBalance;
    }).toList();

    await Future.wait(fetchFutures);
    setState(() {}); // Update UI
  }

  Future<void> _generateAndPrintCustomerBalances(List<Customer> customers) async {
    final pdf = pw.Document();
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) => [
          pw.Center(
            child: pw.Text(
              languageProvider.isEnglish
                  ? 'Customer Balance List'
                  : 'کسٹمر بیلنس کی فہرست',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: [
              '#',
              languageProvider.isEnglish ? 'Name' : 'نام',
              languageProvider.isEnglish ? 'Phone' : 'فون',
              languageProvider.isEnglish ? 'Address' : 'پتہ',
              languageProvider.isEnglish ? 'City' : 'شہر',
              languageProvider.isEnglish ? 'Balance (Rs)' : 'بیلنس (روپے)',
            ],
            data: customers.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final customer = entry.value;
              final balance = _customerBalances[customer.id]?.toStringAsFixed(2) ?? '0.00';
              return [
                index.toString(),
                customer.name,
                customer.phone,
                customer.address,
                customer.city,
                balance,
              ];
            }).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) => pdf.save(),
    );
  }

  Future<double> _getRemainingFillesBalance(String customerId) async {
    try {
      final customerLedgerRef = _db.child('filledledger').child(customerId);
      final DatabaseEvent snapshot = await customerLedgerRef.orderByChild('createdAt').once();

      double remainingBalance = 0.0;

      if (snapshot.snapshot.exists) {
        final Map<dynamic, dynamic> ledgerEntries = snapshot.snapshot.value as Map<dynamic, dynamic>;

        // Process all ledger entries to calculate the balance
        ledgerEntries.forEach((key, value) {
          if (value != null && value is Map) {
            final debitAmount = (value['debitAmount'] ?? 0.0).toDouble();
            final creditAmount = (value['creditAmount'] ?? 0.0).toDouble();

            // For opening balance (credit), add to balance
            // For payments (debit), subtract from balance
            remainingBalance = remainingBalance + creditAmount - debitAmount;
          }
        });
      }

      // Update the cache
      if (_ledgerCache.containsKey(customerId)) {
        _ledgerCache[customerId]!['filledBalance'] = remainingBalance;
      } else {
        _ledgerCache[customerId] = {'filledBalance': remainingBalance};
      }

      return remainingBalance;
    } catch (e) {
      print("Error calculating balance: $e");
      return 0.0;
    }
  }

  Future<void> _fetchCustomersAndLoadBalances(CustomerProvider customerProvider) async {
    await customerProvider.fetchCustomers();
    await _loadCustomerBalances();
  }

  Future<Map<String, dynamic>?> _selectBank(BuildContext context) async {
    if (_cachedBanks.isEmpty) {
      final bankSnapshot = await FirebaseDatabase.instance.ref('banks').once();
      if (bankSnapshot.snapshot.value == null) return null;

      final banks = bankSnapshot.snapshot.value as Map<dynamic, dynamic>;
      _cachedBanks = banks.entries.map((e) => {
        'id': e.key,
        'name': e.value['name'],
        'balance': e.value['balance']
      }).toList();
    }

    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    Map<String, dynamic>? selectedBank;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.isEnglish ? 'Select Bank' : 'بینک منتخب کریں'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _cachedBanks.length,
            itemBuilder: (context, index) {
              final bankData = _cachedBanks[index];
              final bankName = bankData['name'];

              // Find matching bank from pakistaniBanks list
              Bank? matchedBank = pakistaniBanks.firstWhere(
                    (b) => b.name.toLowerCase() == bankName.toLowerCase(),
                orElse: () => Bank(
                    name: bankName,
                    iconPath: 'assets/default_bank.png'
                ),
              );

              return Card(
                margin: EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Image.asset(
                    matchedBank.iconPath,
                    width: 40,
                    height: 40,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.account_balance, size: 40);
                    },
                  ),
                  title: Text(
                    bankName,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  // subtitle: Text(
                  //   '${languageProvider.isEnglish ? "Balance" : "بیلنس"}: ${bankData['balance']} Rs',
                  // ),
                  onTap: () {
                    selectedBank = {
                      'id': bankData['id'],
                      'name': bankName,
                      'balance': bankData['balance']
                    };
                    Navigator.pop(context);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
          ),
        ],
      ),
    );

    return selectedBank;
  }

  Future<Uint8List?> _pickImage(BuildContext context) async {
    Uint8List? imageBytes;
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    if (kIsWeb) {
      // For web, use file_picker
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        imageBytes = result.files.first.bytes;
      }
    } else {
      // For mobile, show source selection dialog
      final ImagePicker _picker = ImagePicker();

      // Show dialog to choose camera or gallery
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(languageProvider.isEnglish ? 'Select Source' : 'ذریعہ منتخب کریں'),
          actions: [
            TextButton(
              child: Text(languageProvider.isEnglish ? 'Camera' : 'کیمرہ'),
              onPressed: () => Navigator.pop(context, ImageSource.camera),
            ),
            TextButton(
              child: Text(languageProvider.isEnglish ? 'Gallery' : 'گیلری'),
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      );

      if (source == null) return null; // User canceled

      XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        imageBytes = await file.readAsBytes();
      }
    }

    return imageBytes;
  }

  Future<void> _showPaymentDialog(BuildContext context, Customer customer) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final filledProvider = Provider.of<FilledProvider>(context, listen: false);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(languageProvider.isEnglish ? 'Make Payment' : 'ادائیگی کریں'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Payment date selection
                    ListTile(
                      title: Text(
                        languageProvider.isEnglish
                            ? 'Payment Date: ${DateFormat('yyyy-MM-dd – HH:mm').format(_selectedPaymentDate)}'
                            : 'ادائیگی کی تاریخ: ${DateFormat('yyyy-MM-dd – HH:mm').format(_selectedPaymentDate)}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _selectedPaymentDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (pickedDate != null) {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_selectedPaymentDate),
                          );
                          if (pickedTime != null) {
                            setState(() {
                              _selectedPaymentDate = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          }
                        }
                      },
                    ),

                    // Payment method dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedPaymentMethod,
                      items: [
                        DropdownMenuItem(
                          value: 'Cash',
                          child: Text(languageProvider.isEnglish ? 'Cash' : 'نقدی'),
                        ),
                        DropdownMenuItem(
                          value: 'Online',
                          child: Text(languageProvider.isEnglish ? 'Online' : 'آن لائن'),
                        ),
                        DropdownMenuItem(
                          value: 'Cheque',
                          child: Text(languageProvider.isEnglish ? 'Cheque' : 'چیک'),
                        ),
                        DropdownMenuItem(
                          value: 'Bank',
                          child: Text(languageProvider.isEnglish ? 'Bank' : 'بینک'),
                        ),
                        DropdownMenuItem(
                          value: 'Slip',
                          child: Text(languageProvider.isEnglish ? 'Slip' : 'پرچی'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedPaymentMethod = value;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish ? 'Select Payment Method' : 'ادائیگی کا طریقہ منتخب کریں',
                        border: const OutlineInputBorder(),
                      ),
                    ),

                    // Cheque payment fields
                    if (_selectedPaymentMethod == 'Cheque') ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _chequeNumberController,
                        decoration: InputDecoration(
                          labelText: languageProvider.isEnglish ? 'Cheque Number' : 'چیک نمبر',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        title: Text(
                          _selectedChequeDate == null
                              ? (languageProvider.isEnglish
                              ? 'Select Cheque Date'
                              : 'چیک کی تاریخ منتخب کریں')
                              : DateFormat('yyyy-MM-dd').format(_selectedChequeDate!),
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate != null) {
                            setState(() => _selectedChequeDate = pickedDate);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: ListTile(
                          title: Text(_selectedBankName ??
                              (languageProvider.isEnglish
                                  ? 'Select Bank'
                                  : 'بینک منتخب کریں')),
                          trailing: const Icon(Icons.arrow_drop_down),
                          onTap: () async {
                            final selectedBank = await _selectBank(context);
                            if (selectedBank != null) {
                              setState(() {
                                _selectedBankId = selectedBank['id'];
                                _selectedBankName = selectedBank['name'];
                              });
                            }
                          },
                        ),
                      ),
                    ],

                    // Bank payment fields
                    if (_selectedPaymentMethod == 'Bank') ...[
                      const SizedBox(height: 16),
                      Card(
                        child: ListTile(
                          title: Text(_selectedBankName ??
                              (languageProvider.isEnglish
                                  ? 'Select Bank'
                                  : 'بینک منتخب کریں')),
                          trailing: const Icon(Icons.arrow_drop_down),
                          onTap: () async {
                            final selectedBank = await _selectBank(context);
                            if (selectedBank != null) {
                              setState(() {
                                _selectedBankId = selectedBank['id'];
                                _selectedBankName = selectedBank['name'];
                              });
                            }
                          },
                        ),
                      ),
                    ],

                    // Payment amount
                    const SizedBox(height: 16),
                    TextField(
                      controller: _paymentAmountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish ? 'Payment Amount' : 'ادائیگی کی رقم',
                        border: const OutlineInputBorder(),
                      ),
                    ),

                    // Description
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (value) => _paymentDescription = value,
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish ? 'Description' : 'تفصیل',
                        border: const OutlineInputBorder(),
                      ),
                    ),

                    // Image upload
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        final image = await _pickImage(context);
                        if (image != null) {
                          setState(() => _paymentImage = image);
                        }
                      },
                      child: Text(languageProvider.isEnglish ? 'Upload Receipt' : 'رسید اپ لوڈ کریں'),
                    ),
                    if (_paymentImage != null)
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        height: 100,
                        width: 100,
                        child: Image.memory(_paymentImage!),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_selectedPaymentMethod == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(languageProvider.isEnglish
                              ? 'Please select a payment method'
                              : 'براہ کرم ادائیگی کا طریقہ منتخب کریں'),
                        ),
                      );
                      return;
                    }

                    final amount = double.tryParse(_paymentAmountController.text);
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(languageProvider.isEnglish
                              ? 'Please enter a valid amount'
                              : 'براہ کرم درست رقم درج کریں'),
                        ),
                      );
                      return;
                    }

                    try {
                      // Create a dummy filled number for ledger entry
                      final filledNumber = DateTime.now().millisecondsSinceEpoch.toString();

                      // Update customer ledger directly
                      // await filledProvider.updateCustomerLedger(
                      //   customer.id,
                      //   creditAmount: 0.0,
                      //   debitAmount: amount,
                      //   remainingBalance: (_customerBalances[customer.id] ?? 0.0) - amount,
                      //   filledNumber: filledNumber,
                      //   referenceNumber: 'Direct Payment',
                      //   paymentMethod: _selectedPaymentMethod,
                      //   bankId: _selectedPaymentMethod == 'Bank' ? _selectedBankId :
                      //   (_selectedPaymentMethod == 'Cheque' ? _selectedBankId : null),
                      //   bankName: _selectedPaymentMethod == 'Bank' ? _selectedBankName :
                      //   (_selectedPaymentMethod == 'Cheque' ? _selectedBankName : null),
                      // );
                      // Update customer ledger directly
                      await filledProvider.updateCustomerLedger(
                        customer.id,
                        creditAmount: 0.0,
                        debitAmount: amount,
                        remainingBalance: (_customerBalances[customer.id] ?? 0.0) - amount,
                        filledNumber: filledNumber,
                        referenceNumber: 'Direct Payment',
                        paymentMethod: _selectedPaymentMethod,
                        bankId: _selectedPaymentMethod == 'Bank' ? _selectedBankId :
                        (_selectedPaymentMethod == 'Cheque' ? _selectedBankId : null),
                        bankName: _selectedPaymentMethod == 'Bank' ? _selectedBankName :
                        (_selectedPaymentMethod == 'Cheque' ? _selectedBankName : null),
                        chequeNumber: _selectedPaymentMethod == 'Cheque' ? _chequeNumberController.text : null,
                        description: _paymentDescription ?? 'Payment from ${customer.name}',
                      );

                      // Handle specific payment methods
                      if (_selectedPaymentMethod == 'Cash') {
                        await filledProvider.addCashBookEntry(
                          description: _paymentDescription ?? 'Payment from ${customer.name}',
                          amount: amount,
                          dateTime: _selectedPaymentDate,
                          type: 'cash_in',
                        );
                      } else if (_selectedPaymentMethod == 'Cheque') {
                        if (_selectedBankId == null || _selectedBankName == null) {
                          throw Exception("Bank not selected for cheque payment");
                        }
                        if (_chequeNumberController.text.isEmpty) {
                          throw Exception("Cheque number is required");
                        }
                        if (_selectedChequeDate == null) {
                          throw Exception("Cheque date is required");
                        }

                        await _db.child('banks/${_selectedBankId}/cheques').push().set({
                          'customerId': customer.id,
                          'customerName': customer.name,
                          'amount': amount,
                          'chequeNumber': _chequeNumberController.text,
                          'chequeDate': _selectedChequeDate!.toIso8601String(),
                          'status': 'pending',
                          'createdAt': DateTime.now().toIso8601String(),
                          'bankName': _selectedBankName,
                        });
                      } else if (_selectedPaymentMethod == 'Bank' && _selectedBankId != null) {
                        await _db.child('banks/${_selectedBankId}/transactions').push().set({
                          'amount': amount,
                          'description': _paymentDescription ?? 'Payment from ${customer.name}',
                          'type': 'cash_in',
                          'timestamp': _selectedPaymentDate.millisecondsSinceEpoch,
                          'customerId': customer.id,
                          'bankName': _selectedBankName,
                        });

                        // Update bank balance
                        final bankBalanceRef = _db.child('banks/${_selectedBankId}/balance');
                        final currentBalance = (await bankBalanceRef.get()).value as num? ?? 0.0;
                        await bankBalanceRef.set(currentBalance + amount);
                      }

                      // Update local balance
                      setState(() {
                        _customerBalances[customer.id] = (_customerBalances[customer.id] ?? 0.0) - amount;
                      });

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(languageProvider.isEnglish
                              ? 'Payment of Rs. $amount recorded successfully'
                              : 'ادائیگی کی رقم $amount کامیابی سے ریکارڈ ہو گئی'),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: ${e.toString()}'),
                        ),
                      );
                    }
                  },
                  child: Text(languageProvider.isEnglish ? 'Record Payment' : 'ادائیگی ریکارڈ کریں'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.isEnglish ? 'Customer List' : 'کسٹمر کی فہرست',
          style: const TextStyle(color: Colors.white),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddCustomer()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: Colors.white),
            tooltip: languageProvider.isEnglish ? 'Export PDF' : 'پی ڈی ایف ایکسپورٹ کریں',
            onPressed: () async {
              final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
              await _generateAndPrintCustomerBalances(customerProvider.customers);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Updated Search Bar with Autocomplete
          Consumer<CustomerProvider>(
            builder: (context, customerProvider, _) {
              if (customerProvider.customers.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish
                            ? 'Search Customers'
                            : 'کسٹمر تلاش کریں',
                        prefixIcon: Icon(Icons.search, color: Colors.orange[300]),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase();
                        });
                      },
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Autocomplete<Customer>(
                    initialValue: TextEditingValue(text: _searchQuery),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<Customer>.empty();
                      }
                      return customerProvider.customers.where((Customer customer) {
                        return customer.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                            customer.phone.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                            customer.address.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                            customer.city.toLowerCase().contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    displayStringForOption: (Customer customer) =>
                    '${customer.name} - ${customer.phone}',
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      // Update search controller when autocomplete changes
                      textEditingController.addListener(() {
                        if (_searchController.text != textEditingController.text) {
                          _searchController.text = textEditingController.text;
                          setState(() {
                            _searchQuery = textEditingController.text.toLowerCase();
                          });
                        }
                      });

                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: languageProvider.isEnglish
                              ? 'Search Customers'
                              : 'کسٹمر تلاش کریں',
                          prefixIcon: Icon(Icons.search, color: Colors.orange[300]),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                        onSubmitted: (value) {
                          onFieldSubmitted();
                          setState(() {
                            _searchQuery = value.toLowerCase();
                          });
                        },
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase();
                          });
                        },
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4.0,
                          borderRadius: BorderRadius.circular(8),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: 200, maxWidth: 400),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final Customer option = options.elementAt(index);
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.orange,
                                    child: Text(
                                      option.name.isNotEmpty ? option.name[0].toUpperCase() : '?',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  title: Text(option.name),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${option.phone}'),
                                      Text('${option.city}'),
                                      Text(
                                        'Balance: ${_customerBalances[option.id]?.toStringAsFixed(2) ?? "0.00"}',
                                        style: TextStyle(
                                          color: (_customerBalances[option.id] ?? 0.0) > 0
                                              ? Colors.green
                                              : Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    onSelected(option);
                                    // Optionally scroll to the selected customer in the list
                                    _scrollToCustomer(option);
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                    onSelected: (Customer selectedCustomer) {
                      setState(() {
                        _searchQuery = selectedCustomer.name.toLowerCase();
                        _searchController.text = selectedCustomer.name;
                      });
                      // Optionally perform additional actions like scrolling to the customer
                      _scrollToCustomer(selectedCustomer);
                    },
                  ),
                ),
              );
            },
          ),

          Expanded(
            child: Consumer<CustomerProvider>(
              builder: (context, customerProvider, child) {
                return FutureBuilder(
                  future: _fetchCustomersAndLoadBalances(customerProvider),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.active ||
                        snapshot.connectionState == ConnectionState.active) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Filter customers based on the search query
                    final filteredCustomers = customerProvider.customers.where((customer) {
                      final name = customer.name.toLowerCase();
                      final phone = customer.phone.toLowerCase();
                      final address = customer.address.toLowerCase();
                      final city = customer.city.toLowerCase();
                      return name.contains(_searchQuery) ||
                          phone.contains(_searchQuery) ||
                          address.contains(_searchQuery) ||
                          city.contains(_searchQuery);
                    }).toList();

                    if (filteredCustomers.isEmpty) {
                      return Center(
                        child: Text(
                          languageProvider.isEnglish
                              ? 'No customers found.'
                              : 'کوئی کسٹمر موجود نہیں',
                          style: TextStyle(color: Colors.orange[300]),
                        ),
                      );
                    }

                    // Rest of your existing layout code remains the same
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 600) {
                          // Web layout (existing code)
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SingleChildScrollView(
                              controller: _scrollController, // Add scroll controller
                              child: DataTable(
                                columns: [
                                  const DataColumn(label: Text('#')),
                                  DataColumn(
                                      label: Text(
                                        languageProvider.isEnglish ? 'Name' : 'نام',
                                        style: const TextStyle(fontSize: 20),
                                      )),
                                  DataColumn(
                                      label: Text(
                                        languageProvider.isEnglish ? 'Address' : 'پتہ',
                                        style: const TextStyle(fontSize: 20),
                                      )),
                                  DataColumn(
                                      label: Text(
                                        languageProvider.isEnglish ? 'City' : 'شہر',
                                        style: const TextStyle(fontSize: 20),
                                      )),
                                  DataColumn(
                                      label: Text(
                                        languageProvider.isEnglish ? 'Phone' : 'فون',
                                        style: const TextStyle(fontSize: 20),
                                      )),
                                  DataColumn(
                                      label: Text(
                                        languageProvider.isEnglish ? 'Balance' : 'بیلنس',
                                        style: const TextStyle(fontSize: 20),
                                      )),
                                  DataColumn(
                                    label: Text(
                                      languageProvider.isEnglish ? 'Pay' : 'ادائیگی',
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                  ),
                                  DataColumn(
                                      label: Text(
                                        languageProvider.isEnglish ? 'Actions' : 'عمل',
                                        style: const TextStyle(fontSize: 20),
                                      )),
                                  DataColumn(
                                    label: Text(
                                      languageProvider.isEnglish ? 'Item Prices' : 'قیمتیں',
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      languageProvider.isEnglish ? 'Payments' : 'ادائیگیاں',
                                      style: TextStyle(fontSize: 20),
                                    ),
                                  ),
                                ],
                                rows: filteredCustomers
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                  final index = entry.key + 1;
                                  final customer = entry.value;
                                  return DataRow(
                                      key: ValueKey(customer.id), // Add key for scrolling
                                      cells: [
                                        DataCell(Text('$index')),
                                        DataCell(Text(customer.name)),
                                        DataCell(Text(customer.address)),
                                        DataCell(Text(customer.city)),
                                        DataCell(Text(customer.phone)),
                                        DataCell(
                                          Text(
                                            'Balance: ${_customerBalances[customer.id]?.toStringAsFixed(2) ?? "0.00"}',
                                            style: const TextStyle(color: Colors.teal),
                                          ),
                                        ),
                                        DataCell(
                                          IconButton(
                                            icon: Icon(Icons.payment, color: Colors.green),
                                            onPressed: () => _showPaymentDialog(context, customer),
                                          ),
                                        ),
                                        DataCell(Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit, color: Colors.orange),
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => AddCustomer(customer: customer),
                                                  ),
                                                );
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red),
                                              onPressed: () => _showDeleteConfirmationDialog(context, customer, customerProvider),
                                            ),
                                          ],
                                        )),
                                        DataCell(
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.orange,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            ),
                                            icon: const Icon(Icons.price_check),
                                            label: Text(languageProvider.isEnglish ? 'Rates' : 'ریٹس'),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => CustomerItemPricesPage(
                                                    customerId: customer.id,
                                                    customerName: customer.name,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        DataCell(
                                          IconButton(
                                            icon: Icon(Icons.history, color: Colors.blue),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => CustomerPaymentHistoryPage(customer: customer),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ]
                                  );
                                }).toList(),
                              ),
                            ),
                          );
                        } else {
                          // Mobile layout (existing code remains the same)
                          return ListView.builder(
                            controller: _scrollController, // Add scroll controller
                            itemCount: filteredCustomers.length,
                            itemBuilder: (context, index) {
                              final customer = filteredCustomers[index];
                              return Card(
                                key: ValueKey(customer.id), // Add key for scrolling
                                elevation: 4,
                                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                color: Colors.orange.shade50,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.orange,
                                    child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
                                  ),
                                  title: Text(customer.name, style: TextStyle(color: Colors.orange[300])),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(customer.address, style: TextStyle(color: Colors.orange[300])),
                                      Text(customer.city, style: TextStyle(color: Colors.orange[300])),
                                      const SizedBox(height: 4),
                                      Text(customer.phone, style: TextStyle(color: Colors.orange[300])),
                                      Text(
                                        'Balance: ${_customerBalances[customer.id]?.toStringAsFixed(2) ?? "0.00"}',
                                        style: const TextStyle(color: Colors.orange),
                                      ),
                                      TextButton.icon(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => CustomerItemPricesPage(
                                                customerId: customer.id,
                                                customerName: customer.name,
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.list_alt, size: 18, color: Colors.teal),
                                        label: Text(
                                          languageProvider.isEnglish ? 'View Item Rates' : 'ریٹس دیکھیں',
                                          style: const TextStyle(color: Colors.teal),
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.payment, color: Colors.green),
                                        onPressed: () => _showPaymentDialog(context, customer),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.teal),
                                        onPressed: () {
                                          _showEditDialog(context, customer, customerProvider);
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _showDeleteConfirmationDialog(context, customer, customerProvider),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.history, color: Colors.blue),
                                        onPressed: () => _showPaymentHistory(context, customer),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Add this new method for scrolling to a specific customer
  void _scrollToCustomer(Customer targetCustomer) {
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    final customers = customerProvider.customers;

    final index = customers.indexWhere((customer) => customer.id == targetCustomer.id);
    if (index != -1) {
      // For DataTable (web layout)
      if (MediaQuery.of(context).size.width > 600) {
        final position = index * 56.0; // Approximate row height
        _scrollController.animateTo(
          position,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } else {
        // For ListView (mobile layout)
        final position = index * 120.0; // Approximate card height
        _scrollController.animateTo(
          position,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _showDeleteConfirmationDialog(
      BuildContext context,
      Customer customer,
      CustomerProvider customerProvider,
      )
  {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.isEnglish
            ? 'Delete Customer?'
            : 'کسٹمر حذف کریں؟'),
        content: Text(languageProvider.isEnglish
            ? 'Are you sure you want to delete ${customer.name}?'
            : 'کیا آپ واقعی ${customer.name} کو حذف کرنا چاہتے ہیں؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await customerProvider.deleteCustomer(customer.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(languageProvider.isEnglish
                        ? 'Customer deleted successfully'
                        : 'کسٹمر کامیابی سے حذف ہو گیا'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(languageProvider.isEnglish
                        ? 'Error deleting customer: $e'
                        : 'کسٹمر کو حذف کرنے میں خرابی: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(languageProvider.isEnglish ? 'Delete' : 'حذف کریں'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(
      BuildContext context,
      Customer customer,
      CustomerProvider customerProvider,
      ) {
    final nameController = TextEditingController(text: customer.name);
    final addressController = TextEditingController(text: customer.address);
    final phoneController = TextEditingController(text: customer.phone);
    final cityController = TextEditingController(text: customer.city);
    final balanceController = TextEditingController(
        text: customer.openingBalance!.toStringAsFixed(2)
    );

    // Initialize date with existing date or current date
    DateTime editOpeningBalanceDate = customer.openingBalanceDate ?? DateTime.now();

    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                languageProvider.isEnglish ? 'Edit Customer' : 'کسٹمر میں ترمیم کریں',
                style: TextStyle(color: Colors.orange.shade800),
              ),
              backgroundColor: Colors.orange.shade50,
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                          labelText: languageProvider.isEnglish ? 'Name' : 'نام',
                          labelStyle: TextStyle(color: Colors.orange.shade600)
                      ),
                    ),
                    TextField(
                      controller: addressController,
                      decoration: InputDecoration(
                          labelText: languageProvider.isEnglish ? 'Address' : 'پتہ',
                          labelStyle: TextStyle(color: Colors.orange.shade600)
                      ),
                    ),
                    TextField(
                      controller: cityController,
                      decoration: InputDecoration(
                          labelText: languageProvider.isEnglish ? 'City' : 'شہر',
                          labelStyle: TextStyle(color: Colors.orange.shade600)
                      ),
                    ),
                    TextField(
                      controller: phoneController,
                      decoration: InputDecoration(
                          labelText: languageProvider.isEnglish ? 'Phone' : 'فون',
                          labelStyle: TextStyle(color: Colors.orange.shade600)
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    TextField(
                      controller: balanceController,
                      decoration: InputDecoration(
                          labelText: languageProvider.isEnglish
                              ? 'Opening Balance'
                              : 'ابتدائی بیلنس',
                          labelStyle: TextStyle(color: Colors.orange.shade600)
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                    ),

                    // Opening Balance Date/Time Selector
                    SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      child: ListTile(
                        leading: Icon(Icons.calendar_today, color: Colors.orange.shade600),
                        title: Text(
                          languageProvider.isEnglish
                              ? 'Opening Balance Date & Time'
                              : 'ابتدائی بیلنس کی تاریخ اور وقت',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.orange.shade600,
                          ),
                        ),
                        subtitle: Text(
                          DateFormat('dd/MM/yyyy - HH:mm').format(editOpeningBalanceDate),
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.orange.shade800,
                          ),
                        ),
                        trailing: Icon(Icons.edit, color: Colors.orange.shade600),
                        onTap: () async {
                          // First pick date
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: editOpeningBalanceDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );

                          if (pickedDate != null) {
                            // Then pick time
                            final pickedTime = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(editOpeningBalanceDate),
                            );

                            if (pickedTime != null) {
                              setState(() {
                                editOpeningBalanceDate = DateTime(
                                  pickedDate.year,
                                  pickedDate.month,
                                  pickedDate.day,
                                  pickedTime.hour,
                                  pickedTime.minute,
                                );
                              });
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                      languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں',
                      style: TextStyle(color: Colors.orange.shade800)
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final openingBalance = double.tryParse(balanceController.text) ?? 0.0;
                    customerProvider.updateCustomer(
                        customer.id,
                        nameController.text,
                        addressController.text,
                        phoneController.text,
                        cityController.text,
                        openingBalance,
                        editOpeningBalanceDate // Pass the selected date/time
                    );
                    Navigator.pop(context);
                  },
                  child: Text(
                    languageProvider.isEnglish ? 'Save' : 'محفوظ کریں',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade300),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showPaymentHistory(BuildContext context, Customer customer) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    try {
      final customerLedgerRef = _db.child('filledledger').child(customer.id);
      final DatabaseEvent snapshot = await customerLedgerRef.orderByChild('createdAt').once();

      if (!snapshot.snapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(languageProvider.isEnglish
                ? 'No payment history found'
                : 'کوئی ادائیگی کی تاریخ نہیں ملی'),
          ),
        );
        return;
      }

      final Map<dynamic, dynamic> ledgerEntries = snapshot.snapshot.value as Map<dynamic, dynamic>;
      final List<Map<String, dynamic>> payments = [];

      ledgerEntries.forEach((key, value) {
        if (value != null && value is Map) {
          final debitAmount = (value['debitAmount'] ?? 0.0).toDouble();
          if (debitAmount > 0) { // Only show debit entries (payments)
            payments.add({
              'key': key,
              'amount': debitAmount,
              'date': value['createdAt'] ?? '',
              'method': value['paymentMethod'] ?? '',
              'description': value['description'] ?? '',
              'bankName': value['bankName'] ?? '',
              'chequeNumber': value['chequeNumber'] ?? '',
            });
          }
        }
      });

      // Sort by date descending
      payments.sort((a, b) => b['date'].compareTo(a['date']));

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(languageProvider.isEnglish
              ? 'Payment History - ${customer.name}'
              : 'ادائیگی کی تاریخ - ${customer.name}'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: payments.isEmpty
                ? Center(
              child: Text(languageProvider.isEnglish
                  ? 'No payments found'
                  : 'کوئی ادائیگی نہیں ملی'),
            )
                : ListView.builder(
              itemCount: payments.length,
              itemBuilder: (context, index) {
                final payment = payments[index];
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(
                      '${payment['amount']} Rs',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${payment['method']}'),
                        if (payment['bankName'] != null && payment['bankName'].isNotEmpty)
                          Text('Bank: ${payment['bankName']}'),
                        if (payment['chequeNumber'] != null && payment['chequeNumber'].isNotEmpty)
                          Text('Cheque: ${payment['chequeNumber']}'),
                        Text(DateFormat('yyyy-MM-dd HH:mm').format(
                            DateTime.parse(payment['date'])
                        )),
                        if (payment['description'] != null && payment['description'].isNotEmpty)
                          Text('Desc: ${payment['description']}'),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deletePayment(
                          context,
                          customer,
                          payment['key'],
                          payment['amount'],
                          payment['method'],
                          payment['bankName'],
                          payment['chequeNumber']
                      ),
                    ),
                  ),
                );
              },
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
        ),
      );
    }
  }

  Future<void> _deletePayment(
      BuildContext context,
      Customer customer,
      String paymentKey,
      double amount,
      String paymentMethod,
      String? bankName,
      String? chequeNumber
      )
  async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final filledProvider = Provider.of<FilledProvider>(context, listen: false);

    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.isEnglish
            ? 'Delete Payment?'
            : 'ادائیگی حذف کریں؟'),
        content: Text(languageProvider.isEnglish
            ? 'Are you sure you want to delete this payment of Rs. $amount?'
            : 'کیا آپ واقعی اس $amount روپے کی ادائیگی کو حذف کرنا چاہتے ہیں؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(languageProvider.isEnglish ? 'Delete' : 'حذف کریں'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Delete from filledledger
        await _db.child('filledledger').child(customer.id).child(paymentKey).remove();

        // Handle reversal based on payment method
        if (paymentMethod == 'Cash') {
          // Add reverse entry to cash book
          await filledProvider.addCashBookEntry(
            description: 'Payment deletion - ${customer.name}',
            amount: amount,
            dateTime: DateTime.now(),
            type: 'cash_out', // Reverse the cash inflow
          );
        }
        else if (paymentMethod == 'Cheque' && chequeNumber != null) {
          // Delete cheque entry
          final chequesRef = _db.child('banks');
          final chequesSnapshot = await chequesRef.orderByChild('chequeNumber').equalTo(chequeNumber).once();
          if (chequesSnapshot.snapshot.exists) {
            final cheques = chequesSnapshot.snapshot.value as Map<dynamic, dynamic>;
            final chequeKey = cheques.keys.first;
            await chequesRef.child(chequeKey).remove();
          }
        }
        else if (paymentMethod == 'Bank' && bankName != null) {
          // Find and delete bank transaction
          final banksRef = _db.child('banks');
          final banksSnapshot = await banksRef.once();

          if (banksSnapshot.snapshot.exists) {
            final banks = banksSnapshot.snapshot.value as Map<dynamic, dynamic>;

            for (var bankEntry in banks.entries) {
              final bankId = bankEntry.key;
              final bankData = bankEntry.value as Map<dynamic, dynamic>;

              if (bankData['name'] == bankName) {
                final transactionsRef = _db.child('banks/$bankId/transactions');
                final transactionsSnapshot = await transactionsRef.orderByChild('amount').equalTo(amount).once();

                if (transactionsSnapshot.snapshot.exists) {
                  final transactions = transactionsSnapshot.snapshot.value as Map<dynamic, dynamic>;
                  final transactionKey = transactions.keys.first;
                  await transactionsRef.child(transactionKey).remove();

                  // Update bank balance (subtract the amount)
                  final currentBalance = (bankData['balance'] ?? 0.0).toDouble();
                  await _db.child('banks/$bankId/balance').set(currentBalance - amount);
                }
                break;
              }
            }
          }
        }

        // Update local balance
        setState(() {
          _customerBalances[customer.id] = (_customerBalances[customer.id] ?? 0.0) + amount;
        });

        Navigator.pop(context); // Close the payment history dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(languageProvider.isEnglish
                ? 'Payment deleted successfully'
                : 'ادائیگی کامیابی سے حذف ہو گئی'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh payment history
        _showPaymentHistory(context, customer);

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting payment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }



}
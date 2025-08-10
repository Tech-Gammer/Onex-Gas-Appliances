// import 'package:firebase_database/firebase_database.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
//
// import '../Provider/customerprovider.dart';
// import '../Provider/lanprovider.dart';
// import 'addcustomers.dart';
//
// class CustomerList extends StatefulWidget {
//   @override
//   _CustomerListState createState() => _CustomerListState();
// }
//
// class _CustomerListState extends State<CustomerList> {
//   TextEditingController _searchController = TextEditingController();
//   String _searchQuery = '';
//   final DatabaseReference _db = FirebaseDatabase.instance.ref();
//   Map<String, double> _customerBalances = {};
//   Map<String, Map<String, dynamic>> _ledgerCache = {}; // Cache for ledger data
//
//   @override
//   void initState() {
//     super.initState();
//     _loadCustomerBalances();
//   }
//
//   Future<void> _loadCustomerBalances() async {
//     final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
//     final customers = customerProvider.customers;
//
//     List<Future<void>> fetchFutures = customers.map((customer) async {
//       final filledBalance = await _getRemainingFillesBalance(customer.id);
//       _customerBalances[customer.id] = filledBalance;
//     }).toList();
//
//     await Future.wait(fetchFutures);
//     setState(() {}); // Update UI
//   }
//
//
//
//   Future<double> _getRemainingFillesBalance(String customerId) async {
//     if (_ledgerCache.containsKey(customerId) && _ledgerCache[customerId]!.containsKey('filledBalance')) {
//       return _ledgerCache[customerId]!['filledBalance'] ?? 0.0;
//     }
//
//     try {
//       final customerLedgerRef = _db.child('filledledger').child(customerId);
//       final DatabaseEvent snapshot = await customerLedgerRef.orderByChild('createdAt').limitToLast(1).once();
//
//       double remainingBalance = 0.0;
//       if (snapshot.snapshot.exists) {
//         final Map<dynamic, dynamic> ledgerEntries = snapshot.snapshot.value as Map<dynamic, dynamic>;
//         final lastEntryKey = ledgerEntries.keys.first;
//         final lastEntry = ledgerEntries[lastEntryKey];
//
//         if (lastEntry != null && lastEntry is Map) {
//           final remainingBalanceValue = lastEntry['remainingBalance'];
//           if (remainingBalanceValue is int) {
//             remainingBalance = remainingBalanceValue.toDouble();
//           } else if (remainingBalanceValue is double) {
//             remainingBalance = remainingBalanceValue;
//           }
//         }
//       }
//
//       // Update the cache with the filled balance
//       if (_ledgerCache.containsKey(customerId)) {
//         _ledgerCache[customerId]!['filledBalance'] = remainingBalance;
//       } else {
//         _ledgerCache[customerId] = {'filledBalance': remainingBalance};
//       }
//
//       return remainingBalance;
//     } catch (e) {
//       return 0.0;
//     }
//   }
//
//   Future<void> _fetchCustomersAndLoadBalances(CustomerProvider customerProvider) async {
//     await customerProvider.fetchCustomers();
//     await _loadCustomerBalances();
//   }
//
//
//   @override
//   Widget build(BuildContext context) {
//     final languageProvider = Provider.of<LanguageProvider>(context);
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           languageProvider.isEnglish ? 'Customer List' : 'کسٹمر کی فہرست',
//           style: const TextStyle(color: Colors.white),
//         ),
//         flexibleSpace: Container(
//           decoration: const BoxDecoration(
//             gradient: LinearGradient(
//               colors: [Color(0xFFFF8A65), Color(0xFFFFB74D)],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//           ),
//         ),        actions: [
//           IconButton(
//             icon: const Icon(Icons.add, color: Colors.white),
//             onPressed: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (context) => AddCustomer()),
//               );
//             },
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           // Search Bar
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: TextField(
//               controller: _searchController,
//               decoration: InputDecoration(
//                 labelText: languageProvider.isEnglish
//                     ? 'Search Customers'
//                     : 'کسٹمر تلاش کریں',
//                 prefixIcon: Icon(Icons.search, color: Colors.orange[300]),
//                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
//               ),
//               onChanged: (value) {
//                 setState(() {
//                   _searchQuery = value.toLowerCase(); // Update the search query
//                 });
//               },
//             ),
//           ),
//           Expanded(
//             child: Consumer<CustomerProvider>(
//               builder: (context, customerProvider, child) {
//                 return FutureBuilder(
//                   // future: customerProvider.fetchCustomers(),
//                   future: _fetchCustomersAndLoadBalances(customerProvider),
//                   builder: (context, snapshot) {
//                     if (snapshot.connectionState == ConnectionState.active ||
//                         snapshot.connectionState == ConnectionState.active) {
//                       return const Center(child: CircularProgressIndicator());
//                     }
//
//                     // Filter customers based on the search query
//                     final filteredCustomers = customerProvider.customers.where((customer) {
//                       final name = customer.name.toLowerCase();
//                       final phone = customer.phone.toLowerCase();
//                       final address = customer.address.toLowerCase();
//                       return name.contains(_searchQuery) ||
//                           phone.contains(_searchQuery) ||
//                           address.contains(_searchQuery);
//                     }).toList();
//
//                     if (filteredCustomers.isEmpty) {
//                       return Center(
//                         child: Text(
//                           languageProvider.isEnglish
//                               ? 'No customers found.'
//                               : 'کوئی کسٹمر موجود نہیں',
//                           style: TextStyle(color: Colors.orange[300]),
//                         ),
//                       );
//                     }
//
//                     // Responsive layout
//                     return LayoutBuilder(
//                       builder: (context, constraints) {
//                         if (constraints.maxWidth > 600) {
//                           // Web layout (with remaining balance in the table)
//                           return Padding(
//                             padding: const EdgeInsets.all(16.0),
//                             child: SingleChildScrollView(
//                               child: DataTable(
//                                 columns: [
//                                   const DataColumn(label: Text('#')),
//                                   DataColumn(
//                                       label: Text(
//                                         languageProvider.isEnglish ? 'Name' : 'نام',
//                                         style: const TextStyle(fontSize: 20),
//                                       )),
//                                   DataColumn(
//                                       label: Text(
//                                         languageProvider.isEnglish ? 'Address' : 'پتہ',
//                                         style: const TextStyle(fontSize: 20),
//                                       )),
//                                   DataColumn(
//                                       label: Text(
//                                         languageProvider.isEnglish ? 'Phone' : 'فون',
//                                         style: const TextStyle(fontSize: 20),
//                                       )),
//                                   DataColumn(
//                                       label: Text(
//                                         languageProvider.isEnglish ? 'Balance' : 'بیلنس',
//                                         style: const TextStyle(fontSize: 20),
//                                       )),
//                                   DataColumn(
//                                       label: Text(
//                                         languageProvider.isEnglish ? 'Actions' : 'عمل',
//                                         style: const TextStyle(fontSize: 20),
//                                       )),
//                                 ],
//                                 rows: filteredCustomers
//                                     .asMap()
//                                     .entries
//                                     .map((entry) {
//                                   final index = entry.key + 1;
//                                   final customer = entry.value;
//                                   return DataRow(cells: [
//                                     DataCell(Text('$index')),
//                                     DataCell(Text(customer.name)),
//                                     DataCell(Text(customer.address)),
//                                     DataCell(Text(customer.phone)),
//                                     DataCell(
//                                       Text(
//                                         'Balance: ${_customerBalances[customer.id]?.toStringAsFixed(2) ?? "0.00"}',
//                                         style: const TextStyle(color: Colors.teal),
//                                       ),
//                                     ),
//                                     DataCell(Row(
//                                       children: [
//                                         IconButton(
//                                           icon: const Icon(Icons.edit, color: Colors.orange),
//                                           onPressed: () {
//                                             _showEditDialog(context, customer, customerProvider);
//                                           },
//                                         ),
//                                         IconButton(
//                                           icon: const Icon(Icons.delete, color: Colors.red),
//                                           onPressed: () => _showDeleteConfirmationDialog(context, customer, customerProvider),
//                                         ),
//                                       ],
//                                     )),
//                                   ]);
//                                 }).toList(),
//                               ),
//                             ),
//                           );
//                         } else {
//                           // Mobile layout (with remaining balance in the card)
//                           return ListView.builder(
//                             itemCount: filteredCustomers.length,
//                             itemBuilder: (context, index) {
//                               final customer = filteredCustomers[index];
//                               return Card(
//                                 elevation: 4,
//                                 margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
//                                 color: Colors.teal.shade50,
//                                 child: ListTile(
//                                   leading: CircleAvatar(
//                                     backgroundColor: Colors.teal.shade400,
//                                     child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
//                                   ),
//                                   title: Text(customer.name, style: TextStyle(color: Colors.teal.shade800)),
//                                   subtitle: Column(
//                                     crossAxisAlignment: CrossAxisAlignment.start,
//                                     children: [
//                                       Text(customer.address, style: TextStyle(color: Colors.teal.shade600)),
//                                       const SizedBox(height: 4),
//                                       Text(customer.phone, style: TextStyle(color: Colors.teal.shade600)),
//                                       Text(
//                                         'Balance: ${_customerBalances[customer.id]?.toStringAsFixed(2) ?? "0.00"}',
//                                         style: const TextStyle(color: Colors.teal),
//                                       ),
//                                     ],
//                                   ),
//                                   trailing: Row(
//                                     mainAxisSize: MainAxisSize.min,
//                                     children: [
//                                       IconButton(
//                                         icon: const Icon(Icons.edit, color: Colors.teal),
//                                         onPressed: () {
//                                           _showEditDialog(context, customer, customerProvider);
//                                         },
//                                       ),
//                                       IconButton(
//                                         icon: const Icon(Icons.delete, color: Colors.red),
//                                         onPressed: () => _showDeleteConfirmationDialog(context, customer, customerProvider),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               );
//                             },
//                           );
//                         }
//                       },
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _showDeleteConfirmationDialog(
//       BuildContext context,
//       Customer customer,
//       CustomerProvider customerProvider,
//       ) {
//     final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
//
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text(languageProvider.isEnglish
//             ? 'Delete Customer?'
//             : 'کسٹمر حذف کریں؟'),
//         content: Text(languageProvider.isEnglish
//             ? 'Are you sure you want to delete ${customer.name}?'
//             : 'کیا آپ واقعی ${customer.name} کو حذف کرنا چاہتے ہیں؟'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
//           ),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//             onPressed: () async {
//               try {
//                 await customerProvider.deleteCustomer(customer.id);
//                 Navigator.pop(context);
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                     content: Text(languageProvider.isEnglish
//                         ? 'Customer deleted successfully'
//                         : 'کسٹمر کامیابی سے حذف ہو گیا'),
//                     backgroundColor: Colors.green,
//                   ),
//                 );
//               } catch (e) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                     content: Text(languageProvider.isEnglish
//                         ? 'Error deleting customer: $e'
//                         : 'کسٹمر کو حذف کرنے میں خرابی: $e'),
//                     backgroundColor: Colors.red,
//                   ),
//                 );
//               }
//             },
//             child: Text(languageProvider.isEnglish ? 'Delete' : 'حذف کریں'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _showEditDialog(
//       BuildContext context,
//       Customer customer,
//       CustomerProvider customerProvider,
//       ) {
//     final nameController = TextEditingController(text: customer.name);
//     final addressController = TextEditingController(text: customer.address);
//     final phoneController = TextEditingController(text: customer.phone);
//
//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: Text('Edit Customer', style: TextStyle(color: Colors.teal.shade800)),
//           backgroundColor: Colors.teal.shade50,
//           content: SingleChildScrollView(
//             child: Column(
//               children: [
//                 TextField(
//                   controller: nameController,
//                   decoration: InputDecoration(labelText: 'Name', labelStyle: TextStyle(color: Colors.teal.shade600)),
//                 ),
//                 TextField(
//                   controller: addressController,
//                   decoration: InputDecoration(labelText: 'Address', labelStyle: TextStyle(color: Colors.teal.shade600)),
//                 ),
//                 TextField(
//                   controller: phoneController,
//                   decoration: InputDecoration(labelText: 'Phone', labelStyle: TextStyle(color: Colors.teal.shade600)),
//                   keyboardType: TextInputType.phone,
//                 ),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: Text('Cancel', style: TextStyle(color: Colors.teal.shade800)),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 customerProvider.updateCustomer(
//                   customer.id,
//                   nameController.text,
//                   addressController.text,
//                   phoneController.text,
//                 );
//                 Navigator.pop(context);
//               },
//               child: const Text('Save',style: TextStyle(color: Colors.white),),
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade400),
//             ),
//           ],
//         );
//       },
//     );
//   }
// }
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../Provider/customerprovider.dart';
import '../Provider/lanprovider.dart';
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
    if (_ledgerCache.containsKey(customerId) && _ledgerCache[customerId]!.containsKey('filledBalance')) {
      return _ledgerCache[customerId]!['filledBalance'] ?? 0.0;
    }

    try {
      final customerLedgerRef = _db.child('filledledger').child(customerId);
      final DatabaseEvent snapshot = await customerLedgerRef.orderByChild('createdAt').limitToLast(1).once();

      double remainingBalance = 0.0;
      if (snapshot.snapshot.exists) {
        final Map<dynamic, dynamic> ledgerEntries = snapshot.snapshot.value as Map<dynamic, dynamic>;
        final lastEntryKey = ledgerEntries.keys.first;
        final lastEntry = ledgerEntries[lastEntryKey];

        if (lastEntry != null && lastEntry is Map) {
          final remainingBalanceValue = lastEntry['remainingBalance'];
          if (remainingBalanceValue is int) {
            remainingBalance = remainingBalanceValue.toDouble();
          } else if (remainingBalanceValue is double) {
            remainingBalance = remainingBalanceValue;
          }
        }
      }

      // Update the cache with the filled balance
      if (_ledgerCache.containsKey(customerId)) {
        _ledgerCache[customerId]!['filledBalance'] = remainingBalance;
      } else {
        _ledgerCache[customerId] = {'filledBalance': remainingBalance};
      }

      return remainingBalance;
    } catch (e) {
      return 0.0;
    }
  }

  Future<void> _fetchCustomersAndLoadBalances(CustomerProvider customerProvider) async {
    await customerProvider.fetchCustomers();
    await _loadCustomerBalances();
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
        ),        actions: [
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
          icon: Icon(Icons.picture_as_pdf,color: Colors.white,),
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
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: languageProvider.isEnglish
                    ? 'Search Customers'
                    : 'کسٹمر تلاش کریں',
                prefixIcon: Icon(Icons.search, color: Colors.orange[300]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase(); // Update the search query
                });
              },
            ),
          ),
          Expanded(
            child: Consumer<CustomerProvider>(
              builder: (context, customerProvider, child) {
                return FutureBuilder(
                  // future: customerProvider.fetchCustomers(),
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
                      return name.contains(_searchQuery) ||
                          phone.contains(_searchQuery) ||
                          address.contains(_searchQuery);
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

                    // Responsive layout
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 600) {
                          // Web layout (with remaining balance in the table)
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SingleChildScrollView(
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
                                        languageProvider.isEnglish ? 'Actions' : 'عمل',
                                        style: const TextStyle(fontSize: 20),
                                      )),
                                  DataColumn(
                                    label: Text(
                                      languageProvider.isEnglish ? 'Item Prices' : 'قیمتیں',
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                  ),

                                ],
                                rows: filteredCustomers
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                  final index = entry.key + 1;
                                  final customer = entry.value;
                                  return
                                    DataRow(cells: [
                                      DataCell(Text('$index')),
                                      DataCell(Text(customer.name)),
                                      DataCell(Text(customer.address)),
                                      DataCell(Text(customer.phone)),
                                      DataCell(
                                        Text(
                                          'Balance: ${_customerBalances[customer.id]?.toStringAsFixed(2) ?? "0.00"}',
                                          style: const TextStyle(color: Colors.teal),
                                        ),
                                      ),
                                      DataCell(Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.orange),
                                            onPressed: () {
                                              _showEditDialog(context, customer, customerProvider);
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

                                    ]);
                                }).toList(),
                              ),
                            ),
                          );
                        } else {
                          // Mobile layout (with remaining balance in the card)
                          return ListView.builder(
                            itemCount: filteredCustomers.length,
                            itemBuilder: (context, index) {
                              final customer = filteredCustomers[index];
                              return Card(
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
                                        icon: const Icon(Icons.edit, color: Colors.teal),
                                        onPressed: () {
                                          _showEditDialog(context, customer, customerProvider);
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _showDeleteConfirmationDialog(context, customer, customerProvider),
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
      )
  {
    final nameController = TextEditingController(text: customer.name);
    final addressController = TextEditingController(text: customer.address);
    final phoneController = TextEditingController(text: customer.phone);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Customer', style: TextStyle(color: Colors.orange.shade800)),
          backgroundColor: Colors.orange.shade50,
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Name', labelStyle: TextStyle(color: Colors.orange.shade600)),
                ),
                TextField(
                  controller: addressController,
                  decoration: InputDecoration(labelText: 'Address', labelStyle: TextStyle(color: Colors.orange.shade600)),
                ),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(labelText: 'Phone', labelStyle: TextStyle(color: Colors.orange.shade600)),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.orange.shade800)),
            ),
            ElevatedButton(
              onPressed: () {
                customerProvider.updateCustomer(
                  customer.id,
                  nameController.text,
                  addressController.text,
                  phoneController.text,
                );
                Navigator.pop(context);
              },
              child: const Text('Save',style: TextStyle(color: Colors.white),),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade300),
            ),
          ],
        );
      },
    );
  }

}
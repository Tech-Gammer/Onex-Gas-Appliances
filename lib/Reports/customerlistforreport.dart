import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Provider/customerprovider.dart';
import '../Provider/lanprovider.dart';
import 'bycustomerreport.dart';
import 'bypaymentType.dart';
import 'custoemrreports.dart';

class CustomerListPage extends StatefulWidget {
  @override
  _CustomerListPageState createState() => _CustomerListPageState();
}

class _CustomerListPageState extends State<CustomerListPage> {
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Fetch customers when the page is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CustomerProvider>(context, listen: false).fetchCustomers();
    });

    // Listen to changes in the search field
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  void _showReportOptions(BuildContext context, String customerName, String customerPhone, String customerId) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            languageProvider.isEnglish ? 'Select Report' : ' رپورٹس منتخب کریں', // Dynamic text based on language
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                title: Text(
                  languageProvider.isEnglish ? 'Ledger' : 'لیجر', // Dynamic text based on language
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CustomerReportPage(
                        customerId: customerId,
                        customerName: customerName,
                        customerPhone: customerPhone,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                title: Text(
                  languageProvider.isEnglish ? 'Reports by CustomerName' : 'کسٹمر نام کے ذریعہ رپورٹس', // Dynamic text based on language
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => byCustomerReport(
                        customerId: customerId,
                        customerName: customerName,
                        customerPhone: customerPhone,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.isEnglish ? 'Customer List For Sarya Ledger' : 'سریا لیجر کے لیے صارفین کی فہرست',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        backgroundColor: Colors.teal, // AppBar background color
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: languageProvider.isEnglish ? 'Search by Customer Name' : 'کسٹمر کے نام سے تلاش کریں',
                hintStyle: TextStyle(color: Colors.white60),
                prefixIcon: Icon(Icons.search, color: Colors.white),
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
              ),
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
      body: Consumer<CustomerProvider>(
        builder: (context, customerProvider, child) {
          // Filter customers based on the search query
          final filteredCustomers = customerProvider.customers.where((customer) {
            return customer.name.toLowerCase().contains(_searchQuery);
          }).toList();

          // Check if customers have been loaded
          if (filteredCustomers.isEmpty) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Colors.teal.shade400), // Loading indicator color
              ),
            );
          }
          // Display filtered customers in a ListView
          return ListView.builder(
            itemCount: filteredCustomers.length,
            itemBuilder: (context, index) {
              final customer = filteredCustomers[index];
              return ListTile(
                title: Text(
                  customer.name,
                  style: TextStyle(color: Colors.teal.shade800), // Title text color
                ),
                subtitle: Text(
                  customer.phone,
                  style: TextStyle(color: Colors.teal.shade600), // Subtitle text color
                ),
                onTap: () {
                  _showReportOptions(
                    context,
                    customer.name,
                    customer.phone,
                    customer.id,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

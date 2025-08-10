import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Provider/customerprovider.dart';
import '../Provider/lanprovider.dart';
import 'filledbycustomerreport.dart';
import 'filledledgerreport.dart';

class Filledcustomerlistpage extends StatefulWidget {
  @override
  _FilledcustomerlistpageState createState() => _FilledcustomerlistpageState();
}

class _FilledcustomerlistpageState extends State<Filledcustomerlistpage> {
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
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            languageProvider.isEnglish ? 'Select Report' : 'رپورٹس منتخب کریں',
            style: TextStyle(
              color: Color(0xFFE65100), // Dark orange text
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.receipt, color: Color(0xFFFF8A65)),
                title: Text(
                  languageProvider.isEnglish ? 'Ledger' : 'لیجر',
                  style: TextStyle(color: Colors.grey[800]),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FilledLedgerReportPage(
                        customerId: customerId,
                        customerName: customerName,
                        customerPhone: customerPhone,
                      ),
                    ),
                  );
                },
              ),
              Divider(height: 1, color: Colors.grey[300]),
              ListTile(
                leading: Icon(Icons.person, color: Color(0xFFFF8A65)),
                title: Text(
                  languageProvider.isEnglish ? 'Reports by CustomerName' : 'کسٹمر نام کے ذریعہ رپورٹس',
                  style: TextStyle(color: Colors.grey[800]),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => filledbycustomerreport(
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
          languageProvider.isEnglish ? 'Customer List For Ledger' : 'لیجر کے لیے صارفین کی فہرست',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
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
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: languageProvider.isEnglish
                      ? 'Search by Customer Name'
                      : 'کسٹمر کے نام سے تلاش کریں',
                  hintStyle: TextStyle(color: Colors.white70),
                  prefixIcon: Icon(Icons.search, color: Colors.white),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                ),
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF3E0), // Light orange
              Color(0xFFFFE0B2), // Lighter orange
            ],
          ),
        ),
        child: Consumer<CustomerProvider>(
          builder: (context, customerProvider, child) {
            // Filter customers based on the search query
            final filteredCustomers = customerProvider.customers.where((customer) {
              return customer.name.toLowerCase().contains(_searchQuery);
            }).toList();

            // Check if customers have been loaded
            if (filteredCustomers.isEmpty) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xFFFF8A65)),
                ),
              );
            }

            // Display filtered customers in a ListView
            return ListView.builder(
              itemCount: filteredCustomers.length,
              itemBuilder: (context, index) {
                final customer = filteredCustomers[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    leading: CircleAvatar(
                      backgroundColor: Color(0xFFFFB74D).withOpacity(0.2),
                      child: Text(
                        customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: Color(0xFFE65100),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      customer.name,
                      style: TextStyle(
                        color: Color(0xFFE65100), // Dark orange text
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      customer.phone,
                      style: TextStyle(
                        color: Colors.grey[700],
                      ),
                    ),
                    trailing: Icon(Icons.chevron_right, color: Color(0xFFFF8A65)),
                    onTap: () {
                      _showReportOptions(
                        context,
                        customer.name,
                        customer.phone,
                        customer.id,
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
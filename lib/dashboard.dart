import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:onex_gas_appliances/roznamchaPage.dart';
import 'package:onex_gas_appliances/simplecashbook/simplecashbook.dart';
import 'package:onex_gas_appliances/userspage.dart';
import 'package:onex_gas_appliances/vendors/vendorchequepage.dart';
import 'package:onex_gas_appliances/vendors/viewvendors.dart';
import 'package:provider/provider.dart';
import 'Auth/login.dart';
import 'Category/categorylistpage.dart';
import 'Category/categorymanagement.dart';
import 'Customer/customerlist.dart';
import 'DailyExpensesPages/viewexpensepage.dart';
import 'Employee/employeelist.dart';
import 'Filled/filledlist.dart';
import 'Filled/quotationlistpage.dart';
import 'NewEmployee/employeemainpage.dart';
import 'Purchase/Purchase Order page.dart';
import 'Purchase/purchaseorderlist.dart';
import 'Reminders/reminderslistpage.dart';
import 'Provider/lanprovider.dart';
import 'Reports/balancesummarypage.dart';
import 'Reports/ledgerselcttion.dart';
import 'Reports/reportselecttionpage.dart';
import 'bankmanagement/addbank.dart';
import 'cashbook/cashbook.dart';
import 'chequeManagement/chequeManagement.dart';
import 'chequePayments/newchequelist.dart';
import 'items/ItemslistPage.dart';
import 'items/inandoutpage.dart';
import 'Purchase/purchaselistpage.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {

  // void _logout(BuildContext context){
  //   Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context)=>LoginPage()  ), (Route<dynamic>route)=>false);
  // }
  void _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
            (Route<dynamic> route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _navigateTo(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF8A65), Color(0xFFFFB74D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          languageProvider.isEnglish ? 'Dashboard' : 'ڈیش بورڈ',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            color: Colors.white,

          ),
        ),
        centerTitle: true,
        elevation: 4,
        shadowColor: Colors.blue.withOpacity(0.2),
        actions: [
          IconButton(
            icon: const Icon(Icons.language,color: Colors.white,),
            onPressed: languageProvider.toggleLanguage,
            tooltip: languageProvider.isEnglish ? 'Switch to Urdu' : 'انگریزی میں تبدیل کریں',
          ),
        ],
      ),
      // drawer: _buildDrawer(context, languageProvider),
      body: MediaQuery.of(context).size.width > 600
          ? Row(
        children: [
          _buildSidebar(context, languageProvider),
          const VerticalDivider(width: 1),
          Expanded(child: _buildContent(context, languageProvider)),
        ],
      )
          : _buildContent(context, languageProvider),

      bottomNavigationBar: MediaQuery.of(context).size.width <= 600
          ? BottomNavigationBar(
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: languageProvider.isEnglish ? 'Home' : 'ہوم',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.add),
            label: languageProvider.isEnglish ? 'Transactions' : 'لین دین',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: languageProvider.isEnglish ? 'Settings' : 'ترتیبات',
          ),
        ],
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Dashboard()),
              );
              break;
            case 1:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LedgerSelection()),
              );
              break;
            case 2:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => UsersPage()),
              );
              break;
          }
        },
      )
          : null,
    );
  }

  Widget _buildSidebar(BuildContext context, LanguageProvider languageProvider) {
    return Container(
      width: 240,
      color: Colors.grey[100],
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          const SizedBox(height: 20),
          Center(
            child: Image.asset('assets/images/logo.png', width: 150),
          ),
          const SizedBox(height: 20),
          _sidebarItem(Icons.home, 'Home', 'ہوم', () => _navigateTo(context, const Dashboard()), languageProvider),
          _sidebarItem(Icons.notifications, 'Reminders', 'یاددہانی', () => _navigateTo(context, const ReminderListPage()), languageProvider),
          _sidebarItem(Icons.list, 'Items List', 'ٹوٹل آئٹمز', () => _navigateTo(context, ItemsListPage()), languageProvider),
          _sidebarItem(Icons.shopping_cart, 'Category management', 'کیٹاگوری منیجمنٹ', () => _navigateTo(context, ListCategoriesPage()), languageProvider),
          _sidebarItem(Icons.shopping_cart, 'Purchase Order', 'خریداری کا آرڈر', () => _navigateTo(context, PurchaseOrderListPage()), languageProvider),
          _sidebarItem(Icons.shopping_cart, 'Purchase', 'خریداری', () => _navigateTo(context, PurchaseListPage()), languageProvider),
          _sidebarItem(Icons.store, 'Vendors', 'بیچنے والا', () => _navigateTo(context, const ViewVendorsPage()), languageProvider),
          _sidebarItem(Icons.account_balance_wallet, 'Transactions', 'لین دین', () => _navigateTo(context, const LedgerSelection()), languageProvider),
          _sidebarItem(Icons.food_bank_outlined, 'Bank Management', 'بینک مینجمنٹ', () => _navigateTo(context, BankManagementPage()), languageProvider),
          _sidebarItem(Icons.access_time_filled_outlined, 'Customer Cheque Management', 'کسٹمر چیک مینجمنٹ', () => _navigateTo(context, ChequeManagementPage()), languageProvider),
          _sidebarItem(Icons.access_time_filled_outlined, 'Vendor Cheque Management', 'ونڈر چیک مینجمنٹ', () => _navigateTo(context, VendorChequesPage()), languageProvider),
          _sidebarItem(Icons.currency_bitcoin_sharp, 'Cash Book', 'کیش بک', () => _navigateTo(context, CashbookPage()), languageProvider),
          _sidebarItem(Icons.account_balance, 'Simple Cash Book', 'سمپل کیش بک', () => _navigateTo(context, SimpleCashbookPage()), languageProvider),
          _sidebarItem(Icons.assignment, 'Roznamcha', 'روزنامچہ', () => _navigateTo(context, const Roznamchapage()), languageProvider),
          _sidebarItem(Icons.assignment, 'Item In & Out', 'سٹاک رپورٹ', () => _navigateTo(context, ItemTransactionReportPage()), languageProvider),
          _sidebarItem(Icons.settings, 'Settings', 'ترتیبات', () => _navigateTo(context, UsersPage()), languageProvider),
          const Divider(),
          _sidebarItem(Icons.logout, 'Logout', 'لاگ آوٹ', () => _logout(context), languageProvider, isLogout: true),
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String en, String ur, VoidCallback onTap, LanguageProvider lang, {bool isLogout = false}) {
    return ListTile(
      leading: Icon(icon, color: isLogout ? Colors.red : Colors.blueAccent),
      title: Text(lang.isEnglish ? en : ur, style: TextStyle(color: isLogout ? Colors.red : null)),
      onTap: onTap,
    );
  }

  Widget _buildContent(BuildContext context, LanguageProvider languageProvider) {
    _checkReminders(context);

    final isWeb = MediaQuery.of(context).size.width > 600;
    final crossAxisCount = isWeb ? 4 : 2;

    final dashboardItems = [
      {'icon': Icons.receipt_long, 'titleEn': 'Quotation', 'titleUr': 'بل اندراج', 'color': Colors.deepPurple, 'page': QuotationListPage()},
      {'icon': Icons.inventory, 'titleEn': 'Invoice', 'titleUr': 'انوائس اندراج', 'color': Colors.orange, 'page': filledListpage()},
      {'icon': Icons.attach_money, 'titleEn': 'Expenses', 'titleUr': 'اخراجات', 'color': Colors.redAccent, 'page': ViewExpensesPage()},
      {'icon': Icons.engineering, 'titleEn': 'Employee', 'titleUr': 'ورکر', 'color': Colors.teal, 'page': HomeScreen()},
      {'icon': Icons.group, 'titleEn': 'Customers', 'titleUr': 'کسٹمرز', 'color': Colors.blueAccent, 'page': CustomerList()},
      {'icon': Icons.account_balance_wallet, 'titleEn': 'View Ledger', 'titleUr': 'کھاتہ دیکھیں', 'color': Colors.green, 'page': const LedgerSelection()},
      {'icon': Icons.analytics, 'titleEn': 'Reports', 'titleUr': 'رپورٹس', 'color': Colors.indigo, 'page': const ReportsPage()},
      {'icon': Icons.analytics, 'titleEn': 'Balance Summary', 'titleUr': 'بیلنس سمری', 'color': Colors.indigo, 'page': const BalanceSummaryPage()},
      {'icon': Icons.settings, 'titleEn': 'Settings', 'titleUr': 'ترتیبات', 'color': Colors.grey, 'page': UsersPage()},
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        itemCount: dashboardItems.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: 1.0,
        ),
        itemBuilder: (context, index) {
          final item = dashboardItems[index];
          return _buildDashboardCard(
            item['icon'] as IconData,
            languageProvider.isEnglish ? item['titleEn'] as String : item['titleUr'] as String,
            item['color'] as Color,
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => item['page'] as Widget)),
            isWeb,
          );
        },
      ),
    );
  }

  Widget _buildDashboardCard(IconData icon, String title, Color color, VoidCallback onTap, bool isWeb) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: isWeb
                ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ]
                : [],
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade200),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                radius: 28,
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isWeb ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _checkReminders(BuildContext context) async {
    final ref = FirebaseDatabase.instance.ref().child('reminders');
    final snapshot = await ref.get();

    if (!snapshot.exists) return;

    final today = DateTime.now();
    final Map reminders = snapshot.value as Map;

    List<Map<String, dynamic>> alertsToShow = [];

    for (var entry in reminders.entries) {
      final reminder = entry.value;
      if (reminder['showAlert'] == true) {
        DateTime reminderDate = DateTime.parse(reminder['date']);
        bool isDueOrPast = !reminderDate.isAfter(today);

        if (isDueOrPast) {
          alertsToShow.add({
            'title': reminder['title'],
            'date': reminderDate,
          });
        }
      }
    }

    if (alertsToShow.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text("Reminders Due"),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: alertsToShow.map((reminder) {
                  return ListTile(
                    leading: const Icon(Icons.notification_important, color: Colors.red),
                    title: Text(reminder['title']),
                    subtitle: Text(
                      "Due: ${reminder['date'].toLocal().toString().split(' ')[0]}",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          ),
        );
      });
    }
  }
}


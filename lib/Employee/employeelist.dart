import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:onex_gas_appliances/Employee/salary_report.dart';
import 'package:provider/provider.dart';

import '../Provider/employeeprovider.dart';
import '../Provider/lanprovider.dart';
import 'addemployee.dart';
import 'attendance.dart';

class EmployeeListPage extends StatefulWidget {
  @override
  _EmployeeListPageState createState() => _EmployeeListPageState();
}

class _EmployeeListPageState extends State<EmployeeListPage>
    with TickerProviderStateMixin {
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, dynamic> _todaysAttendance = {};
  bool _isAttendanceLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final DatabaseReference _expensesRef = FirebaseDatabase.instance.ref().child('expenses');

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    _animationController.forward();

    // FIXED: Use Future.microtask instead of addPostFrameCallback
    // This ensures provider is ready before fetching
    Future.microtask(() {
      if (mounted) {
        _fetchTodaysAttendance();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchTodaysAttendance() async {
    if (!mounted) return;

    setState(() {
      _isAttendanceLoading = true;
    });

    try {
      final provider = Provider.of<EmployeeProvider>(context, listen: false);
      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final allEmployees = provider.employees;

      // FIXED: Check if employees map is empty
      if (allEmployees.isEmpty) {
        if (mounted) {
          setState(() {
            _todaysAttendance = {};
            _isAttendanceLoading = false;
          });
        }
        return;
      }

      Map<String, dynamic> fetchedAttendance = {};

      // FIXED: Add timeout to prevent infinite loading
      await Future.wait(
        allEmployees.entries.map((entry) async {
          final employeeId = entry.key;
          try {
            final attendanceMap = await provider.getAttendanceForDateRange(
              employeeId,
              DateTimeRange(start: today, end: today),
            ).timeout(
              Duration(seconds: 5),
              onTimeout: () {
                print('Timeout fetching attendance for employee: $employeeId');
                return {};
              },
            );

            if (attendanceMap.containsKey(dateKey)) {
              fetchedAttendance[employeeId] = attendanceMap[dateKey];
            }
          } catch (e) {
            print('Error fetching attendance for $employeeId: $e');
            // Continue with other employees even if one fails
          }
        }),
        eagerError: false, // Don't stop on first error
      );

      if (mounted) {
        setState(() {
          _todaysAttendance = fetchedAttendance;
          _isAttendanceLoading = false;
        });

        // FIXED: Add debug logging
        print('Fetched attendance for ${fetchedAttendance.length} employees');
      }
    } catch (e) {
      print('Critical error in _fetchTodaysAttendance: $e');
      if (mounted) {
        setState(() {
          _isAttendanceLoading = false;
          _todaysAttendance = {}; // Reset to empty instead of keeping stale data
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load attendance: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5), // Longer duration for error
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _fetchTodaysAttendance,
            ),
          ),
        );
      }
    }
  }

  void _showExpenseDialog(String employeeId, String employeeName) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isEnglish = languageProvider.isEnglish;

    TextEditingController amountController = TextEditingController();
    TextEditingController descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.attach_money_rounded, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text(isEnglish ? 'Add Expense' : 'اخراجات شامل کریں'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEnglish ? 'For $employeeName' : '$employeeName کے لیے',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: isEnglish ? 'Amount' : 'رقم',
                prefixIcon: Icon(Icons.attach_money_rounded),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: isEnglish ? 'Description' : 'تفصیل',
                prefixIcon: Icon(Icons.description_rounded),
              ),
            ),
            SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.calendar_today_rounded),
              title: Text(isEnglish ? 'Date' : 'تاریخ'),
              subtitle: Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null && picked != selectedDate) {
                  setState(() {
                    selectedDate = picked;
                  });
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isEnglish ? 'Cancel' : 'منسوخ کریں'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF10B981)),
            onPressed: () async {
              if (amountController.text.isEmpty || descriptionController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isEnglish ? 'Please fill all fields' : 'براہ کرم تمام فیلڈز بھریں'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                final double amount = double.tryParse(amountController.text) ?? 0.0;
                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEnglish ? 'Please enter valid amount' : 'براہ کرم درست رقم درج کریں'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final provider = Provider.of<EmployeeProvider>(context, listen: false);

                // Show loading
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isEnglish ? 'Adding expense...' : 'اخراجات شامل کیے جا رہے ہیں...'),
                    backgroundColor: Colors.blue,
                    duration: Duration(seconds: 2),
                  ),
                );

                await provider.addExpense(employeeId, {
                  'amount': amount,
                  'description': descriptionController.text,
                  'date': selectedDate.toIso8601String().split('T').first,
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                });

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isEnglish ? 'Expense added successfully!' : 'اخراجات کامیابی سے شامل ہو گئے!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );

                // Refresh the expenses list if it's open
                setState(() {});

              } catch (e) {
                print('Error adding expense: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isEnglish ? 'Failed to add expense: $e' : 'اخراجات شامل کرنے میں ناکامی: $e'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 5),
                  ),
                );
              }
            },
            child: Text(isEnglish ? 'Add' : 'شامل کریں'),
          ),
        ],
      ),
    );
  }

  void _showSalaryDialog(String employeeId, String employeeName) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isEnglish = languageProvider.isEnglish;
    final provider = Provider.of<EmployeeProvider>(context, listen: false);

    TextEditingController basicSalaryController = TextEditingController();

    // Calculate current month's expenses
    final currentMonth = DateTime.now().month;
    final currentYear = DateTime.now().year;
    final monthlyExpenses = provider.calculateMonthlyExpenses(employeeId, currentYear, currentMonth);

    // Load existing salary data
    Future.microtask(() async {
      final salaryData = await provider.getEmployeeSalary(employeeId);
      if (salaryData != null) {
        basicSalaryController.text = (salaryData['basicSalary'] ?? '').toString();
      }
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF667EEA)),
                SizedBox(width: 8),
                Text(isEnglish ? 'Set Salary' : 'تنخواہ مقرر کریں'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isEnglish ? 'For $employeeName' : '$employeeName کے لیے',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),

                  // Monthly Expenses Info
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Color(0xFFFFEEBA)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Color(0xFF856404), size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isEnglish
                                ? 'This month expenses: Rs. ${monthlyExpenses.toStringAsFixed(2)}'
                                : 'اس مہینے کے اخراجات: Rs. ${monthlyExpenses.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 12, color: Color(0xFF856404)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  TextField(
                    controller: basicSalaryController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isEnglish ? 'Salary Amount' : 'تنخواہ کی رقم',
                      prefixIcon: Icon(Icons.money_rounded),
                    ),
                    onChanged: (value) {
                      setDialogState(() {});
                    },
                  ),

                  SizedBox(height: 16),

                  // Salary Summary
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      children: [
                        _buildSalarySummaryRow(
                          isEnglish ? 'Salary:' : 'تنخواہ:',
                          _parseDouble(basicSalaryController.text),
                          Color(0xFF667EEA),
                        ),
                        _buildSalarySummaryRow(
                          isEnglish ? 'Expenses:' : 'اخراجات:',
                          monthlyExpenses,
                          Color(0xFFEF4444),
                        ),
                        Divider(height: 16),
                        _buildSalarySummaryRow(
                          isEnglish ? 'Net Salary:' : 'خالص تنخواہ:',
                          _parseDouble(basicSalaryController.text) - monthlyExpenses,
                          Color(0xFF10B981),
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(isEnglish ? 'Cancel' : 'منسوخ کریں'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF667EEA)),
                onPressed: () async {
                  final basicSalary = _parseDouble(basicSalaryController.text);

                  if (basicSalary <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEnglish ? 'Please enter valid salary amount' : 'براہ کرم درست تنخواہ کی رقم درج کریں'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final provider = Provider.of<EmployeeProvider>(context, listen: false);
                  await provider.setSalary(employeeId, {
                    'basicSalary': basicSalary,
                    'lastUpdated': DateTime.now().millisecondsSinceEpoch,
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEnglish ? 'Salary updated successfully!' : 'تنخواہ کامیابی سے اپ ڈیٹ ہو گئی!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: Text(isEnglish ? 'Save' : 'محفوظ کریں'),
              ),
            ],
          );
        },
      ),
    );
  }

  double _parseDouble(String value) {
    return double.tryParse(value) ?? 0.0;
  }

  Widget _buildSalarySummaryRow(String label, double amount, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            'Rs. ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _showEmployeeDetails(String employeeId, Map<String, String> employee) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isEnglish = languageProvider.isEnglish;
    final provider = Provider.of<EmployeeProvider>(context, listen: false);

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      final currentMonth = DateTime.now().month;
      final currentYear = DateTime.now().year;

      // Fetch salary
      final salaryData = await provider.getEmployeeSalary(employeeId);
      final monthlySalary = (salaryData?['basicSalary'] as num?)?.toDouble() ?? 0.0;

      // Fetch expenses using async method
      final monthlyExpenses = await provider.calculateMonthlyExpensesAsync(employeeId, currentYear, currentMonth);
      final netSalary = monthlySalary - monthlyExpenses;

      // Close loading dialog
      Navigator.pop(context);

      // Show the bottom sheet
      showModalBottomSheet(
        context: context,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        isScrollControlled: true,
        builder: (context) => Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        (employee['name'] ?? '').isNotEmpty ? employee['name']![0].toUpperCase() : '?',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(employee['name'] ?? '', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('ID: $employeeId', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // Net Salary Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF34D399)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      isEnglish ? 'Net Salary This Month' : 'اس مہینے کی خالص تنخواہ',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Rs. ${netSalary.toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // Salary and Expenses Summary
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      title: isEnglish ? 'Monthly Salary' : 'ماہانہ تنخواہ',
                      amount: monthlySalary,
                      color: Color(0xFF667EEA),
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      title: isEnglish ? 'Monthly Expenses' : 'ماہانہ اخراجات',
                      amount: monthlyExpenses,
                      color: Color(0xFFEF4444),
                      icon: Icons.attach_money_rounded,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Divider(),
              SizedBox(height: 16),

              // Action Buttons (keep existing code)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildDetailActionButton(
                    icon: Icons.attach_money_rounded,
                    label: isEnglish ? 'Add Expense' : 'اخراجات شامل کریں',
                    color: Color(0xFF10B981),
                    onTap: () {
                      Navigator.pop(context);
                      _showExpenseDialog(employeeId, employee['name'] ?? '');
                    },
                  ),
                  _buildDetailActionButton(
                    icon: Icons.account_balance_wallet_rounded,
                    label: isEnglish ? 'Set Salary' : 'تنخواہ مقرر کریں',
                    color: Color(0xFF667EEA),
                    onTap: () {
                      Navigator.pop(context);
                      _showSalaryDialog(employeeId, employee['name'] ?? '');
                    },
                  ),
                  _buildDetailActionButton(
                    icon: Icons.list_alt_rounded,
                    label: isEnglish ? 'View Expenses' : 'اخراجات دیکھیں',
                    color: Color(0xFFFF8A65),
                    onTap: () {
                      Navigator.pop(context);
                      _showExpensesList(employeeId, employee['name'] ?? '');
                    },
                  ),
                ],
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading employee details: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSummaryCard({required String title, required double amount, required Color color, required IconData icon}) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 20, color: color),
          ),
          SizedBox(height: 8),
          Text(
            'Rs. ${amount.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
          ],
        ),
      ),
    );
  }

  void _showExpensesList(String employeeId, String employeeName) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isEnglish = languageProvider.isEnglish;
    final provider = Provider.of<EmployeeProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            SizedBox(height: 20),
            Text(
              isEnglish ? 'Expenses - $employeeName' : 'اخراجات - $employeeName',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<DatabaseEvent>(
                stream: _expensesRef.child(employeeId).onValue,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(isEnglish ? 'Error loading expenses' : 'خرچے لوڈ ہونے میں خرابی'),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                    return Center(child: Text(isEnglish ? 'No expenses found' : 'کوئی اخراجات نہیں ملے'));
                  }

                  final expensesData = snapshot.data!.snapshot.value as Map<dynamic, dynamic>?;

                  if (expensesData == null || expensesData.isEmpty) {
                    return Center(child: Text(isEnglish ? 'No expenses found' : 'کوئی اخراجات نہیں ملے'));
                  }

                  final expenses = Map<String, dynamic>.from(expensesData);
                  final expenseList = expenses.entries.toList()
                    ..sort((a, b) => (b.value['timestamp'] ?? 0).compareTo(a.value['timestamp'] ?? 0));

                  return ListView.builder(
                    itemCount: expenseList.length,
                    itemBuilder: (context, index) {
                      final expense = expenseList[index];
                      final data = Map<String, dynamic>.from(expense.value);

                      return ListTile(
                        leading: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.attach_money_rounded, size: 20, color: Color(0xFF10B981)),
                        ),
                        title: Text(data['description'] ?? ''),
                        subtitle: Text(data['date'] ?? ''),
                        trailing: Text(
                          'Rs. ${(data['amount'] ?? 0).toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                        ),
                        onLongPress: () => _confirmDeleteExpense(employeeId, expense.key, data['description'] ?? ''),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteExpense(String employeeId, String expenseId, String description) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isEnglish = languageProvider.isEnglish;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEnglish ? 'Delete Expense?' : 'خرچہ حذف کریں؟'),
        content: Text(isEnglish
            ? 'Are you sure you want to delete expense: $description?'
            : 'کیا آپ واقعی یہ خرچہ حذف کرنا چاہتے ہیں: $description؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isEnglish ? 'Cancel' : 'منسوخ کریں')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await Provider.of<EmployeeProvider>(context, listen: false).deleteExpense(employeeId, expenseId);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(isEnglish ? 'Expense deleted' : 'خرچہ حذف ہو گیا'), backgroundColor: Colors.green),
              );
            },
            child: Text(isEnglish ? 'Delete' : 'حذف کریں', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final employeeProvider = Provider.of<EmployeeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish = languageProvider.isEnglish;

    final filteredEmployees = employeeProvider.employees.entries.where((entry) {
      final employee = entry.value;
      return employee['name']?.toLowerCase().contains(_searchQuery) ?? false;
    }).toList();

    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildModernAppBar(isEnglish),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchTodaysAttendance,
                child: Container(
                  margin: EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          _buildSearchBar(isEnglish),
                          const SizedBox(height: 24),
                          _buildStatsCards(filteredEmployees.length, isEnglish),
                          const SizedBox(height: 24),
                          _buildEmployeeListHeader(isEnglish, filteredEmployees.length),
                          const SizedBox(height: 16),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                if (constraints.maxWidth > 600) {
                                  return _buildWebLayout(isEnglish, filteredEmployees);
                                }
                                return _buildMobileLayout(isEnglish, filteredEmployees);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(isEnglish),
    );
  }

  Widget _buildModernAppBar(bool isEnglish) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF667EEA).withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEnglish ? 'Employee Management' : 'ملازمین کا انتظام',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  isEnglish ? 'Team Overview & Attendance' : 'ٹیم کا جائزہ اور حاضری',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isEnglish) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: isEnglish ? 'Search employees...' : 'ملازمین تلاش کریں...',
          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16),
          prefixIcon: Container(
            margin: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFF667EEA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.search_rounded, color: Colors.white, size: 20),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear_rounded, color: Colors.grey[500]),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
              });
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        ),
      ),
    );
  }

  Widget _buildStatsCards(int totalEmployees, bool isEnglish) {
    final presentCount = _todaysAttendance.values.where((v) => v['status'] == 'present').length;
    final absentCount = _todaysAttendance.values.where((v) => v['status'] == 'absent').length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.people_alt_rounded,
            title: isEnglish ? 'Total Employees' : 'کل ملازم',
            value: totalEmployees.toString(),
            color: Color(0xFF10B981),
            gradient: [Color(0xFF10B981), Color(0xFF34D399)],
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.check_circle_rounded,
            title: isEnglish ? 'Present Today' : 'آج حاضر',
            value: presentCount.toString(),
            color: Color(0xFF3B82F6),
            gradient: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.cancel_rounded,
            title: isEnglish ? 'Absent Today' : 'آج غیرحاضر',
            value: absentCount.toString(),
            color: Color(0xFFEF4444),
            gradient: [Color(0xFFEF4444), Color(0xFFF87171)],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required List<Color> gradient,
  })
  {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeListHeader(bool isEnglish, int count) {
    return Row(
      children: [
        Text(
          isEnglish ? 'Employees' : 'ملازم',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        SizedBox(width: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Color(0xFF667EEA).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF667EEA),
            ),
          ),
        ),
        Spacer(),
        if (_isAttendanceLoading)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                ),
                SizedBox(width: 6),
                Text(
                  isEnglish ? 'Loading...' : 'لوڈ ہو رہا ہے...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.amber[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildWebLayout(bool isEnglish, List<MapEntry<String, Map<String, String>>> employees) {
    if (_isAttendanceLoading && employees.isEmpty) {
      return Center(child: CircularProgressIndicator(color: Color(0xFF667EEA)));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          child: DataTable(
            columnSpacing: 30,
            horizontalMargin: 30,
            dataRowHeight: 70,
            headingRowHeight: 60,
            headingRowColor: MaterialStateProperty.all(Color(0xFF667EEA).withOpacity(0.05)),
            columns: [
              _buildDataColumn(isEnglish ? 'Employee' : 'ملازم'),
              _buildDataColumn(isEnglish ? 'Contact Info' : 'رابطے کی معلومات'),
              _buildDataColumn(isEnglish ? 'Status' : 'حالت'),
              _buildDataColumn(isEnglish ? 'Actions' : 'اعمال'),
            ],
            rows: employees.map((entry) => _buildDataRow(entry, isEnglish)).toList(),
          ),
        ),
      ),
    );
  }

  DataColumn _buildDataColumn(String label) {
    return DataColumn(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF667EEA),
          fontSize: 14,
        ),
      ),
    );
  }

  DataRow _buildDataRow(MapEntry<String, Map<String, String>> entry, bool isEnglish) {
    final id = entry.key;
    final employee = entry.value;
    final alreadyMarked = _todaysAttendance.containsKey(id);
    final attendanceStatus = _todaysAttendance[id]?['status'];

    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    (employee['name'] ?? '').isNotEmpty
                        ? employee['name']![0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    employee['name'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.grey[800],
                    ),
                  ),
                  Text(
                    'ID: $id',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on_rounded, size: 14, color: Colors.grey[500]),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      employee['address'] ?? '',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.phone_rounded, size: 14, color: Colors.grey[500]),
                  SizedBox(width: 6),
                  Text(
                    employee['phone'] ?? '',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
            ],
          ),
        ),
        DataCell(
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _getStatusColor(attendanceStatus, alreadyMarked).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _getStatusColor(attendanceStatus, alreadyMarked).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getStatusColor(attendanceStatus, alreadyMarked),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  _getStatusText(attendanceStatus, alreadyMarked, isEnglish, _todaysAttendance[id]), // Add the 4th parameter
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(attendanceStatus, alreadyMarked),
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(
          Row(
            children: [
              _buildModernActionButton(
                icon: Icons.edit_rounded,
                color: Color(0xFF10B981),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddEmployeePage(employeeId: id)),
                ),
              ),
              SizedBox(width: 8),
              _buildModernActionButton(
                icon: Icons.delete_rounded,
                color: Color(0xFFEF4444),
                onPressed: () => _confirmDelete(id),
              ),
              // Add this button in the actions section of both layouts
              _buildModernActionButton(
                icon: Icons.info_outline_rounded,
                color: Color(0xFF667EEA),
                onPressed: () => _showEmployeeDetails(id, employee),
              ),
              SizedBox(width: 12),
              _buildAttendanceButtons(id, isEnglish),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String? status, bool alreadyMarked) {
    if (!alreadyMarked) return Colors.grey;
    return status == 'present' ? Color(0xFF10B981) : Color(0xFFEF4444);
  }

// In _getStatusText method, modify to include time
  String _getStatusText(String? status, bool alreadyMarked, bool isEnglish, Map<String, dynamic>? attendanceData) {
    if (!alreadyMarked) return isEnglish ? 'Not Marked' : 'نشان نہیں لگایا';

    final time = attendanceData?['time'] ?? '';
    final statusText = status == 'present'
        ? (isEnglish ? 'Present' : 'حاضر')
        : (isEnglish ? 'Absent' : 'غیرحاضر');

    return time.isNotEmpty ? '$statusText ($time)' : statusText;
  }

  Widget _buildAttendanceButtons(String id, bool isEnglish) {
    if (_isAttendanceLoading) {
      return Container(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF667EEA)),
      );
    }

    final alreadyMarked = _todaysAttendance.containsKey(id);

    return Row(
      children: [
        _buildStatusButton(
          label: isEnglish ? 'Present' : 'حاضر',
          color: Color(0xFF10B981),
          alreadyMarked: alreadyMarked,
          onPressed: () => _markAttendance(context, id, 'present'),
        ),
        SizedBox(width: 8),
        _buildStatusButton(
          label: isEnglish ? 'Absent' : 'غیرحاضر',
          color: Color(0xFFEF4444),
          alreadyMarked: alreadyMarked,
          onPressed: () => _markAttendance(context, id, 'absent'),
        ),
      ],
    );
  }

  Widget _buildModernActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: color, size: 18),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildStatusButton({
    required String label,
    required Color color,
    required bool alreadyMarked,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 32,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: alreadyMarked ? Colors.grey[100] : color,
          foregroundColor: alreadyMarked ? Colors.grey[500] : Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: alreadyMarked ? 0 : 2,
          shadowColor: color.withOpacity(0.3),
        ),
        onPressed: alreadyMarked ? null : onPressed,
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(bool isEnglish, List<MapEntry<String, Map<String, String>>> employees) {
    if (_isAttendanceLoading && employees.isEmpty) {
      return Center(child: CircularProgressIndicator(color: Color(0xFF667EEA)));
    }

    return ListView.builder(
      itemCount: employees.length,
      itemBuilder: (context, index) {
        final entry = employees[index];
        final id = entry.key;
        final employee = entry.value;
        final alreadyMarked = _todaysAttendance.containsKey(id);
        final attendanceStatus = _todaysAttendance[id]?['status'];

        return Container(
          margin: EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          (employee['name'] ?? '').isNotEmpty
                              ? employee['name']![0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            employee['name'] ?? '',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'ID: $id',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getStatusColor(attendanceStatus, alreadyMarked).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getStatusColor(attendanceStatus, alreadyMarked).withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(attendanceStatus, alreadyMarked),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  // _getStatusText(attendanceStatus, alreadyMarked, isEnglish),
                                  _getStatusText(attendanceStatus, alreadyMarked, isEnglish, _todaysAttendance[id]), // Add the 4th parameter
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _getStatusColor(attendanceStatus, alreadyMarked),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                _buildMobileInfoRow(Icons.location_on_rounded, employee['address'] ?? '', Color(0xFF667EEA)),
                _buildMobileInfoRow(Icons.phone_rounded, employee['phone'] ?? '', Color(0xFF10B981)),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          _buildStatusButton(
                            label: isEnglish ? 'Present' : 'حاضر',
                            color: Color(0xFF10B981),
                            alreadyMarked: alreadyMarked,
                            onPressed: () => _markAttendance(context, id, 'present'),
                          ),
                          SizedBox(width: 12),
                          _buildStatusButton(
                            label: isEnglish ? 'Absent' : 'غیرحاضر',
                            color: Color(0xFFEF4444),
                            alreadyMarked: alreadyMarked,
                            onPressed: () => _markAttendance(context, id, 'absent'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12),
                    _buildModernActionButton(
                      icon: Icons.edit_rounded,
                      color: Color(0xFF10B981),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AddEmployeePage(employeeId: id)),
                      ),
                    ),
                    // Add this button in the actions section of both layouts
                    _buildModernActionButton(
                      icon: Icons.info_outline_rounded,
                      color: Color(0xFF667EEA),
                      onPressed: () => _showEmployeeDetails(id, employee),
                    ),
                    SizedBox(width: 8),
                    _buildModernActionButton(
                      icon: Icons.delete_rounded,
                      color: Color(0xFFEF4444),
                      onPressed: () => _confirmDelete(id),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileInfoRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton(bool isEnglish) {
    return FloatingActionButton(
      heroTag: "main_fab",
      onPressed: () {
        showModalBottomSheet(
          context: context,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (context) => Container(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 24),
                _buildMenuOption(
                  icon: Icons.add_rounded,
                  title: isEnglish ? 'Add Employee' : 'ملازم شامل کریں',
                  color: Color(0xFF10B981),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AddEmployeePage()),
                    );
                  },
                ),
                SizedBox(height: 16),
                _buildMenuOption(
                  icon: Icons.analytics_rounded,
                  title: isEnglish ? 'Attendance Report' : 'حاضری کی رپورٹ',
                  color: Color(0xFF667EEA),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AttendanceReportPage()),
                    );
                  },
                ),
                SizedBox(height: 16),
                // In the _buildFloatingActionButton method, add this option:
                _buildMenuOption(
                  icon: Icons.account_balance_wallet_rounded,
                  title: isEnglish ? 'Salary Report' : 'تنخواہ رپورٹ',
                  color: Color(0xFF10B981),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SalaryReportPage()),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
      backgroundColor: Color(0xFF667EEA),
      child: Icon(Icons.add_rounded, color: Colors.white),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.grey[800],
        ),
      ),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[400]),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  void _confirmDelete(String id) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isEnglish = languageProvider.isEnglish;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.warning_rounded, color: Colors.red, size: 24),
            ),
            SizedBox(width: 12),
            Text(
              isEnglish ? 'Delete Employee' : 'ملازم حذف کریں',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          isEnglish
              ? 'Are you sure you want to permanently delete this employee? This action cannot be undone.'
              : 'کیا آپ واقعی اس ملازم کو مستقل طور پر حذف کرنا چاہتے ہیں؟ یہ عمل واپس نہیں ہو سکتا۔',
          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              isEnglish ? 'Cancel' : 'منسوخ کریں',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              try {
                await Provider.of<EmployeeProvider>(context, listen: false)
                    .deleteEmployee(id);
                Navigator.pop(ctx);
              } catch (e) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isEnglish
                        ? 'Deletion failed: $e'
                        : 'حذف ہونے میں ناکام: $e'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
            child: Text(
              isEnglish ? 'Delete' : 'حذف کریں',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _markAttendance(BuildContext parentContext, String id, String status) {
    final languageProvider = Provider.of<LanguageProvider>(parentContext, listen: false);
    final isEnglish = languageProvider.isEnglish;
    String description = '';
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: parentContext,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Color(0xFF667EEA).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.calendar_today_rounded, color: Color(0xFF667EEA), size: 20),
                  ),
                  SizedBox(width: 12),
                  Text(
                    isEnglish
                        ? 'Mark Attendance as ${status.capitalize()}'
                        : '${status == 'present' ? 'حاضر' : 'غیرحاضر'} کے طور پر حاضری درج کریں',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEnglish
                          ? 'Please provide details for the ${status} status:'
                          : 'کی حالت کے لئے تفصیلات فراہم کریں:''${status == 'present' ? 'حاضر' : 'غیرحاضر'}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    SizedBox(height: 16),

                    // Date Picker
                    ListTile(
                      leading: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.calendar_today_rounded, size: 20, color: Color(0xFF10B981)),
                      ),
                      title: Text(isEnglish ? 'Date' : 'تاریخ'),
                      subtitle: Text(
                        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      trailing: Icon(Icons.arrow_drop_down_rounded),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(Duration(days: 1)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: Color(0xFF667EEA),
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                  onSurface: Colors.black,
                                ),
                                dialogBackgroundColor: Colors.white,
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null && picked != selectedDate) {
                          setDialogState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                    ),

                    // Time Picker
                    ListTile(
                      leading: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Color(0xFF667EEA).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.access_time_rounded, size: 20, color: Color(0xFF667EEA)),
                      ),
                      title: Text(isEnglish ? 'Time' : 'وقت'),
                      subtitle: Text(
                        selectedTime.format(context),
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      trailing: Icon(Icons.arrow_drop_down_rounded),
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: Color(0xFF667EEA),
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                  onSurface: Colors.black,
                                ),
                                dialogBackgroundColor: Colors.white,
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null && picked != selectedTime) {
                          setDialogState(() {
                            selectedTime = picked;
                          });
                        }
                      },
                    ),

                    SizedBox(height: 16),

                    // Description Field
                    Text(
                      isEnglish ? 'Description (Optional)' : 'تفصیل (اختیاری)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      onChanged: (value) {
                        description = value;
                      },
                      decoration: InputDecoration(
                        hintText: isEnglish
                            ? 'Enter description...'
                            : 'تفصیل درج کریں...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      maxLines: 3,
                    ),

                    // Selected Date & Time Summary
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: Colors.blue),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isEnglish
                                  ? 'Attendance will be marked for ${selectedDate.day}/${selectedDate.month}/${selectedDate.year} at ${selectedTime.format(context)}'
                                  : 'حاضری ${selectedDate.day}/${selectedDate.month}/${selectedDate.year} کو ${selectedTime.format(context)} بجے درج کی جائے گی',
                              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: Text(isEnglish ? 'Cancel' : 'رد کریں'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF667EEA),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    // Combine date and time
                    final DateTime combinedDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );

                    final dateKey = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

                    await Provider.of<EmployeeProvider>(parentContext, listen: false)
                        .markAttendance(parentContext, id, status, description, combinedDateTime);

                    Navigator.pop(dialogContext);

                    if (mounted) {
                      setState(() {
                        _todaysAttendance[id] = {
                          'status': status,
                          'description': description,
                          'date': dateKey,
                          'time': '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                        };
                      });
                    }

                    await Future.delayed(Duration(milliseconds: 300));
                    await _fetchTodaysAttendance();

                    if (mounted) {
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        SnackBar(
                          content: Text(isEnglish
                              ? 'Attendance marked successfully!'
                              : 'حاضری کامیابی سے درج ہو گئی!'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }
                  },
                  child: Text(isEnglish ? 'Confirm' : 'تصدیق کریں'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1).toLowerCase()}";
  }
}
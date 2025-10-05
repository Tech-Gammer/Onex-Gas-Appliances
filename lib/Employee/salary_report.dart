import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Provider/employeeprovider.dart';
import '../Provider/lanprovider.dart';

class SalaryReportPage extends StatefulWidget {
  @override
  _SalaryReportPageState createState() => _SalaryReportPageState();
}

class _SalaryReportPageState extends State<SalaryReportPage> {
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );

  Map<String, Map<String, dynamic>> _salaryReports = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateSalaryReports();

      // Listen to provider changes
      Provider.of<EmployeeProvider>(context, listen: false).addListener(() {
        if (mounted) {
          _calculateSalaryReports();
        }
      });
    });
  }

  Future<void> _calculateSalaryReports() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    final provider = Provider.of<EmployeeProvider>(context, listen: false);

    Map<String, Map<String, dynamic>> reports = {};

    for (var employeeEntry in provider.employees.entries) {
      final employeeId = employeeEntry.key;
      final employee = employeeEntry.value;

      try {
        // Get salary data
        final salaryData = await provider.getEmployeeSalary(employeeId);
        final basicSalary = (salaryData?['basicSalary'] as num?)?.toDouble() ?? 0.0;

        // Use async method to get expenses
        final totalExpenses = await provider.calculateExpensesInDateRangeAsync(employeeId, _selectedDateRange);
        final netSalary = basicSalary - totalExpenses;

        // Count expenses
        final snapshot = await FirebaseDatabase.instance.ref().child('expenses').child(employeeId).get();
        int expensesCount = 0;
        if (snapshot.exists && snapshot.value != null) {
          final expensesData = snapshot.value as Map;
          expensesData.forEach((key, value) {
            if (value is Map) {
              final dateString = value['date'];
              if (dateString != null) {
                try {
                  final expenseDate = DateTime.parse(dateString);
                  if ((expenseDate.isAtSameMomentAs(_selectedDateRange.start) || expenseDate.isAfter(_selectedDateRange.start)) &&
                      (expenseDate.isAtSameMomentAs(_selectedDateRange.end) || expenseDate.isBefore(_selectedDateRange.end.add(Duration(days: 1))))) {
                    expensesCount++;
                  }
                } catch (e) {}
              }
            }
          });
        }

        reports[employeeId] = {
          'basicSalary': basicSalary,
          'totalExpenses': totalExpenses,
          'netSalary': netSalary,
          'expensesCount': expensesCount,
          'employeeName': employee['name'] ?? 'Unknown',
        };

        print('Report for ${employee['name']}: Salary=$basicSalary, Expenses=$totalExpenses, Net=$netSalary');

      } catch (e) {
        print('Error calculating salary for $employeeId: $e');
        reports[employeeId] = {
          'basicSalary': 0.0,
          'totalExpenses': 0.0,
          'netSalary': 0.0,
          'expensesCount': 0,
          'employeeName': employee['name'] ?? 'Unknown',
        };
      }
    }

    if (mounted) {
      setState(() {
        _salaryReports = reports;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _selectedDateRange,
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
        _isLoading = true;
      });
      await _calculateSalaryReports();
    }
  }

  void _showExpenseDetails(String employeeId, String employeeName) {
    final provider = Provider.of<EmployeeProvider>(context, listen: false);
    final expenses = provider.getExpensesInDateRange(employeeId, _selectedDateRange);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isEnglish = languageProvider.isEnglish;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${isEnglish ? 'Expenses for' : 'کے اخراجات'} $employeeName'),
        content: Container(
          width: double.maxFinite,
          child: expenses.isEmpty
              ? Text(isEnglish ? 'No expenses in selected date range' : 'منتخب کردہ تاریخ کی حد میں کوئی اخراجات نہیں ہیں')
              : ListView.builder(
            shrinkWrap: true,
            itemCount: expenses.length,
            itemBuilder: (context, index) {
              final expenseEntry = expenses.entries.toList()[index];
              final expenseData = expenseEntry.value;
              return ListTile(
                title: Text(expenseData['description'] ?? 'No Description'),
                subtitle: Text(expenseData['date'] ?? 'No Date'),
                trailing: Text('Rs. ${((expenseData['amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}'),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isEnglish ? 'Close' : 'بند کریں'),
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

    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(isEnglish ? 'Salary Report' : 'تنخواہ رپورٹ'),
        backgroundColor: Color(0xFF667EEA),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _calculateSalaryReports,
            tooltip: isEnglish ? 'Refresh' : 'تازہ کریں',
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Range Picker Card
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, color: Color(0xFF667EEA)),
                    SizedBox(width: 12),
                    Text(
                      isEnglish ? 'Select Date Range' : 'تاریخ کی حد منتخب کریں',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                InkWell(
                  onTap: () => _selectDateRange(context),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFF667EEA).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Color(0xFF667EEA).withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_selectedDateRange.start.day}/${_selectedDateRange.start.month}/${_selectedDateRange.start.year}',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '${_selectedDateRange.end.day}/${_selectedDateRange.end.month}/${_selectedDateRange.end.year}',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF667EEA)),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  isEnglish
                      ? 'Expenses within this range will be deducted from salary'
                      : 'اس حد کے اندر اخراجات تنخواہ سے منہا کیے جائیں گے',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Summary Card
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  isEnglish ? 'Total Salary' : 'کل تنخواہ',
                  _calculateTotalSalary(),
                  Colors.white,
                ),
                _buildSummaryItem(
                  isEnglish ? 'Total Expenses' : 'کل اخراجات',
                  _calculateTotalExpenses(),
                  Colors.white,
                ),
                _buildSummaryItem(
                  isEnglish ? 'Net Payable' : 'قابل ادائیگی',
                  _calculateNetPayable(),
                  Colors.white,
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Employee List Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  isEnglish ? 'Employee Salary Breakdown' : 'ملازم کی تنخواہ کی تفصیل',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Spacer(),
                Text(
                  '${employeeProvider.employees.length} ${isEnglish ? 'Employees' : 'ملازم'}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Employee Salary List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: Color(0xFF667EEA)))
                : employeeProvider.employees.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_alt_outlined, size: 64, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    isEnglish ? 'No Employees Found' : 'کوئی ملازم نہیں ملا',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: employeeProvider.employees.length,
              itemBuilder: (context, index) {
                final employeeEntry = employeeProvider.employees.entries.toList()[index];
                final employeeId = employeeEntry.key;
                final employee = employeeEntry.value;
                final report = _salaryReports[employeeId] ?? {
                  'basicSalary': 0.0,
                  'totalExpenses': 0.0,
                  'netSalary': 0.0,
                  'expensesCount': 0,
                };

                return _buildEmployeeSalaryCard(
                  employeeId,
                  employee,
                  report,
                  isEnglish,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String title, double amount, Color color) {
    return Column(
      children: [
        Text(
          'Rs. ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            color: color.withOpacity(0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  double _calculateTotalSalary() {
    double total = 0;
    _salaryReports.forEach((employeeId, report) {
      total += (report['basicSalary'] ?? 0).toDouble();
    });
    return total;
  }

  double _calculateTotalExpenses() {
    double total = 0;
    _salaryReports.forEach((employeeId, report) {
      total += (report['totalExpenses'] ?? 0).toDouble();
    });
    return total;
  }

  double _calculateNetPayable() {
    return _calculateTotalSalary() - _calculateTotalExpenses();
  }

  Widget _buildEmployeeSalaryCard(
      String employeeId,
      Map<String, String> employee,
      Map<String, dynamic> report,
      bool isEnglish,
      ) {
    final basicSalary = (report['basicSalary'] ?? 0).toDouble();
    final totalExpenses = (report['totalExpenses'] ?? 0).toDouble();
    final netSalary = (report['netSalary'] ?? 0).toDouble();
    final expensesCount = (report['expensesCount'] ?? 0).toInt();

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      (employee['name'] ?? '').isNotEmpty ? employee['name']![0].toUpperCase() : '?',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee['name'] ?? 'No Name',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'ID: $employeeId',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.info_outline, color: Color(0xFF667EEA)),
                  onPressed: () => _showExpenseDetails(employeeId, employee['name'] ?? ''),
                  tooltip: isEnglish ? 'View Expenses' : 'اخراجات دیکھیں',
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: netSalary >= 0 ? Color(0xFF10B981).withOpacity(0.1) : Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Rs. ${netSalary.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: netSalary >= 0 ? Color(0xFF10B981) : Color(0xFFEF4444),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildBreakdownItem(
                  isEnglish ? 'Salary' : 'تنخواہ',
                  basicSalary,
                  Color(0xFF667EEA),
                ),
                _buildBreakdownItem(
                  isEnglish ? 'Expenses' : 'اخراجات',
                  totalExpenses,
                  Color(0xFFEF4444),
                ),
                _buildBreakdownItem(
                  '${expensesCount} ${isEnglish ? 'Items' : 'اشیاء'}',
                  totalExpenses,
                  Color(0xFFFF8A65),
                  showAmount: false,
                ),
              ],
            ),
            if (expensesCount > 0) ...[
              SizedBox(height: 8),
              Text(
                '${isEnglish ? 'View' : 'دیکھیں'} $expensesCount ${isEnglish ? 'expenses' : 'اخراجات'}',
                style: TextStyle(color: Colors.blue, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownItem(String title, double amount, Color color, {bool showAmount = true}) {
    return Column(
      children: [
        Text(
          showAmount ? 'Rs. ${amount.toStringAsFixed(2)}' : title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        SizedBox(height: 4),
        Text(
          showAmount ? title : '',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
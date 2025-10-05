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

  // Replace the _calculateSalaryReports method in SalaryReportPage
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
        final salarySummary = await provider.getSalarySummaryWithAttendance(
            employeeId,
            _selectedDateRange
        );

        reports[employeeId] = {
          'basicSalary': salarySummary['basicSalary'] ?? 0.0,
          'totalExpenses': salarySummary['totalExpenses'] ?? 0.0,
          'netSalary': salarySummary['netSalary'] ?? 0.0,
          'expensesCount': salarySummary['expensesCount'] ?? 0,
          'presentDays': salarySummary['presentDays'] ?? 0,
          'totalWorkingDays': salarySummary['totalWorkingDays'] ?? 0,
          'attendancePercentage': salarySummary['attendancePercentage'] ?? 0,
          'employeeName': employee['name'] ?? 'Unknown',
        };

      } catch (e) {
        print('Error calculating salary for $employeeId: $e');
        reports[employeeId] = {
          'basicSalary': 0.0,
          'totalExpenses': 0.0,
          'netSalary': 0.0,
          'expensesCount': 0,
          'presentDays': 0,
          'totalWorkingDays': 0,
          'attendancePercentage': 0,
          'employeeName': employee['name'] ?? 'Unknown',
        };
      }
    }

    if (mounted) {
      setState(() {
        _salaryReports = reports;
        _isLoading = false;
      });

      // Debug output
      _debugSalaryCalculation();
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
          // Attendance Summary
          _buildAttendanceSummary(isEnglish),

          SizedBox(height: 16),
          // Summary Card
          // Replace your current summary section with this:
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
            child: Column(
              children: [
                Row(
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
                SizedBox(height: 12),
                // Add a small indicator showing this is attendance-based
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isEnglish ? 'Based on Attendance' : 'حاضری پر مبنی',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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

  Widget _buildSummaryItem(String title, double amount, Color color,
      {bool showCurrency = true, bool isPercentage = false})
  {
    return Column(
      children: [
        Text(
          isPercentage
              ? '${amount.toStringAsFixed(1)}%'
              : showCurrency
              ? 'Rs. ${amount.toStringAsFixed(2)}'
              : amount.toInt().toString(),
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

  // Add this method to show attendance summary
  Widget _buildAttendanceSummary(bool isEnglish) {
    int totalPresentDays = 0;
    int totalWorkingDays = 0;

    _salaryReports.forEach((employeeId, report) {
      final presentDays = (report['presentDays'] ?? 0);
      final workingDays = (report['totalWorkingDays'] ?? 0);

      totalPresentDays += (presentDays is num) ? presentDays.toInt() : 0;
      totalWorkingDays += (workingDays is num) ? workingDays.toInt() : 0;
    });

    final double overallAttendance = totalWorkingDays > 0
        ? (totalPresentDays / totalWorkingDays) * 100
        : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            isEnglish ? 'Present Days' : 'حاضر دن',
            totalPresentDays.toDouble(),
            _getAttendanceColor(overallAttendance),
            showCurrency: false,
          ),
          _buildSummaryItem(
            isEnglish ? 'Working Days' : 'کام کے دن',
            totalWorkingDays.toDouble(),
            const Color(0xFF667EEA),
            showCurrency: false,
          ),
          _buildSummaryItem(
            isEnglish ? 'Attendance' : 'حاضری',
            overallAttendance,
            _getAttendanceColor(overallAttendance),
            showCurrency: false,
            isPercentage: true,
          ),
        ],
      ),
    );
  }

  void _debugSalaryCalculation() {
    print('=== SALARY REPORT DEBUG INFO ===');
    print('Date Range: ${_selectedDateRange.start} to ${_selectedDateRange.end}');
    print('Total Employees: ${_salaryReports.length}');

    _salaryReports.forEach((employeeId, report) {
      print('\n--- ${report['employeeName']} ---');
      print('Present Days: ${report['presentDays']}');
      print('Total Working Days: ${report['totalWorkingDays']}');
      print('Attendance %: ${report['attendancePercentage']}%');
      print('Basic Salary: Rs. ${report['basicSalary']}');
      print('Total Expenses: Rs. ${report['totalExpenses']}');
      print('Net Salary: Rs. ${report['netSalary']}');
    });

    print('\n=== TOTALS ===');
    print('Total Salary: Rs. ${_calculateTotalSalary()}');
    print('Total Expenses: Rs. ${_calculateTotalExpenses()}');
    print('Net Payable: Rs. ${_calculateNetPayable()}');
    print('============================');
  }

  double _calculateTotalSalary() {
    double total = 0;
    _salaryReports.forEach((employeeId, report) {
      final basicSalary = (report['basicSalary'] ?? 0).toDouble();
      total += basicSalary;

      print('=== SALARY DEBUG for ${report['employeeName']} ===');
      print('Employee ID: $employeeId');
      print('Present Days: ${report['presentDays']}');
      print('Total Working Days: ${report['totalWorkingDays']}');
      print('Basic Salary from report: $basicSalary');
      print('Monthly Salary from provider: ${Provider.of<EmployeeProvider>(context, listen: false).calculateMonthlySalary(employeeId, _selectedDateRange.start.year, _selectedDateRange.start.month)}');
    });

    print('=== TOTAL SALARY: $total ===');
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

// Update the _buildEmployeeSalaryCard method
  Widget _buildEmployeeSalaryCard(
      String employeeId,
      Map<String, String> employee,
      Map<String, dynamic> report,
      bool isEnglish,
      )
  {
    final basicSalary = (report['basicSalary'] ?? 0).toDouble();
    final totalExpenses = (report['totalExpenses'] ?? 0).toDouble();
    final netSalary = (report['netSalary'] ?? 0).toDouble();
    final expensesCount = (report['expensesCount'] ?? 0).toInt();
    final presentDays = (report['presentDays'] ?? 0).toInt();
    final totalWorkingDays = (report['totalWorkingDays'] ?? 0).toInt();
    final attendancePercentage = (report['attendancePercentage'] ?? 0).toDouble();

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
                      SizedBox(height: 4),
                      // Attendance information
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getAttendanceColor(attendancePercentage),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$presentDays/$totalWorkingDays ${isEnglish ? 'Days' : 'دن'}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '${attendancePercentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: _getAttendanceColor(attendancePercentage),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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
                _buildBreakdownItem(
                  '${presentDays}/${totalWorkingDays}',
                  presentDays.toDouble(),
                  _getAttendanceColor(attendancePercentage),
                  showAmount: false,
                ),
              ],
            ),
            SizedBox(height: 8),
            // Attendance progress bar
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(3),
              ),
              child: Stack(
                children: [
                  Container(
                    width: (MediaQuery.of(context).size.width - 64) * (attendancePercentage / 100),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getAttendanceColor(attendancePercentage),
                          _getAttendanceColor(attendancePercentage).withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

// Helper method to get color based on attendance percentage
  Color _getAttendanceColor(double percentage) {
    if (percentage >= 90) return Color(0xFF10B981);
    if (percentage >= 75) return Color(0xFF3B82F6);
    if (percentage >= 60) return Color(0xFFFFB74D);
    return Color(0xFFEF4444);
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
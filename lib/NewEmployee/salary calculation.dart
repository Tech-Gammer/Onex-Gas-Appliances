import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onex_gas_appliances/NewEmployee/salary_history_screen.dart';

import 'dbworking.dart';
import 'model.dart';


class SalaryCalculationScreen extends StatefulWidget {
  @override
  _SalaryCalculationScreenState createState() => _SalaryCalculationScreenState();
}

class _SalaryCalculationScreenState extends State<SalaryCalculationScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<Employee> _employees = [];
  DateTime _selectedMonth = DateTime.now();
  Map<String, Map<String, dynamic>> _salaryResults = {};
  Map<String, double> _advanceDeductions = {}; // Track advance deductions for each employee
  Map<String, bool> _savedStatus = {}; // Track saved status for each employee

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    final employees = await _dbService.getEmployees();
    setState(() {
      _employees = employees;
    });
  }

  Future<void> _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = picked;
        _salaryResults.clear();
      });
    }
  }

  Future<void> _calculateSalary(String employeeId) async {
    try {
      double advanceDeduction = _advanceDeductions[employeeId] ?? 0.0;
      final result = await _dbService.calculateSalary(employeeId, _selectedMonth, advanceDeduction: advanceDeduction);
      setState(() {
        _salaryResults[employeeId] = result;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error calculating salary: $e')),
      );
    }
  }

  void _showAdvanceDeductionDialog(Employee employee) {
    double currentDeduction = _advanceDeductions[employee.id!] ?? 0.0;
    TextEditingController deductionController = TextEditingController(text: currentDeduction.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set Advance Deduction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Employee: ${employee.name}'),
            Text('Total Advance: PKR ${employee.totalAdvance}'),
            SizedBox(height: 16),
            TextFormField(
              controller: deductionController,
              decoration: InputDecoration(
                labelText: 'Deduction Amount',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              double deduction = double.tryParse(deductionController.text) ?? 0.0;
              if (deduction > employee.totalAdvance) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Deduction cannot exceed total advance amount!')),
                );
                return;
              }

              setState(() {
                _advanceDeductions[employee.id!] = deduction;
              });
              Navigator.pop(context);

              // Recalculate salary with new deduction
              _calculateSalary(employee.id!);
            },
            child: Text('Apply'),
          ),
        ],
      ),
    );
  }

  Future<void> _calculateAllSalaries() async {
    for (var employee in _employees) {
      await _calculateSalary(employee.id!);
    }
  }

  Widget _buildSalaryCard(Employee employee, Map<String, dynamic>? result) {
    double advanceDeduction = _advanceDeductions[employee.id!] ?? 0.0;
    bool isSaved = _savedStatus[employee.id!] ?? false;

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    employee.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (isSaved)
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Chip(
                  label: Text(
                    employee.salaryType.toUpperCase(),
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: employee.salaryType == 'monthly'
                      ? Colors.blue
                      : Colors.orange,
                ),
              ],
            ),
            SizedBox(height: 8),
            Text('Basic Salary: PKR ${employee.basicSalary} ${employee.salaryType == 'monthly' ? '/month' : '/day'}'),
            Text('Total Advance: PKR ${employee.totalAdvance}',
                style: TextStyle(color: Colors.orange)),

            if (result != null) ...[
              SizedBox(height: 12),
              Divider(),
              Text(
                'Salary Calculation for ${DateFormat('MMMM yyyy').format(_selectedMonth)}:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),

              // Present Days Information
              Row(
                children: [
                  Expanded(child: Text('Present Days:')),
                  Text('${result['presentDays']}/${result['totalWorkingDays']}'),
                ],
              ),

              // Daily Rate Information
              if (employee.salaryType == 'monthly')
                Row(
                  children: [
                    Expanded(child: Text('Daily Rate:')),
                    Text('PKR ${(result['dailyRate'] as double).toStringAsFixed(2)}'),
                  ],
                ),

              SizedBox(height: 4),
              Row(
                children: [
                  Expanded(child: Text('Gross Salary:')),
                  Text(
                    'PKR ${(result['grossSalary'] as double).toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              Row(
                children: [
                  Expanded(child: Text('Expenses Deduction:')),
                  Text(
                    '-PKR ${(result['totalExpenses'] as double).toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              ),

              Row(
                children: [
                  Expanded(child: Text('Advance Deduction:')),
                  InkWell(
                    onTap: () => _showAdvanceDeductionDialog(employee),
                    child: Text(
                      '-PKR ${(result['advanceDeduction'] as double).toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                ],
              ),

              Divider(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Net Salary:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    'PKR ${(result['netSalary'] as double).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: result['netSalary'] >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12),
              if (!isSaved)
                ElevatedButton(
                  onPressed: () => _saveSalary(employee.id!),
                  child: Text('Save Salary'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 40),
                    backgroundColor: Colors.green,
                  ),
                )
              else
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Salary Saved',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              // Show expenses list if any
              if ((result['expenses'] as List).isNotEmpty) ...[
                SizedBox(height: 8),
                Text(
                  'Expenses Details:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                ...(result['expenses'] as List).map<Widget>((expense) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            expense.description,
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        Text(
                          '-PKR ${expense.amount}',
                          style: TextStyle(fontSize: 12, color: Colors.red),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ] else ...[
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _calculateSalary(employee.id!),
                      child: Text('Calculate Salary'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 40),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.money_off, color: Colors.orange),
                    onPressed: () => _showAdvanceDeductionDialog(employee),
                    tooltip: 'Set Advance Deduction',
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _saveSalary(String employeeId) async {
    try {
      final result = _salaryResults[employeeId];
      if (result == null) return;

      Salary salary = Salary(
        employeeId: employeeId,
        month: _selectedMonth,
        presentDays: result['presentDays'],
        totalWorkingDays: result['totalWorkingDays'],
        grossSalary: result['grossSalary'],
        totalExpenses: result['totalExpenses'],
        advanceDeduction: result['advanceDeduction'],
        netSalary: result['netSalary'],
        calculationDate: DateTime.now(),
      );

      await _dbService.saveSalary(salary);

      setState(() {
        _savedStatus[employeeId] = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Salary saved successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving salary: $e')),
      );
    }
  }

  Future<void> _saveAllSalaries() async {
    int savedCount = 0;
    for (var employee in _employees) {
      if (_salaryResults.containsKey(employee.id!) && !(_savedStatus[employee.id!] ?? false)) {
        await _saveSalary(employee.id!);
        savedCount++;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$savedCount salaries saved successfully!')),
    );
  }


  @override
  Widget build(BuildContext context) {
    int calculatedCount = _salaryResults.length;
    int totalCount = _employees.length;
    int savedCount = _savedStatus.values.where((saved) => saved).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Calculate Salary'),
        actions: [
          if (savedCount > 0)
            IconButton(
              icon: Icon(Icons.history),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SalaryHistoryScreen()),
                );
              },
              tooltip: 'View Salary History',
            ),
        ],
      ),
      body: _employees.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Month Selection Card
            Card(
              child: ListTile(
                leading: Icon(Icons.calendar_today),
                title: Text('Selected Month'),
                subtitle: Text(DateFormat('MMMM yyyy').format(_selectedMonth)),
                trailing: IconButton(
                  icon: Icon(Icons.edit_calendar),
                  onPressed: _selectMonth,
                ),
              ),
            ),

            SizedBox(height: 16),

            // Progress Indicators
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          Text('Calculated', style: TextStyle(fontSize: 12)),
                          Text('$calculatedCount/$totalCount',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Card(
                    color: Colors.green[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          Text('Saved', style: TextStyle(fontSize: 12)),
                          Text('$savedCount/$totalCount',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _calculateAllSalaries,
                    child: Text('Calculate All'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveAllSalaries,
                    child: Text('Save All'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Employees List
            Expanded(
              child: ListView.builder(
                itemCount: _employees.length,
                itemBuilder: (context, index) {
                  final employee = _employees[index];
                  final result = _salaryResults[employee.id!];
                  return _buildSalaryCard(employee, result);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
      final result = await _dbService.calculateSalary(employeeId, _selectedMonth);
      setState(() {
        _salaryResults[employeeId] = result;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error calculating salary: $e')),
      );
    }
  }

  Future<void> _calculateAllSalaries() async {
    for (var employee in _employees) {
      await _calculateSalary(employee.id!);
    }
  }

  Widget _buildSalaryCard(Employee employee, Map<String, dynamic>? result) {
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
            Text('Basic Salary: \$${employee.basicSalary} ${employee.salaryType == 'monthly' ? '/month' : '/day'}'),

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
                    Text('\$${(result['dailyRate'] as double).toStringAsFixed(2)}'),
                  ],
                ),

              SizedBox(height: 4),
              Row(
                children: [
                  Expanded(child: Text('Gross Salary:')),
                  Text(
                    '\$${(result['grossSalary'] as double).toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              Row(
                children: [
                  Expanded(child: Text('Expenses Deduction:')),
                  Text(
                    '-\$${(result['totalExpenses'] as double).toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.red),
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
                    '\$${(result['netSalary'] as double).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: result['netSalary'] >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
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
                          '-\$${expense.amount}',
                          style: TextStyle(fontSize: 12, color: Colors.red),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ] else ...[
              SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _calculateSalary(employee.id!),
                child: Text('Calculate Salary'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 40),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int calculatedCount = _salaryResults.length;
    int totalCount = _employees.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Calculate Salary'),
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

            // Calculation Progress
            if (calculatedCount > 0)
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Calculation Progress:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$calculatedCount/$totalCount',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

            SizedBox(height: 16),

            // Calculate All Button
            ElevatedButton(
              onPressed: _calculateAllSalaries,
              child: Text('Calculate All Salaries'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
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
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
    if (picked != null && picked != _selectedMonth) {
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

  @override
  Widget build(BuildContext context) {
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
            Card(
              child: ListTile(
                title: Text('Selected Month'),
                subtitle: Text(DateFormat('yyyy-MM').format(_selectedMonth)),
                trailing: IconButton(
                  icon: Icon(Icons.calendar_today),
                  onPressed: _selectMonth,
                ),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _calculateAllSalaries,
              child: Text('Calculate All Salaries'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _employees.length,
                itemBuilder: (context, index) {
                  final employee = _employees[index];
                  final result = _salaryResults[employee.id!];

                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            employee.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text('Salary Type: ${employee.salaryType}'),
                          Text('Basic Salary: \$${employee.basicSalary}'),

                          if (result != null) ...[
                            SizedBox(height: 8),
                            Divider(),
                            Text(
                              'Salary Calculation:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text('Present Days: ${result['presentDays']}'),
                            Text('Total Expenses: \$${result['totalExpenses']}'),
                            Text('Gross Salary: \$${result['grossSalary']}'),
                            Text(
                              'Net Salary: \$${result['netSalary']}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: result['netSalary'] >= 0 ? Colors.green : Colors.red,
                              ),
                            ),
                          ] else ...[
                            SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => _calculateSalary(employee.id!),
                              child: Text('Calculate Salary'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
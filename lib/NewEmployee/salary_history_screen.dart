import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'dbworking.dart';
import 'model.dart';

class SalaryHistoryScreen extends StatefulWidget {
  @override
  _SalaryHistoryScreenState createState() => _SalaryHistoryScreenState();
}

class _SalaryHistoryScreenState extends State<SalaryHistoryScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<Salary> _salaries = [];
  List<Employee> _employees = [];
  Map<String, Employee> _employeeMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final salaries = await _dbService.getAllSalaries();
      final employees = await _dbService.getEmployees();

      Map<String, Employee> employeeMap = {};
      for (var employee in employees) {
        employeeMap[employee.id!] = employee;
      }

      setState(() {
        _salaries = salaries;
        _employees = employees;
        _employeeMap = employeeMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading salary history: $e')),
      );
    }
  }

  void _showSalaryDetails(Salary salary) {
    Employee employee = _employeeMap[salary.employeeId]!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Salary Details - ${DateFormat('MMMM yyyy').format(salary.month)}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Employee: ${employee.name}',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              _buildDetailRow('Present Days:', '${salary.presentDays}/${salary.totalWorkingDays}'),
              _buildDetailRow('Gross Salary:', 'PKR ${salary.grossSalary.toStringAsFixed(2)}'),
              _buildDetailRow('Expenses Deduction:', '-PKR ${salary.totalExpenses.toStringAsFixed(2)}'),
              _buildDetailRow('Advance Deduction:', '-PKR ${salary.advanceDeduction.toStringAsFixed(2)}'),
              Divider(),
              _buildDetailRow('Net Salary:', 'PKR ${salary.netSalary.toStringAsFixed(2)}',
                  isBold: true, color: salary.netSalary >= 0 ? Colors.green : Colors.red),
              SizedBox(height: 8),
              Text('Calculated on: ${DateFormat('yyyy-MM-dd').format(salary.calculationDate)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              if (salary.isPaid)
                Text('Paid on: ${DateFormat('yyyy-MM-dd').format(salary.paymentDate!)}',
                    style: TextStyle(fontSize: 12, color: Colors.green)),
            ],
          ),
        ),
        actions: [
          if (!salary.isPaid)
            TextButton(
              onPressed: () {
                _markAsPaid(salary);
                Navigator.pop(context);
              },
              child: Text('Mark as Paid'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal))),
          Text(value, style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          )),
        ],
      ),
    );
  }

  Future<void> _markAsPaid(Salary salary) async {
    try {
      await _dbService.markSalaryAsPaid(salary.id!);
      _loadData(); // Refresh the list
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Salary marked as paid!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking salary as paid: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Salary History'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _salaries.isEmpty
          ? Center(child: Text('No salary records found'))
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Records: ${_salaries.length}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Total Paid: ${_salaries.where((s) => s.isPaid).length}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _salaries.length,
                itemBuilder: (context, index) {
                  final salary = _salaries[index];
                  final employee = _employeeMap[salary.employeeId];

                  if (employee == null) {
                    return SizedBox(); // Skip if employee not found
                  }

                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(employee.name[0]),
                        backgroundColor: salary.isPaid ? Colors.green : Colors.blue,
                      ),
                      title: Text(employee.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(DateFormat('MMMM yyyy').format(salary.month)),
                          Text('Net Salary: PKR ${salary.netSalary.toStringAsFixed(2)}'),
                          Row(
                            children: [
                              Icon(
                                salary.isPaid ? Icons.check_circle : Icons.pending,
                                size: 16,
                                color: salary.isPaid ? Colors.green : Colors.orange,
                              ),
                              SizedBox(width: 4),
                              Text(
                                salary.isPaid ? 'Paid' : 'Pending',
                                style: TextStyle(
                                  color: salary.isPaid ? Colors.green : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _showSalaryDetails(salary),
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
import 'package:flutter/material.dart';

import 'addexpensepage.dart';
import 'dbworking.dart';
import 'model.dart';


class EmployeeListScreen extends StatefulWidget {
  @override
  _EmployeeListScreenState createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<Employee> _employees = [];

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

  void _showEmployeeOptions(Employee employee) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.money_off),
              title: Text('Add Expense'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddExpenseScreen(employee: employee),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.delete),
              title: Text('Delete Employee'),
              onTap: () {
                Navigator.pop(context);
                _deleteEmployee(employee);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteEmployee(Employee employee) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Employee'),
        content: Text('Are you sure you want to delete ${employee.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _dbService.deleteEmployee(employee.id!);
        _loadEmployees();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Employee deleted successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting employee: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Employee List'),
      ),
      body: _employees.isEmpty
          ? Center(child: Text('No employees found'))
          : ListView.builder(
        itemCount: _employees.length,
        itemBuilder: (context, index) {
          final employee = _employees[index];
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              title: Text(employee.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(employee.address),
                  Text('Salary: \$${employee.basicSalary} (${employee.salaryType})'),
                  Text('Joined: ${employee.joinDate.toString().split(' ')[0]}'),
                ],
              ),
              trailing: IconButton(
                icon: Icon(Icons.more_vert),
                onPressed: () => _showEmployeeOptions(employee),
              ),
            ),
          );
        },
      ),
    );
  }
}
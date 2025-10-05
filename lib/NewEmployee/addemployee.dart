import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'dbworking.dart';
import 'model.dart';


class AddEmployeeScreen extends StatefulWidget {
  @override
  _AddEmployeeScreenState createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _salaryController = TextEditingController();
  String _salaryType = 'monthly';
  DateTime _joinDate = DateTime.now();
  final DatabaseService _dbService = DatabaseService();

  Future<void> _selectJoinDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _joinDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _joinDate) {
      setState(() {
        _joinDate = picked;
      });
    }
  }

  Future<void> _addEmployee() async {
    if (_formKey.currentState!.validate()) {
      try {
        Employee employee = Employee(
          name: _nameController.text,
          address: _addressController.text,
          basicSalary: double.parse(_salaryController.text),
          salaryType: _salaryType,
          joinDate: _joinDate,
        );

        await _dbService.addEmployee(employee);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Employee added successfully!')),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding employee: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Employee'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Employee Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter employee name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter address';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _salaryController,
                decoration: InputDecoration(
                  labelText: 'Basic Salary',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter basic salary';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _salaryType,
                decoration: InputDecoration(
                  labelText: 'Salary Type',
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                ],
                onChanged: (value) {
                  setState(() {
                    _salaryType = value!;
                  });
                },
              ),
              SizedBox(height: 16),
              ListTile(
                title: Text('Join Date'),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(_joinDate)),
                trailing: Icon(Icons.calendar_today),
                onTap: _selectJoinDate,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _addEmployee,
                child: Text('Add Employee'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'dbworking.dart';
import 'model.dart';


class AddExpenseScreen extends StatefulWidget {
  final Employee employee;

  const AddExpenseScreen({Key? key, required this.employee}) : super(key: key);

  @override
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _expenseDate = DateTime.now();
  final DatabaseService _dbService = DatabaseService();

  Future<void> _selectExpenseDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _expenseDate) {
      setState(() {
        _expenseDate = picked;
      });
    }
  }

  Future<void> _addExpense() async {
    if (_formKey.currentState!.validate()) {
      try {
        Expense expense = Expense(
          employeeId: widget.employee.id!,
          description: _descriptionController.text,
          amount: double.parse(_amountController.text),
          date: _expenseDate,
        );

        await _dbService.addExpense(expense);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Expense added successfully!')),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding expense: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Expense - ${widget.employee.name}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Employee: ${widget.employee.name}',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('Salary Type: ${widget.employee.salaryType}'),
                      Text('Basic Salary: \$${widget.employee.basicSalary}'),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Expense Description',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter expense description';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              ListTile(
                title: Text('Expense Date'),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(_expenseDate)),
                trailing: Icon(Icons.calendar_today),
                onTap: _selectExpenseDate,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _addExpense,
                child: Text('Add Expense'),
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
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'dbworking.dart';
import 'model.dart';

class AddAdvanceScreen extends StatefulWidget {
  final Employee employee;

  const AddAdvanceScreen({Key? key, required this.employee}) : super(key: key);

  @override
  _AddAdvanceScreenState createState() => _AddAdvanceScreenState();
}

class _AddAdvanceScreenState extends State<AddAdvanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _advanceDate = DateTime.now();
  final DatabaseService _dbService = DatabaseService();

  Future<void> _selectAdvanceDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _advanceDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _advanceDate) {
      setState(() {
        _advanceDate = picked;
      });
    }
  }

  Future<void> _addAdvance() async {
    if (_formKey.currentState!.validate()) {
      try {
        Advance advance = Advance(
          employeeId: widget.employee.id!,
          amount: double.parse(_amountController.text),
          date: _advanceDate,
          description: _descriptionController.text.isEmpty
              ? 'Advance Payment'
              : _descriptionController.text,
        );

        await _dbService.addAdvance(advance);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Advance added successfully!')),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding advance: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Advance - ${widget.employee.name}'),
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
                      Text('Current Total Advance: \$${widget.employee.totalAdvance}',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          )),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Advance Amount',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter advance amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              ListTile(
                title: Text('Advance Date'),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(_advanceDate)),
                trailing: Icon(Icons.calendar_today),
                onTap: _selectAdvanceDate,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _addAdvance,
                child: Text('Add Advance'),
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
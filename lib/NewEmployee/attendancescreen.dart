import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'dbworking.dart';
import 'model.dart';


class AttendanceScreen extends StatefulWidget {
  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<Employee> _employees = [];
  DateTime _selectedDate = DateTime.now();
  Map<String, bool> _attendanceStatus = {};

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    final employees = await _dbService.getEmployees();
    setState(() {
      _employees = employees;
      // Initialize all as present by default
      for (var employee in employees) {
        _attendanceStatus[employee.id!] = true;
      }
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _markAttendance() async {
    try {
      for (var employee in _employees) {
        Attendance attendance = Attendance(
          employeeId: employee.id!,
          date: _selectedDate,
          checkIn: DateTime.now(),
          isPresent: _attendanceStatus[employee.id!] ?? false,
        );

        await _dbService.markAttendance(attendance);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attendance marked successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking attendance: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mark Attendance'),
      ),
      body: _employees.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: ListTile(
                title: Text('Selected Date'),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                trailing: IconButton(
                  icon: Icon(Icons.calendar_today),
                  onPressed: _selectDate,
                ),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _employees.length,
                itemBuilder: (context, index) {
                  final employee = _employees[index];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(employee.name),
                      subtitle: Text(employee.salaryType),
                      trailing: Switch(
                        value: _attendanceStatus[employee.id!] ?? false,
                        onChanged: (value) {
                          setState(() {
                            _attendanceStatus[employee.id!] = value;
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _markAttendance,
              child: Text('Mark Attendance for All'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
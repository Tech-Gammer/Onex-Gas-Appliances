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
      // Initialize all as absent by default
      for (var employee in employees) {
        _attendanceStatus[employee.id!] = false;
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
      int markedCount = 0;
      for (var employee in _employees) {
        if (_attendanceStatus[employee.id!] == true) {
          Attendance attendance = Attendance(
            employeeId: employee.id!,
            date: _selectedDate,
            checkIn: DateTime.now(),
            isPresent: true,
          );

          await _dbService.markAttendance(attendance);
          markedCount++;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attendance marked for $markedCount employees!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking attendance: $e')),
      );
    }
  }

  Future<void> _markAllPresent() {
    setState(() {
      for (var employee in _employees) {
        _attendanceStatus[employee.id!] = true;
      }
    });
    return Future.value();
  }

  Future<void> _markAllAbsent() {
    setState(() {
      for (var employee in _employees) {
        _attendanceStatus[employee.id!] = false;
      }
    });
    return Future.value();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mark Attendance'),
        actions: [
          IconButton(
            icon: Icon(Icons.check_circle),
            onPressed: _markAllPresent,
            tooltip: 'Mark All Present',
          ),
          IconButton(
            icon: Icon(Icons.cancel),
            onPressed: _markAllAbsent,
            tooltip: 'Mark All Absent',
          ),
        ],
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
                subtitle: Text(DateFormat('EEEE, yyyy-MM-dd').format(_selectedDate)),
                trailing: IconButton(
                  icon: Icon(Icons.calendar_today),
                  onPressed: _selectDate,
                ),
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Mark employees present for selected date:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Present employees will receive salary for this day',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _employees.length,
                itemBuilder: (context, index) {
                  final employee = _employees[index];
                  final isPresent = _attendanceStatus[employee.id!] ?? false;

                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(employee.name[0]),
                        backgroundColor: isPresent ? Colors.green : Colors.grey,
                      ),
                      title: Text(employee.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(employee.salaryType == 'monthly'
                              ? 'Monthly - \$${employee.basicSalary}/month'
                              : 'Daily - \$${employee.basicSalary}/day'),
                          Text(
                            isPresent ? 'PRESENT' : 'ABSENT',
                            style: TextStyle(
                              color: isPresent ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      trailing: Switch(
                        value: isPresent,
                        onChanged: (value) {
                          setState(() {
                            _attendanceStatus[employee.id!] = value;
                          });
                        },
                      ),
                      onTap: () {
                        setState(() {
                          _attendanceStatus[employee.id!] = !isPresent;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _markAllPresent,
                    child: Text('Mark All Present'),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _markAllAbsent,
                    child: Text('Mark All Absent'),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _markAttendance,
              child: Text('Save Attendance'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                backgroundColor: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
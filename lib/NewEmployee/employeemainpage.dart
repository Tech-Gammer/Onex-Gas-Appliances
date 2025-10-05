import 'package:flutter/material.dart';
import 'package:onex_gas_appliances/NewEmployee/salary%20calculation.dart';

import 'addemployee.dart';
import 'attendancescreen.dart';
import 'employeelistpage.dart';


class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Employee Management'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 6,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildMenuCard(
              context,
              'Add Employee',
              Icons.person_add,
              Colors.green,
                  () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddEmployeeScreen()),
              ),
            ),
            _buildMenuCard(
              context,
              'Employee List',
              Icons.people,
              Colors.blue,
                  () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EmployeeListScreen()),
              ),
            ),
            _buildMenuCard(
              context,
              'Mark Attendance',
              Icons.calendar_today,
              Colors.orange,
                  () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AttendanceScreen()),
              ),
            ),
            _buildMenuCard(
              context,
              'Calculate Salary',
              Icons.calculate,
              Colors.purple,
                  () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SalaryCalculationScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
      BuildContext context,
      String title,
      IconData icon,
      Color color,
      VoidCallback onTap,
      ) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: color),
            SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
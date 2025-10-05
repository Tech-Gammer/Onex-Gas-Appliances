import 'package:firebase_database/firebase_database.dart';

import 'model.dart';


class DatabaseService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Employee CRUD
  Future<void> addEmployee(Employee employee) async {
    final employeeRef = _dbRef.child('employees').push();
    employee.id = employeeRef.key;
    await employeeRef.set(employee.toJson());
  }

  Future<List<Employee>> getEmployees() async {
    final snapshot = await _dbRef.child('employees').get();
    if (snapshot.exists) {
      Map<dynamic, dynamic> employeesMap = snapshot.value as Map;
      return employeesMap.entries.map((entry) {
        return Employee.fromJson(Map<String, dynamic>.from(entry.value));
      }).toList();
    }
    return [];
  }

  Future<void> updateEmployee(Employee employee) async {
    await _dbRef.child('employees').child(employee.id!).update(employee.toJson());
  }

  Future<void> deleteEmployee(String employeeId) async {
    await _dbRef.child('employees').child(employeeId).remove();
  }

  // Attendance CRUD
  Future<void> markAttendance(Attendance attendance) async {
    final attendanceRef = _dbRef.child('attendance').push();
    attendance.id = attendanceRef.key;

    // Store attendance with date as key for easy querying
    String dateKey = "${attendance.date.year}-${attendance.date.month}-${attendance.date.day}";
    await _dbRef.child('employee_attendance')
        .child(attendance.employeeId)
        .child(dateKey)
        .set(attendance.toJson());

    await attendanceRef.set(attendance.toJson());
  }

  Future<List<Attendance>> getEmployeeAttendance(String employeeId, DateTime month) async {
    final snapshot = await _dbRef.child('employee_attendance')
        .child(employeeId)
        .get();

    if (snapshot.exists) {
      Map<dynamic, dynamic> attendanceMap = snapshot.value as Map;
      List<Attendance> attendances = [];

      attendanceMap.forEach((key, value) {
        Attendance attendance = Attendance.fromJson(Map<String, dynamic>.from(value));
        if (attendance.date.year == month.year && attendance.date.month == month.month) {
          attendances.add(attendance);
        }
      });

      return attendances;
    }
    return [];
  }

  // Expense CRUD
  Future<void> addExpense(Expense expense) async {
    final expenseRef = _dbRef.child('expenses').push();
    expense.id = expenseRef.key;
    await expenseRef.set(expense.toJson());
  }

  Future<List<Expense>> getEmployeeExpenses(String employeeId, DateTime month) async {
    final snapshot = await _dbRef.child('expenses').get();
    if (snapshot.exists) {
      Map<dynamic, dynamic> expensesMap = snapshot.value as Map;
      return expensesMap.entries.map((entry) {
        Expense expense = Expense.fromJson(Map<String, dynamic>.from(entry.value));
        return expense;
      }).where((expense) =>
      expense.employeeId == employeeId &&
          expense.date.year == month.year &&
          expense.date.month == month.month
      ).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> calculateSalary(String employeeId, DateTime month) async {
    Employee employee = (await getEmployees()).firstWhere((emp) => emp.id == employeeId);
    List<Attendance> attendances = await getEmployeeAttendance(employeeId, month);
    List<Expense> expenses = await getEmployeeExpenses(employeeId, month);

    // Count present days
    int presentDays = attendances.where((a) => a.isPresent).length;

    // Fixed 30 days per month for calculation
    int fixedWorkingDays = 30;

    double totalExpenses = expenses.fold(0, (sum, expense) => sum + expense.amount);

    double salary = 0;

    if (employee.salaryType == 'monthly') {
      // For monthly employees: (Basic Salary / 30) * Present Days
      double dailyRate = employee.basicSalary / fixedWorkingDays;
      salary = dailyRate * presentDays;
    } else {
      // For daily employees: Basic Salary * Present Days
      salary = presentDays * employee.basicSalary;
    }

    double netSalary = salary - totalExpenses;

    return {
      'employee': employee,
      'presentDays': presentDays,
      'totalWorkingDays': fixedWorkingDays, // Now always 30
      'totalExpenses': totalExpenses,
      'grossSalary': salary,
      'netSalary': netSalary,
      'expenses': expenses,
      'dailyRate': employee.salaryType == 'monthly' ? employee.basicSalary / fixedWorkingDays : employee.basicSalary,
    };
  }

// Helper method to calculate working days in a month (excluding weekends)
//   int _getWorkingDaysInMonth(DateTime month) {
//     DateTime firstDay = DateTime(month.year, month.month, 1);
//     DateTime lastDay = DateTime(month.year, month.month + 1, 0);
//
//     int workingDays = 0;
//     DateTime currentDay = firstDay;
//
//     while (currentDay.isBefore(lastDay) || currentDay.isAtSameMomentAs(lastDay)) {
//       // Check if it's a weekday (Monday to Friday)
//       if (currentDay.weekday != DateTime.saturday && currentDay.weekday != DateTime.sunday) {
//         workingDays++;
//       }
//       currentDay = currentDay.add(Duration(days: 1));
//     }
//
//     return workingDays;
//   }
  int _getWorkingDaysInMonth(DateTime month) {
    return 30; // Always return 30 days
  }


}
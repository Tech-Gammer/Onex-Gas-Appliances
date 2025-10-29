import 'package:firebase_database/firebase_database.dart';

import 'model.dart';


class DatabaseService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();


  Future<void> addAdvance(Advance advance) async {
    final advanceRef = _dbRef.child('advances').push();
    advance.id = advanceRef.key;
    await advanceRef.set(advance.toJson());

    // Update employee's total advance amount
    final employeeSnapshot = await _dbRef.child('employees').child(advance.employeeId).get();
    if (employeeSnapshot.exists) {
      Map<String, dynamic> employeeData = Map<String, dynamic>.from(employeeSnapshot.value as Map);
      double currentAdvance = employeeData['totalAdvance']?.toDouble() ?? 0.0;
      double newAdvance = currentAdvance + advance.amount;

      await _dbRef.child('employees').child(advance.employeeId).update({
        'totalAdvance': newAdvance,
      });
    }
  }

  Future<List<Advance>> getEmployeeAdvances(String employeeId) async {
    final snapshot = await _dbRef.child('advances').get();
    if (snapshot.exists) {
      Map<dynamic, dynamic> advancesMap = snapshot.value as Map;
      return advancesMap.entries.map((entry) {
        Advance advance = Advance.fromJson(Map<String, dynamic>.from(entry.value));
        return advance;
      }).where((advance) => advance.employeeId == employeeId).toList();
    }
    return [];
  }

  Future<void> repayAdvance(String employeeId, double amount) async {
    final employeeSnapshot = await _dbRef.child('employees').child(employeeId).get();
    if (employeeSnapshot.exists) {
      Map<String, dynamic> employeeData = Map<String, dynamic>.from(employeeSnapshot.value as Map);
      double currentAdvance = employeeData['totalAdvance']?.toDouble() ?? 0.0;
      double newAdvance = (currentAdvance - amount).clamp(0.0, double.infinity);

      await _dbRef.child('employees').child(employeeId).update({
        'totalAdvance': newAdvance,
      });
    }
  }

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

  Future<Map<String, dynamic>> calculateSalary(String employeeId, DateTime month, {double advanceDeduction = 0.0}) async {
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

    // Apply advance deduction
    double actualAdvanceDeduction = advanceDeduction.clamp(0.0, employee.totalAdvance);
    double netSalary = salary - totalExpenses - actualAdvanceDeduction;

    return {
      'employee': employee,
      'presentDays': presentDays,
      'totalWorkingDays': fixedWorkingDays,
      'totalExpenses': totalExpenses,
      'grossSalary': salary,
      'advanceDeduction': actualAdvanceDeduction,
      'netSalary': netSalary,
      'expenses': expenses,
      'dailyRate': employee.salaryType == 'monthly' ? employee.basicSalary / fixedWorkingDays : employee.basicSalary,
    };
  }

// Salary CRUD
  Future<void> saveSalary(Salary salary) async {
    // Check if salary already exists for this employee and month
    final existingSalary = await getEmployeeSalaryForMonth(salary.employeeId, salary.month);

    if (existingSalary != null) {
      // Update existing salary
      await _dbRef.child('salaries').child(existingSalary.id!).update(salary.toJson());
    } else {
      // Create new salary
      final salaryRef = _dbRef.child('salaries').push();
      salary.id = salaryRef.key;
      await salaryRef.set(salary.toJson());
    }

    // If advance deduction was applied, update the employee's total advance
    if (salary.advanceDeduction > 0) {
      await repayAdvance(salary.employeeId, salary.advanceDeduction);
    }
  }

  Future<Salary?> getEmployeeSalaryForMonth(String employeeId, DateTime month) async {
    final snapshot = await _dbRef.child('salaries').get();
    if (snapshot.exists) {
      Map<dynamic, dynamic> salariesMap = snapshot.value as Map;
      for (var entry in salariesMap.entries) {
        Salary salary = Salary.fromJson(Map<String, dynamic>.from(entry.value));
        if (salary.employeeId == employeeId &&
            salary.month.year == month.year &&
            salary.month.month == month.month) {
          salary.id = entry.key;
          return salary;
        }
      }
    }
    return null;
  }

  Future<List<Salary>> getEmployeeSalaries(String employeeId) async {
    final snapshot = await _dbRef.child('salaries').get();
    if (snapshot.exists) {
      Map<dynamic, dynamic> salariesMap = snapshot.value as Map;
      List<Salary> salaries = [];
      salariesMap.entries.forEach((entry) {
        Salary salary = Salary.fromJson(Map<String, dynamic>.from(entry.value));
        if (salary.employeeId == employeeId) {
          salary.id = entry.key;
          salaries.add(salary);
        }
      });
      // Sort by month descending
      salaries.sort((a, b) => b.month.compareTo(a.month));
      return salaries;
    }
    return [];
  }

  Future<List<Salary>> getAllSalaries() async {
    final snapshot = await _dbRef.child('salaries').get();
    if (snapshot.exists) {
      Map<dynamic, dynamic> salariesMap = snapshot.value as Map;
      List<Salary> salaries = [];
      salariesMap.entries.forEach((entry) {
        Salary salary = Salary.fromJson(Map<String, dynamic>.from(entry.value));
        salary.id = entry.key;
        salaries.add(salary);
      });
      // Sort by month descending
      salaries.sort((a, b) => b.month.compareTo(a.month));
      return salaries;
    }
    return [];
  }

  Future<void> markSalaryAsPaid(String salaryId) async {
    await _dbRef.child('salaries').child(salaryId).update({
      'isPaid': true,
      'paymentDate': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> deleteSalary(String salaryId) async {
    await _dbRef.child('salaries').child(salaryId).remove();
  }

  // Reports Methods
  Future<Map<String, dynamic>> getMonthlyReport(DateTime month) async {
    List<Salary> salaries = await getAllSalaries();
    salaries = salaries.where((salary) =>
    salary.month.year == month.year && salary.month.month == month.month).toList();

    double totalGrossSalary = salaries.fold(0, (sum, salary) => sum + salary.grossSalary);
    double totalExpenses = salaries.fold(0, (sum, salary) => sum + salary.totalExpenses);
    double totalAdvanceDeductions = salaries.fold(0, (sum, salary) => sum + salary.advanceDeduction);
    double totalNetSalary = salaries.fold(0, (sum, salary) => sum + salary.netSalary);

    return {
      'month': month,
      'totalEmployees': salaries.length,
      'totalGrossSalary': totalGrossSalary,
      'totalExpenses': totalExpenses,
      'totalAdvanceDeductions': totalAdvanceDeductions,
      'totalNetSalary': totalNetSalary,
      'salaries': salaries,
    };
  }

  Future<Map<String, dynamic>> getEmployeeReport(String employeeId, DateTime startDate, DateTime endDate) async {
    List<Salary> salaries = await getEmployeeSalaries(employeeId);
    salaries = salaries.where((salary) =>
    salary.month.isAfter(startDate.subtract(Duration(days: 1))) &&
        salary.month.isBefore(endDate.add(Duration(days: 1)))).toList();

    double totalGrossSalary = salaries.fold(0, (sum, salary) => sum + salary.grossSalary);
    double totalExpenses = salaries.fold(0, (sum, salary) => sum + salary.totalExpenses);
    double totalAdvanceDeductions = salaries.fold(0, (sum, salary) => sum + salary.advanceDeduction);
    double totalNetSalary = salaries.fold(0, (sum, salary) => sum + salary.netSalary);

    return {
      'employeeId': employeeId,
      'startDate': startDate,
      'endDate': endDate,
      'totalMonths': salaries.length,
      'totalGrossSalary': totalGrossSalary,
      'totalExpenses': totalExpenses,
      'totalAdvanceDeductions': totalAdvanceDeductions,
      'totalNetSalary': totalNetSalary,
      'salaries': salaries,
    };
  }


}
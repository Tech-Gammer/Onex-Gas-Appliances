import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class EmployeeProvider with ChangeNotifier {
  final DatabaseReference _database = FirebaseDatabase.instance.ref('employees');
  final DatabaseReference _attendanceRef = FirebaseDatabase.instance.ref('attendance');
  final DatabaseReference _expensesRef = FirebaseDatabase.instance.ref('expenses');
  final DatabaseReference _salaryRef = FirebaseDatabase.instance.ref('salaries');

  Map<String, Map<String, String>> _employees = {};
  Map<String, dynamic> _expenses = {};
  Map<String, dynamic> _salaries = {};

  Map<String, Map<String, String>> get employees => _employees;
  Map<String, dynamic> get expenses => _expenses;
  Map<String, dynamic> get salaries => _salaries;

  EmployeeProvider() {
    _fetchEmployees();
    _fetchExpenses();
    _fetchSalaries();
  }





  Future<int> calculatePresentDays(String employeeId, DateTimeRange dateRange) async {
    try {
      final attendanceData = await getAttendanceForDateRange(employeeId, dateRange);
      int presentDays = 0;

      attendanceData.forEach((dateString, attendance) {
        if (attendance['status'] == 'present') {
          presentDays++;
        }
      });

      print('Present days for $employeeId: $presentDays');
      return presentDays;
    } catch (e) {
      print('Error calculating present days for $employeeId: $e');
      return 0;
    }
  }

  int calculateTotalWorkingDays(DateTimeRange dateRange) {
    int workingDays = 0;
    DateTime current = dateRange.start;

    while (current.isBefore(dateRange.end.add(Duration(days: 1)))) {
      // Skip weekends (Saturday = 6, Sunday = 7)
      if (current.weekday != DateTime.saturday && current.weekday != DateTime.sunday) {
        workingDays++;
      }
      current = current.add(Duration(days: 1));
    }

    print('Total working days in range: $workingDays');
    return workingDays;
  }

  Future<double> calculateSalaryBasedOnAttendance(
      String employeeId,
      DateTimeRange dateRange
      ) async {
    try {
      // Get employee's monthly salary
      final monthlySalary = calculateMonthlySalary(employeeId, dateRange.start.year, dateRange.start.month);

      // Calculate present days
      final presentDays = await calculatePresentDays(employeeId, dateRange);

      // Calculate total working days in the range
      final totalWorkingDays = calculateTotalWorkingDays(dateRange);

      if (totalWorkingDays == 0) return 0.0;

      // Calculate per day salary
      final perDaySalary = monthlySalary / totalWorkingDays;

      // Calculate salary based on present days
      final attendanceBasedSalary = perDaySalary * presentDays;

      print('=== Salary Calculation for ${_employees[employeeId]?['name']} ===');
      print('Monthly Salary: $monthlySalary');
      print('Present Days: $presentDays');
      print('Total Working Days: $totalWorkingDays');
      print('Per Day Salary: $perDaySalary');
      print('Final Salary: $attendanceBasedSalary');
      print('================================');

      return attendanceBasedSalary;
    } catch (e) {
      print('Error calculating attendance-based salary for $employeeId: $e');
      return 0.0;
    }
  }

  Future<Map<String, dynamic>> getSalarySummaryWithAttendance(
      String employeeId,
      DateTimeRange dateRange
      )
  async {
    try {
      final attendanceBasedSalary = await calculateSalaryBasedOnAttendance(employeeId, dateRange);
      final totalExpenses = await calculateExpensesInDateRangeAsync(employeeId, dateRange);
      final netSalary = attendanceBasedSalary - totalExpenses;
      final expenses = getExpensesInDateRange(employeeId, dateRange);
      final presentDays = await calculatePresentDays(employeeId, dateRange);
      final totalWorkingDays = calculateTotalWorkingDays(dateRange);

      print('Salary Summary with Attendance for $employeeId:');
      print('Attendance Based Salary: $attendanceBasedSalary');
      print('Total Expenses: $totalExpenses');
      print('Net Salary: $netSalary');
      print('Present Days: $presentDays/$totalWorkingDays');

      return {
        'basicSalary': attendanceBasedSalary,
        'totalExpenses': totalExpenses,
        'netSalary': netSalary,
        'expensesCount': expenses.length,
        'presentDays': presentDays,
        'totalWorkingDays': totalWorkingDays,
        'attendancePercentage': totalWorkingDays > 0 ? (presentDays / totalWorkingDays) * 100 : 0,
      };
    } catch (e) {
      print('Error in getSalarySummaryWithAttendance for $employeeId: $e');
      return {
        'basicSalary': 0.0,
        'totalExpenses': 0.0,
        'netSalary': 0.0,
        'expensesCount': 0,
        'presentDays': 0,
        'totalWorkingDays': 0,
        'attendancePercentage': 0,
      };
    }
  }

  Map<String, dynamic> getExpensesInDateRange(String employeeId, DateTimeRange dateRange) {
    final employeeExpenses = _expenses[employeeId];
    if (employeeExpenses == null || employeeExpenses.isEmpty) {
      print('No expenses found for employee: $employeeId');
      return {};
    }

    Map<String, dynamic> filteredExpenses = {};
    print('Filtering expenses for $employeeId between ${dateRange.start} and ${dateRange.end}');

    employeeExpenses.forEach((expenseId, expenseData) {
      if (expenseData is Map) {
        final dateString = expenseData['date'];
        if (dateString != null) {
          try {
            // Parse the date string
            final expenseDate = DateTime.parse(dateString);

            // Check if expense date is within range (inclusive)
            if ((expenseDate.isAtSameMomentAs(dateRange.start) ||
                expenseDate.isAfter(dateRange.start)) &&
                (expenseDate.isAtSameMomentAs(dateRange.end) ||
                    expenseDate.isBefore(dateRange.end.add(Duration(days: 1))))) {
              filteredExpenses[expenseId] = expenseData;
              print('Including expense: $expenseId, date: $dateString, amount: ${expenseData['amount']}');
            }
          } catch (e) {
            print('Error parsing date: $dateString for expense $expenseId: $e');
          }
        }
      }
    });

    print('Found ${filteredExpenses.length} expenses for $employeeId in date range');
    return filteredExpenses;
  }

  double calculateExpensesInDateRange(String employeeId, DateTimeRange dateRange) {
    final expenses = getExpensesInDateRange(employeeId, dateRange);
    double total = 0.0;

    expenses.forEach((expenseId, expenseData) {
      if (expenseData is Map && expenseData['amount'] != null) {
        try {
          final amount = expenseData['amount'] is String
              ? double.tryParse(expenseData['amount']) ?? 0.0
              : (expenseData['amount'] as num).toDouble();
          total += amount;
          print('Adding expense amount: $amount for $employeeId, ID: $expenseId');
        } catch (e) {
          print('Error parsing expense amount for $expenseId: $e');
        }
      }
    });

    print('Total expenses for $employeeId: $total');
    return total;
  }

  double calculateMonthlySalary(String employeeId, int year, int month) {
    try {
      print('=== CALCULATING MONTHLY SALARY ===');
      print('Employee ID: $employeeId');
      print('Salaries map keys: ${_salaries.keys}');
      print('Salaries map: $_salaries');

      final salaryData = _salaries[employeeId];
      if (salaryData == null) {
        print('❌ No salary data found for employee: $employeeId');
        print('Available employee IDs in salaries: ${_salaries.keys}');
        return 0.0;
      }

      print('Salary data found: $salaryData');

      // Handle different possible data structures
      double basicSalary = 0.0;

      if (salaryData is Map) {
        basicSalary = (salaryData['basicSalary'] as num?)?.toDouble() ?? 0.0;
      } else if (salaryData is num) {
        basicSalary = salaryData.toDouble();
      } else if (salaryData is String) {
        basicSalary = double.tryParse(salaryData) ?? 0.0;
      }

      print('✅ Extracted basic salary: $basicSalary');
      return basicSalary;
    } catch (e) {
      print('❌ Error in calculateMonthlySalary: $e');
      return 0.0;
    }
  }

  Map<String, dynamic> getSalarySummary(String employeeId, DateTimeRange dateRange) {
    try {
      final monthlySalary = calculateMonthlySalary(
          employeeId,
          dateRange.start.year,
          dateRange.start.month
      );

      final totalExpenses = calculateExpensesInDateRange(employeeId, dateRange);
      final netSalary = monthlySalary - totalExpenses;
      final expenses = getExpensesInDateRange(employeeId, dateRange);

      print('Salary Summary for $employeeId: Salary=$monthlySalary, Expenses=$totalExpenses, Net=$netSalary');

      return {
        'basicSalary': monthlySalary,
        'totalExpenses': totalExpenses,
        'netSalary': netSalary,
        'expensesCount': expenses.length,
      };
    } catch (e) {
      print('Error in getSalarySummary for $employeeId: $e');
      return {
        'basicSalary': 0.0,
        'totalExpenses': 0.0,
        'netSalary': 0.0,
        'expensesCount': 0,
      };
    }
  }

  double calculateNetSalary(String employeeId, DateTimeRange dateRange) {
    final monthlySalary = calculateMonthlySalary(employeeId, DateTime.now().year, DateTime.now().month);
    final totalExpenses = calculateExpensesInDateRange(employeeId, dateRange);

    return monthlySalary - totalExpenses;
  }

  void _fetchEmployees() {
    _database.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        _employees = data.map((key, value) =>
            MapEntry(key, Map<String, String>.from(value as Map)));
      } else if (data is List) {
        _employees = {
          for (int i = 0; i < data.length; i++)
            if (data[i] != null)
              i.toString(): Map<String, String>.from(data[i] as Map),
        };
      } else {
        _employees = {};
      }
      notifyListeners();
    });
  }

  void _fetchExpenses() {
    _expensesRef.onValue.listen((event) {
      final data = event.snapshot.value;
      print('Raw expenses data from Firebase: $data');
      print('Data type: ${data.runtimeType}');

      if (data == null) {
        print('No expenses data found in Firebase');
        _expenses = {};
        notifyListeners();
        return;
      }

      if (data is Map) {
        // Deep conversion of nested maps
        _expenses = {};
        data.forEach((employeeId, employeeExpenses) {
          if (employeeExpenses is Map) {
            _expenses[employeeId.toString()] = {};
            employeeExpenses.forEach((expenseId, expenseData) {
              if (expenseData is Map) {
                _expenses[employeeId.toString()][expenseId.toString()] =
                Map<String, dynamic>.from(expenseData);
              }
            });
          }
        });

        print('Processed expenses: $_expenses');
        print('Employee IDs with expenses: ${_expenses.keys.toList()}');
      } else {
        print('Unexpected data type: ${data.runtimeType}');
        _expenses = {};
      }

      notifyListeners();
    });
  }

  void _fetchSalaries() {
    _salaryRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        _salaries = Map<String, dynamic>.from(data);
      } else {
        _salaries = {};
      }
      notifyListeners();
    });
  }

  Future<void> addOrUpdateEmployee(String id, Map<String, String> employeeData) async {
    await _database.child(id).set(employeeData);
  }

  Future<void> deleteEmployee(String id) async {
    await _database.child(id).remove();
    // Also delete related expenses and salary records
    await _expensesRef.child(id).remove();
    await _salaryRef.child(id).remove();
  }

  Future<void> addExpense(String employeeId, Map<String, dynamic> expenseData) async {
    try {
      final DatabaseReference expenseRef = FirebaseDatabase.instance
          .ref()
          .child('expenses')
          .child(employeeId)
          .push(); // Use push() to generate unique key

      await expenseRef.set({
        ...expenseData,
        'id': expenseRef.key, // Store the unique ID
      });

      print('Expense added successfully for employee: $employeeId');
    } catch (e) {
      print('Error adding expense: $e');
      throw e; // Re-throw to handle in UI
    }
  }

  Future<void> deleteExpense(String employeeId, String expenseId) async {
    await _expensesRef.child(employeeId).child(expenseId).remove();
  }

  Future<Map<String, dynamic>> getEmployeeExpenses(String employeeId) async {
    final snapshot = await _expensesRef.child(employeeId).get();
    if (snapshot.exists) {
      return Map<String, dynamic>.from(snapshot.value as Map);
    }
    return {};
  }

  Future<void> setSalary(String employeeId, Map<String, dynamic> salaryData) async {
    await _salaryRef.child(employeeId).set(salaryData);
  }

  Future<Map<String, dynamic>?> getEmployeeSalary(String employeeId) async {
    final snapshot = await _salaryRef.child(employeeId).get();
    if (snapshot.exists) {
      return Map<String, dynamic>.from(snapshot.value as Map);
    }
    return null;
  }

  double calculateMonthlyExpenses(String employeeId, int year, int month) {
    final employeeExpenses = _expenses[employeeId];
    if (employeeExpenses == null) return 0.0;

    double total = 0.0;
    employeeExpenses.forEach((expenseId, expenseData) {
      if (expenseData is Map) {
        final dateString = expenseData['date'];
        if (dateString != null) {
          final date = DateTime.parse(dateString);
          if (date.year == year && date.month == month) {
            final amount = (expenseData['amount'] as num?)?.toDouble() ?? 0.0;
            total += amount;
          }
        }
      }
    });

    return total;
  }

  Future<void> markAttendance(
      BuildContext context,
      String employeeId,
      String status,
      String description,
      DateTime dateTime)
  async {
    final dateString = dateTime.toIso8601String().split('T').first;
    final timeString = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

    try {
      final snapshot = await _attendanceRef.child(employeeId).child(dateString).get();
      if (snapshot.exists) {
        // Check if attendance for this specific time already exists
        final existingData = Map<String, dynamic>.from(snapshot.value as Map);
        if (existingData['time'] == timeString) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Attendance already marked for this time."),
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }
      }

      await _attendanceRef.child(employeeId).child(dateString).set({
        'status': status,
        'description': description,
        'date': dateString,
        'time': timeString,
        'timestamp': dateTime.millisecondsSinceEpoch,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Attendance marked successfully."),
          duration: Duration(seconds: 3),
        ),
      );
      notifyListeners();
    } catch (e) {
      print("Error saving attendance: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to mark attendance: $e"),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> deleteAttendance(String employeeId, String dateString) async {
    try {
      await _attendanceRef.child(employeeId).child(dateString).remove();
      notifyListeners();
    } catch (e) {
      print("Error deleting attendance: $e");
      throw e;
    }
  }

  Future<Map<String, Map<String, dynamic>>> getAttendanceForDateRange(
      String employeeId, DateTimeRange dateRange)
  async {
    Map<String, Map<String, dynamic>> attendanceData = {};

    for (DateTime date = dateRange.start;
    date.isBefore(dateRange.end.add(const Duration(days: 1)));
    date = date.add(const Duration(days: 1))) {
      final dateString = date.toIso8601String().split('T').first;
      final snapshot = await _attendanceRef.child(employeeId).child(dateString).get();

      if (snapshot.exists) {
        attendanceData[dateString] = Map<String, dynamic>.from(snapshot.value as Map);
      }
    }

    return attendanceData;
  }

  Future<double> calculateMonthlyExpensesAsync(String employeeId, int year, int month) async {
    try {
      final snapshot = await _expensesRef.child(employeeId).get();

      if (!snapshot.exists || snapshot.value == null) {
        print('No expenses found in Firebase for employee: $employeeId');
        return 0.0;
      }

      final expensesData = snapshot.value as Map<dynamic, dynamic>;
      double total = 0.0;

      expensesData.forEach((expenseId, expenseData) {
        if (expenseData is Map) {
          final dateString = expenseData['date'];
          if (dateString != null) {
            try {
              final date = DateTime.parse(dateString);
              if (date.year == year && date.month == month) {
                final amount = expenseData['amount'];
                if (amount != null) {
                  total += (amount is String ? double.tryParse(amount) ?? 0.0 : (amount as num).toDouble());
                }
              }
            } catch (e) {
              print('Error parsing date for expense $expenseId: $e');
            }
          }
        }
      });

      print('Total expenses for $employeeId in $year-$month: $total');
      return total;
    } catch (e) {
      print('Error calculating monthly expenses for $employeeId: $e');
      return 0.0;
    }
  }

  Future<double> calculateExpensesInDateRangeAsync(String employeeId, DateTimeRange dateRange) async {
    try {
      final snapshot = await _expensesRef.child(employeeId).get();

      if (!snapshot.exists || snapshot.value == null) {
        print('No expenses found for employee: $employeeId');
        return 0.0;
      }

      final expensesData = snapshot.value as Map<dynamic, dynamic>;
      double total = 0.0;

      expensesData.forEach((expenseId, expenseData) {
        if (expenseData is Map) {
          final dateString = expenseData['date'];
          if (dateString != null) {
            try {
              final expenseDate = DateTime.parse(dateString);

              if ((expenseDate.isAtSameMomentAs(dateRange.start) || expenseDate.isAfter(dateRange.start)) &&
                  (expenseDate.isAtSameMomentAs(dateRange.end) || expenseDate.isBefore(dateRange.end.add(Duration(days: 1))))) {
                final amount = expenseData['amount'];
                if (amount != null) {
                  final amountValue = amount is String ? double.tryParse(amount) ?? 0.0 : (amount as num).toDouble();
                  total += amountValue;
                  print('Adding expense: $amountValue, date: $dateString');
                }
              }
            } catch (e) {
              print('Error parsing expense: $e');
            }
          }
        }
      });

      print('Total expenses for $employeeId in range: $total');
      return total;
    } catch (e) {
      print('Error calculating expenses: $e');
      return 0.0;
    }
  }
}
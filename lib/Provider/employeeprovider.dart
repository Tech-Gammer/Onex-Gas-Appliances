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

// Add this method to calculate expenses total properly:
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

// Fixed: Calculate monthly salary - fetch from Firebase if not in memory
  double calculateMonthlySalary(String employeeId, int year, int month) {
    final salaryData = _salaries[employeeId];
    if (salaryData == null) {
      print('No salary data found in memory for employee: $employeeId');
      return 0.0;
    }

    final basicSalary = (salaryData['basicSalary'] as num?)?.toDouble() ?? 0.0;
    print('Salary for $employeeId: $basicSalary');
    return basicSalary;
  }

// Fixed: Get salary summary for a date range with better error handling
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

// Calculate net salary after deducting expenses
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

// In your EmployeeProvider class
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

  // Salary Methods
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

  // Calculate total expenses for an employee in a specific month
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
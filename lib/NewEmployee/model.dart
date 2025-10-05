class Employee {
  String? id;
  String name;
  String address;
  double basicSalary;
  String salaryType; // 'monthly' or 'daily'
  DateTime joinDate;

  Employee({
    this.id,
    required this.name,
    required this.address,
    required this.basicSalary,
    required this.salaryType,
    required this.joinDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'basicSalary': basicSalary,
      'salaryType': salaryType,
      'joinDate': joinDate.millisecondsSinceEpoch,
    };
  }

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      basicSalary: json['basicSalary'].toDouble(),
      salaryType: json['salaryType'],
      joinDate: DateTime.fromMillisecondsSinceEpoch(json['joinDate']),
    );
  }
}

class Attendance {
  String? id;
  String employeeId;
  DateTime date;
  DateTime checkIn;
  DateTime? checkOut;
  bool isPresent;

  Attendance({
    this.id,
    required this.employeeId,
    required this.date,
    required this.checkIn,
    this.checkOut,
    required this.isPresent,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'date': date.millisecondsSinceEpoch,
      'checkIn': checkIn.millisecondsSinceEpoch,
      'checkOut': checkOut?.millisecondsSinceEpoch,
      'isPresent': isPresent,
    };
  }

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['id'],
      employeeId: json['employeeId'],
      date: DateTime.fromMillisecondsSinceEpoch(json['date']),
      checkIn: DateTime.fromMillisecondsSinceEpoch(json['checkIn']),
      checkOut: json['checkOut'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['checkOut'])
          : null,
      isPresent: json['isPresent'],
    );
  }
}

class Expense {
  String? id;
  String employeeId;
  String description;
  double amount;
  DateTime date;

  Expense({
    this.id,
    required this.employeeId,
    required this.description,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'description': description,
      'amount': amount,
      'date': date.millisecondsSinceEpoch,
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'],
      employeeId: json['employeeId'],
      description: json['description'],
      amount: json['amount'].toDouble(),
      date: DateTime.fromMillisecondsSinceEpoch(json['date']),
    );
  }
}
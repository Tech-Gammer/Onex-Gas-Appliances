class Employee {
  String? id;
  String name;
  String address;
  double basicSalary;
  String salaryType; // 'monthly' or 'daily'
  DateTime joinDate;
  double totalAdvance; // Total advance amount taken

  Employee({
    this.id,
    required this.name,
    required this.address,
    required this.basicSalary,
    required this.salaryType,
    required this.joinDate,
    this.totalAdvance = 0.0,

  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'basicSalary': basicSalary,
      'salaryType': salaryType,
      'joinDate': joinDate.millisecondsSinceEpoch,
      'totalAdvance': totalAdvance,
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
      totalAdvance: json['totalAdvance']?.toDouble() ?? 0.0,

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

class Advance {
  String? id;
  String employeeId;
  double amount;
  DateTime date;
  String description;
  bool isRepaid; // Whether this advance has been repaid

  Advance({
    this.id,
    required this.employeeId,
    required this.amount,
    required this.date,
    required this.description,
    this.isRepaid = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'amount': amount,
      'date': date.millisecondsSinceEpoch,
      'description': description,
      'isRepaid': isRepaid,
    };
  }

  factory Advance.fromJson(Map<String, dynamic> json) {
    return Advance(
      id: json['id'],
      employeeId: json['employeeId'],
      amount: json['amount'].toDouble(),
      date: DateTime.fromMillisecondsSinceEpoch(json['date']),
      description: json['description'],
      isRepaid: json['isRepaid'] ?? false,
    );
  }
}

class Salary {
  String? id;
  String employeeId;
  DateTime month; // The month for which salary is calculated
  int presentDays;
  int totalWorkingDays;
  double grossSalary;
  double totalExpenses;
  double advanceDeduction;
  double netSalary;
  DateTime calculationDate;
  bool isPaid;
  DateTime? paymentDate;

  Salary({
    this.id,
    required this.employeeId,
    required this.month,
    required this.presentDays,
    required this.totalWorkingDays,
    required this.grossSalary,
    required this.totalExpenses,
    required this.advanceDeduction,
    required this.netSalary,
    required this.calculationDate,
    this.isPaid = false,
    this.paymentDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'month': month.millisecondsSinceEpoch,
      'presentDays': presentDays,
      'totalWorkingDays': totalWorkingDays,
      'grossSalary': grossSalary,
      'totalExpenses': totalExpenses,
      'advanceDeduction': advanceDeduction,
      'netSalary': netSalary,
      'calculationDate': calculationDate.millisecondsSinceEpoch,
      'isPaid': isPaid,
      'paymentDate': paymentDate?.millisecondsSinceEpoch,
    };
  }

  factory Salary.fromJson(Map<String, dynamic> json) {
    return Salary(
      id: json['id'],
      employeeId: json['employeeId'],
      month: DateTime.fromMillisecondsSinceEpoch(json['month']),
      presentDays: json['presentDays'],
      totalWorkingDays: json['totalWorkingDays'],
      grossSalary: json['grossSalary'].toDouble(),
      totalExpenses: json['totalExpenses'].toDouble(),
      advanceDeduction: json['advanceDeduction'].toDouble(),
      netSalary: json['netSalary'].toDouble(),
      calculationDate: DateTime.fromMillisecondsSinceEpoch(json['calculationDate']),
      isPaid: json['isPaid'] ?? false,
      paymentDate: json['paymentDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['paymentDate'])
          : null,
    );
  }
}
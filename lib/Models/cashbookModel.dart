class CashbookEntry {
  final String? id;
  final String description;
  final double amount;
  final DateTime dateTime;
  final String type;
  bool isPaid;
  String? paymentMethod;
  double? paidAmount;
  DateTime? paymentDate;

  CashbookEntry({
    this.id,
    required this.description,
    required this.amount,
    required this.dateTime,
    required this.type,
    this.isPaid = false,
    this.paymentMethod,
    this.paidAmount,
    this.paymentDate,
  });

  factory CashbookEntry.fromJson(Map<String, dynamic> json) {
    return CashbookEntry(
      id: json['id'],
      description: json['description'],
      amount: (json['amount'] is int) ? (json['amount'] as int).toDouble() : json['amount'],
      dateTime: DateTime.parse(json['dateTime']),
      type: json['type'],
      isPaid: json['isPaid'] ?? false,
      paymentMethod: json['paymentMethod'],
      paidAmount: json['paidAmount']?.toDouble(),
      paymentDate: json['paymentDate'] != null
          ? DateTime.parse(json['paymentDate'])
          : null,
    );
  }


  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'dateTime': dateTime.toIso8601String(), // Ensure correct formatting
      'type': type,
      'isPaid': isPaid,
      'paymentMethod': paymentMethod,
      'paidAmount': paidAmount,
      'paymentDate': paymentDate?.toIso8601String(),
    };
  }
}

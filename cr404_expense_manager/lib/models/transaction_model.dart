class TransactionModel {
  final int id;
  final int userId;
  final int accountId;
  final int? categoryId;
  final String txType; // 'income', 'expense'
  final double amount;
  final DateTime txDate;
  final String? note;
  final bool isFuturePlanned;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined metadata
  final String? accountName;
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColor;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.accountId,
    this.categoryId,
    required this.txType,
    required this.amount,
    required this.txDate,
    this.note,
    this.isFuturePlanned = false,
    this.createdAt,
    this.updatedAt,
    this.accountName,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate = DateTime.now();
    final rawDate = map['tx_date'] ?? map['transaction_date'];
    if (rawDate != null) {
      if (rawDate is DateTime) {
        parsedDate = rawDate;
      } else {
        parsedDate = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
      }
    }

    return TransactionModel(
      id: int.tryParse(map['id']?.toString() ?? '0') ?? 0,
      userId: int.tryParse(map['user_id']?.toString() ?? '0') ?? 0,
      accountId: int.tryParse(map['account_id']?.toString() ?? '0') ?? 0,
      categoryId: int.tryParse(map['category_id']?.toString() ?? ''),
      txType: map['tx_type']?.toString() ?? map['type']?.toString() ?? 'expense',
      amount: double.tryParse(map['amount']?.toString() ?? '0') ?? 0.0,
      txDate: parsedDate,
      note: map['note']?.toString(),
      isFuturePlanned: map['is_future_planned'] == 1 ||
          map['is_future_planned'] == '1' ||
          map['is_future_planned'] == true,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
      accountName: map['account_name']?.toString(),
      categoryName: map['category_name']?.toString(),
      categoryIcon: map['category_icon']?.toString() ?? map['icon_key']?.toString(),
      categoryColor: map['category_color']?.toString() ?? map['color_hex']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'account_id': accountId,
      'category_id': categoryId,
      'type': txType,
      'tx_type': txType,
      'amount': amount,
      'transaction_date': txDate.toIso8601String().split('T')[0],
      'tx_date': txDate.toIso8601String(),
      'note': note,
      'is_future_planned': isFuturePlanned ? 1 : 0,
    };
  }
}


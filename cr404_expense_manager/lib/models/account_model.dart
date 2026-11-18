class AccountModel {
  final int id;
  final int userId;
  final String name;
  final String accountType; // 'cash', 'bank', 'prepaid', 'credit', 'ewallet'
  final double balance;
  final double creditLimit;
  final bool includeInTotal;
  final bool isHidden;
  final String colorHex;
  final DateTime? lastUsedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AccountModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.accountType,
    required this.balance,
    this.creditLimit = 0.0,
    this.includeInTotal = true,
    this.isHidden = false,
    this.colorHex = '#0284C7',
    this.lastUsedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory AccountModel.fromMap(Map<String, dynamic> map) {
    return AccountModel(
      id: int.tryParse(map['id']?.toString() ?? '0') ?? 0,
      userId: int.tryParse(map['user_id']?.toString() ?? '0') ?? 0,
      name: map['name']?.toString() ?? '',
      accountType: map['account_type']?.toString() ?? 'cash',
      balance: double.tryParse(map['calculated_balance']?.toString() ??
          map['balance']?.toString() ??
          map['current_balance']?.toString() ??
          '0') ?? 0.0,
      creditLimit: double.tryParse(map['credit_limit']?.toString() ?? '0') ?? 0.0,
      includeInTotal: map['include_in_total'] == 1 ||
          map['include_in_total'] == '1' ||
          map['include_in_total'] == true,
      isHidden: map['is_hidden'] == 1 ||
          map['is_hidden'] == '1' ||
          map['is_hidden'] == true,
      colorHex: map['color_hex']?.toString() ?? '#0284C7',
      lastUsedAt: map['last_used_at'] != null ? DateTime.tryParse(map['last_used_at'].toString()) : null,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'account_type': accountType,
      'balance': balance,
      'credit_limit': creditLimit,
      'include_in_total': includeInTotal ? 1 : 0,
      'is_hidden': isHidden ? 1 : 0,
      'color_hex': colorHex,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}


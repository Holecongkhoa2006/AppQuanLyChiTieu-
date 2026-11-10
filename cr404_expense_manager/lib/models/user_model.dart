// =============================================================================
// user_model.dart — Model người dùng CR404 Expense Manager
// Khớp với schema thực tế: username, full_name, currency, hide_balance
// Mở rộng Admin: role, status, suspension_reason, last_login_at, tx_count
// =============================================================================

class UserModel {
  final int id;
  final String username;
  final String fullName;
  final String email;
  final String? passwordHash;
  final String currency;
  final bool hideBalance;
  final String role;    // 'user' | 'premium' | 'admin'
  final String status;  // 'active' | 'suspended' | 'soft_deleted'
  final String? suspensionReason;
  final DateTime? lastLoginAt;
  final int transactionCount; // Chỉ dùng trong Admin panel (COUNT, không phải SUM)
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    this.passwordHash,
    this.currency = 'đ',
    this.hideBalance = false,
    this.role = 'user',
    this.status = 'active',
    this.suspensionReason,
    this.lastLoginAt,
    this.transactionCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  // Hiển thị tên ưu tiên: full_name > username > email prefix
  String get displayName =>
      fullName.isNotEmpty ? fullName : (username.isNotEmpty ? username : email.split('@').first);

  bool get isAdmin   => role == 'admin';
  bool get isPremium => role == 'premium';
  bool get isActive  => status == 'active';

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id:          int.tryParse(map['id']?.toString() ?? '0') ?? 0,
      username:    map['username']?.toString() ?? '',
      fullName:    map['full_name']?.toString() ?? map['username']?.toString() ?? '',
      email:       map['email']?.toString() ?? '',
      passwordHash: map['password_hash']?.toString(),
      currency:    map['currency']?.toString() ?? 'đ',
      hideBalance: map['hide_balance'] == 1 || map['hide_balance'] == '1' || map['hide_balance'] == true,
      role:        map['role']?.toString() ?? 'user',
      status:      map['status']?.toString() ?? 'active',
      suspensionReason: map['suspension_reason']?.toString(),
      lastLoginAt: map['last_login_at'] != null
          ? DateTime.tryParse(map['last_login_at'].toString())
          : null,
      transactionCount: int.tryParse(map['tx_count']?.toString() ?? '0') ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id':         id,
      'username':   username,
      'full_name':  fullName,
      'email':      email,
      'currency':   currency,
      'hide_balance': hideBalance ? 1 : 0,
      'role':       role,
      'status':     status,
    };
  }

  UserModel copyWith({
    int? id,
    String? username,
    String? fullName,
    String? email,
    String? currency,
    bool? hideBalance,
    String? role,
    String? status,
    String? suspensionReason,
    DateTime? lastLoginAt,
    int? transactionCount,
  }) {
    return UserModel(
      id:                 id ?? this.id,
      username:           username ?? this.username,
      fullName:           fullName ?? this.fullName,
      email:              email ?? this.email,
      passwordHash:       passwordHash,
      currency:           currency ?? this.currency,
      hideBalance:        hideBalance ?? this.hideBalance,
      role:               role ?? this.role,
      status:             status ?? this.status,
      suspensionReason:   suspensionReason ?? this.suspensionReason,
      lastLoginAt:        lastLoginAt ?? this.lastLoginAt,
      transactionCount:   transactionCount ?? this.transactionCount,
      createdAt:          createdAt,
      updatedAt:          updatedAt,
    );
  }
}

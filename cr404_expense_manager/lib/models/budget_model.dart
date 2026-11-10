class BudgetModel {
  final int id;
  final int userId;
  final int? categoryId;
  final String periodType; // 'weekly', 'monthly', 'yearly'
  final DateTime startDate;
  final DateTime endDate;
  final double limitAmount;
  final double alertThresholdPct;
  final double spentAmount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined metadata
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColor;

  BudgetModel({
    required this.id,
    required this.userId,
    this.categoryId,
    required this.periodType,
    required this.startDate,
    required this.endDate,
    required this.limitAmount,
    this.alertThresholdPct = 80.0,
    this.spentAmount = 0.0,
    this.createdAt,
    this.updatedAt,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
  });

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val == null) return fallback;
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString()) ?? fallback;
    }

    return BudgetModel(
      id: int.tryParse(map['id']?.toString() ?? '0') ?? 0,
      userId: int.tryParse(map['user_id']?.toString() ?? '0') ?? 0,
      categoryId: int.tryParse(map['category_id']?.toString() ?? ''),
      periodType: map['period_type']?.toString() ?? map['period']?.toString() ?? 'monthly',
      startDate: parseDate(map['start_date'], DateTime.now()),
      endDate: parseDate(map['end_date'], DateTime.now()),
      limitAmount: double.tryParse(map['limit_amount']?.toString() ?? '0') ?? 0.0,
      alertThresholdPct: double.tryParse(map['alert_threshold_pct']?.toString() ?? '80') ?? 80.0,
      spentAmount: double.tryParse(map['spent']?.toString() ?? map['spent_amount']?.toString() ?? '0') ?? 0.0,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
      categoryName: map['category_name']?.toString() ?? (map['category_id'] == null ? 'Tất cả hạng mục' : 'Hạng mục'),
      categoryIcon: map['category_icon']?.toString() ?? map['icon_key']?.toString() ?? 'bullseye',
      categoryColor: map['category_color']?.toString() ?? map['color_hex']?.toString() ?? '#0284C7',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'category_id': categoryId,
      'period_type': periodType,
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate.toIso8601String().split('T')[0],
      'limit_amount': limitAmount,
      'alert_threshold_pct': alertThresholdPct,
    };
  }
}


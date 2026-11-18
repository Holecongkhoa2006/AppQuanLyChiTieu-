class CategoryModel {
  final int id;
  final int? userId;
  final String name;
  final String categoryType; // 'income', 'expense'
  final String colorHex;
  final String iconKey;
  final bool isActive;
  final DateTime? createdAt;

  CategoryModel({
    required this.id,
    this.userId,
    required this.name,
    required this.categoryType,
    this.colorHex = '#0284C7',
    this.iconKey = 'layerGroup',
    this.isActive = true,
    this.createdAt,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: int.tryParse(map['id']?.toString() ?? '0') ?? 0,
      userId: int.tryParse(map['user_id']?.toString() ?? ''),
      name: map['name']?.toString() ?? '',
      categoryType: map['category_type']?.toString() ?? map['type']?.toString() ?? 'expense',
      colorHex: map['color_hex']?.toString() ?? '#0284C7',
      iconKey: map['icon_key']?.toString() ?? map['icon_code']?.toString() ?? map['icon']?.toString() ?? 'layerGroup',
      isActive: map['is_active'] == null ||
          map['is_active'] == 1 ||
          map['is_active'] == '1' ||
          map['is_active'] == true,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'category_type': categoryType,
      'color_hex': colorHex,
      'icon_key': iconKey,
      'is_active': isActive ? 1 : 0,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}


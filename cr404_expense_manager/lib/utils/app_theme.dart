// =============================================================================
// app_theme.dart — Design System Material 3: Màu sắc, Theme, Helpers
// =============================================================================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'currency_formatter.dart';

// ─── MÀU SẮC CHUẨN TÀI CHÍNH THƯƠNG MẠI ──────────────────────────────────────
class AppColors {
  AppColors._();

  // Bảng màu chính
  static const Color primary      = Color(0xFF0284C7); // Ocean Blue
  static const Color primaryDark  = Color(0xFF0369A1);
  static const Color primaryLight = Color(0xFFE0F2FE);
  
  static const Color income       = Color(0xFF059669); // Emerald
  static const Color incomeLight  = Color(0xFFD1FAE5);
  
  static const Color expense      = Color(0xFFDC2626); // Red
  static const Color expenseLight = Color(0xFFFEE2E2);
  
  static const Color warning      = Color(0xFFD97706); // Amber
  static const Color warningLight = Color(0xFFFEF3C7);

  // Surfaces & Backgrounds (Material 3 Commercial Light Theme)
  static const Color scaffoldBg   = Color(0xFFF8FAFC);
  static const Color surface      = Colors.white;
  static const Color surfaceCard  = Colors.white;
  static const Color surfaceLight = Color(0xFFF1F5F9);
  static const Color border       = Color(0xFFE2E8F0);
  static const Color divider      = Color(0xFFF1F5F9);

  // Text
  static const Color textPrimary   = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF64748B); // Slate 500
  static const Color textMuted     = Color(0xFF94A3B8); // Slate 400

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
  );
  static const LinearGradient incomeGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF059669), Color(0xFF047857)],
  );
  static const LinearGradient expenseGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
  );
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
  );

  // ─── ADAPTIVE CONTRAST GUARD (WCAG AA) & MÀU DANH MỤC THỜI GIAN THỰC ────────

  /// Chuyển mã Hex từ MySQL sang Color an toàn
  static Color parseHexColor(String? hexString, {Color fallback = const Color(0xFF0284C7)}) {
    if (hexString == null || hexString.trim().isEmpty) return fallback;
    final clean = hexString.replaceFirst('#', '').trim();
    if (clean.length == 6) {
      final val = int.tryParse('FF$clean', radix: 16);
      if (val != null) return Color(val);
    } else if (clean.length == 8) {
      final val = int.tryParse(clean, radix: 16);
      if (val != null) return Color(val);
    }
    return fallback;
  }

  /// Tự động cân chỉnh độ tương phản màu danh mục theo Nền Sáng / Nền Tối (Chuẩn WCAG AA)
  static Color getAdaptiveCategoryColor(String? hexString, BuildContext context) {
    final rawColor = parseHexColor(hexString);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hsl = HSLColor.fromColor(rawColor);
    final luminance = rawColor.computeLuminance();

    // Nếu trên nền Sáng mà màu Admin chọn quá chói (như vàng chanh #FFEB3B, luminance > 0.65)
    // -> giảm độ sáng xuống để icon và chữ hiển thị rõ ràng, không bị lóa mắt
    if (!isDark && luminance > 0.65) {
      return hsl.withLightness(0.38).withSaturation((hsl.saturation * 1.1).clamp(0.0, 1.0)).toColor();
    }
    // Nếu trên nền Tối mà màu quá sẫm (luminance < 0.15) -> tăng độ sáng lên để nổi bật trên nền tối
    if (isDark && luminance < 0.15) {
      return hsl.withLightness(0.68).toColor();
    }
    return rawColor;
  }

  /// Màu nền Badge bo tròn dịu mắt cho Icon danh mục trên cả nền Sáng và Tối
  static Color getAdaptiveCategoryBadgeBg(String? hexString, BuildContext context) {
    final fg = getAdaptiveCategoryColor(hexString, context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return fg.withValues(alpha: isDark ? 0.22 : 0.14);
  }
}

// ─── MATERIAL 3 THEME DATA ───────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.scaffoldBg,
    primaryColor: AppColors.primary,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.income,
      surface: AppColors.surface,
      error: AppColors.expense,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.textPrimary,
    ),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      iconTheme: IconThemeData(color: AppColors.textPrimary),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surfaceCard,
      elevation: 0,
      shadowColor: Colors.black.withAlpha(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, space: 1, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.expense)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.expense)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      ),
    ),
  );

  // Backward compatibility getter
  static ThemeData get dark => lightTheme;
}

// ─── TIỆN ÍCH ĐỊNH DẠNG ──────────────────────────────────────────────────────
class Formatters {
  Formatters._();
  static String money(dynamic amount) => CurrencyFormatter.formatVND(amount);
  static String formatMoney(dynamic amount) => CurrencyFormatter.formatVND(amount);
  static String date(DateTime d) => CurrencyFormatter.formatDate(d);
  static String formatDate(DateTime d) => CurrencyFormatter.formatDate(d);
  static String monthYear(DateTime d) => DateFormat('MM/yyyy').format(d);
  static String weekday(DateTime d) {
    try {
      return DateFormat('EEEE', 'vi_VN').format(d);
    } catch (_) {
      const days = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
      return days[d.weekday - 1];
    }
  }
}

// ─── HELPER CHUYỂN ĐỔI MÀU HEX ───────────────────────────────────────────────
Color hexToColor(String? hex) {
  if (hex == null || hex.isEmpty) return AppColors.primary;
  try {
    String cleanHex = hex.replaceAll('#', '').trim();
    if (cleanHex.length == 6) {
      cleanHex = 'FF$cleanHex';
    }
    return Color(int.parse(cleanHex, radix: 16));
  } catch (_) {
    return AppColors.primary;
  }
}

// ─── WIDGET TÁI SỬ DỤNG ──────────────────────────────────────────────────────

/// Card chuẩn phong cách Material 3 với viền mỏng và bo góc 16
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final Color? color;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.borderColor,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      margin: margin ?? const EdgeInsets.only(bottom: 12),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: cardContent,
      );
    }
    return cardContent;
  }
}

/// Nút bấm chính
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final LinearGradient gradient;
  final Color shadowColor;

  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.gradient = AppColors.primaryGradient,
    this.shadowColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed == null ? null : gradient,
          color: onPressed == null ? AppColors.border : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: onPressed == null ? [] : [
            BoxShadow(color: shadowColor.withAlpha(60), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: loading ? null : onPressed,
          child: loading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ),
    );
  }
}

/// Banner lỗi
class ErrorBanner extends StatelessWidget {
  final String message;
  const ErrorBanner(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.expenseLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.expense.withAlpha(80)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.expense, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: const TextStyle(color: AppColors.expense, fontSize: 13, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}

/// Widget báo lỗi kết nối có nút thử lại
class ConnectionErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ConnectionErrorWidget({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.expenseLight, shape: BoxShape.circle),
            child: const Icon(Icons.wifi_off_rounded, color: AppColors.expense, size: 48),
          ),
          const SizedBox(height: 20),
          const Text('Không thể kết nối MySQL', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử kết nối lại'),
          ),
        ]),
      ),
    );
  }
}

/// Widget trạng thái trống
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const EmptyStateWidget({super.key, required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.primary, size: 40),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

/// TextField chuẩn cho toàn bộ form
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final String? hint;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure      = false,
    this.suffix,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        suffixIcon: suffix,
      ),
    );
  }
}

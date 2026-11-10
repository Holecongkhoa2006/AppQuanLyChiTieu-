import 'dart:ui';
import 'package:intl/intl.dart';

/// Tiện ích định dạng tiền tệ VNĐ và thời gian chuẩn thương mại
class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _vndCurrency = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  static final NumberFormat _numberFormat = NumberFormat('#,##0', 'vi_VN');

  /// Định dạng chuẩn: `216.858.120 ₫`
  static String formatVND(dynamic amount, {bool showSymbol = true}) {
    if (amount == null) return showSymbol ? '0 ₫' : '0';
    double val = 0;
    if (amount is num) {
      val = amount.toDouble();
    } else {
      val = double.tryParse(amount.toString()) ?? 0;
    }
    return showSymbol ? _vndCurrency.format(val).trim() : _numberFormat.format(val);
  }

  /// Định dạng rút gọn trên biểu đồ (VD: `1,44M`, `420k`, `144k`)
  static String formatCompact(dynamic amount) {
    if (amount == null) return '0';
    double val = 0;
    if (amount is num) {
      val = amount.toDouble();
    } else {
      val = double.tryParse(amount.toString()) ?? 0;
    }
    final abs = val.abs();
    final sign = val < 0 ? '-' : '';
    if (abs >= 1000000000) {
      return '$sign${(abs / 1000000000).toStringAsFixed(1).replaceAll('.0', '')}B';
    } else if (abs >= 1000000) {
      return '$sign${(abs / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    } else if (abs >= 1000) {
      return '$sign${(abs / 1000).toStringAsFixed(0)}k';
    }
    return '$sign${abs.toStringAsFixed(0)}';
  }

  /// Định dạng ngày `DD/MM/YYYY`
  static String formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// Định dạng ngày ngắn `DD/MM`
  static String formatShortDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('dd/MM').format(date);
  }

  /// Định dạng tháng năm `MM/yyyy` hoặc `Tháng M, yyyy`
  static String formatMonthYear(DateTime? date) {
    if (date == null) return '';
    return 'Tháng ${date.month}/${date.year}';
  }

  /// FontFeature để các số thẳng cột
  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  // ─── TÍNH NĂNG ĐA TIỀN TỆ & TỶ GIÁ THỰC (MULTI-CURRENCY LIVE FX) ─────────

  /// Quy đổi từ ngoại tệ (USD, EUR, JPY...) sang VND theo tỷ giá thực tế từ Aiven MySQL
  static double convertForeignToVnd({
    required double amount,
    required String currencyCode,
    required Map<String, double> ratesToVnd,
  }) {
    final code = currencyCode.toUpperCase().trim();
    if (code == 'VND' || code == 'Đ' || code == '₫') return amount;
    final rate = ratesToVnd[code] ?? 1.0;
    return (amount * rate).roundToDouble();
  }

  /// Định dạng số tiền ngoại tệ kèm ký hiệu chuẩn (VD: `$50.00`, `€35.50`, `¥3,200`)
  static String formatForeign(double amount, String currencyCode, {String? symbol}) {
    final code = currencyCode.toUpperCase().trim();
    final sym = symbol ?? code;
    if (code == 'USD') {
      return NumberFormat.currency(locale: 'en_US', symbol: sym).format(amount);
    } else if (code == 'EUR') {
      return NumberFormat.currency(locale: 'de_DE', symbol: sym).format(amount);
    } else if (code == 'JPY') {
      return NumberFormat.currency(locale: 'ja_JP', symbol: sym, decimalDigits: 0).format(amount);
    }
    return '${NumberFormat('#,##0.00').format(amount)} $sym';
  }
}


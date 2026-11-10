// =============================================================================
// app_icons.dart — Quản lý toàn bộ Icon Font Awesome đẹp mắt cho ứng dụng
// =============================================================================
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AppIcons {
  AppIcons._();

  // ─── ICON HẠNG MỤC THU / CHI (CATEGORIES) ──────────────────────────────────
  static FaIconData getCategoryIcon(String? code) {
    if (code == null || code.isEmpty) return FontAwesomeIcons.layerGroup;
    final c = code.toLowerCase().trim();

    // Map các mã icon phổ biến sang Font Awesome
    switch (c) {
      // Ăn uống
      case 'restaurant':
      case 'food':
      case 'dining':
      case 'ăn uống':
      case '🍔':
      case '🍜':
        return FontAwesomeIcons.utensils;
      case 'coffee':
      case 'cafe':
      case 'cà phê':
      case '☕':
        return FontAwesomeIcons.mugHot;

      // Mua sắm
      case 'shopping_bag':
      case 'shopping':
      case 'cart':
      case 'mua sắm':
      case '🛍️':
      case '🛒':
        return FontAwesomeIcons.bagShopping;

      // Nhà cửa / Tiền điện nước
      case 'home':
      case 'house':
      case 'nhà cửa':
      case '🏠':
        return FontAwesomeIcons.houseChimney;
      case 'bill':
      case 'electric':
      case 'water':
      case 'hóa đơn':
        return FontAwesomeIcons.fileInvoiceDollar;

      // Vận chuyển / Xăng dầu
      case 'directions_car':
      case 'car':
      case 'transport':
      case 'vận chuyển':
      case 'xăng xe':
      case '🚗':
        return FontAwesomeIcons.carSide;
      case 'gas':
      case 'fuel':
        return FontAwesomeIcons.gasPump;

      // Giải trí / Du lịch
      case 'celebration':
      case 'entertainment':
      case 'party':
      case 'giải trí':
      case '🎉':
        return FontAwesomeIcons.champagneGlasses;
      case 'game':
      case 'gamepad':
        return FontAwesomeIcons.gamepad;
      case 'travel':
      case 'flight':
      case 'du lịch':
      case '✈️':
        return FontAwesomeIcons.planeDeparture;

      // Thu nhập / Lương
      case 'payments':
      case 'salary':
      case 'income':
      case 'lương / thu nhập':
      case 'thu nhập':
      case '💵':
        return FontAwesomeIcons.moneyBillWave;
      case 'bonus':
      case 'thưởng':
        return FontAwesomeIcons.sackDollar;

      // Sức khỏe / Y tế
      case 'local_hospital':
      case 'medical':
      case 'health':
      case 'hospital':
      case 'y tế':
      case 'thuốc':
      case '💊':
        return FontAwesomeIcons.kitMedical;

      // Giáo dục / Học tập
      case 'school':
      case 'education':
      case 'book':
      case 'giáo dục':
      case 'học tập':
      case '📚':
        return FontAwesomeIcons.graduationCap;

      // Cá nhân / Làm đẹp / Spa
      case 'face_retouching_natural':
      case 'personal':
      case 'beauty':
      case 'spa':
      case 'cá nhân':
      case 'làm đẹp':
        return FontAwesomeIcons.spa;

      // Quà tặng
      case 'gift':
      case 'quà tặng':
      case '🎁':
        return FontAwesomeIcons.gift;

      // Ngân sách / Mục tiêu
      case 'target':
      case 'bullseye':
      case 'ngân sách':
      case '🎯':
        return FontAwesomeIcons.bullseye;

      // Đầu tư
      case 'investment':
      case 'invest':
      case 'đầu tư':
        return FontAwesomeIcons.arrowTrendUp;

      // Khác
      case 'more_horiz':
      case 'more':
      case 'khác':
      case 'category':
        return FontAwesomeIcons.ellipsis;

      default:
        return FontAwesomeIcons.shapes;
    }
  }

  // ─── ICON LOẠI TÀI KHOẢN (ACCOUNTS) ────────────────────────────────────────
  static FaIconData getAccountIcon(String? type) {
    if (type == null) return FontAwesomeIcons.wallet;
    final t = type.toLowerCase().trim();

    switch (t) {
      case 'cash':
      case 'wallet':
      case 'tiền mặt':
        return FontAwesomeIcons.wallet;
      case 'bank':
      case 'ngân hàng':
        return FontAwesomeIcons.buildingColumns;
      case 'credit':
      case 'thẻ tín dụng':
        return FontAwesomeIcons.creditCard;
      case 'prepaid':
      case 'thẻ trả trước':
        return FontAwesomeIcons.idCard;
      case 'savings':
      case 'tiết kiệm':
        return FontAwesomeIcons.piggyBank;
      default:
        return FontAwesomeIcons.vault;
    }
  }

  // ─── ICON ĐIỀU HƯỚNG TỔNG QUAN ──────────────────────────────────────────────
  static const FaIconData navDashboard = FontAwesomeIcons.tableColumns;
  static const FaIconData navAccounts  = FontAwesomeIcons.wallet;
  static const FaIconData navCalendar  = FontAwesomeIcons.calendarDays;
  static const FaIconData navChart     = FontAwesomeIcons.chartPie;
  static const FaIconData navBudget    = FontAwesomeIcons.bullseye;
  static const FaIconData add          = FontAwesomeIcons.plus;

  // Icon Trạng thái
  static const FaIconData incomeArrow  = FontAwesomeIcons.arrowDown;
  static const FaIconData expenseArrow = FontAwesomeIcons.arrowUp;
  static const FaIconData eyeOpen      = FontAwesomeIcons.eye;
  static const FaIconData eyeClosed    = FontAwesomeIcons.eyeSlash;
  static const FaIconData warning      = FontAwesomeIcons.triangleExclamation;
  static const FaIconData bell         = FontAwesomeIcons.bell;
  static const FaIconData logout       = FontAwesomeIcons.rightFromBracket;
  static const FaIconData user         = FontAwesomeIcons.user;
  static const FaIconData lock         = FontAwesomeIcons.lock;
  static const FaIconData note         = FontAwesomeIcons.noteSticky;
}

// ─── WIDGET BADGE ICON HẠNG MỤC CỰC ĐẸP ──────────────────────────────────────
class CategoryIconBadge extends StatelessWidget {
  final String? iconCode;
  final Color color;
  final double size;
  final double iconSize;

  const CategoryIconBadge({
    super.key,
    required this.iconCode,
    required this.color,
    this.size = 42,
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: FaIcon(
          AppIcons.getCategoryIcon(iconCode),
          color: color,
          size: iconSize,
        ),
      ),
    );
  }
}

// ─── WIDGET BADGE ICON TÀI KHOẢN CHUYÊN NGHIỆP ──────────────────────────────
class AccountIconBadge extends StatelessWidget {
  final String? accountType;
  final Color color;
  final double size;
  final double iconSize;

  const AccountIconBadge({
    super.key,
    required this.accountType,
    required this.color,
    this.size = 46,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withValues(alpha: 0.75),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: FaIcon(
          AppIcons.getAccountIcon(accountType),
          color: Colors.white,
          size: iconSize,
        ),
      ),
    );
  }
}

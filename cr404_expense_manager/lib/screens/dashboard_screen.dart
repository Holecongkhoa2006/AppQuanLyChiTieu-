import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_theme.dart';
import '../utils/app_icons.dart';
import '../utils/currency_formatter.dart';
import '../models/account_model.dart';
import '../models/budget_model.dart';
import '../services/mysql_service.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  final int userId;
  final VoidCallback? onOpenCalendar12Months;

  const DashboardScreen({
    super.key,
    required this.userId,
    this.onOpenCalendar12Months,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  bool _hasError = false;
  String _errorMsg = '';
  bool _hideBalance = false;
  DateTime _selectedDate = DateTime.now();

  Map<String, dynamic>? _bundle;
  String _userName = 'Người dùng';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadUserSession();
    _fetchData();
  }

  Future<void> _loadUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName =
          prefs.getString('user_full_name') ??
          prefs.getString('user_name') ??
          'Người dùng';
      _hideBalance = prefs.getBool('hide_balances') ?? false;
    });
  }

  Future<void> _toggleHideBalance() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hideBalance = !_hideBalance;
    });
    await prefs.setBool('hide_balances', _hideBalance);
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final bundle = await MySqlService.instance.fetchDashboardBundle(
        widget.userId,
        _selectedDate,
      );
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMsg = e.toString();
        _loading = false;
      });
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month + offset,
      );
    });
    _fetchData();
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Đăng xuất tài khoản',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text('Bạn có chắc muốn đăng xuất khỏi ứng dụng?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading && _bundle == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_hasError && _bundle == null) {
      return ConnectionErrorWidget(message: _errorMsg, onRetry: _fetchData);
    }

    final totalOwned = (_bundle?['total_owned'] as num?)?.toDouble() ?? 0.0;
    final creditDebt = (_bundle?['credit_debt'] as num?)?.toDouble() ?? 0.0;
    final currentMonthData =
        _bundle?['current_month'] as Map<String, dynamic>? ?? {};
    final prevMonthData = _bundle?['prev_month'] as Map<String, dynamic>? ?? {};
    final List<AccountModel> accounts = _bundle?['accounts'] != null
        ? List<AccountModel>.from(_bundle!['accounts'])
        : [];
    final List<Map<String, dynamic>> last7Days = _bundle?['last_7_days'] != null
        ? List<Map<String, dynamic>>.from(_bundle!['last_7_days'])
        : [];
    final List<double> netWorthTrend = _bundle?['net_worth_trend'] != null
        ? List<double>.from(_bundle!['net_worth_trend'])
        : [0, 0, 0, 0, 0];
    final List<BudgetModel> budgets = _bundle?['budgets'] != null
        ? List<BudgetModel>.from(_bundle!['budgets'])
        : [];

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryLight,
              child: Text(
                _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Xin chào, $_userName',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    CurrencyFormatter.formatMonthYear(_selectedDate),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Bộ chọn tháng
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 22),
            tooltip: 'Tháng trước',
            onPressed: () => _changeMonth(-1),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 22),
            tooltip: 'Tháng sau',
            onPressed: () => _changeMonth(1),
          ),
          // Ẩn/Hiện số dư
          IconButton(
            icon: Icon(
              _hideBalance
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 20,
            ),
            tooltip: _hideBalance ? 'Hiện số dư' : 'Ẩn số dư',
            onPressed: _toggleHideBalance,
          ),
          // Đăng xuất
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              size: 20,
              color: AppColors.expense,
            ),
            tooltip: 'Đăng xuất',
            onPressed: _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _fetchData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CARD 1: SƠ LƯỢC 2 THÁNG LIỀN KỀ
              _buildTwoMonthsComparisonCard(currentMonthData, prevMonthData),
              const SizedBox(height: 16),

              // CARD 2: CÁC TÀI KHOẢN (VÍ, NGÂN HÀNG, THẺ)
              _buildAccountsCard(accounts),
              const SizedBox(height: 16),

              // CARD 3: CÁC CHI PHÍ - 7 NGÀY QUA (BAR CHART)
              _buildLast7DaysExpenseCard(last7Days),
              const SizedBox(height: 16),

              // CARD 4: SỐ DƯ & XU HƯỚNG TÀI SẢN (LINE CHART)
              _buildNetWorthAndTrendCard(totalOwned, creditDebt, netWorthTrend),
              const SizedBox(height: 16),

              // CARD 5: TÓM TẮT NGÂN SÁCH
              _buildBudgetSummaryCard(budgets),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CARD 1: Sơ lược 2 tháng liền kề (Semi-Donut so sánh)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildTwoMonthsComparisonCard(
    Map<String, dynamic> curr,
    Map<String, dynamic> prev,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sơ lược 2 tháng liền kề',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (widget.onOpenCalendar12Months != null)
                TextButton(
                  onPressed: widget.onOpenCalendar12Months,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 30),
                  ),
                  child: const Text(
                    'Xem 12 tháng',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMonthSemiDonutColumn(
                  title: 'Tháng ${_selectedDate.month}/${_selectedDate.year}',
                  income: (curr['income'] as num?)?.toDouble() ?? 0.0,
                  expense: (curr['expense'] as num?)?.toDouble() ?? 0.0,
                ),
              ),
              Container(width: 1, height: 160, color: AppColors.border),
              Expanded(
                child: _buildMonthSemiDonutColumn(
                  title:
                      'Tháng ${prev['month'] ?? _selectedDate.month - 1}/${prev['year'] ?? _selectedDate.year}',
                  income: (prev['income'] as num?)?.toDouble() ?? 0.0,
                  expense: (prev['expense'] as num?)?.toDouble() ?? 0.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSemiDonutColumn({
    required String title,
    required double income,
    required double expense,
  }) {
    final net = income - expense;
    final total = income + expense;
    final incomePct = total > 0 ? (income / total) * 100 : 50.0;
    final expensePct = total > 0 ? (expense / total) * 100 : 50.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          // Semi-Donut
          SizedBox(
            height: 70,
            width: 110,
            child: PieChart(
              PieChartData(
                startDegreeOffset: 180,
                sectionsSpace: 2,
                centerSpaceRadius: 28,
                sections: [
                  PieChartSectionData(
                    value: incomePct,
                    color: AppColors.income,
                    showTitle: false,
                    radius: 12,
                  ),
                  PieChartSectionData(
                    value: expensePct,
                    color: AppColors.expense,
                    showTitle: false,
                    radius: 12,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildTinyRow('Thu nhập', income, AppColors.income),
          const SizedBox(height: 4),
          _buildTinyRow('Chi phí', expense, AppColors.expense),
          const Divider(height: 12),
          _buildTinyRow(
            'Tổng ròng',
            net,
            net >= 0 ? AppColors.income : AppColors.expense,
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTinyRow(
    String label,
    double val,
    Color color, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          _hideBalance ? '••••••••' : CurrencyFormatter.formatVND(val),
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            fontFeatures: CurrencyFormatter.tabularFigures,
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CARD 2: Danh sách các tài khoản
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildAccountsCard(List<AccountModel> accounts) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Các tài khoản',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${accounts.length} ví/thẻ',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (accounts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Chưa có tài khoản nào',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ...accounts.map((acc) {
              final isCredit = acc.accountType == 'credit';
              final color = hexToColor(acc.colorHex);
              final dateStr = acc.lastUsedAt != null
                  ? CurrencyFormatter.formatDate(acc.lastUsedAt)
                  : 'Chưa sử dụng';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: FaIcon(
                          AppIcons.getAccountIcon(acc.accountType),
                          color: color,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            acc.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Lần dùng cuối: $dateStr',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _hideBalance
                          ? '••••••••'
                          : CurrencyFormatter.formatVND(acc.balance),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isCredit && acc.balance < 0
                            ? AppColors.expense
                            : AppColors.textPrimary,
                        fontFeatures: CurrencyFormatter.tabularFigures,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CARD 3: Thu chi 7 ngày qua (Bar Chart - Hiển thị cả Thu & Chi)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildLast7DaysExpenseCard(List<Map<String, dynamic>> last7Days) {
    double maxAmt = 100000;
    for (var item in last7Days) {
      final inc = (item['income'] as num?)?.toDouble() ?? 0.0;
      final exp = (item['expense'] as num?)?.toDouble() ??
          (item['amount'] as num?)?.toDouble() ??
          0.0;
      if (inc > maxAmt) maxAmt = inc;
      if (exp > maxAmt) maxAmt = exp;
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Thu & Chi — 7 ngày qua',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.income,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Thu',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.expense,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Chi',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxAmt * 1.25,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.textPrimary,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final item = last7Days[group.x.toInt()];
                      final date = item['date'] as DateTime;
                      final isIncome = rodIndex == 0;
                      return BarTooltipItem(
                        '${CurrencyFormatter.formatShortDate(date)}\n',
                        const TextStyle(color: Colors.white70, fontSize: 11),
                        children: [
                          TextSpan(
                            text: '${isIncome ? "Thu: +" : "Chi: -"}${CurrencyFormatter.formatVND(rod.toY)}',
                            style: TextStyle(
                              color: isIncome
                                  ? const Color(0xFF34D399)
                                  : const Color(0xFFF87171),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        int idx = value.toInt();
                        if (idx >= 0 && idx < last7Days.length) {
                          final date = last7Days[idx]['date'] as DateTime;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              CurrencyFormatter.formatShortDate(date),
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(last7Days.length, (i) {
                  final inc =
                      (last7Days[i]['income'] as num?)?.toDouble() ?? 0.0;
                  final exp =
                      (last7Days[i]['expense'] as num?)?.toDouble() ??
                          (last7Days[i]['amount'] as num?)?.toDouble() ??
                          0.0;
                  return BarChartGroupData(
                    x: i,
                    barsSpace: 4,
                    barRods: [
                      BarChartRodData(
                        toY: inc,
                        gradient: AppColors.incomeGradient,
                        width: 8,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                      BarChartRodData(
                        toY: exp,
                        gradient: AppColors.expenseGradient,
                        width: 8,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CARD 4: Số dư & Xu hướng tài sản (Line Chart)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildNetWorthAndTrendCard(
    double totalOwned,
    double creditDebt,
    List<double> trend,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Số dư & Xu hướng Tài sản',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tổng tiền đang sở hữu',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _hideBalance
                          ? '••••••••'
                          : CurrencyFormatter.formatVND(totalOwned),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.income,
                        fontFeatures: CurrencyFormatter.tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thẻ tín dụng (Dư nợ)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _hideBalance
                          ? '••••••••'
                          : (creditDebt > 0
                                ? '-${CurrencyFormatter.formatVND(creditDebt)}'
                                : '0 ₫'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.expense,
                        fontFeatures: CurrencyFormatter.tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Biểu đồ miền LineChart
          SizedBox(
            height: 130,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      trend.length,
                      (i) => FlSpot(i.toDouble(), trend[i]),
                    ),
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AppColors.income,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.income.withAlpha(40),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CARD 5: Tóm tắt ngân sách (Thanh tiến độ & vạch hôm nay)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildBudgetSummaryCard(List<BudgetModel> budgets) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tóm tắt Ngân sách',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${budgets.length} ngân sách',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (budgets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'Chưa thiết lập ngân sách nào cho tháng này',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ...budgets.take(3).map((b) {
              final pct = b.limitAmount > 0
                  ? (b.spentAmount / b.limitAmount).clamp(0.0, 1.0)
                  : 0.0;
              Color barColor;
              if (pct >= 0.95) {
                barColor = AppColors.expense;
              } else if (pct >= 0.70) {
                barColor = AppColors.warning;
              } else {
                barColor = AppColors.income;
              }

              // Vị trí hôm nay trong chu kỳ (0.0 đến 1.0)
              final now = DateTime.now();
              final totalDays = b.endDate.difference(b.startDate).inDays + 1;
              final passedDays = now.difference(b.startDate).inDays + 1;
              final todayPct = totalDays > 0
                  ? (passedDays / totalDays).clamp(0.0, 1.0)
                  : 0.5;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          b.categoryName ?? 'Tất cả hạng mục',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${CurrencyFormatter.formatVND(b.spentAmount)} / ${CurrencyFormatter.formatVND(b.limitAmount)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: barColor,
                            fontFeatures: CurrencyFormatter.tabularFigures,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Thanh tiến độ có vạch ngày hôm nay
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        return Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.centerLeft,
                          children: [
                            // Nền thanh
                            Container(
                              height: 8,
                              width: width,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            // Tiến độ đã chi
                            Container(
                              height: 8,
                              width: width * pct,
                              decoration: BoxDecoration(
                                color: barColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            // Vạch dọc đánh dấu ngày hôm nay
                            Positioned(
                              left: (width * todayPct).clamp(0.0, width - 2),
                              top: -3,
                              child: Container(
                                width: 2,
                                height: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

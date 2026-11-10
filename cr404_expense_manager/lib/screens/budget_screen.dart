import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../utils/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../models/budget_model.dart';
import '../models/category_model.dart';
import '../services/mysql_service.dart';

class BudgetScreen extends StatefulWidget {
  final int userId;
  const BudgetScreen({super.key, required this.userId});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen>
    with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  List<BudgetModel> _budgets = [];
  Map<String, dynamic>? _burnUpData;
  bool _showBurnUp = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final results = await Future.wait([
        MySqlService.instance.getBudgets(widget.userId),
        MySqlService.instance.getCumulativeBurnUpData(
          widget.userId,
          now.year,
          now.month,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _budgets = results[0] as List<BudgetModel>;
        _burnUpData = results[1] as Map<String, dynamic>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openAddBudgetModal() async {
    List<CategoryModel> categories = [];
    try {
      categories = await MySqlService.instance.getCategories('expense');
    } catch (_) {}

    CategoryModel? selectedCategory;
    String selectedPeriod = 'monthly';
    final limitCtrl = TextEditingController(text: '5000000');

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Thiết lập Ngân sách mới',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Chu kỳ
              DropdownButtonFormField<String>(
                initialValue: selectedPeriod,
                decoration: const InputDecoration(
                  labelText: 'Chu kỳ ngân sách',
                ),
                items: const [
                  DropdownMenuItem(value: 'weekly', child: Text('Hàng tuần')),
                  DropdownMenuItem(value: 'monthly', child: Text('Hàng tháng')),
                  DropdownMenuItem(value: 'yearly', child: Text('Hàng năm')),
                ],
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedPeriod = val);
                },
              ),
              const SizedBox(height: 12),
              // Hạng mục (NULL = Tất cả hạng mục)
              DropdownButtonFormField<CategoryModel?>(
                initialValue: selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Hạng mục áp dụng',
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('🎯 Tất cả hạng mục'),
                  ),
                  ...categories.map(
                    (c) => DropdownMenuItem(value: c, child: Text(c.name)),
                  ),
                ],
                onChanged: (val) => setModalState(() => selectedCategory = val),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: limitCtrl,
                label: 'Hạn mức chi tiêu (VNĐ)',
                icon: Icons.track_changes_rounded,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              GradientButton(
                label: 'Tạo Ngân sách',
                onPressed: () async {
                  final limit =
                      double.tryParse(
                        limitCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
                      ) ??
                      0.0;
                  if (limit <= 0) return;

                  final now = DateTime.now();
                  DateTime start = DateTime(now.year, now.month, 1);
                  DateTime end = DateTime(now.year, now.month + 1, 0);

                  if (selectedPeriod == 'weekly') {
                    start = now.subtract(Duration(days: now.weekday - 1));
                    end = start.add(const Duration(days: 6));
                  } else if (selectedPeriod == 'yearly') {
                    start = DateTime(now.year, 1, 1);
                    end = DateTime(now.year, 12, 31);
                  }

                  await MySqlService.instance.createBudget(
                    userId: widget.userId,
                    categoryId: selectedCategory?.id,
                    periodType: selectedPeriod,
                    startDate: start,
                    endDate: end,
                    limitAmount: limit,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadData();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading && _budgets.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final weeklyBudgets = _budgets
        .where((b) => b.periodType == 'weekly')
        .toList();
    final monthlyBudgets = _budgets
        .where((b) => b.periodType == 'monthly')
        .toList();
    final yearlyBudgets = _budgets
        .where((b) => b.periodType == 'yearly')
        .toList();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadData,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // Header & Nút thêm ngân sách
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Kế hoạch Ngân sách',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      backgroundColor: AppColors.primary,
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text(
                      'Thêm ngân sách',
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: _openAddBudgetModal,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // BIỂU ĐỒ MIỀN LŨY KẾ BURN-UP (Khi chạm vào "Tất cả hạng mục" hoặc hiển thị mặc định)
              if (_burnUpData != null && _showBurnUp) _buildBurnUpCard(),
              const SizedBox(height: 16),

              // NHÓM 1: NGÂN SÁCH HÀNG THÁNG
              if (monthlyBudgets.isNotEmpty) ...[
                _buildSectionHeader(
                  'Ngân sách hàng tháng (${monthlyBudgets.length})',
                ),
                ...monthlyBudgets.map((b) => _buildBudgetCard(b)),
                const SizedBox(height: 16),
              ],

              // NHÓM 2: NGÂN SÁCH HÀNG TUẦN
              if (weeklyBudgets.isNotEmpty) ...[
                _buildSectionHeader(
                  'Ngân sách hàng tuần (${weeklyBudgets.length})',
                ),
                ...weeklyBudgets.map((b) => _buildBudgetCard(b)),
                const SizedBox(height: 16),
              ],

              // NHÓM 3: NGÂN SÁCH HÀNG NĂM
              if (yearlyBudgets.isNotEmpty) ...[
                _buildSectionHeader(
                  'Ngân sách hàng năm (${yearlyBudgets.length})',
                ),
                ...yearlyBudgets.map((b) => _buildBudgetCard(b)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CARD BIỂU ĐỒ MIỀN LŨY KẾ (CUMULATIVE BURN-UP CHART)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildBurnUpCard() {
    final limit =
        (_burnUpData!['limit_amount'] as num?)?.toDouble() ?? 10000000.0;
    final spent = (_burnUpData!['current_spent'] as num?)?.toDouble() ?? 0.0;
    final int daysInMonth = _burnUpData!['days_in_month'] as int? ?? 30;
    final List<Map<String, dynamic>> points = List<Map<String, dynamic>>.from(
      _burnUpData!['points'] ?? [],
    );

    List<FlSpot> spots = [];
    for (var p in points) {
      final day = (p['day'] as num).toDouble();
      final cum = (p['cumulative'] as num).toDouble();
      spots.add(FlSpot(day, cum));
    }
    if (spots.isEmpty) {
      spots = [const FlSpot(1, 0)];
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Biểu đồ lũy kế Burn-up — Tháng này',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: Icon(
                  _showBurnUp
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20,
                ),
                onPressed: () => setState(() => _showBurnUp = !_showBurnUp),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Đã chi: ${CurrencyFormatter.formatVND(spent)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.expense,
                ),
              ),
              Text(
                'Hạn mức: ${CurrencyFormatter.formatVND(limit)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minX: 1,
                maxX: daysInMonth.toDouble(),
                minY: 0,
                maxY: (limit * 1.25 > spent ? limit * 1.25 : spent * 1.2),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.textPrimary,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((s) {
                        return LineTooltipItem(
                          'Ngày ${s.x.toInt()}\n${CurrencyFormatter.formatVND(s.y)}',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: AppColors.border, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 5,
                      getTitlesWidget: (val, meta) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${val.toInt()}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Đường kẻ ngang màu đỏ đánh dấu Hạn mức
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: limit,
                      color: AppColors.expense,
                      strokeWidth: 2,
                      dashArray: [6, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        padding: const EdgeInsets.only(right: 6, bottom: 2),
                        style: const TextStyle(
                          color: AppColors.expense,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                        labelResolver: (_) => 'Hạn mức',
                      ),
                    ),
                  ],
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.25,
                    color: AppColors.primary,
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withAlpha(35),
                    ),
                    dotData: const FlDotData(show: false),
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
  // CARD CHI TIẾT TỪNG NGÂN SÁCH
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildBudgetCard(BudgetModel b) {
    final pct = b.limitAmount > 0
        ? (b.spentAmount / b.limitAmount).clamp(0.0, 1.0)
        : 0.0;
    final remaining = b.limitAmount - b.spentAmount;

    Color progressColor;
    if (pct >= 0.95) {
      progressColor = AppColors.expense;
    } else if (pct >= 0.70) {
      progressColor = AppColors.warning;
    } else {
      progressColor = AppColors.income;
    }

    final now = DateTime.now();
    final totalDays = b.endDate.difference(b.startDate).inDays + 1;
    final passedDays = now.difference(b.startDate).inDays + 1;
    final remainingDays = totalDays - passedDays;
    final todayPct = totalDays > 0
        ? (passedDays / totalDays).clamp(0.0, 1.0)
        : 0.5;

    final safeSpendPerDay = remainingDays > 0 && remaining > 0
        ? remaining / remainingDays
        : 0.0;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () {
        if (b.categoryId == null) {
          setState(() => _showBurnUp = true);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dòng thời gian: 01/06/2026 — 98% — 30/06/2026
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${CurrencyFormatter.formatDate(b.startDate)} — ${(todayPct * 100).toStringAsFixed(0)}% — ${CurrencyFormatter.formatDate(b.endDate)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: progressColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(pct * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: progressColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            b.categoryName ?? '🎯 Tất cả hạng mục',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),

          // Thanh tiến độ có vạch đánh dấu ngày hôm nay
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 8,
                    width: width,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Container(
                    height: 8,
                    width: width * pct,
                    decoration: BoxDecoration(
                      color: progressColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Positioned(
                    left: (width * todayPct).clamp(0.0, width - 2),
                    top: -4,
                    child: Container(
                      width: 2,
                      height: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),

          // Dòng số liệu: 0 ₫ — Đã chi — Hạn mức
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '0 ₫',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              Text(
                'Đã chi: ${CurrencyFormatter.formatVND(b.spentAmount)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: progressColor,
                ),
              ),
              Text(
                'Hạn mức: ${CurrencyFormatter.formatVND(b.limitAmount)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Divider(height: 18),

          // Hộp thông tin Số dư còn lại + Định mức chi an toàn / ngày
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Số dư còn lại',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.formatVND(remaining),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: remaining >= 0
                              ? AppColors.income
                              : AppColors.expense,
                          fontFeatures: CurrencyFormatter.tabularFigures,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chi an toàn / ngày',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.formatVND(safeSpendPerDay),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          fontFeatures: CurrencyFormatter.tabularFigures,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../utils/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../services/mysql_service.dart';

class ChartScreen extends StatefulWidget {
  final int userId;
  const ChartScreen({super.key, required this.userId});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen>
    with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  List<Map<String, dynamic>> _categories = [];
  DateTime _selectedMonth = DateTime.now();
  int _touchedIndex = -1;

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
      final data = await MySqlService.instance.getExpenseByCategory(
        widget.userId,
        _selectedMonth.year,
        _selectedMonth.month,
      );
      if (!mounted) return;
      setState(() {
        _categories = data;
        _loading = false;
        if (_categories.isNotEmpty && _touchedIndex >= _categories.length) {
          _touchedIndex = 0;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + offset,
      );
      _touchedIndex = -1;
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    double totalExpense = _categories.fold(
      0.0,
      (s, c) => s + ((c['total'] as num?)?.toDouble() ?? 0.0),
    );

    // Lấy thông tin hiển thị tại tâm Donut
    String centerTitle = 'Tổng chi tiêu';
    double centerAmount = totalExpense;
    String centerPercent = '100%';

    if (_touchedIndex >= 0 && _touchedIndex < _categories.length) {
      final item = _categories[_touchedIndex];
      centerTitle = item['name'] as String;
      centerAmount = (item['total'] as num?)?.toDouble() ?? 0.0;
      final pct = totalExpense > 0 ? (centerAmount / totalExpense) * 100 : 0.0;
      centerPercent = '${pct.toStringAsFixed(2)}%';
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // Month Selector Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 24),
                    onPressed: () => _changeMonth(-1),
                  ),
                  Text(
                    'Tháng ${_selectedMonth.month} năm ${_selectedMonth.year}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 24),
                    onPressed: () => _changeMonth(1),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _categories.isEmpty
                  ? const Center(
                      child: Text(
                        'Chưa có chi tiêu nào trong tháng này',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _loadData,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        children: [
                          // Donut Chart Card với tâm rộng 75
                          AppCard(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: SizedBox(
                              height: 250,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  PieChart(
                                    PieChartData(
                                      pieTouchData: PieTouchData(
                                        touchCallback:
                                            (
                                              FlTouchEvent event,
                                              pieTouchResponse,
                                            ) {
                                              setState(() {
                                                if (!event
                                                        .isInterestedForInteractions ||
                                                    pieTouchResponse == null ||
                                                    pieTouchResponse
                                                            .touchedSection ==
                                                        null) {
                                                  return;
                                                }
                                                _touchedIndex = pieTouchResponse
                                                    .touchedSection!
                                                    .touchedSectionIndex;
                                              });
                                            },
                                      ),
                                      borderData: FlBorderData(show: false),
                                      sectionsSpace: 3,
                                      centerSpaceRadius: 75,
                                      sections: List.generate(
                                        _categories.length,
                                        (i) {
                                          final isTouched = i == _touchedIndex;
                                          final radius = isTouched
                                              ? 28.0
                                              : 20.0;
                                          final item = _categories[i];
                                          final amt =
                                              (item['total'] as num?)
                                                  ?.toDouble() ??
                                              0.0;
                                          final color = hexToColor(
                                            item['color'] as String?,
                                          );

                                          return PieChartSectionData(
                                            color: color,
                                            value: amt,
                                            title: '',
                                            radius: radius,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  // Nội dung ở tâm Donut (Category, Amount, %)
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        centerTitle,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        CurrencyFormatter.formatVND(
                                          centerAmount,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.expense,
                                          fontFeatures:
                                              CurrencyFormatter.tabularFigures,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.expenseLight,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          centerPercent,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.expense,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Danh sách phân rã theo hạng mục
                          const Text(
                            'Chi tiết theo Hạng mục',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),

                          AppCard(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              children: [
                                ...List.generate(_categories.length, (i) {
                                  final item = _categories[i];
                                  final amt =
                                      (item['total'] as num?)?.toDouble() ??
                                      0.0;
                                  final color = hexToColor(
                                    item['color'] as String?,
                                  );
                                  final pct = totalExpense > 0
                                      ? (amt / totalExpense) * 100
                                      : 0.0;
                                  final isSelected = i == _touchedIndex;

                                  return InkWell(
                                    onTap: () {
                                      setState(() => _touchedIndex = i);
                                    },
                                    child: Container(
                                      color: isSelected
                                          ? AppColors.primaryLight.withAlpha(80)
                                          : Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          // Chấm màu
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Tên hạng mục
                                          Expanded(
                                            child: Text(
                                              item['name'] as String,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: isSelected
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                          // % Tỷ trọng
                                          Text(
                                            '${pct.toStringAsFixed(1)}%',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          // Số tiền chi
                                          Text(
                                            '-${CurrencyFormatter.formatVND(amt)}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.expense,
                                              fontFeatures: CurrencyFormatter
                                                  .tabularFigures,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                                const Divider(height: 1),
                                // Dòng Tổng cộng cuối cùng
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Tổng cộng',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        CurrencyFormatter.formatVND(
                                          totalExpense,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.expense,
                                          fontFeatures:
                                              CurrencyFormatter.tabularFigures,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

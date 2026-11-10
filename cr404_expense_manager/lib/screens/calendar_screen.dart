import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../utils/app_theme.dart';
import '../utils/app_icons.dart';
import '../utils/currency_formatter.dart';
import '../models/transaction_model.dart';
import '../services/mysql_service.dart';

class CalendarScreen extends StatefulWidget {
  final int userId;
  final bool initial12MonthsView;

  const CalendarScreen({
    super.key,
    required this.userId,
    this.initial12MonthsView = false,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with AutomaticKeepAliveClientMixin {
  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  int _viewMode = 0; // 0 = Lịch ngày, 1 = Sơ lược 12 tháng

  bool _loadingMonth = false;
  bool _loadingDay = false;
  Map<DateTime, Map<String, double>> _calendarData = {};
  List<TransactionModel> _dayTransactions = [];
  List<Map<String, dynamic>> _year12Months = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.initial12MonthsView) {
      _viewMode = 1;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    if (_viewMode == 0) {
      await _loadMonthData();
      await _loadDayTransactions(_selectedDay);
    } else {
      await _load12MonthsData();
    }
  }

  Future<void> _loadMonthData() async {
    setState(() => _loadingMonth = true);
    try {
      final data = await MySqlService.instance.getMonthlyCalendarData(
        widget.userId,
        _focusedMonth.year,
        _focusedMonth.month,
      );
      if (!mounted) return;
      setState(() {
        _calendarData = data;
        _loadingMonth = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMonth = false);
    }
  }

  Future<void> _loadDayTransactions(DateTime day) async {
    setState(() => _loadingDay = true);
    try {
      final txns = await MySqlService.instance.getTransactionsByDay(
        widget.userId,
        day,
      );
      if (!mounted) return;
      setState(() {
        _dayTransactions = txns;
        _loadingDay = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingDay = false);
    }
  }

  Future<void> _load12MonthsData() async {
    setState(() => _loadingMonth = true);
    try {
      final list = await MySqlService.instance.get12MonthsSummary(
        widget.userId,
        _focusedMonth.year,
      );
      if (!mounted) return;
      setState(() {
        _year12Months = list;
        _loadingMonth = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMonth = false);
    }
  }

  void _changePeriod(int offset) {
    setState(() {
      if (_viewMode == 0) {
        _focusedMonth = DateTime(
          _focusedMonth.year,
          _focusedMonth.month + offset,
        );
      } else {
        _focusedMonth = DateTime(
          _focusedMonth.year + offset,
          _focusedMonth.month,
        );
      }
    });
    _loadData();
  }

  Future<void> _deleteTx(TransactionModel tx) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận xóa giao dịch'),
        content: Text(
          'Bạn có chắc muốn xóa giao dịch "${tx.note ?? tx.categoryName ?? 'Chi tiêu'}" số tiền ${CurrencyFormatter.formatVND(tx.amount)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await MySqlService.instance.deleteTransaction(tx.id, widget.userId);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final titleStr = _viewMode == 0
        ? 'Tháng ${_focusedMonth.month} năm ${_focusedMonth.year}'
        : 'Năm ${_focusedMonth.year}';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation & Segmented Mode Switch
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: Colors.white,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded, size: 24),
                        onPressed: () => _changePeriod(-1),
                      ),
                      Text(
                        titleStr,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded, size: 24),
                        onPressed: () => _changePeriod(1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        label: Text(
                          'Lịch ngày',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ButtonSegment(
                        value: 1,
                        label: Text(
                          'Sơ lược 12 tháng',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    selected: {_viewMode},
                    onSelectionChanged: (val) {
                      setState(() => _viewMode = val.first);
                      _loadData();
                    },
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: AppColors.primaryLight,
                      selectedForegroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content
            Expanded(
              child: _loadingMonth
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _viewMode == 0
                  ? _buildDailyCalendarView()
                  : _build12MonthsView(),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 1. CHẾ ĐỘ LỊCH NGÀY (7 CỘT + GRIDVIEW + TỔNG & LISTVIEW)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildDailyCalendarView() {
    final daysInMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
      0,
    ).day;
    final firstWeekday = DateTime(
      _focusedMonth.year,
      _focusedMonth.month,
      1,
    ).weekday; // 1 = T2 ... 7 = CN

    double dayIncome = 0;
    double dayExpense = 0;
    for (var tx in _dayTransactions) {
      if (tx.txType == 'income') {
        dayIncome += tx.amount;
      } else {
        dayExpense += tx.amount;
      }
    }

    return Column(
      children: [
        // Header 7 cột
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: const [
              _WeekdayHeader('T.Hai'),
              _WeekdayHeader('T.Ba'),
              _WeekdayHeader('T.Tư'),
              _WeekdayHeader('T.Năm'),
              _WeekdayHeader('T.Sáu'),
              _WeekdayHeader('T.Bảy'),
              _WeekdayHeader('CN', isWeekend: true),
            ],
          ),
        ),
        const Divider(height: 1),

        // GridView 7 cột ngày trong tháng
        Container(
          color: Colors.white,
          height: 240,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42, // 6 tuần x 7 ngày
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, index) {
              final dayOffset = index - (firstWeekday - 1);
              if (dayOffset < 0 || dayOffset >= daysInMonth) {
                return const SizedBox.shrink();
              }

              final dayNum = dayOffset + 1;
              final currentDate = DateTime(
                _focusedMonth.year,
                _focusedMonth.month,
                dayNum,
              );
              final isSelected =
                  currentDate.year == _selectedDay.year &&
                  currentDate.month == _selectedDay.month &&
                  currentDate.day == _selectedDay.day;
              final isToday =
                  currentDate.year == DateTime.now().year &&
                  currentDate.month == DateTime.now().month &&
                  currentDate.day == DateTime.now().day;

              final dayKey = DateTime(
                currentDate.year,
                currentDate.month,
                currentDate.day,
              );
              final dayData = _calendarData[dayKey];
              final inc = dayData?['income'] ?? 0.0;
              final exp = dayData?['expense'] ?? 0.0;
              final net = inc - exp;

              return InkWell(
                onTap: () {
                  setState(() => _selectedDay = currentDate);
                  _loadDayTransactions(currentDate);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryLight.withAlpha(120)
                        : (isToday
                              ? AppColors.surfaceLight
                              : Colors.transparent),
                    border: isSelected
                        ? Border.all(color: AppColors.primary, width: 1.5)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNum',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected || isToday
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (inc > 0)
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: AppColors.income,
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (inc > 0 && exp > 0) const SizedBox(width: 2),
                          if (exp > 0)
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: AppColors.expense,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      if (net != 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.formatCompact(net),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: net > 0
                                ? AppColors.income
                                : AppColors.expense,
                            fontFeatures: CurrencyFormatter.tabularFigures,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),

        // Thống kê ngày đã chọn
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppColors.surfaceLight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ngày ${CurrencyFormatter.formatDate(_selectedDay)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  Text(
                    '+${CurrencyFormatter.formatVND(dayIncome)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.income,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '-${CurrencyFormatter.formatVND(dayExpense)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.expense,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Danh sách giao dịch trong ngày
        Expanded(
          child: _loadingDay
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _dayTransactions.isEmpty
              ? const Center(
                  child: Text(
                    'Không có giao dịch nào trong ngày này',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: _dayTransactions.length,
                  itemBuilder: (context, i) {
                    final tx = _dayTransactions[i];
                    final isInc = tx.txType == 'income';
                    final color = hexToColor(tx.categoryColor);

                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
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
                                AppIcons.getCategoryIcon(tx.categoryIcon),
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
                                  tx.categoryName ?? 'Chưa phân loại',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (tx.note != null && tx.note!.isNotEmpty)
                                  Text(
                                    tx.note!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                Text(
                                  tx.accountName ?? '',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${isInc ? '+' : '-'}${CurrencyFormatter.formatVND(tx.amount)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isInc
                                  ? AppColors.income
                                  : AppColors.expense,
                              fontFeatures: CurrencyFormatter.tabularFigures,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: AppColors.expense,
                            ),
                            onPressed: () => _deleteTx(tx),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 2. CHẾ ĐỘ SƠ LƯỢC 12 THÁNG TRONG NĂM
  // ───────────────────────────────────────────────────────────────────────────
  Widget _build12MonthsView() {
    if (_year12Months.isEmpty) {
      return const Center(
        child: Text(
          'Không có dữ liệu thu chi cho năm này',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: _year12Months.length,
      itemBuilder: (context, i) {
        final item = _year12Months[i];
        final monthNum = item['month'] as int;
        final inc = (item['income'] as num?)?.toDouble() ?? 0.0;
        final exp = (item['expense'] as num?)?.toDouble() ?? 0.0;
        final net = (item['net'] as num?)?.toDouble() ?? 0.0;
        final total = inc + exp;

        final incPct = total > 0 ? (inc / total) * 100 : 50.0;
        final expPct = total > 0 ? (exp / total) * 100 : 50.0;

        return AppCard(
          margin: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              // Mini Donut
              SizedBox(
                width: 60,
                height: 60,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 18,
                    sections: [
                      PieChartSectionData(
                        value: incPct,
                        color: AppColors.income,
                        showTitle: false,
                        radius: 8,
                      ),
                      PieChartSectionData(
                        value: expPct,
                        color: AppColors.expense,
                        showTitle: false,
                        radius: 8,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Thông tin tháng
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tháng $monthNum',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Thu nhập',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '+${CurrencyFormatter.formatVND(inc)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.income,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Chi phí',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '-${CurrencyFormatter.formatVND(exp)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.expense,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tổng ròng',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.formatVND(net),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: net >= 0
                                ? AppColors.income
                                : AppColors.expense,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  final String title;
  final bool isWeekend;
  const _WeekdayHeader(this.title, {this.isWeekend = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isWeekend ? AppColors.expense : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

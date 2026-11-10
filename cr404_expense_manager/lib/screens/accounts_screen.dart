import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../utils/app_theme.dart';
import '../utils/app_icons.dart';
import '../utils/currency_formatter.dart';
import '../models/account_model.dart';
import '../services/mysql_service.dart';

class AccountsScreen extends StatefulWidget {
  final int userId;
  const AccountsScreen({super.key, required this.userId});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen>
    with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  List<AccountModel> _accounts = [];
  bool _hideBalance = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _loading = true);
    try {
      final list = await MySqlService.instance.getAccounts(widget.userId);
      if (!mounted) return;
      setState(() {
        _accounts = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleInclude(AccountModel acc, bool val) async {
    await MySqlService.instance.toggleAccountIncludeInTotal(acc.id, val);
    _loadAccounts();
  }

  // Modal Chuyển khoản nội bộ
  void _openTransferModal(AccountModel sourceAcc) {
    if (_accounts.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cần ít nhất 2 tài khoản để thực hiện chuyển khoản!'),
        ),
      );
      return;
    }

    final targetCandidates = _accounts
        .where((a) => a.id != sourceAcc.id)
        .toList();
    AccountModel targetAcc = targetCandidates.first;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController(
      text: 'Chuyển tiền sang ${targetAcc.name}',
    );

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
                    'Chuyển khoản nội bộ',
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
              // Từ ví nguồn
              Text(
                'Từ tài khoản: ${sourceAcc.name} (Số dư: ${CurrencyFormatter.formatVND(sourceAcc.balance)})',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              // Sang ví đích
              DropdownButtonFormField<AccountModel>(
                initialValue: targetAcc,
                decoration: const InputDecoration(labelText: 'Đến tài khoản'),
                items: targetCandidates.map((a) {
                  return DropdownMenuItem(value: a, child: Text(a.name));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setModalState(() {
                      targetAcc = val;
                      noteCtrl.text = 'Chuyển tiền sang ${val.name}';
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: amountCtrl,
                label: 'Số tiền chuyển (VNĐ)',
                icon: Icons.payments_outlined,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: noteCtrl,
                label: 'Ghi chú',
                icon: Icons.notes_rounded,
              ),
              const SizedBox(height: 20),
              GradientButton(
                label: 'Xác nhận Chuyển khoản',
                onPressed: () async {
                  final amt =
                      double.tryParse(
                        amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
                      ) ??
                      0.0;
                  if (amt <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Vui lòng nhập số tiền hợp lệ!'),
                      ),
                    );
                    return;
                  }
                  final ok = await MySqlService.instance
                      .transferBetweenAccounts(
                        userId: widget.userId,
                        fromAccountId: sourceAcc.id,
                        toAccountId: targetAcc.id,
                        amount: amt,
                        note: noteCtrl.text.trim(),
                      );
                  if (ok) {
                    if (ctx.mounted) Navigator.pop(ctx);
                    _loadAccounts();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Chuyển tiền thành công!'),
                          backgroundColor: AppColors.income,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Modal Thêm tài khoản mới
  void _openAddAccountModal() {
    final nameCtrl = TextEditingController();
    final balanceCtrl = TextEditingController(text: '0');
    final limitCtrl = TextEditingController(text: '0');
    String selectedType = 'cash';

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
                    'Thêm tài khoản / Ví mới',
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
              AppTextField(
                controller: nameCtrl,
                label: 'Tên tài khoản (Ví dụ: Techcombank, MoMo)',
                icon: Icons.account_balance_wallet_outlined,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                decoration: const InputDecoration(labelText: 'Loại tài khoản'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Ví tiền mặt')),
                  DropdownMenuItem(
                    value: 'bank',
                    child: Text('Tài khoản ngân hàng'),
                  ),
                  DropdownMenuItem(
                    value: 'ewallet',
                    child: Text('Ví điện tử (MoMo, ZaloPay)'),
                  ),
                  DropdownMenuItem(
                    value: 'credit',
                    child: Text('Thẻ tín dụng'),
                  ),
                  DropdownMenuItem(
                    value: 'prepaid',
                    child: Text('Thẻ trả trước'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedType = val);
                },
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: balanceCtrl,
                label: 'Số dư ban đầu (VNĐ)',
                icon: Icons.attach_money_rounded,
                keyboardType: TextInputType.number,
              ),
              if (selectedType == 'credit') ...[
                const SizedBox(height: 12),
                AppTextField(
                  controller: limitCtrl,
                  label: 'Hạn mức tín dụng (VNĐ)',
                  icon: Icons.credit_score_rounded,
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: 20),
              GradientButton(
                label: 'Lưu tài khoản',
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final bal =
                      double.tryParse(
                        balanceCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
                      ) ??
                      0.0;
                  final lim =
                      double.tryParse(
                        limitCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
                      ) ??
                      0.0;

                  await MySqlService.instance.createAccount(
                    userId: widget.userId,
                    name: nameCtrl.text.trim(),
                    accountType: selectedType,
                    balance: bal,
                    creditLimit: lim,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadAccounts();
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

    // Tính tổng chỉ với các tài khoản có include_in_total == true
    double includedTotal = 0;
    for (var a in _accounts) {
      if (a.includeInTotal) {
        includedTotal += a.balance;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header Tổng cộng
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tổng cộng tài sản (Được bật tính)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _hideBalance
                            ? '••••••••'
                            : CurrencyFormatter.formatVND(includedTotal),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.income,
                          fontFeatures: CurrencyFormatter.tabularFigures,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      _hideBalance
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () =>
                        setState(() => _hideBalance = !_hideBalance),
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
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _loadAccounts,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        children: [
                          ..._accounts.map((acc) {
                            final color = hexToColor(acc.colorHex);
                            final isCredit = acc.accountType == 'credit';

                            return AppCard(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: color.withAlpha(25),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Center(
                                          child: FaIcon(
                                            AppIcons.getAccountIcon(
                                              acc.accountType,
                                            ),
                                            color: color,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              acc.name,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            Text(
                                              isCredit
                                                  ? 'Thẻ tín dụng (Hạn mức: ${CurrencyFormatter.formatVND(acc.creditLimit)})'
                                                  : 'Tài khoản thường',
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
                                            : CurrencyFormatter.formatVND(
                                                acc.balance,
                                              ),
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: isCredit && acc.balance < 0
                                              ? AppColors.expense
                                              : AppColors.textPrimary,
                                          fontFeatures:
                                              CurrencyFormatter.tabularFigures,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  // 3 nút điều khiển trực tiếp trên thẻ
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Switch "Bình thường" (Tính vào tổng)
                                      Row(
                                        children: [
                                          Switch(
                                            value: acc.includeInTotal,
                                            activeThumbColor: AppColors.primary,
                                            onChanged: (val) =>
                                                _toggleInclude(acc, val),
                                          ),
                                          const Text(
                                            'Tính vào tổng',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          // Chuyển khoản nội bộ
                                          IconButton(
                                            icon: const Icon(
                                              Icons.swap_horiz_rounded,
                                              color: AppColors.primary,
                                              size: 22,
                                            ),
                                            tooltip:
                                                'Chuyển khoản nội bộ (<->)',
                                            onPressed: () =>
                                                _openTransferModal(acc),
                                          ),
                                          // Con mắt ẩn/hiện
                                          IconButton(
                                            icon: Icon(
                                              _hideBalance
                                                  ? Icons
                                                        .visibility_off_outlined
                                                  : Icons.visibility_outlined,
                                              size: 20,
                                              color: AppColors.textSecondary,
                                            ),
                                            onPressed: () => setState(
                                              () =>
                                                  _hideBalance = !_hideBalance,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                          // Nút thêm tài khoản
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(
                              Icons.add_rounded,
                              color: AppColors.primary,
                            ),
                            label: const Text(
                              '+ Thêm tài khoản mới',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: _openAddAccountModal,
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

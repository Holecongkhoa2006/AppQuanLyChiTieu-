import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../utils/app_theme.dart';
import '../utils/app_icons.dart';
import '../utils/currency_formatter.dart';
import '../models/account_model.dart';
import '../models/category_model.dart';
import '../services/mysql_service.dart';
import '../services/bill_ocr_service.dart';

class AddTransactionScreen extends StatefulWidget {
  final int userId;
  final List<dynamic>? accounts;

  const AddTransactionScreen({super.key, required this.userId, this.accounts});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  int _txTypeIndex = 0; // 0 = Chi phí, 1 = Thu nhập, 2 = Chuyển khoản
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  List<AccountModel> _accountList = [];
  List<CategoryModel> _categoryList = [];

  AccountModel? _selectedAccount;
  AccountModel? _toAccount; // Cho chuyển khoản
  CategoryModel? _selectedCategory;

  bool _isFuturePlanned = false;
  bool _loading = false;
  bool _loadingInit = true;
  bool _scanningOcr = false;

  // ─── TÍNH NĂNG THÔNG MINH: ĐA TIỀN TỆ & CỜ TÍNH NĂNG ─────────────────────
  bool _ocrEnabled = true;
  bool _multiCurrencyEnabled = true;
  String _selectedCurrency = 'VND';
  List<Map<String, dynamic>> _currencies = [];
  Map<String, double> _ratesToVnd = {'VND': 1.0};
  List<Map<String, dynamic>> _categoryKeywords = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadInitData();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitData() async {
    setState(() => _loadingInit = true);
    try {
      final accs = await MySqlService.instance.getAccounts(widget.userId);
      final cats = await MySqlService.instance.getCategories('expense', userId: widget.userId);
      
      // Tải cấu hình từ xa: cờ tính năng, danh sách ngoại tệ & từ khóa
      final flags = await MySqlService.instance.getRemoteFeatureFlags();
      final curs = await MySqlService.instance.getActiveSystemCurrencies();
      final kwMap = await MySqlService.instance.getCategoryKeywordsMap();

      final Map<String, double> rateMap = {};
      for (final c in curs) {
        final code = (c['code'] ?? 'VND').toString().toUpperCase();
        rateMap[code] = (c['rate_to_vnd'] as num?)?.toDouble() ?? 1.0;
      }

      setState(() {
        _accountList = accs;
        if (accs.isNotEmpty) {
          _selectedAccount = accs.first;
          if (accs.length > 1) {
            _toAccount = accs[1];
          }
        }
        _categoryList = cats;
        if (cats.isNotEmpty) {
          _selectedCategory = cats.first;
        }

        _ocrEnabled = flags['receipt_ocr_scanner_v2'] ?? true;
        _multiCurrencyEnabled = flags['multi_currency_live_fx'] ?? true;
        _currencies = curs;
        _ratesToVnd = rateMap;
        _categoryKeywords = kwMap;
        _loadingInit = false;
      });
    } catch (_) {
      setState(() => _loadingInit = false);
    }
  }

  Future<void> _changeType(int index) async {
    setState(() {
      _txTypeIndex = index;
    });

    if (index == 0) {
      final cats = await MySqlService.instance.getCategories('expense', userId: widget.userId);
      setState(() {
        _categoryList = cats;
        _selectedCategory = cats.isNotEmpty ? cats.first : null;
      });
    } else if (index == 1) {
      final cats = await MySqlService.instance.getCategories('income', userId: widget.userId);
      setState(() {
        _categoryList = cats;
        _selectedCategory = cats.isNotEmpty ? cats.first : null;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  // ─── TÍNH NĂNG OCR QUÉT BILL CHUYỂN KHOẢN & HÓA ĐƠN ──────────────────────
  Future<void> _showScanOptions() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quét Bill / Hóa Đơn Thông Minh (OCR v2)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              const Text(
                'Nhận diện Bill chuyển khoản ngân hàng hoặc Hóa đơn siêu thị/nhà hàng',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const Divider(height: 24),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                ),
                title: const Text('Chụp ảnh Hóa đơn / Bill giấy', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Mở camera chụp trực tiếp hóa đơn thanh toán', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _processBillImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.income.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.income),
                ),
                title: const Text('Chọn ảnh chụp màn hình Bill chuyển khoản', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Từ thư viện ảnh (Vietcombank, MB, Techcombank, MoMo...)', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _processBillImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processBillImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 92,
      );
      if (picked == null) return;

      setState(() => _scanningOcr = true);

      final result = await BillOcrService.instance.scanBillImage(
        imagePath: picked.path,
        categoryKeywords: _categoryKeywords,
      );

      if (!mounted) return;
      setState(() => _scanningOcr = false);

      if (result == null || result.amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy số tiền hợp lệ trên bill. Vui lòng thử lại với ảnh rõ nét hơn!'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }

      // 1. Tự động điền số tiền
      if (result.currencyCode == 'USD' || result.currencyCode == 'EUR') {
        _amountCtrl.text = result.amount.toStringAsFixed(2);
      } else {
        _amountCtrl.text = result.amount.toStringAsFixed(0);
      }

      // 2. Tự động chuyển đơn vị tiền tệ nếu phát hiện ngoại tệ
      if (_multiCurrencyEnabled && _ratesToVnd.containsKey(result.currencyCode)) {
        _selectedCurrency = result.currencyCode;
      } else {
        _selectedCurrency = 'VND';
      }

      // 3. Tự động chuyển phân loại (Thu/Chi)
      final newTypeIndex = result.type == 'income' ? 1 : 0;
      if (newTypeIndex != _txTypeIndex) {
        await _changeType(newTypeIndex);
      }

      // 4. Tự động điền ngày giao dịch
      _selectedDate = result.transactionDate;

      // 5. Tự động điền nội dung giao dịch
      if (result.note.isNotEmpty) {
        _noteCtrl.text = result.note;
      }

      // 6. Tự động khớp Ví/Tài khoản nguồn
      if (result.detectedBankOrWallet != null && _accountList.isNotEmpty) {
        final bankLower = result.detectedBankOrWallet!.toLowerCase();
        for (final acc in _accountList) {
          final accName = acc.name.toLowerCase();
          if (accName.contains(bankLower) || 
              (bankLower.contains('ví') && acc.accountType == 'cash') ||
              (bankLower.contains('bank') && acc.accountType == 'bank')) {
            _selectedAccount = acc;
            break;
          }
        }
      }

      // 7. Tự động gợi ý và chọn danh mục
      if (result.suggestedCategoryName != null && _categoryList.isNotEmpty) {
        final catLower = result.suggestedCategoryName!.toLowerCase();
        for (final cat in _categoryList) {
          if (cat.name.toLowerCase() == catLower || cat.name.toLowerCase().contains(catLower)) {
            _selectedCategory = cat;
            break;
          }
        }
      }

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Bóc tách thành công: ${_amountCtrl.text} $_selectedCurrency ${result.detectedBankOrWallet != null ? '• ${result.detectedBankOrWallet}' : ''}',
          ),
          backgroundColor: AppColors.income,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _scanningOcr = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi quét bill: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
  }

  // ─── LƯU GIAO DỊCH KÈM QUY ĐỔI NGOẠI TỆ THEO TỶ GIÁ THỰC ────────────────
  Future<void> _save() async {
    final rawAmountText = _amountCtrl.text.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
    final rawAmount = double.tryParse(rawAmountText) ?? 0.0;

    if (rawAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập số tiền hợp lệ!'),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    if (_selectedAccount == null) {
      if (_accountList.isNotEmpty) {
        _selectedAccount = _accountList.first;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa có tài khoản nào được tạo hoặc đang tải. Vui lòng thử lại!'),
            backgroundColor: AppColors.expense,
          ),
        );
        return;
      }
    }

    setState(() => _loading = true);

    try {
      // Tính toán số tiền quy đổi sang VND để bảo đảm Trigger tính toán current_balance luôn chuẩn xác 100%
      final double finalVndAmount = CurrencyFormatter.convertForeignToVnd(
        amount: rawAmount,
        currencyCode: _selectedCurrency,
        ratesToVnd: _ratesToVnd,
      );

      // Nếu là ngoại tệ, tự động ghi chú tỷ giá và số tiền gốc vào trường note
      String noteText = _noteCtrl.text.trim();
      if (_selectedCurrency != 'VND') {
        final rate = _ratesToVnd[_selectedCurrency] ?? 1.0;
        final fxFootnote = '[Gốc: ${CurrencyFormatter.formatForeign(rawAmount, _selectedCurrency)} • Tỷ giá: ${CurrencyFormatter.formatVND(rate, showSymbol: false)}]';
        noteText = noteText.isNotEmpty ? '$noteText $fxFootnote' : fxFootnote;
      }

      if (_txTypeIndex == 2) {
        // Chuyển khoản nội bộ
        if (_toAccount == null || _toAccount!.id == _selectedAccount!.id) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vui lòng chọn tài khoản đích khác tài khoản nguồn!'),
            ),
          );
          setState(() => _loading = false);
          return;
        }

        final ok = await MySqlService.instance.transferBetweenAccounts(
          userId: widget.userId,
          fromAccountId: _selectedAccount!.id,
          toAccountId: _toAccount!.id,
          amount: finalVndAmount,
          note: noteText.isNotEmpty ? noteText : 'Chuyển tiền nội bộ',
        );

        if (ok && mounted) {
          Navigator.pop(context, true);
        }
      } else {
        // Thu nhập hoặc Chi phí
        final String txType = _txTypeIndex == 0 ? 'expense' : 'income';
        final ok = await MySqlService.instance.addTransaction(
          userId: widget.userId,
          accountId: _selectedAccount!.id,
          categoryId: _selectedCategory?.id,
          type: txType,
          amount: finalVndAmount,
          note: noteText,
          date: _selectedDate,
          isFuturePlanned: _isFuturePlanned,
        );

        if (ok && mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingInit) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    // Tỷ giá quy đổi Live FX preview
    final rawAmount = double.tryParse(_amountCtrl.text.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    final convertedVnd = CurrencyFormatter.convertForeignToVnd(
      amount: rawAmount,
      currencyCode: _selectedCurrency,
      ratesToVnd: _ratesToVnd,
    );

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Thêm Giao Dịch Mới'),
        elevation: 0,
        actions: [
          if (_ocrEnabled)
            IconButton(
              icon: const Icon(Icons.document_scanner_rounded, color: AppColors.primary),
              tooltip: 'Quét Bill OCR',
              onPressed: _scanningOcr ? null : _showScanOptions,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── BANNER QUÉT BILL CHUYỂN KHOẢN OCR V2 ──
              if (_ocrEnabled)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _scanningOcr
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Quét Bill Chuyển Khoản OCR v2',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            Text(
                              _scanningOcr ? 'Đang nhận diện hóa đơn/bill...' : 'Tự động bóc tách tiền, ngày giờ & ngân hàng',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.camera_alt_rounded, size: 16),
                        label: const Text('Quét Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: _scanningOcr ? null : _showScanOptions,
                      ),
                    ],
                  ),
                ),

              // Segment chọn loại giao dịch: Chi phí / Thu nhập / Chuyển khoản
              Center(
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Text('Chi phí', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('Thu nhập', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    ButtonSegment(
                      value: 2,
                      label: Text('Chuyển khoản', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                  selected: {_txTypeIndex},
                  onSelectionChanged: (val) => _changeType(val.first),
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: _txTypeIndex == 0
                        ? AppColors.expenseLight
                        : (_txTypeIndex == 1
                            ? AppColors.incomeLight
                            : AppColors.primaryLight),
                    selectedForegroundColor: _txTypeIndex == 0
                        ? AppColors.expense
                        : (_txTypeIndex == 1
                            ? AppColors.income
                            : AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Ô NHẬP SỐ TIỀN & ĐA TIỀN TỆ (MULTI-CURRENCY LIVE FX) ──
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'SỐ TIỀN GIAO DỊCH',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),

                        // Dropdown Đơn vị tiền tệ (VND, USD, EUR, JPY...)
                        if (_multiCurrencyEnabled && _currencies.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.scaffoldBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedCurrency,
                                isDense: true,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
                                items: _currencies.map((c) {
                                  final code = c['code'].toString();
                                  final sym = c['symbol'].toString();
                                  return DropdownMenuItem(
                                    value: code,
                                    child: Text('$code ($sym)'),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedCurrency = val);
                                  }
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    TextField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: _txTypeIndex == 0
                            ? AppColors.expense
                            : (_txTypeIndex == 1
                                ? AppColors.income
                                : AppColors.primary),
                        fontFeatures: CurrencyFormatter.tabularFigures,
                      ),
                      decoration: InputDecoration(
                        hintText: _selectedCurrency == 'VND' ? '0 ₫' : '0.00',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),

                    // Tự động tính toán và hiển thị Tỷ giá quy đổi Live FX sang VND
                    if (_selectedCurrency != 'VND' && rawAmount > 0) ...[
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.currency_exchange_rounded, size: 14, color: AppColors.income),
                          const SizedBox(width: 6),
                          Text(
                            '≈ ${CurrencyFormatter.formatVND(convertedVnd)}',
                            style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.income, fontSize: 14),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(1 $_selectedCurrency = ${CurrencyFormatter.formatVND(_ratesToVnd[_selectedCurrency] ?? 1.0)})',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Chọn Tài khoản nguồn
              DropdownButtonFormField<AccountModel>(
                value: _accountList.contains(_selectedAccount)
                    ? _selectedAccount
                    : (_accountList.isNotEmpty ? _accountList.first : null),
                decoration: InputDecoration(
                  labelText: _txTypeIndex == 2 ? 'Từ tài khoản' : 'Tài khoản thanh toán',
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary),
                ),
                items: _accountList.map((a) {
                  return DropdownMenuItem(
                    value: a,
                    child: Text('${a.name} (${CurrencyFormatter.formatVND(a.balance)})'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedAccount = val),
              ),
              const SizedBox(height: 14),

              // Nếu là chuyển khoản: Chọn tài khoản đích
              if (_txTypeIndex == 2) ...[
                DropdownButtonFormField<AccountModel>(
                  value: _accountList.contains(_toAccount)
                      ? _toAccount
                      : (_accountList.length > 1 ? _accountList[1] : null),
                  decoration: const InputDecoration(
                    labelText: 'Đến tài khoản',
                    prefixIcon: Icon(Icons.swap_horiz_rounded, color: AppColors.primary),
                  ),
                  items: _accountList.map((a) {
                    return DropdownMenuItem(
                      value: a,
                      child: Text('${a.name} (${CurrencyFormatter.formatVND(a.balance)})'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _toAccount = val),
                ),
                const SizedBox(height: 14),
              ],

              // ── CHỌN HẠNG MỤC CÂN CHỈNH ĐỘ TƯƠNG PHẢN (ADAPTIVE CONTRAST GUARD) ──
              if (_txTypeIndex != 2) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Chọn Hạng mục',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    if (_selectedCategory != null)
                      Text(
                        _selectedCategory!.name,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _categoryList.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.82,
                  ),
                  itemBuilder: (context, i) {
                    final cat = _categoryList[i];
                    final isSelected = _selectedCategory?.id == cat.id;

                    // Sử dụng Adaptive Color Contrast Guard để màu không bị lóa trên nền Sáng/Tối
                    final color = AppColors.getAdaptiveCategoryColor(cat.colorHex, context);
                    final badgeBg = AppColors.getAdaptiveCategoryBadgeBg(cat.colorHex, context);

                    return InkWell(
                      onTap: () => setState(() => _selectedCategory = cat),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? badgeBg : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? color : AppColors.border,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2))]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                shape: BoxShape.circle,
                              ),
                              child: FaIcon(
                                AppIcons.getCategoryIcon(cat.iconKey),
                                color: color,
                                size: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              cat.name,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? color : AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Chọn Ngày
              InkWell(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, color: AppColors.primary, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            'Ngày giao dịch: ${CurrencyFormatter.formatDate(_selectedDate)}',
                            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Ghi chú
              TextField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú (Ví dụ: Ăn trưa cùng đồng nghiệp, Bill VCB...)',
                  prefixIcon: Icon(Icons.notes_rounded, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 16),

              // Giao dịch dự kiến tương lai
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Giao dịch dự kiến tương lai', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('Không trừ vào số dư tài khoản ngay', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                    Switch(
                      value: _isFuturePlanned,
                      activeThumbColor: AppColors.primary,
                      onChanged: (val) => setState(() => _isFuturePlanned = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Nút Lưu
              GradientButton(
                label: 'Lưu Giao Dịch',
                gradient: _txTypeIndex == 0
                    ? AppColors.expenseGradient
                    : (_txTypeIndex == 1
                        ? AppColors.incomeGradient
                        : AppColors.primaryGradient),
                shadowColor: _txTypeIndex == 0
                    ? AppColors.expense
                    : (_txTypeIndex == 1
                        ? AppColors.income
                        : AppColors.primary),
                onPressed: _save,
                loading: _loading,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

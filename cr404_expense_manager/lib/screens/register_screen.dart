import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../utils/app_theme.dart';
import '../services/mysql_service.dart';
import '../main.dart' show MainHomeScreen;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  // Onboarding parameters
  final _cashBalanceCtrl = TextEditingController(text: '2000000');
  final _bankBalanceCtrl = TextEditingController(text: '15000000');
  final _monthlyBudgetCtrl = TextEditingController(text: '10000000');

  bool _obscure = true;
  bool _loading = false;
  bool _showOnboardingDetails = true;
  String? _errorMsg;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _cashBalanceCtrl.dispose();
    _bankBalanceCtrl.dispose();
    _monthlyBudgetCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordCtrl.text != _confirmCtrl.text) {
      setState(() => _errorMsg = 'Mật khẩu xác nhận không khớp!');
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      final double initialCash =
          double.tryParse(
            _cashBalanceCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
          ) ??
          2000000.0;
      final double initialBank =
          double.tryParse(
            _bankBalanceCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
          ) ??
          15000000.0;
      final double initialBudget =
          double.tryParse(
            _monthlyBudgetCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
          ) ??
          10000000.0;

      final res = await MySqlService.instance.registerUser(
        fullName: _fullNameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        initialCash: initialCash,
        initialBank: initialBank,
        monthlyBudget: initialBudget,
      );

      if (res == null) {
        setState(() {
          _errorMsg = 'Email này đã tồn tại trong hệ thống. Vui lòng đăng nhập hoặc dùng email khác!';
          _loading = false;
        });
        return;
      }

      final userId = res['id'] as int;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('logged_in_user_id', userId);
      await prefs.setInt('user_id', userId);
      await prefs.setString('user_full_name', _fullNameCtrl.text.trim());
      await prefs.setString('user_name', _fullNameCtrl.text.trim());
      await prefs.setString('user_email', _emailCtrl.text.trim());
      await prefs.setBool('onboarding_completed', true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đăng ký & Khởi tạo ví thành công! Chào mừng bạn.'),
          backgroundColor: AppColors.income,
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => MainHomeScreen(initialUserId: userId)),
        (_) => false,
      );
    } catch (e) {
      setState(() {
        _errorMsg = 'Lỗi kết nối máy chủ Cloud:\n$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(title: const Text('Tạo tài khoản mới'), elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header badge
                Center(
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      gradient: AppColors.incomeGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.income.withAlpha(80),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: FaIcon(
                        FontAwesomeIcons.userPlus,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Đăng ký tài khoản',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Center(
                  child: Text(
                    'Khởi tạo ví & hạng mục chuẩn tự động',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                if (_errorMsg != null) ErrorBanner(_errorMsg!),

                // Section 1: Thông tin đăng nhập
                const Text(
                  '1. THÔNG TIN CÁ NHÂN',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),

                AppTextField(
                  controller: _fullNameCtrl,
                  label: 'Họ và tên',
                  icon: Icons.person_outline_rounded,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Vui lòng nhập họ tên'
                      : null,
                ),
                const SizedBox(height: 12),

                AppTextField(
                  controller: _emailCtrl,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Email không hợp lệ'
                      : null,
                ),
                const SizedBox(height: 12),

                AppTextField(
                  controller: _passwordCtrl,
                  label: 'Mật khẩu',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscure,
                  suffix: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'Mật khẩu ít nhất 6 ký tự'
                      : null,
                ),
                const SizedBox(height: 12),

                AppTextField(
                  controller: _confirmCtrl,
                  label: 'Xác nhận mật khẩu',
                  icon: Icons.lock_reset_rounded,
                  obscure: _obscure,
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Vui lòng xác nhận mật khẩu'
                      : null,
                ),
                const SizedBox(height: 24),

                // Section 2: Khởi tạo Onboarding (Ví & Ngân sách)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '2. KHỞI TẠO VÍ & NGÂN SÁCH (ONBOARDING)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _showOnboardingDetails
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      onPressed: () => setState(
                        () => _showOnboardingDetails = !_showOnboardingDetails,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_showOnboardingDetails) ...[
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hệ thống sẽ tự động tạo sẵn 10 hạng mục chi tiêu và 3 tài khoản khởi đầu cho bạn:',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        AppTextField(
                          controller: _cashBalanceCtrl,
                          label: 'Số dư Ví tiền mặt ban đầu (VNĐ)',
                          icon: Icons.wallet_rounded,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),

                        AppTextField(
                          controller: _bankBalanceCtrl,
                          label: 'Số dư Ngân hàng ban đầu (VNĐ)',
                          icon: Icons.account_balance_rounded,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),

                        AppTextField(
                          controller: _monthlyBudgetCtrl,
                          label: 'Hạn mức Ngân sách tháng này (VNĐ)',
                          icon: Icons.track_changes_rounded,
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                GradientButton(
                  label: 'Hoàn tất Đăng ký & Vào ứng dụng',
                  gradient: AppColors.incomeGradient,
                  shadowColor: AppColors.income,
                  onPressed: _register,
                  loading: _loading,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

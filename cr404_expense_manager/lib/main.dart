// =============================================================================
// main.dart — Entry Point, Material 3 Theme, Auth Session Check & MainNavigation
// =============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'utils/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/accounts_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/chart_screen.dart';
import 'screens/budget_screen.dart';
import 'screens/add_transaction_screen.dart';
import 'services/mysql_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN', null);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const ExpenseApp());
}

class ExpenseApp extends StatelessWidget {
  const ExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quản Lý Chi Tiêu - CR404',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}

// ─── SPLASH SCREEN ────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();

    Future.delayed(const Duration(milliseconds: 1800), _checkAuth);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('logged_in_user_id') ?? prefs.getInt('user_id');

    final dest = (userId != null && userId > 0)
        ? MainHomeScreen(initialUserId: userId)
        : const LoginScreen();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, anim, secondaryAnimation) => FadeTransition(opacity: anim, child: dest),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(90),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: FaIcon(FontAwesomeIcons.wallet, color: Colors.white, size: 42),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Quản Lý Chi Tiêu',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'CR404 • Expense Manager • MySQL 8.0',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 36),
                const SizedBox(
                  width: 28, height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── MAIN HOME NAVIGATION ─────────────────────────────────────────────────────
class MainHomeScreen extends StatefulWidget {
  final int? initialUserId;
  const MainHomeScreen({super.key, this.initialUserId});
  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _tabIndex = 0;
  final Set<int> _loadedTabs = {0};
  int? _userId;
  String _userName  = 'Người dùng';
  String _userEmail = '';
  String _userRole  = 'user';  // 'user' | 'premium' | 'admin'
  Key _refreshKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    if (widget.initialUserId != null && widget.initialUserId! > 0) {
      _userId = widget.initialUserId;
    }
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('logged_in_user_id') ?? prefs.getInt('user_id') ?? widget.initialUserId;
    if (uid == null || uid <= 0) {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _userId    = uid;
      _userName  = prefs.getString('user_full_name') ?? prefs.getString('user_name') ?? 'Người dùng';
      _userEmail = prefs.getString('user_email') ?? '';
      _userRole  = prefs.getString('user_role') ?? 'user';
    });

    // Tự động đồng bộ quyền hạn (role) & kiểm tra trạng thái tài khoản từ Aiven Database
    try {
      final conn = await MySqlService.instance.getConnection();
      try {
        // Kiểm tra Chế độ Bảo trì từ Web Admin
        final maint = await conn.execute(
          "SELECT value FROM system_settings WHERE setting_key = 'maintenance_mode' LIMIT 1"
        );
        if (maint.rows.isNotEmpty) {
          final mVal = maint.rows.first.assoc()['value']?.toString().toLowerCase();
          if (mVal == '1' || mVal == 'true') {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⚠️ Hệ thống đang bảo trì theo lệnh từ Web Admin.'),
                  backgroundColor: AppColors.expense,
                  duration: Duration(seconds: 5),
                ),
              );
            }
          }
        }

        final res = await conn.execute(
          'SELECT role, status, suspension_reason FROM users WHERE id = :uid LIMIT 1',
          {'uid': uid},
        );
        if (res.rows.isNotEmpty) {
          final row = res.rows.first.assoc();
          final dbRole = row['role']?.toString() ?? 'user';
          final dbStatus = row['status']?.toString() ?? 'active';

          // Nếu tài khoản bị khóa trên Web Admin, đăng xuất ngay và báo lý do
          if (dbStatus == 'suspended' || dbStatus == 'soft_deleted') {
            final reason = row['suspension_reason'] ?? 'Tài khoản đã bị tạm khóa bởi Quản trị viên.';
            await prefs.clear();
            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Tài khoản bị khóa: $reason'),
                  backgroundColor: AppColors.expense,
                ),
              );
            }
            return;
          }

          await prefs.setString('user_role', dbRole);
          if (mounted && _userRole != dbRole) {
            setState(() {
              _userRole = dbRole;
            });
          }
        }
      } finally {
        await conn.close();
      }
    } catch (_) {}
  }

  void _onTabSelected(int index) {
    setState(() {
      _tabIndex = index;
      _loadedTabs.add(index);
      _refreshKey = UniqueKey(); // Tự động tải lại dữ liệu mới nhất khi ấn vào mục!
    });
  }

  Future<void> _openAddTransaction() async {
    final uid = _userId;
    if (uid == null || uid <= 0) return;
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddTransactionScreen(userId: uid)),
    );
    if (added == true) {
      setState(() {
        _refreshKey = UniqueKey(); // Trigger rebuild and reload of tabs
      });
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null || _userId! <= 0) {
      return const Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final activeUserId = _userId!;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      drawer: _buildDrawer(),
      body: KeyedSubtree(
        key: _refreshKey,
        child: IndexedStack(
          index: _tabIndex,
          children: [
            DashboardScreen(
              userId: activeUserId,
              onOpenCalendar12Months: () {
                _onTabSelected(1);
              },
            ),
            _loadedTabs.contains(1)
                ? CalendarScreen(userId: activeUserId)
                : const SizedBox.shrink(),
            _loadedTabs.contains(2)
                ? ChartScreen(userId: activeUserId)
                : const SizedBox.shrink(),
            _loadedTabs.contains(3)
                ? AccountsScreen(userId: activeUserId)
                : const SizedBox.shrink(),
            _loadedTabs.contains(4)
                ? BudgetScreen(userId: activeUserId)
                : const SizedBox.shrink(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTransaction,
        elevation: 4,
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.white,
        elevation: 8,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, FontAwesomeIcons.tableColumns, 'Tổng quan'),
              _buildNavItem(1, FontAwesomeIcons.calendarDays, 'Lịch'),
              const SizedBox(width: 44), // Chỗ trống cho FloatingActionButton ở giữa
              _buildNavItem(2, FontAwesomeIcons.chartPie, 'Biểu đồ'),
              _buildNavItem(3, FontAwesomeIcons.wallet, 'Tài khoản'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, dynamic icon, String label) {
    final isSelected = _tabIndex == index;
    final color = isSelected ? AppColors.primary : AppColors.textSecondary;

    return InkWell(
      onTap: () => _onTabSelected(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(icon, size: 18, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
            accountName: Text(_userName, style: const TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: Text(_userEmail.isNotEmpty ? _userEmail : 'cr404@expense.local'),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_outlined, color: AppColors.primary),
            title: const Text('Tổng quan'),
            selected: _tabIndex == 0,
            onTap: () {
              Navigator.pop(context);
              _onTabSelected(0);
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined, color: AppColors.primary),
            title: const Text('Lịch thu chi'),
            selected: _tabIndex == 1,
            onTap: () {
              Navigator.pop(context);
              _onTabSelected(1);
            },
          ),
          ListTile(
            leading: const Icon(Icons.pie_chart_outline_rounded, color: AppColors.primary),
            title: const Text('Biểu đồ chi tiêu'),
            selected: _tabIndex == 2,
            onTap: () {
              Navigator.pop(context);
              _onTabSelected(2);
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary),
            title: const Text('Quản lý ví & thẻ'),
            selected: _tabIndex == 3,
            onTap: () {
              Navigator.pop(context);
              _onTabSelected(3);
            },
          ),
          ListTile(
            leading: const Icon(Icons.track_changes_outlined, color: AppColors.primary),
            title: const Text('Kế hoạch ngân sách'),
            selected: _tabIndex == 4,
            onTap: () {
              Navigator.pop(context);
              _onTabSelected(4);
            },
          ),
          const Divider(),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.expense),
            title: const Text('Đăng xuất', style: TextStyle(color: AppColors.expense, fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context);
              _logout();
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

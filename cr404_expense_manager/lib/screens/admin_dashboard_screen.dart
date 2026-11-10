// =============================================================================
// admin_dashboard_screen.dart — Admin Console 5 Tabs
// CR404 Expense Manager — FinTech Admin Panel
// Tuân thủ Zero-Knowledge Privacy: Admin chỉ xem COUNT, không xem SUM(amount)
// =============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/mysql_service.dart';
import '../utils/app_theme.dart';

class AdminDashboardScreen extends StatefulWidget {
  final int adminUserId;
  const AdminDashboardScreen({super.key, required this.adminUserId});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        title: const Text(
          'Admin Console',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded, size: 18), text: 'Dashboard'),
            Tab(icon: Icon(Icons.people_rounded, size: 18), text: 'Người dùng'),
            Tab(icon: Icon(Icons.category_rounded, size: 18), text: 'Master Data'),
            Tab(icon: Icon(Icons.notifications_rounded, size: 18), text: 'Thông báo'),
            Tab(icon: Icon(Icons.settings_rounded, size: 18), text: 'Cài đặt'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _DashboardTab(adminUserId: widget.adminUserId),
          _UserManagementTab(adminUserId: widget.adminUserId),
          _MasterDataTab(adminUserId: widget.adminUserId),
          _NotificationsTab(adminUserId: widget.adminUserId),
          _SettingsTab(adminUserId: widget.adminUserId),
        ],
      ),
    );
  }
}

// =============================================================================
// TAB 1 — DASHBOARD (KPIs + Biểu đồ tăng trưởng)
// =============================================================================
class _DashboardTab extends StatefulWidget {
  final int adminUserId;
  const _DashboardTab({required this.adminUserId});

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final stats = await MySqlService.instance.adminGetDashboardStats();
      if (mounted) setState(() { _stats = stats; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_error != null) return _ErrorWidget(error: _error!, onRetry: _load);

    final s = _stats!;
    final stickiness = (s['stickiness_pct'] as double? ?? 0.0).toStringAsFixed(1);
    final topCats = (s['top_categories'] as List? ?? []).cast<Map<String, dynamic>>();
    final growth7d = (s['user_growth_7d'] as List? ?? []).cast<Map<String, dynamic>>();

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── KPI Cards Row 1 ──
          Row(children: [
            Expanded(child: _KpiCard('Tổng Users', '${s['total_users']}', Icons.people_rounded, AppColors.primary)),
            const SizedBox(width: 10),
            Expanded(child: _KpiCard('Đang hoạt động', '${s['active_users']}', Icons.check_circle_rounded, AppColors.income)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _KpiCard('Mới hôm nay', '${s['new_1d']}', Icons.person_add_rounded, Colors.orange)),
            const SizedBox(width: 10),
            Expanded(child: _KpiCard('Mới 7 ngày', '${s['new_7d']}', Icons.trending_up_rounded, Colors.purple)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _KpiCard('Mới 30 ngày', '${s['new_30d']}', Icons.calendar_month_rounded, Colors.teal)),
            const SizedBox(width: 10),
            Expanded(child: _KpiCard('Stickiness', '$stickiness%', Icons.favorite_rounded, Colors.pink)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _KpiCard('DAU', '${s['dau']}', Icons.today_rounded, Colors.indigo)),
            const SizedBox(width: 10),
            Expanded(child: _KpiCard('MAU', '${s['mau']}', Icons.date_range_rounded, Colors.brown)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _KpiCard('Tổng giao dịch', '${s['total_tx']}', Icons.receipt_long_rounded, AppColors.primary)),
            const SizedBox(width: 10),
            Expanded(child: _KpiCard('GD hôm nay', '${s['tx_today']}', Icons.flash_on_rounded, Colors.amber.shade700)),
          ]),

          // ── Tăng trưởng users 7 ngày ──
          if (growth7d.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionHeader('📈 Tăng trưởng Users — 7 ngày qua'),
            const SizedBox(height: 8),
            _MiniBarChart(
              items: growth7d.map((g) => _BarItem(
                label: (g['day'] as String? ?? '').substring(5),
                value: (g['count'] as int? ?? 0).toDouble(),
              )).toList(),
              maxBarHeight: 60,
              color: AppColors.primary,
            ),
          ],

          // ── Top categories ──
          if (topCats.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionHeader('🏆 Top Danh mục phổ biến (theo số giao dịch)'),
            const SizedBox(height: 8),
            ...topCats.asMap().entries.map((e) {
              final rank = e.key + 1;
              final cat  = e.value;
              final maxCount = (topCats.first['tx_count'] as int? ?? 1).toDouble();
              final count = (cat['tx_count'] as int? ?? 0).toDouble();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  SizedBox(
                    width: 24,
                    child: Text('$rank', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: Color(int.parse('0xFF${(cat['color'] as String? ?? '#607D8B').replaceFirst('#', '')}')),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${cat['name']} (${cat['type']})', style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 2),
                      LinearProgressIndicator(
                        value: maxCount > 0 ? count / maxCount : 0,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade200,
                        color: Color(int.parse('0xFF${(cat['color'] as String? ?? '#607D8B').replaceFirst('#', '')}')),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Text('${cat['tx_count']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ]),
              );
            }),
          ],

          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Làm mới dữ liệu'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TAB 2 — QUẢN LÝ NGƯỜI DÙNG
// =============================================================================
class _UserManagementTab extends StatefulWidget {
  final int adminUserId;
  const _UserManagementTab({required this.adminUserId});

  @override
  State<_UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<_UserManagementTab> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  String _filterStatus = 'all';
  String _filterRole   = 'all';
  int _page = 1;
  int _totalPages = 1;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool resetPage = false}) async {
    if (resetPage) _page = 1;
    setState(() { _loading = true; _error = null; });
    try {
      final result = await MySqlService.instance.adminGetUsers(
        search: _search.trim().isEmpty ? null : _search.trim(),
        status: _filterStatus == 'all' ? null : _filterStatus,
        role:   _filterRole   == 'all' ? null : _filterRole,
        page:   _page,
      );
      if (mounted) {
        setState(() {
          _users      = (result['users'] as List? ?? []).cast<Map<String, dynamic>>();
          _totalPages = result['total_pages'] as int? ?? 1;
          _loading    = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _showUserActions(Map<String, dynamic> user) async {
    final userId   = int.tryParse(user['id']?.toString() ?? '0') ?? 0;
    final userName = user['full_name'] ?? user['username'] ?? 'User $userId';

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _UserActionsSheet(
        userId:      userId,
        userName:    userName,
        currentRole: user['role'] ?? 'user',
        currentStatus: user['status'] ?? 'active',
        adminId:     widget.adminUserId,
        onDone:      _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Search bar
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Tìm theo email, username, họ tên...',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: _search.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); _load(resetPage: true); },
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            isDense: true,
          ),
          onChanged: (v) { _search = v; _load(resetPage: true); },
        ),
      ),
      // Filters
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Expanded(child: _DropdownFilter(
            label: 'Trạng thái',
            value: _filterStatus,
            items: const {'all': 'Tất cả', 'active': 'Active', 'suspended': 'Bị khóa', 'soft_deleted': 'Đã ẩn'},
            onChanged: (v) { setState(() => _filterStatus = v); _load(resetPage: true); },
          )),
          const SizedBox(width: 8),
          Expanded(child: _DropdownFilter(
            label: 'Vai trò',
            value: _filterRole,
            items: const {'all': 'Tất cả', 'user': 'User', 'premium': 'Premium', 'admin': 'Admin'},
            onChanged: (v) { setState(() => _filterRole = v); _load(resetPage: true); },
          )),
        ]),
      ),
      if (_loading) const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
      if (_error != null) Expanded(child: _ErrorWidget(error: _error!, onRetry: _load)),
      if (!_loading && _error == null) Expanded(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.primary,
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (ctx, i) {
              final u = _users[i];
              final status = u['status'] ?? 'active';
              final role   = u['role'] ?? 'user';
              final txCount = u['tx_count'] ?? '0';
              final lastLogin = u['last_login_at'];
              final created = (u['created_at'] ?? '').toString().substring(0, 10);

              Color statusColor = AppColors.income;
              if (status == 'suspended')    statusColor = Colors.orange;
              if (status == 'soft_deleted') statusColor = AppColors.expense;

              Color roleColor = Colors.grey;
              if (role == 'admin')   roleColor = AppColors.primary;
              if (role == 'premium') roleColor = Colors.amber.shade700;

              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(
                      (u['full_name'] ?? u['username'] ?? 'U').toString().isNotEmpty
                          ? (u['full_name'] ?? u['username'] ?? 'U').toString()[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    '${u['full_name'] ?? u['username'] ?? 'Unknown'} (#${u['id']})',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u['email'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Row(children: [
                      _Chip(label: role, color: roleColor),
                      const SizedBox(width: 4),
                      _Chip(label: status, color: statusColor),
                      const SizedBox(width: 4),
                      _Chip(label: '$txCount GD', color: Colors.blueGrey),
                    ]),
                    Text(
                      'Tạo: $created  |  Đăng nhập: ${lastLogin?.toString().substring(0, 10) ?? "Chưa"}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ]),
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert_rounded, color: AppColors.primary),
                    onPressed: () => _showUserActions(u),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      // Pagination
      if (!_loading && _error == null && _totalPages > 1) Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: _page > 1 ? () { _page--; _load(); } : null,
          ),
          Text('Trang $_page / $_totalPages', style: const TextStyle(fontSize: 13)),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: _page < _totalPages ? () { _page++; _load(); } : null,
          ),
        ]),
      ),
    ]);
  }
}

class _UserActionsSheet extends StatefulWidget {
  final int userId, adminId;
  final String userName, currentRole, currentStatus;
  final VoidCallback onDone;
  const _UserActionsSheet({
    required this.userId, required this.userName, required this.currentRole,
    required this.currentStatus, required this.adminId, required this.onDone,
  });

  @override
  State<_UserActionsSheet> createState() => _UserActionsSheetState();
}

class _UserActionsSheetState extends State<_UserActionsSheet> {
  bool _busy = false;
  final _reasonCtrl    = TextEditingController();
  final _passwordCtrl  = TextEditingController();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _do(Future<bool> Function() action, String actionName) async {
    setState(() => _busy = true);
    final ok = await action();
    if (mounted) {
      setState(() => _busy = false);
      Navigator.pop(context);
      widget.onDone();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '$actionName thành công!' : '$actionName thất bại!'),
        backgroundColor: ok ? AppColors.income : AppColors.expense,
      ));
    }
  }

  Future<bool> _confirm(String title, String msg) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.manage_accounts_rounded, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text('Hành động: ${widget.userName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
        ]),
        const Divider(height: 20),
        if (_busy) const Center(child: CircularProgressIndicator(color: AppColors.primary)) else ...[
          // Đổi vai trò
          const Text('Đổi vai trò:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          Row(children: ['user', 'premium', 'admin'].map((r) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(r),
              selected: widget.currentRole == r,
              selectedColor: AppColors.primary.withOpacity(0.2),
              onSelected: (sel) {
                if (sel && r != widget.currentRole) {
                  _do(() => MySqlService.instance.adminUpdateUserRole(widget.userId, r, adminId: widget.adminId), 'Đổi vai trò');
                }
              },
            ),
          )).toList()),
          const SizedBox(height: 12),
          // Trạng thái
          const Text('Thay đổi trạng thái:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          if (widget.currentStatus != 'active') ListTile(
            dense: true,
            leading: const Icon(Icons.lock_open_rounded, color: AppColors.income),
            title: const Text('Mở khóa tài khoản'),
            onTap: () => _do(
              () => MySqlService.instance.adminUpdateUserStatus(widget.userId, 'active', adminId: widget.adminId),
              'Mở khóa',
            ),
          ),
          if (widget.currentStatus == 'active') ListTile(
            dense: true,
            leading: const Icon(Icons.lock_rounded, color: Colors.orange),
            title: const Text('Khóa tạm thời (suspended)'),
            subtitle: TextField(
              controller: _reasonCtrl,
              decoration: const InputDecoration(hintText: 'Lý do khóa (bắt buộc)', isDense: true),
            ),
            onTap: () {
              if (_reasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập lý do khóa!')));
                return;
              }
              _do(
                () => MySqlService.instance.adminUpdateUserStatus(
                  widget.userId, 'suspended', reason: _reasonCtrl.text.trim(), adminId: widget.adminId,
                ),
                'Khóa tài khoản',
              );
            },
          ),
          const SizedBox(height: 8),
          // Đặt lại mật khẩu
          const Text('Đặt lại mật khẩu tạm:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: TextField(
              controller: _passwordCtrl,
              decoration: const InputDecoration(hintText: 'Mật khẩu mới (tối thiểu 6 ký tự)', isDense: true,
                  border: OutlineInputBorder()),
            )),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                if (_passwordCtrl.text.trim().length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mật khẩu tối thiểu 6 ký tự!')));
                  return;
                }
                _do(
                  () => MySqlService.instance.adminResetPassword(widget.userId, _passwordCtrl.text.trim(), adminId: widget.adminId),
                  'Đặt lại mật khẩu',
                );
              },
              child: const Text('Lưu', style: TextStyle(color: Colors.white)),
            ),
          ]),
          const SizedBox(height: 12),
          // Hard delete
          ListTile(
            dense: true,
            leading: const Icon(Icons.delete_forever_rounded, color: AppColors.expense),
            title: const Text('Xóa vĩnh viễn (Hard Delete)', style: TextStyle(color: AppColors.expense)),
            subtitle: const Text('Dùng khi user yêu cầu hợp lệ theo GDPR/pháp lý'),
            onTap: () async {
              final ok1 = await _confirm('Xác nhận lần 1', 'Bạn chắc chắn muốn xóa vĩnh viễn ${widget.userName}?');
              if (!ok1 || !mounted) return;
              final ok2 = await _confirm('Xác nhận lần 2 (KHÔNG THỂ HOÀN TÁC)',
                  'Thao tác này sẽ ẩn tài khoản vĩnh viễn. Dữ liệu giao dịch vẫn được bảo toàn để không ảnh hưởng trigger. Tiếp tục?');
              if (!ok2 || !mounted) return;
              _do(
                () => MySqlService.instance.adminHardDeleteUser(widget.userId, adminId: widget.adminId),
                'Xóa vĩnh viễn',
              );
            },
          ),
        ],
        const SizedBox(height: 20),
      ]),
    );
  }
}

// =============================================================================
// TAB 3 — MASTER DATA (Danh mục gốc + Live Preview + Tiền tệ)
// =============================================================================
class _MasterDataTab extends StatefulWidget {
  final int adminUserId;
  const _MasterDataTab({required this.adminUserId});

  @override
  State<_MasterDataTab> createState() => _MasterDataTabState();
}

class _MasterDataTabState extends State<_MasterDataTab> with SingleTickerProviderStateMixin {
  late TabController _subTab;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _currencies  = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _subTab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _subTab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final cats  = await MySqlService.instance.adminGetDefaultCategories();
    final curs  = await MySqlService.instance.adminGetCurrencies();
    if (mounted) setState(() { _categories = cats; _currencies = curs; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Material(
        color: AppColors.primary.withOpacity(0.08),
        child: TabBar(
          controller: _subTab,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Danh mục gốc'),
            Tab(text: 'Tiền tệ'),
          ],
        ),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : TabBarView(
                controller: _subTab,
                children: [
                  _CategoriesSubTab(
                    categories: _categories,
                    adminId: widget.adminUserId,
                    onRefresh: _load,
                  ),
                  _CurrenciesSubTab(
                    currencies: _currencies,
                    adminId: widget.adminUserId,
                    onRefresh: _load,
                  ),
                ],
              ),
      ),
    ]);
  }
}

class _CategoriesSubTab extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final int adminId;
  final VoidCallback onRefresh;
  const _CategoriesSubTab({required this.categories, required this.adminId, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          const Text('Danh mục mặc định hệ thống', style: TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
            icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
            label: const Text('Thêm', style: TextStyle(color: Colors.white, fontSize: 12)),
            onPressed: () => _showCategoryForm(context, null),
          ),
        ]),
      ),
      // Live Mobile Preview
      _MobilePreviewWidget(categories: categories),
      const SizedBox(height: 8),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: categories.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            final cat = categories[i];
            final hex = cat['color_hex'] ?? '#607D8B';
            Color color;
            try { color = Color(int.parse('0xFF${hex.replaceFirst('#', '')}')); }
            catch (_) { color = Colors.grey; }
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.15),
                radius: 16,
                child: Icon(Icons.category_rounded, color: color, size: 16),
              ),
              title: Text('${cat['name']} (${cat['type']})', style: const TextStyle(fontSize: 13)),
              subtitle: Text(
                'icon: ${cat['icon_code']} | ${(cat['keywords'] ?? '').toString().isEmpty ? 'Chưa có từ khóa' : cat['keywords'].toString().substring(0, (cat['keywords'].toString().length > 30 ? 30 : cat['keywords'].toString().length))}...',
                style: const TextStyle(fontSize: 10),
              ),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.edit_rounded, size: 16, color: AppColors.primary), onPressed: () => _showCategoryForm(context, cat)),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.expense),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: ctx,
                      builder: (_) => AlertDialog(
                        title: const Text('Xóa danh mục gốc?'),
                        content: Text('Xóa "${cat['name']}" khỏi danh sách mặc định?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ) ?? false;
                    if (ok) {
                      await MySqlService.instance.adminDeleteDefaultCategory(
                        int.tryParse(cat['id']?.toString() ?? '0') ?? 0,
                        adminId: adminId,
                      );
                      onRefresh();
                    }
                  },
                ),
              ]),
            );
          },
        ),
      ),
    ]);
  }

  void _showCategoryForm(BuildContext context, Map<String, dynamic>? cat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _CategoryForm(cat: cat, adminId: adminId, onSaved: onRefresh),
    );
  }
}

class _CategoryForm extends StatefulWidget {
  final Map<String, dynamic>? cat;
  final int adminId;
  final VoidCallback onSaved;
  const _CategoryForm({this.cat, required this.adminId, required this.onSaved});

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  final _nameCtrl     = TextEditingController();
  final _iconCtrl     = TextEditingController();
  final _colorCtrl    = TextEditingController();
  final _keywordsCtrl = TextEditingController();
  final _sortCtrl     = TextEditingController(text: '0');
  String _type = 'expense';
  bool _isVisible = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.cat != null) {
      _nameCtrl.text     = widget.cat!['name'] ?? '';
      _iconCtrl.text     = widget.cat!['icon_code'] ?? '';
      _colorCtrl.text    = widget.cat!['color_hex'] ?? '#607D8B';
      _keywordsCtrl.text = widget.cat!['keywords'] ?? '';
      _sortCtrl.text     = widget.cat!['sort_order']?.toString() ?? '0';
      _type              = widget.cat!['type'] ?? 'expense';
      _isVisible         = (widget.cat!['is_visible'] == 1 || widget.cat!['is_visible'] == '1');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _iconCtrl.dispose(); _colorCtrl.dispose();
    _keywordsCtrl.dispose(); _sortCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tên danh mục không được trống!')));
      return;
    }
    setState(() => _saving = true);
    final ok = await MySqlService.instance.adminSaveDefaultCategory(
      id:        widget.cat != null ? int.tryParse(widget.cat!['id']?.toString() ?? '') : null,
      name:      _nameCtrl.text.trim(),
      type:      _type,
      iconCode:  _iconCtrl.text.trim().isEmpty ? 'category' : _iconCtrl.text.trim(),
      colorHex:  _colorCtrl.text.trim().isEmpty ? '#607D8B' : _colorCtrl.text.trim(),
      keywords:  _keywordsCtrl.text.trim(),
      sortOrder: int.tryParse(_sortCtrl.text) ?? 0,
      isVisible: _isVisible,
      adminId:   widget.adminId,
    );
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Lưu danh mục thành công!' : 'Lỗi khi lưu!'),
        backgroundColor: ok ? AppColors.income : AppColors.expense,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.cat != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isEdit ? 'Sửa danh mục gốc' : 'Thêm danh mục gốc',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          _FormField('Tên danh mục *', _nameCtrl, hint: 'VD: Ăn uống'),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Loại:  ', style: TextStyle(fontSize: 13)),
            ChoiceChip(label: const Text('Chi phí'), selected: _type == 'expense',
                selectedColor: AppColors.expense.withOpacity(0.2),
                onSelected: (s) { if (s) setState(() => _type = 'expense'); }),
            const SizedBox(width: 8),
            ChoiceChip(label: const Text('Thu nhập'), selected: _type == 'income',
                selectedColor: AppColors.income.withOpacity(0.2),
                onSelected: (s) { if (s) setState(() => _type = 'income'); }),
          ]),
          const SizedBox(height: 8),
          _FormField('Mã icon (icon_code)', _iconCtrl, hint: 'VD: restaurant, home, shopping_bag'),
          const SizedBox(height: 8),
          _FormField('Mã màu (color_hex)', _colorCtrl, hint: 'VD: #FF5722'),
          const SizedBox(height: 8),
          _FormField('Từ khóa tự động phân loại', _keywordsCtrl,
              hint: 'VD: grab, be, taxi, xăng (cách nhau bởi dấu phẩy)', maxLines: 2),
          const SizedBox(height: 8),
          _FormField('Thứ tự sắp xếp', _sortCtrl, hint: '0', inputType: TextInputType.number),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Hiển thị:  ', style: TextStyle(fontSize: 13)),
            Switch(value: _isVisible, onChanged: (v) => setState(() => _isVisible = v), activeColor: AppColors.primary),
          ]),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Lưu danh mục', style: TextStyle(color: Colors.white)),
          )),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

/// Widget xem trước giao diện Mobile (Light & Dark)
class _MobilePreviewWidget extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  const _MobilePreviewWidget({required this.categories});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('🔍 Xem trước giao diện Mobile', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _PhoneFrame(isDark: false, categories: categories)),
          const SizedBox(width: 10),
          Expanded(child: _PhoneFrame(isDark: true, categories: categories)),
        ]),
      ]),
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  final bool isDark;
  final List<Map<String, dynamic>> categories;
  const _PhoneFrame({required this.isDark, required this.categories});

  @override
  Widget build(BuildContext context) {
    final bg   = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final text = isDark ? Colors.white : Colors.black87;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFDDDDDD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade400, width: 2),
      ),
      padding: const EdgeInsets.all(6),
      child: Container(
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isDark ? '🌙 Dark Mode' : '☀️ Light Mode',
              style: TextStyle(color: text, fontSize: 9, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4, runSpacing: 4,
            children: categories.take(6).map((cat) {
              final hex = cat['color_hex'] ?? '#607D8B';
              Color color;
              try { color = Color(int.parse('0xFF${hex.replaceFirst('#', '')}')); }
              catch (_) { color = Colors.grey; }
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.5)),
                ),
                child: Text(
                  cat['name'] ?? '',
                  style: TextStyle(fontSize: 8, color: isDark ? color.withOpacity(0.9) : color, fontWeight: FontWeight.w600),
                ),
              );
            }).toList(),
          ),
        ]),
      ),
    );
  }
}

class _CurrenciesSubTab extends StatelessWidget {
  final List<Map<String, dynamic>> currencies;
  final int adminId;
  final VoidCallback onRefresh;
  const _CurrenciesSubTab({required this.currencies, required this.adminId, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          const Text('Tiền tệ hỗ trợ', style: TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
            icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
            label: const Text('Thêm', style: TextStyle(color: Colors.white, fontSize: 12)),
            onPressed: () => _showCurrencyForm(context, null),
          ),
        ]),
      ),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: currencies.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            final cur = currencies[i];
            final isActive = cur['is_active'] == 1 || cur['is_active'] == '1';
            return ListTile(
              dense: true,
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: Text(cur['symbol'] ?? r'$', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
              ),
              title: Text('${cur['code']} — ${cur['name']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text('1 ${cur['code']} = ${cur['rate_to_vnd']} VND', style: const TextStyle(fontSize: 11)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: isActive ? AppColors.income : Colors.grey, size: 18),
                IconButton(icon: const Icon(Icons.edit_rounded, size: 16, color: AppColors.primary),
                    onPressed: () => _showCurrencyForm(ctx, cur)),
              ]),
            );
          },
        ),
      ),
    ]);
  }

  void _showCurrencyForm(BuildContext context, Map<String, dynamic>? cur) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _CurrencyForm(cur: cur, adminId: adminId, onSaved: onRefresh),
    );
  }
}

class _CurrencyForm extends StatefulWidget {
  final Map<String, dynamic>? cur;
  final int adminId;
  final VoidCallback onSaved;
  const _CurrencyForm({this.cur, required this.adminId, required this.onSaved});

  @override
  State<_CurrencyForm> createState() => _CurrencyFormState();
}

class _CurrencyFormState extends State<_CurrencyForm> {
  final _codeCtrl   = TextEditingController();
  final _symbolCtrl = TextEditingController();
  final _nameCtrl   = TextEditingController();
  final _rateCtrl   = TextEditingController();
  final _sortCtrl   = TextEditingController(text: '0');
  bool _isActive = true;
  bool _saving   = false;

  @override
  void initState() {
    super.initState();
    if (widget.cur != null) {
      _codeCtrl.text   = widget.cur!['code'] ?? '';
      _symbolCtrl.text = widget.cur!['symbol'] ?? '';
      _nameCtrl.text   = widget.cur!['name'] ?? '';
      _rateCtrl.text   = widget.cur!['rate_to_vnd']?.toString() ?? '1';
      _sortCtrl.text   = widget.cur!['sort_order']?.toString() ?? '0';
      _isActive        = widget.cur!['is_active'] == 1 || widget.cur!['is_active'] == '1';
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose(); _symbolCtrl.dispose(); _nameCtrl.dispose();
    _rateCtrl.dispose(); _sortCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_codeCtrl.text.trim().isEmpty || _nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mã và tên tiền tệ không được trống!')));
      return;
    }
    setState(() => _saving = true);
    final ok = await MySqlService.instance.adminSaveCurrency(
      id:        widget.cur != null ? int.tryParse(widget.cur!['id']?.toString() ?? '') : null,
      code:      _codeCtrl.text.trim().toUpperCase(),
      symbol:    _symbolCtrl.text.trim(),
      name:      _nameCtrl.text.trim(),
      rateToVnd: double.tryParse(_rateCtrl.text) ?? 1.0,
      isActive:  _isActive,
      sortOrder: int.tryParse(_sortCtrl.text) ?? 0,
    );
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Lưu tiền tệ thành công!' : 'Lỗi khi lưu!'),
        backgroundColor: ok ? AppColors.income : AppColors.expense,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.cur != null ? 'Sửa tiền tệ' : 'Thêm tiền tệ',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _FormField('Mã (code) *', _codeCtrl, hint: 'VD: USD')),
            const SizedBox(width: 8),
            Expanded(child: _FormField('Ký hiệu *', _symbolCtrl, hint: 'VD: \$')),
          ]),
          const SizedBox(height: 8),
          _FormField('Tên tiền tệ *', _nameCtrl, hint: 'VD: US Dollar'),
          const SizedBox(height: 8),
          _FormField('Tỷ giá quy đổi sang VND', _rateCtrl, hint: '25500', inputType: TextInputType.number),
          const SizedBox(height: 8),
          _FormField('Thứ tự', _sortCtrl, hint: '0', inputType: TextInputType.number),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Kích hoạt:  ', style: TextStyle(fontSize: 13)),
            Switch(value: _isActive, onChanged: (v) => setState(() => _isActive = v), activeColor: AppColors.primary),
          ]),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Lưu tiền tệ', style: TextStyle(color: Colors.white)),
          )),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

// =============================================================================
// TAB 4 — THÔNG BÁO & PHẢN HỒI
// =============================================================================
class _NotificationsTab extends StatefulWidget {
  final int adminUserId;
  const _NotificationsTab({required this.adminUserId});

  @override
  State<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<_NotificationsTab> with SingleTickerProviderStateMixin {
  late TabController _subTab;
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _feedbacks     = [];
  String _feedbackFilter = 'all';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _subTab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() { _subTab.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final notifs = await MySqlService.instance.adminGetPushNotifications();
    final feeds  = await MySqlService.instance.adminGetFeedbacks(
      status: _feedbackFilter == 'all' ? null : _feedbackFilter,
    );
    if (mounted) setState(() { _notifications = notifs; _feedbacks = feeds; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Material(
        color: AppColors.primary.withOpacity(0.08),
        child: TabBar(
          controller: _subTab,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [Tab(text: 'Push Notifications'), Tab(text: 'Phản hồi & Báo lỗi')],
        ),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : TabBarView(
                controller: _subTab,
                children: [
                  _PushNotifSubTab(notifications: _notifications, adminId: widget.adminUserId, onRefresh: _load),
                  _FeedbackSubTab(feedbacks: _feedbacks, adminId: widget.adminUserId,
                      filter: _feedbackFilter, onFilterChange: (f) { _feedbackFilter = f; _load(); }, onRefresh: _load),
                ],
              ),
      ),
    ]);
  }
}

class _PushNotifSubTab extends StatelessWidget {
  final List<Map<String, dynamic>> notifications;
  final int adminId;
  final VoidCallback onRefresh;
  const _PushNotifSubTab({required this.notifications, required this.adminId, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          const Text('Thông báo đẩy', style: TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
            icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
            label: const Text('Tạo mới', style: TextStyle(color: Colors.white, fontSize: 12)),
            onPressed: () => _showForm(context),
          ),
        ]),
      ),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: notifications.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (ctx, i) {
            final n = notifications[i];
            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.notifications_rounded, color: AppColors.primary),
                title: Text(n['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(n['body'] ?? '', style: const TextStyle(fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                  Row(children: [
                    _Chip(label: n['target_group'] ?? '', color: Colors.indigo),
                    const SizedBox(width: 4),
                    _Chip(label: n['send_mode'] ?? '', color: Colors.teal),
                    const SizedBox(width: 4),
                    _Chip(label: n['status'] ?? '', color: _notifStatusColor(n['status'] ?? '')),
                  ]),
                ]),
                trailing: Text(n['created_at']?.toString().substring(0, 10) ?? '',
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Color _notifStatusColor(String s) {
    if (s == 'sent' || s == 'active') return AppColors.income;
    if (s == 'cancelled' || s == 'paused') return AppColors.expense;
    return Colors.grey;
  }

  void _showForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _PushNotifForm(adminId: adminId, onSaved: onRefresh),
    );
  }
}

class _PushNotifForm extends StatefulWidget {
  final int adminId;
  final VoidCallback onSaved;
  const _PushNotifForm({required this.adminId, required this.onSaved});

  @override
  State<_PushNotifForm> createState() => _PushNotifFormState();
}

class _PushNotifFormState extends State<_PushNotifForm> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl  = TextEditingController();
  final _timeCtrl  = TextEditingController(text: '20:00:00');
  String _targetGroup = 'all';
  String _sendMode    = 'daily_cron';
  bool _smartSkip  = true;
  int  _jitter     = 15;
  bool _saving     = false;

  @override
  void dispose() { _titleCtrl.dispose(); _bodyCtrl.dispose(); _timeCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tiêu đề và nội dung không được trống!')));
      return;
    }
    setState(() => _saving = true);
    final ok = await MySqlService.instance.adminSavePushNotification(
      title:         _titleCtrl.text.trim(),
      body:          _bodyCtrl.text.trim(),
      targetGroup:   _targetGroup,
      sendMode:      _sendMode,
      scheduledTime: _timeCtrl.text.trim().isEmpty ? '20:00:00' : _timeCtrl.text.trim(),
      smartSkip:     _smartSkip,
      rollingJitter: _jitter,
      adminId:       widget.adminId,
    );
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Tạo thông báo thành công!' : 'Lỗi khi tạo!'),
        backgroundColor: ok ? AppColors.income : AppColors.expense,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Tạo thông báo đẩy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          _FormField('Tiêu đề *', _titleCtrl, hint: 'VD: Nhắc ghi chi tiêu hôm nay 💡'),
          const SizedBox(height: 8),
          _FormField('Nội dung *', _bodyCtrl, hint: 'VD: Bạn đã ghi chi tiêu hôm nay chưa? 📒', maxLines: 3),
          const SizedBox(height: 8),
          const Text('Nhóm người nhận:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Wrap(
            spacing: 6,
            children: ['all', 'free', 'premium', 'inactive_7d'].map((g) => ChoiceChip(
              label: Text(g, style: const TextStyle(fontSize: 12)),
              selected: _targetGroup == g,
              selectedColor: AppColors.primary.withOpacity(0.2),
              onSelected: (s) { if (s) setState(() => _targetGroup = g); },
            )).toList(),
          ),
          const SizedBox(height: 8),
          const Text('Chế độ gửi:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Row(children: [
            Expanded(child: ChoiceChip(
              label: const Text('Gửi ngay'),
              selected: _sendMode == 'immediate',
              selectedColor: AppColors.primary.withOpacity(0.2),
              onSelected: (s) { if (s) setState(() => _sendMode = 'immediate'); },
            )),
            const SizedBox(width: 8),
            Expanded(child: ChoiceChip(
              label: const Text('Lặp hàng ngày'),
              selected: _sendMode == 'daily_cron',
              selectedColor: AppColors.primary.withOpacity(0.2),
              onSelected: (s) { if (s) setState(() => _sendMode = 'daily_cron'); },
            )),
          ]),
          if (_sendMode == 'daily_cron') ...[
            const SizedBox(height: 8),
            _FormField('Giờ gửi (HH:MM:SS)', _timeCtrl, hint: '20:00:00'),
            const SizedBox(height: 8),
            Row(children: [
              const Expanded(child: Text('Smart Skip (bỏ qua nếu user đã ghi GD):', style: TextStyle(fontSize: 12))),
              Switch(value: _smartSkip, onChanged: (v) => setState(() => _smartSkip = v), activeColor: AppColors.primary),
            ]),
            Row(children: [
              const Text('Rolling Jitter (phút): ', style: TextStyle(fontSize: 12)),
              Slider(
                value: _jitter.toDouble(),
                min: 0, max: 30, divisions: 6,
                label: '$_jitter phút',
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() => _jitter = v.round()),
              ),
              Text('$_jitter phút', style: const TextStyle(fontSize: 12)),
            ]),
          ],
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Tạo thông báo', style: TextStyle(color: Colors.white)),
          )),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

class _FeedbackSubTab extends StatelessWidget {
  final List<Map<String, dynamic>> feedbacks;
  final int adminId;
  final String filter;
  final VoidCallback onRefresh;
  final ValueChanged<String> onFilterChange;
  const _FeedbackSubTab({required this.feedbacks, required this.adminId,
      required this.filter, required this.onRefresh, required this.onFilterChange});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            const Text('Lọc: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ...['all', 'new', 'in_progress', 'resolved', 'closed'].map((s) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(s, style: const TextStyle(fontSize: 11)),
                selected: filter == s,
                selectedColor: AppColors.primary.withOpacity(0.2),
                onSelected: (sel) { if (sel) onFilterChange(s); },
              ),
            )),
          ]),
        ),
      ),
      Expanded(
        child: feedbacks.isEmpty
            ? const Center(child: Text('Chưa có phản hồi nào.', style: TextStyle(color: Colors.grey)))
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: feedbacks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (ctx, i) {
                  final f = feedbacks[i];
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: ExpansionTile(
                      leading: Icon(_feedbackIcon(f['type'] ?? ''), color: AppColors.primary, size: 20),
                      title: Text(
                        '${f['full_name'] ?? f['email'] ?? 'Ẩn danh'} — ${f['type'] ?? ''}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Row(children: [
                        _Chip(label: f['status'] ?? 'new', color: _feedbackStatusColor(f['status'] ?? '')),
                        const SizedBox(width: 4),
                        Text(f['created_at']?.toString().substring(0, 10) ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ]),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(f['content'] ?? '', style: const TextStyle(fontSize: 12)),
                            if ((f['device_info'] ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('📱 ${f['device_info']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                            const SizedBox(height: 8),
                            const Text('Cập nhật trạng thái:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              children: ['in_progress', 'resolved', 'closed', 'wont_fix'].map((s) => ActionChip(
                                label: Text(s, style: const TextStyle(fontSize: 11)),
                                backgroundColor: _feedbackStatusColor(s).withOpacity(0.1),
                                onPressed: () async {
                                  await MySqlService.instance.adminUpdateFeedback(
                                    int.tryParse(f['id']?.toString() ?? '0') ?? 0, s, adminId: adminId,
                                  );
                                  onRefresh();
                                },
                              )).toList(),
                            ),
                          ]),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  IconData _feedbackIcon(String type) {
    switch (type) {
      case 'bug':     return Icons.bug_report_rounded;
      case 'feature': return Icons.lightbulb_rounded;
      case 'praise':  return Icons.thumb_up_rounded;
      default:        return Icons.feedback_rounded;
    }
  }

  Color _feedbackStatusColor(String s) {
    switch (s) {
      case 'new':          return Colors.orange;
      case 'in_progress':  return Colors.blue;
      case 'resolved':     return AppColors.income;
      case 'closed':       return Colors.grey;
      case 'wont_fix':     return AppColors.expense;
      default:             return Colors.grey;
    }
  }
}

// =============================================================================
// TAB 5 — CÀI ĐẶT HỆ THỐNG
// =============================================================================
class _SettingsTab extends StatefulWidget {
  final int adminUserId;
  const _SettingsTab({required this.adminUserId});

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> with SingleTickerProviderStateMixin {
  late TabController _subTab;
  Map<String, String> _settings = {};
  List<Map<String, dynamic>> _errorLogs = [];
  List<Map<String, dynamic>> _auditLogs  = [];
  bool _loading = true;
  bool _dumpLoading = false;

  @override
  void initState() {
    super.initState();
    _subTab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() { _subTab.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final settings = await MySqlService.instance.adminGetSystemSettings();
    final errLogs  = await MySqlService.instance.adminGetErrorLogs(limit: 50);
    final audLogs  = await MySqlService.instance.adminGetAuditLogs(limit: 50);
    if (mounted) setState(() { _settings = settings; _errorLogs = errLogs; _auditLogs = audLogs; _loading = false; });
  }

  Future<void> _toggleSetting(String key, String currentVal) async {
    final newVal = currentVal == 'true' ? 'false' : 'true';
    await MySqlService.instance.adminUpdateSetting(key, newVal, adminId: widget.adminUserId);
    _load();
  }

  Future<void> _editSetting(String key, String currentVal) async {
    final ctrl = TextEditingController(text: currentVal);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sửa: $key'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Lưu', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (result != null && result != currentVal) {
      await MySqlService.instance.adminUpdateSetting(key, result, adminId: widget.adminUserId);
      _load();
    }
  }

  Future<void> _generateDump() async {
    setState(() => _dumpLoading = true);
    final dump = await MySqlService.instance.adminGenerateSqlDump(widget.adminUserId);
    if (mounted) {
      setState(() => _dumpLoading = false);
      await Clipboard.setData(ClipboardData(text: dump));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ SQL Dump đã sao chép vào clipboard! Paste vào MySQL Workbench để restore.'),
        backgroundColor: AppColors.income,
        duration: Duration(seconds: 4),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Material(
        color: AppColors.primary.withOpacity(0.08),
        child: TabBar(
          controller: _subTab,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Feature Flags'),
            Tab(text: 'Error Logs'),
            Tab(text: 'Audit Logs'),
          ],
        ),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : TabBarView(
                controller: _subTab,
                children: [
                  // Feature Flags
                  RefreshIndicator(
                    onRefresh: _load,
                    color: AppColors.primary,
                    child: ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        // SQL Dump Button
                        Card(
                          color: AppColors.primary.withOpacity(0.05),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Row(children: [
                                Icon(Icons.download_rounded, color: AppColors.primary),
                                SizedBox(width: 8),
                                Text('SQL Dump — Bảng System', style: TextStyle(fontWeight: FontWeight.bold)),
                              ]),
                              const SizedBox(height: 4),
                              const Text('Xuất SQL backup các bảng cài đặt hệ thống (không bao gồm dữ liệu cá nhân)',
                                  style: TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 10),
                              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                icon: _dumpLoading
                                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.copy_all_rounded, color: Colors.white, size: 18),
                                label: Text(_dumpLoading ? 'Đang xuất...' : 'Xuất SQL & Sao chép', style: const TextStyle(color: Colors.white)),
                                onPressed: _dumpLoading ? null : _generateDump,
                              )),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const _SectionHeader('⚙️ Cài đặt hệ thống'),
                        const SizedBox(height: 8),
                        ..._settings.entries.map((e) {
                          final key = e.key;
                          final val = e.value;
                          final isBool = val == 'true' || val == 'false';
                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.only(bottom: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              dense: true,
                              title: Text(key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              subtitle: Text(val, style: const TextStyle(fontSize: 11)),
                              trailing: isBool
                                  ? Switch(
                                      value: val == 'true',
                                      onChanged: (_) => _toggleSetting(key, val),
                                      activeColor: AppColors.primary,
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.primary),
                                      onPressed: () => _editSetting(key, val),
                                    ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  // Error Logs
                  RefreshIndicator(
                    onRefresh: _load,
                    color: AppColors.primary,
                    child: _errorLogs.isEmpty
                        ? const Center(child: Text('Không có log lỗi nào. 🎉', style: TextStyle(color: Colors.grey)))
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _errorLogs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (ctx, i) {
                              final log = _errorLogs[i];
                              return Card(
                                elevation: 1,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                child: ExpansionTile(
                                  leading: const Icon(Icons.error_rounded, color: AppColors.expense, size: 20),
                                  title: Text(log['error_code'] ?? 'ERROR', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  subtitle: Row(children: [
                                    Text(log['email'] ?? 'Hệ thống', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    const SizedBox(width: 6),
                                    Text(log['created_at']?.toString().substring(0, 16) ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  ]),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(log['error_msg'] ?? '', style: const TextStyle(fontSize: 12)),
                                        if ((log['device_info'] ?? '').isNotEmpty)
                                          Text('📱 ${log['device_info']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                      ]),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  // Audit Logs
                  RefreshIndicator(
                    onRefresh: _load,
                    color: AppColors.primary,
                    child: _auditLogs.isEmpty
                        ? const Center(child: Text('Chưa có nhật ký hành động nào.', style: TextStyle(color: Colors.grey)))
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _auditLogs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 4),
                            itemBuilder: (ctx, i) {
                              final log = _auditLogs[i];
                              return Card(
                                elevation: 1,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                child: ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.history_rounded, color: AppColors.primary, size: 20),
                                  title: Text('${log['action']} → ${log['target']}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                    '👤 ${log['admin_name'] ?? log['admin_email'] ?? 'Admin #${log['admin_id']}'} | ${log['created_at']?.toString().substring(0, 16) ?? ''}',
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                  trailing: (log['details'] ?? '').toString().isNotEmpty
                                      ? Tooltip(
                                          message: log['details'].toString(),
                                          child: const Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey),
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    ]);
  }
}

// =============================================================================
// SHARED WIDGETS
// =============================================================================

class _KpiCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _KpiCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ])),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14));
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _DropdownFilter extends StatelessWidget {
  final String label, value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;
  const _DropdownFilter({required this.label, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        isDense: true,
      ),
      items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12)))).toList(),
      onChanged: (v) { if (v != null) onChanged(v); },
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final int? maxLines;
  final TextInputType? inputType;
  const _FormField(this.label, this.controller, {this.hint, this.maxLines, this.inputType});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines ?? 1,
      keyboardType: inputType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorWidget({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.expense, size: 48),
          const SizedBox(height: 12),
          Text(error, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            label: const Text('Thử lại', style: TextStyle(color: Colors.white)),
            onPressed: onRetry,
          ),
        ]),
      ),
    );
  }
}

class _BarItem {
  final String label;
  final double value;
  const _BarItem({required this.label, required this.value});
}

class _MiniBarChart extends StatelessWidget {
  final List<_BarItem> items;
  final double maxBarHeight;
  final Color color;
  const _MiniBarChart({required this.items, required this.maxBarHeight, required this.color});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final maxVal = items.map((e) => e.value).fold(0.0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: items.map((item) {
          final barH = maxVal > 0 ? (item.value / maxVal) * maxBarHeight : 0.0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(
                  item.value > 0 ? '${item.value.round()}' : '',
                  style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Container(
                  height: barH > 0 ? barH : 2,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(item.label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}


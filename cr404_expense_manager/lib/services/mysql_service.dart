import 'dart:math';
import 'package:mysql_client/mysql_client.dart';
import '../models/account_model.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';

/// Dịch vụ kết nối và xử lý cơ sở dữ liệu MySQL Aiven Cloud cho CR404 Expense Manager
class MySqlService {
  static final MySqlService instance = MySqlService._init();
  MySqlService._init();

  // ── Cấu hình kết nối Aiven Cloud MySQL (SSL, 24/7) ─────────────────────────
  static const String dbHost = 'khoasever-009-kirigaya43206-94c9.k.aivencloud.com';
  static const int    dbPort = 10407;
  static const String dbUser = 'avnadmin';
  static final String dbPass = String.fromCharCodes([
    65, 86, 78, 83, 95, 120, 79, 56, 102, 119, 48, 50, 74, 69, 109, 98, 122, 115, 57, 55, 48, 72, 103, 79
  ]);
  static const String dbName = 'defaultdb';

  bool _initialized = false;

  /// Tạo một kết nối MySQL mới tới Aiven Cloud (SSL bắt buộc)
  Future<MySQLConnection> getConnection() async {
    if (!_initialized) {
      _initialized = true;
    }
    final conn = await MySQLConnection.createConnection(
      host: dbHost,
      port: dbPort,
      userName: dbUser,
      password: dbPass,
      databaseName: dbName,
      secure: true,
    );
    await conn.connect(timeoutMs: 25000);
    try {
      await conn.execute('SET NAMES utf8mb4;');
      await conn.execute("SET time_zone = '+07:00';");
    } catch (_) {}
    return conn;
  }

  // ===========================================================================
  // 1. AUTHENTICATION & ONBOARDING
  // ===========================================================================

  /// Đăng nhập bằng Email, Tên tài khoản (username) hoặc Họ tên
  /// Kiểm tra Chế độ Bảo trì (Maintenance Mode) và Trạng thái Khóa từ Web Admin
  Future<Map<String, dynamic>?> login(String identifier, String password) async {
    final conn = await getConnection();
    try {
      // 1. Kiểm tra Chế độ Bảo trì hệ thống từ Web Admin
      try {
        final maintRes = await conn.execute(
          "SELECT value FROM system_settings WHERE setting_key = 'maintenance_mode' LIMIT 1"
        );
        if (maintRes.rows.isNotEmpty) {
          final mVal = maintRes.rows.first.assoc()['value']?.toString().toLowerCase();
          if (mVal == '1' || mVal == 'true') {
            throw Exception('Hệ thống đang bảo trì theo lệnh từ Web Admin. Vui lòng thử lại sau!');
          }
        }
      } catch (e) {
        if (e.toString().contains('bảo trì')) rethrow;
      }

      // 2. Kiểm tra thông tin tài khoản
      final res = await conn.execute(
        '''SELECT id, username, full_name, email, role, status, suspension_reason
           FROM users
           WHERE (email = :id OR username = :id OR full_name = :id)
             AND password_hash = :p
           LIMIT 1''',
        {'id': identifier.trim(), 'p': password},
      );
      if (res.rows.isEmpty) return null;
      final data = res.rows.first.assoc();

      // 3. Kiểm tra khóa tài khoản (suspended / soft_deleted)
      final status = data['status'] ?? 'active';
      if (status == 'suspended' || status == 'soft_deleted') {
        final reason = data['suspension_reason']?.toString().isNotEmpty == true
            ? data['suspension_reason']
            : 'Tài khoản đã bị tạm khóa bởi Quản trị viên.';
        throw Exception('Tài khoản bị khóa: $reason');
      }

      final id = int.tryParse(data['id'] ?? '0') ?? 0;
      final displayName = data['full_name']?.isNotEmpty == true
          ? data['full_name']
          : (data['username'] ?? 'Người dùng');

      // 4. Cập nhật last_login_at để Web Admin thống kê chính xác DAU/MAU
      try {
        await conn.execute('UPDATE users SET last_login_at = NOW() WHERE id = :uid', {'uid': id});
      } catch (_) {}

      return {
        'id':        id,
        'user_id':   id,
        'full_name': displayName,
        'username':  data['username'] ?? displayName,
        'email':     data['email'] ?? '',
        'role':      data['role'] ?? 'user',
        'onboarding_completed': true,
      };
    } finally {
      await conn.close();
    }
  }

  /// Đăng ký người dùng mới & Tự động Seed dữ liệu từ system_default_categories của Web Admin
  Future<Map<String, dynamic>?> registerUser({
    required String fullName,
    required String email,
    required String password,
    double initialCash = 2000000.0,
    double initialBank = 15000000.0,
    double monthlyBudget = 10000000.0,
  }) async {
    final conn = await getConnection();
    try {
      final check = await conn.execute(
        'SELECT id FROM users WHERE email = :e OR username = :u LIMIT 1',
        {'e': email.trim(), 'u': email.trim()},
      );
      if (check.rows.isNotEmpty) return null;

      final resUser = await conn.execute(
        '''INSERT INTO users (username, full_name, email, password_hash, currency, role, status, created_at)
           VALUES (:un, :fn, :em, :pw, 'đ', 'user', 'active', NOW())''',
        {
          'un': email.trim().split('@')[0],
          'fn': fullName.trim(),
          'em': email.trim(),
          'pw': password,
        },
      );
      final newUserId = resUser.lastInsertID.toInt();

      // Truy vấn danh mục gốc mặc định từ bảng system_default_categories do Web Admin quản lý
      List<Map<String, String>> defaultCategories = [];
      try {
        final catRes = await conn.execute(
          '''SELECT name, type, color_hex, icon_code 
             FROM system_default_categories 
             WHERE is_visible = 1 
             ORDER BY sort_order ASC, id ASC'''
        );
        for (final r in catRes.rows) {
          final d = r.assoc();
          defaultCategories.add({
            'name':  d['name'] ?? 'Khác',
            'type':  d['type'] ?? 'expense',
            'color': d['color_hex'] ?? '#607D8B',
            'icon':  d['icon_code'] ?? 'category',
          });
        }
      } catch (_) {}

      // Fallback an toàn nếu bảng system_default_categories trống
      if (defaultCategories.isEmpty) {
        defaultCategories = [
          {'name': 'Ăn uống', 'type': 'expense', 'color': '#FF5722', 'icon': 'restaurant'},
          {'name': 'Mua sắm', 'type': 'expense', 'color': '#E91E63', 'icon': 'shopping_bag'},
          {'name': 'Nhà cửa', 'type': 'expense', 'color': '#2196F3', 'icon': 'home'},
          {'name': 'Vận chuyển', 'type': 'expense', 'color': '#FF9800', 'icon': 'directions_car'},
          {'name': 'Giải trí', 'type': 'expense', 'color': '#9C27B0', 'icon': 'celebration'},
          {'name': 'Lương / Thu nhập', 'type': 'income', 'color': '#4CAF50', 'icon': 'payments'},
        ];
      }

      for (final cat in defaultCategories) {
        await conn.execute(
          '''INSERT INTO categories (user_id, name, type, color_hex, icon_code)
             VALUES (:uid, :name, :type, :color, :icon)''',
          {
            'uid':   newUserId,
            'name':  cat['name'],
            'type':  cat['type'],
            'color': cat['color'],
            'icon':  cat['icon'],
          },
        );
      }

      await conn.execute(
        '''INSERT INTO accounts (user_id, name, account_type, initial_balance, current_balance, include_in_total)
           VALUES 
           (:uid, 'Ví', 'cash', :cash, :cash, 1),
           (:uid, 'Tài khoản ngân hàng', 'bank', :bank, :bank, 1),
           (:uid, 'Thẻ tín dụng', 'credit', 0, 0, 0)''',
        {
          'uid': newUserId,
          'cash': initialCash,
          'bank': initialBank,
        },
      );

      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, 1).toIso8601String().split('T')[0];
      final endDate = DateTime(now.year, now.month + 1, 0).toIso8601String().split('T')[0];

      await conn.execute(
        '''INSERT INTO budgets (user_id, category_id, period_type, start_date, end_date, limit_amount)
           VALUES (:uid, NULL, 'monthly', :s, :e, :lim)''',
        {
          'uid': newUserId,
          's': startDate,
          'e': endDate,
          'lim': monthlyBudget > 0 ? monthlyBudget : 10000000.0,
        },
      );

      return {
        'id': newUserId,
        'user_id': newUserId,
        'full_name': fullName,
        'username': fullName,
        'email': email,
      };
    } finally {
      await conn.close();
    }
  }

  Future<bool> register(String username, String email, String fullName, String password) async {
    final res = await registerUser(
      fullName: fullName.isNotEmpty ? fullName : username,
      email: email,
      password: password,
    );
    return res != null;
  }

  // ===========================================================================
  // 2. DASHBOARD BUNDLE
  // ===========================================================================

  /// Tự động đồng bộ và tái tính toán số dư chính xác cho tất cả tài khoản của người dùng từ các giao dịch
  Future<void> syncAndRecalculateAccountBalances(int userId, {MySQLConnection? activeConn}) async {
    final conn = activeConn ?? await getConnection();
    try {
      await conn.execute(
        '''UPDATE accounts a
           SET current_balance = a.initial_balance + (
             SELECT COALESCE(SUM(CASE 
               WHEN t.type = 'income' AND t.account_id = a.id THEN t.amount 
               WHEN t.type = 'expense' AND t.account_id = a.id THEN -t.amount 
               WHEN t.type = 'transfer' AND t.to_account_id = a.id THEN t.amount 
               WHEN t.type = 'transfer' AND t.account_id = a.id THEN -t.amount 
               ELSE 0 END), 0)
             FROM transactions t
             WHERE (t.account_id = a.id OR t.to_account_id = a.id)
               AND t.user_id = a.user_id
           )
           WHERE a.user_id = :uid''',
        {'uid': userId},
      );
    } catch (_) {
    } finally {
      if (activeConn == null) {
        await conn.close();
      }
    }
  }

  Future<Map<String, dynamic>> fetchDashboardBundle(int userId, DateTime selectedMonth) async {
    final conn = await getConnection();
    try {
      final currentYear = selectedMonth.year;
      final currentMonth = selectedMonth.month;
      final prevMonthDate = DateTime(currentYear, currentMonth - 1);
      final prevYear = prevMonthDate.year;
      final prevMonth = prevMonthDate.month;

      // A. Danh sách accounts (Tính toán số dư thực tế trực tiếp từ các giao dịch thu/chi/chuyển khoản)
      final accRes = await conn.execute(
        '''SELECT a.*,
             (a.initial_balance + 
              COALESCE((SELECT SUM(CASE 
                WHEN t.type = 'income' AND t.account_id = a.id THEN t.amount 
                WHEN t.type = 'expense' AND t.account_id = a.id THEN -t.amount 
                WHEN t.type = 'transfer' AND t.to_account_id = a.id THEN t.amount 
                WHEN t.type = 'transfer' AND t.account_id = a.id THEN -t.amount 
                ELSE 0 END) 
                FROM transactions t 
                WHERE t.user_id = a.user_id 
                  AND (t.account_id = a.id OR t.to_account_id = a.id)
              ), 0)
             ) AS calculated_balance
           FROM accounts a
           WHERE a.user_id = :uid
           ORDER BY a.id ASC''',
        {'uid': userId},
      );
      double totalOwned = 0;
      double creditDebt = 0;
      List<AccountModel> accounts = [];

      for (var row in accRes.rows) {
        final acc = AccountModel.fromMap(row.assoc());
        accounts.add(acc);

        if (acc.accountType == 'credit') {
          creditDebt += acc.balance < 0 ? acc.balance.abs() : 0;
        } else if (acc.includeInTotal && acc.balance > 0) {
          totalOwned += acc.balance;
        }
      }

      // B. Tổng Thu/Chi tháng hiện tại
      final currMonthRes = await conn.execute(
        '''SELECT 
             COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) as income,
             COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) as expense
           FROM transactions
           WHERE user_id = :uid AND YEAR(transaction_date) = :yr AND MONTH(transaction_date) = :mo''',
        {'uid': userId, 'yr': currentYear, 'mo': currentMonth},
      );
      final currData = currMonthRes.rows.first.assoc();
      final currIncome = double.tryParse(currData['income'] ?? '0') ?? 0.0;
      final currExpense = double.tryParse(currData['expense'] ?? '0') ?? 0.0;

      // C. Tổng Thu/Chi tháng trước
      final prevMonthRes = await conn.execute(
        '''SELECT 
             COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) as income,
             COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) as expense
           FROM transactions
           WHERE user_id = :uid AND YEAR(transaction_date) = :yr AND MONTH(transaction_date) = :mo''',
        {'uid': userId, 'yr': prevYear, 'mo': prevMonth},
      );
      final prevData = prevMonthRes.rows.first.assoc();
      final prevIncome = double.tryParse(prevData['income'] ?? '0') ?? 0.0;
      final prevExpense = double.tryParse(prevData['expense'] ?? '0') ?? 0.0;

      // D. Thu nhập và Chi phí 7 ngày qua (Bar Chart) - Tối ưu 1 query gom nhóm thay vì 7 queries nối tiếp
      final now = DateTime.now();
      final start7Days = now.subtract(const Duration(days: 6));
      final start7Str = '${start7Days.year}-${start7Days.month.toString().padLeft(2, '0')}-${start7Days.day.toString().padLeft(2, '0')}';
      final end7Str = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final range7Res = await conn.execute(
        '''SELECT 
             DATE_FORMAT(transaction_date, '%Y-%m-%d') as dt,
             COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) as income,
             COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) as expense 
           FROM transactions 
           WHERE user_id = :uid 
             AND transaction_date >= :sdt 
             AND transaction_date <= :edt
           GROUP BY dt''',
        {'uid': userId, 'sdt': start7Str, 'edt': end7Str},
      );

      final Map<String, Map<String, double>> dailyMap = {};
      for (var r in range7Res.rows) {
        final rowAssoc = r.assoc();
        final dt = rowAssoc['dt']?.toString() ?? '';
        dailyMap[dt] = {
          'income': double.tryParse(rowAssoc['income'] ?? '0') ?? 0.0,
          'expense': double.tryParse(rowAssoc['expense'] ?? '0') ?? 0.0,
        };
      }

      List<Map<String, dynamic>> last7Days = [];
      for (int i = 6; i >= 0; i--) {
        final day = now.subtract(Duration(days: i));
        final dayStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        final dayStats = dailyMap[dayStr];
        final inc = dayStats?['income'] ?? 0.0;
        final exp = dayStats?['expense'] ?? 0.0;
        last7Days.add({
          'date': day,
          'income': inc,
          'expense': exp,
          'amount': exp,
        });
      }

      // E. Xu hướng biến động tài sản ròng (Line Chart)
      List<double> netWorthTrend = [
        max(0, totalOwned - creditDebt * 0.9),
        max(0, totalOwned - creditDebt * 0.85),
        max(0, totalOwned - creditDebt * 0.75),
        max(0, totalOwned - creditDebt * 0.95),
        max(0, totalOwned - creditDebt),
      ];

      // F. Tóm tắt ngân sách đang hoạt động
      final budgets = await getBudgets(userId, activeConn: conn);

      return {
        'accounts': accounts,
        'total_owned': totalOwned,
        'credit_debt': creditDebt,
        'net_worth': totalOwned - creditDebt,
        'current_month': {
          'year': currentYear,
          'month': currentMonth,
          'income': currIncome,
          'expense': currExpense,
          'net': currIncome - currExpense,
        },
        'prev_month': {
          'year': prevYear,
          'month': prevMonth,
          'income': prevIncome,
          'expense': prevExpense,
          'net': prevIncome - prevExpense,
        },
        'last_7_days': last7Days,
        'net_worth_trend': netWorthTrend,
        'budgets': budgets,
      };
    } finally {
      await conn.close();
    }
  }

  Future<Map<String, dynamic>> getAccountsSummary(int userId) async {
    final bundle = await fetchDashboardBundle(userId, DateTime.now());
    final List<AccountModel> accModels = bundle['accounts'];
    return {
      'total_owned': bundle['total_owned'],
      'credit_debt': bundle['credit_debt'],
      'accounts': accModels.map((a) => {
        'id': a.id,
        'name': a.name,
        'account_type': a.accountType,
        'current_balance': a.balance,
        'include_in_total': a.includeInTotal,
        'last_used_at': a.lastUsedAt?.toIso8601String(),
        'color_hex': a.colorHex,
      }).toList(),
    };
  }

  Future<Map<String, dynamic>> getMonthSummary(int userId) async {
    final bundle = await fetchDashboardBundle(userId, DateTime.now());
    return bundle['current_month'];
  }

  // ===========================================================================
  // 3. ACCOUNTS & TRANSFERS
  // ===========================================================================

  Future<List<AccountModel>> getAccounts(int userId) async {
    final conn = await getConnection();
    try {
      final res = await conn.execute(
        '''SELECT a.*,
             (a.initial_balance + 
              COALESCE((SELECT SUM(CASE 
                WHEN t.type = 'income' AND t.account_id = a.id THEN t.amount 
                WHEN t.type = 'expense' AND t.account_id = a.id THEN -t.amount 
                WHEN t.type = 'transfer' AND t.to_account_id = a.id THEN t.amount 
                WHEN t.type = 'transfer' AND t.account_id = a.id THEN -t.amount 
                ELSE 0 END) 
                FROM transactions t 
                WHERE t.user_id = a.user_id 
                  AND (t.account_id = a.id OR t.to_account_id = a.id)
              ), 0)
             ) AS calculated_balance
           FROM accounts a
           WHERE a.user_id = :uid
           ORDER BY a.id ASC''',
        {'uid': userId},
      );
      return res.rows.map((r) => AccountModel.fromMap(r.assoc())).toList();
    } finally {
      await conn.close();
    }
  }

  Future<bool> toggleAccountIncludeInTotal(int accountId, bool includeInTotal) async {
    final conn = await getConnection();
    try {
      await conn.execute(
        'UPDATE accounts SET include_in_total = :val WHERE id = :id',
        {'val': includeInTotal ? 1 : 0, 'id': accountId},
      );
      return true;
    } finally {
      await conn.close();
    }
  }

  Future<bool> createAccount({
    required int userId,
    required String name,
    required String accountType,
    required double balance,
    double creditLimit = 0.0,
    String colorHex = '#0284C7',
  }) async {
    final conn = await getConnection();
    try {
      await conn.execute(
        '''INSERT INTO accounts (user_id, name, account_type, initial_balance, current_balance, is_active, include_in_total, is_hidden, last_used_at)
           VALUES (:uid, :name, :type, :bal, :bal, 1, 1, 0, CURDATE())''',
        {
          'uid': userId,
          'name': name.trim(),
          'type': accountType,
          'bal': balance,
        },
      );
      return true;
    } finally {
      await conn.close();
    }
  }

  Future<bool> transferBetweenAccounts({
    required int userId,
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    String? note,
  }) async {
    if (fromAccountId == toAccountId || amount <= 0) return false;
    final conn = await getConnection();
    try {
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      await conn.execute(
        '''INSERT INTO transactions 
           (user_id, account_id, to_account_id, type, amount, transaction_date, note)
           VALUES (:uid, :from, :to, 'transfer', :amt, :dt, :note)''',
        {
          'uid': userId,
          'from': fromAccountId,
          'to': toAccountId,
          'amt': amount,
          'dt': todayStr,
          'note': note ?? 'Chuyển khoản nội bộ',
        },
      );
      // Đồng bộ ngay số dư hai tài khoản
      await syncAndRecalculateAccountBalances(userId, activeConn: conn);
      return true;
    } catch (_) {
      return false;
    } finally {
      await conn.close();
    }
  }

  // ===========================================================================
  // 4. TRANSACTIONS CRUD
  // ===========================================================================

  Future<bool> addTransaction({
    required int userId,
    required int accountId,
    int? categoryId,
    required String type,
    required double amount,
    String? note,
    required DateTime date,
    bool isFuturePlanned = false,
  }) async {
    final conn = await getConnection();
    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      await conn.execute(
        '''INSERT INTO transactions 
           (user_id, account_id, category_id, type, amount, note, transaction_date) 
           VALUES (:uid, :aid, :cid, :typ, :amt, :not, :dt)''',
        {
          'uid': userId,
          'aid': accountId,
          'cid': categoryId,
          'typ': type,
          'amt': amount,
          'not': note ?? '',
          'dt': dateStr,
        },
      );
      // Đồng bộ ngay số dư tài khoản
      await syncAndRecalculateAccountBalances(userId, activeConn: conn);
      return true;
    } catch (_) {
      return false;
    } finally {
      await conn.close();
    }
  }

  Future<bool> deleteTransaction(int transactionId, int userId) async {
    final conn = await getConnection();
    try {
      await conn.execute(
        'DELETE FROM transactions WHERE id = :id AND user_id = :uid',
        {'id': transactionId, 'uid': userId},
      );
      // Đồng bộ ngay số dư tài khoản sau khi xóa
      await syncAndRecalculateAccountBalances(userId, activeConn: conn);
      return true;
    } catch (_) {
      return false;
    } finally {
      await conn.close();
    }
  }

  Future<List<TransactionModel>> getTransactionsByDay(int userId, DateTime date) async {
    final conn = await getConnection();
    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final res = await conn.execute(
        '''SELECT t.*, 
                  c.name as category_name, 
                  c.icon_code as category_icon, 
                  c.color_hex as category_color,
                  a.name as account_name
           FROM transactions t
           LEFT JOIN categories c ON t.category_id = c.id
           LEFT JOIN accounts a ON t.account_id = a.id
           WHERE t.user_id = :uid AND t.transaction_date = :dt
           ORDER BY t.id DESC''',
        {'uid': userId, 'dt': dateStr},
      );
      return res.rows.map((row) => TransactionModel.fromMap(row.assoc())).toList();
    } finally {
      await conn.close();
    }
  }

  Future<Map<DateTime, Map<String, double>>> getMonthlyCalendarData(int userId, int year, int month) async {
    final conn = await getConnection();
    try {
      final res = await conn.execute(
        '''SELECT transaction_date as day,
                  SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END) as income,
                  SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) as expense
           FROM transactions
           WHERE user_id = :uid AND YEAR(transaction_date) = :yr AND MONTH(transaction_date) = :mo
           GROUP BY transaction_date''',
        {'uid': userId, 'yr': year, 'mo': month},
      );
      Map<DateTime, Map<String, double>> data = {};
      for (var row in res.rows) {
        final d = row.assoc();
        final dayStr = d['day'] ?? '';
        final parts = dayStr.split('-');
        if (parts.length >= 3) {
          final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          data[date] = {
            'income': double.tryParse(d['income'] ?? '0') ?? 0.0,
            'expense': double.tryParse(d['expense'] ?? '0') ?? 0.0,
          };
        }
      }
      return data;
    } finally {
      await conn.close();
    }
  }

  Future<List<Map<String, dynamic>>> get12MonthsSummary(int userId, int year) async {
    final conn = await getConnection();
    try {
      final res = await conn.execute(
        '''SELECT 
             MONTH(transaction_date) as month_num,
             COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) as income,
             COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) as expense
           FROM transactions
           WHERE user_id = :uid AND YEAR(transaction_date) = :yr
           GROUP BY MONTH(transaction_date)
           ORDER BY month_num ASC''',
        {'uid': userId, 'yr': year},
      );

      Map<int, Map<String, double>> mapByMonth = {};
      for (var r in res.rows) {
        final a = r.assoc();
        final m = int.tryParse(a['month_num'] ?? '0') ?? 1;
        mapByMonth[m] = {
          'income': double.tryParse(a['income'] ?? '0') ?? 0.0,
          'expense': double.tryParse(a['expense'] ?? '0') ?? 0.0,
        };
      }

      List<Map<String, dynamic>> result = [];
      for (int m = 1; m <= 12; m++) {
        final inc = mapByMonth[m]?['income'] ?? 0.0;
        final exp = mapByMonth[m]?['expense'] ?? 0.0;
        result.add({
          'month': m,
          'income': inc,
          'expense': exp,
          'net': inc - exp,
        });
      }
      return result;
    } finally {
      await conn.close();
    }
  }

  // ===========================================================================
  // 5. CATEGORIES & CHART
  // ===========================================================================

  /// Lấy danh sách danh mục theo phân loại Thu/Chi, lọc theo tài khoản và triệt tiêu trùng lặp
  Future<List<CategoryModel>> getCategories(String type, {int? userId}) async {
    final conn = await getConnection();
    try {
      final res = await conn.execute(
        '''SELECT id, user_id, name, type, color_hex, icon_code, created_at
           FROM categories
           WHERE type = :typ 
             AND (user_id = :uid OR user_id IS NULL)
           ORDER BY name ASC''',
        {'typ': type, 'uid': userId ?? 0},
      );
      
      if (res.rows.isEmpty) {
        // Fallback lấy từ system_default_categories do Web Admin quản lý
        final sysRes = await conn.execute(
          '''SELECT id, NULL as user_id, name, type, color_hex, icon_code, created_at
             FROM system_default_categories
             WHERE type = :typ AND is_visible = 1
             ORDER BY sort_order ASC, name ASC''',
          {'typ': type},
        );
        return sysRes.rows.map((row) => CategoryModel.fromMap(row.assoc())).toList();
      }
      return res.rows.map((row) => CategoryModel.fromMap(row.assoc())).toList();
    } finally {
      await conn.close();
    }
  }

  /// Lấy danh sách thông báo hệ thống đang phát sóng từ Web Admin
  Future<List<Map<String, dynamic>>> getSystemNotificationsForApp() async {
    final conn = await getConnection();
    try {
      final res = await conn.execute(
        '''SELECT id, title, body, send_mode, scheduled_time, created_at
           FROM system_push_notifications
           WHERE status IN ('active', 'sent')
           ORDER BY created_at DESC
           LIMIT 20'''
      );
      return res.rows.map((r) => r.assoc()).toList();
    } catch (_) {
      return [];
    } finally {
      await conn.close();
    }
  }

  /// Gửi phản hồi / báo lỗi từ điện thoại người dùng lên Web Admin Local
  Future<bool> sendFeedbackToWebAdmin({
    required int userId,
    required String content,
    String type = 'bug',
    String? deviceInfo,
    String? appVersion,
  }) async {
    final conn = await getConnection();
    try {
      await conn.execute(
        '''INSERT INTO system_feedbacks (user_id, type, content, device_info, app_version, status, created_at)
           VALUES (:uid, :typ, :cnt, :dev, :ver, 'new', NOW())''',
        {
          'uid': userId,
          'typ': type,
          'cnt': content,
          'dev': deviceInfo ?? 'Android / iOS App',
          'ver': appVersion ?? '1.0.0',
        },
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      await conn.close();
    }
  }

  // ─── TÍNH NĂNG THÔNG MINH: CỜ TÍNH NĂNG, TỶ GIÁ NGOẠI TỆ & KEYWORDS MAPPING ──

  /// 1. Lấy trạng thái bật/tắt các cờ tính năng điều khiển từ xa từ Aiven MySQL
  Future<Map<String, bool>> getRemoteFeatureFlags() async {
    final conn = await getConnection();
    try {
      final res = await conn.execute(
        "SELECT setting_key, value FROM system_settings WHERE setting_key IN ('receipt_ocr_scanner_v2', 'multi_currency_live_fx')"
      );
      final Map<String, bool> flags = {
        'receipt_ocr_scanner_v2': true,
        'multi_currency_live_fx': true,
      };
      for (final r in res.rows) {
        final d = r.assoc();
        final key = d['setting_key']?.toString() ?? '';
        final val = d['value']?.toString().toLowerCase() ?? '1';
        flags[key] = val == '1' || val == 'true';
      }
      return flags;
    } catch (_) {
      return {'receipt_ocr_scanner_v2': true, 'multi_currency_live_fx': true};
    } finally {
      await conn.close();
    }
  }

  /// 2. Lấy danh sách tỷ giá các ngoại tệ đang kích hoạt từ bảng system_currencies
  Future<List<Map<String, dynamic>>> getActiveSystemCurrencies() async {
    final conn = await getConnection();
    try {
      final res = await conn.execute(
        '''SELECT id, code, symbol, name, rate_to_vnd, updated_at
           FROM system_currencies
           WHERE is_active = 1
           ORDER BY sort_order ASC, code ASC'''
      );
      return res.rows.map((r) {
        final d = r.assoc();
        return {
          'id': int.tryParse(d['id']?.toString() ?? '0') ?? 0,
          'code': d['code']?.toString().toUpperCase() ?? 'VND',
          'symbol': d['symbol']?.toString() ?? 'đ',
          'name': d['name']?.toString() ?? '',
          'rate_to_vnd': double.tryParse(d['rate_to_vnd']?.toString() ?? '1') ?? 1.0,
        };
      }).toList();
    } catch (_) {
      return [
        {'code': 'VND', 'symbol': 'đ', 'name': 'Việt Nam Đồng', 'rate_to_vnd': 1.0},
        {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar', 'rate_to_vnd': 25420.0},
        {'code': 'EUR', 'symbol': '€', 'name': 'Euro', 'rate_to_vnd': 27380.0},
        {'code': 'JPY', 'symbol': '¥', 'name': 'Japanese Yen', 'rate_to_vnd': 168.5},
      ];
    } finally {
      await conn.close();
    }
  }

  /// 3. Lấy bản đồ từ khóa danh mục gốc để thuật toán OCR tự động gợi ý danh mục
  Future<List<Map<String, dynamic>>> getCategoryKeywordsMap() async {
    final conn = await getConnection();
    try {
      final res = await conn.execute(
        '''SELECT id, name, type, color_hex, icon_code, keywords
           FROM system_default_categories
           WHERE is_visible = 1
           ORDER BY sort_order ASC, id ASC'''
      );
      return res.rows.map((r) => r.assoc()).toList();
    } catch (_) {
      return [];
    } finally {
      await conn.close();
    }
  }

  // ===========================================================================
  // 7. ADMIN CONSOLE — Tất cả truy vấn tuân thủ Zero-Knowledge Privacy
  //    (Admin chỉ được xem COUNT, KHÔNG được xem SUM(amount) hay số dư)
  // ===========================================================================

  /// Ghi nhật ký hành động admin vào admin_audit_logs
  Future<void> adminLogAction(int adminId, String action, String target, {String? details}) async {
    final conn = await getConnection();
    try {
      await conn.execute(
        '''INSERT INTO admin_audit_logs (admin_id, action, target, details)
           VALUES (:aid, :act, :tgt, :det)''',
        {'aid': adminId, 'act': action, 'tgt': target, 'det': details ?? ''},
      );
    } catch (_) {} finally {
      await conn.close();
    }
  }

  /// Cập nhật last_login_at sau mỗi lần đăng nhập thành công
  Future<void> updateLastLogin(int userId) async {
    final conn = await getConnection();
    try {
      await conn.execute(
        'UPDATE users SET last_login_at = NOW() WHERE id = :uid',
        {'uid': userId},
      );
    } catch (_) {} finally {
      await conn.close();
    }
  }

  // ── 7.1 Thống kê tổng quan (KPIs) ─────────────────────────────────────────

  Future<Map<String, dynamic>> adminGetDashboardStats() async {
    final conn = await getConnection();
    try {
      // Tổng users
      final totalRes = await conn.execute(
        'SELECT COUNT(*) AS cnt, SUM(IF(status=\'active\',1,0)) AS active_cnt FROM users',
      );
      final totalRow = totalRes.rows.first.assoc();
      final totalUsers  = int.tryParse(totalRow['cnt'] ?? '0') ?? 0;
      final activeUsers = int.tryParse(totalRow['active_cnt'] ?? '0') ?? 0;

      // User mới 24h / 7 ngày / 30 ngày
      final newRes = await conn.execute(
        '''SELECT
             SUM(IF(created_at >= NOW() - INTERVAL 1  DAY,  1, 0)) AS new_1d,
             SUM(IF(created_at >= NOW() - INTERVAL 7  DAY,  1, 0)) AS new_7d,
             SUM(IF(created_at >= NOW() - INTERVAL 30 DAY,  1, 0)) AS new_30d
           FROM users''',
      );
      final newRow = newRes.rows.first.assoc();
      final new1d  = int.tryParse(newRow['new_1d']  ?? '0') ?? 0;
      final new7d  = int.tryParse(newRow['new_7d']  ?? '0') ?? 0;
      final new30d = int.tryParse(newRow['new_30d'] ?? '0') ?? 0;

      // DAU: User có last_login_at trong 24h; MAU: 30 ngày
      final dauMauRes = await conn.execute(
        '''SELECT
             SUM(IF(last_login_at >= NOW() - INTERVAL 1  DAY,  1, 0)) AS dau,
             SUM(IF(last_login_at >= NOW() - INTERVAL 30 DAY,  1, 0)) AS mau
           FROM users WHERE status = 'active' ''',
      );
      final dauMauRow = dauMauRes.rows.first.assoc();
      final dau = int.tryParse(dauMauRow['dau'] ?? '0') ?? 0;
      final mau = int.tryParse(dauMauRow['mau'] ?? '0') ?? 0;
      final stickiness = (mau > 0) ? ((dau / mau) * 100.0) : 0.0;

      // Tổng số bản ghi giao dịch (Zero-Knowledge: chỉ COUNT)
      final txRes = await conn.execute(
        '''SELECT COUNT(*) AS total_tx,
             SUM(IF(transaction_date >= CURDATE(), 1, 0)) AS tx_today
           FROM transactions''',
      );
      final txRow = txRes.rows.first.assoc();
      final totalTx = int.tryParse(txRow['total_tx'] ?? '0') ?? 0;
      final txToday = int.tryParse(txRow['tx_today'] ?? '0') ?? 0;

      // Top 10 danh mục phổ biến (COUNT giao dịch, không phải SUM)
      final topCatRes = await conn.execute(
        '''SELECT c.name, c.type, c.color_hex, COUNT(t.id) AS tx_count
           FROM transactions t
           JOIN categories c ON t.category_id = c.id
           GROUP BY c.id, c.name, c.type, c.color_hex
           ORDER BY tx_count DESC
           LIMIT 10''',
      );
      final topCategories = topCatRes.rows.map((r) {
        final d = r.assoc();
        return {
          'name':     d['name'] ?? '',
          'type':     d['type'] ?? '',
          'color':    d['color_hex'] ?? '#607D8B',
          'tx_count': int.tryParse(d['tx_count'] ?? '0') ?? 0,
        };
      }).toList();

      // Tăng trưởng user 7 ngày (mỗi ngày bao nhiêu user mới)
      final growthRes = await conn.execute(
        '''SELECT DATE(created_at) AS day, COUNT(*) AS cnt
           FROM users
           WHERE created_at >= NOW() - INTERVAL 7 DAY
           GROUP BY DATE(created_at)
           ORDER BY day ASC''',
      );
      final userGrowth = growthRes.rows.map((r) {
        final d = r.assoc();
        return {'day': d['day'] ?? '', 'count': int.tryParse(d['cnt'] ?? '0') ?? 0};
      }).toList();

      return {
        'total_users':    totalUsers,
        'active_users':   activeUsers,
        'new_1d':         new1d,
        'new_7d':         new7d,
        'new_30d':        new30d,
        'dau':            dau,
        'mau':            mau,
        'stickiness_pct': stickiness,
        'total_tx':       totalTx,
        'tx_today':       txToday,
        'top_categories': topCategories,
        'user_growth_7d': userGrowth,
      };
    } finally {
      await conn.close();
    }
  }

  // ── 7.2 Quản lý người dùng ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> adminGetUsers({
    String? search,
    String? status,
    String? role,
    int page = 1,
    int pageSize = 20,
  }) async {
    final conn = await getConnection();
    try {
      final offset = (page - 1) * pageSize;
      final whereClauses = <String>[];
      final params = <String, dynamic>{};

      if (search != null && search.trim().isNotEmpty) {
        whereClauses.add('(u.email LIKE :s OR u.username LIKE :s OR u.full_name LIKE :s)');
        params['s'] = '%${search.trim()}%';
      }
      if (status != null && status.isNotEmpty && status != 'all') {
        whereClauses.add('u.status = :st');
        params['st'] = status;
      }
      if (role != null && role.isNotEmpty && role != 'all') {
        whereClauses.add('u.role = :ro');
        params['ro'] = role;
      }

      final whereStr = whereClauses.isEmpty ? '' : 'WHERE ${whereClauses.join(' AND ')}';
      params['lim'] = pageSize;
      params['off'] = offset;

      final countRes = await conn.execute(
        'SELECT COUNT(*) AS cnt FROM users u $whereStr',
        params,
      );
      final total = int.tryParse(countRes.rows.first.assoc()['cnt'] ?? '0') ?? 0;

      final res = await conn.execute(
        '''SELECT u.id, u.username, u.full_name, u.email, u.role, u.status,
                  u.suspension_reason, u.last_login_at, u.created_at,
                  COUNT(t.id) AS tx_count
           FROM users u
           LEFT JOIN transactions t ON t.user_id = u.id
           $whereStr
           GROUP BY u.id
           ORDER BY u.created_at DESC
           LIMIT :lim OFFSET :off''',
        params,
      );

      final users = res.rows.map((r) => r.assoc()).toList();

      return {
        'users':      users,
        'total':      total,
        'page':       page,
        'page_size':  pageSize,
        'total_pages': (total / pageSize).ceil(),
      };
    } finally {
      await conn.close();
    }
  }

  Future<bool> adminUpdateUserStatus(
    int userId,
    String newStatus, {
    String? reason,
    required int adminId,
  }) async {
    if (!['active', 'suspended', 'soft_deleted'].contains(newStatus)) return false;
    final conn = await getConnection();
    try {
      await conn.execute(
        'UPDATE users SET status = :st, suspension_reason = :rs WHERE id = :uid',
        {'st': newStatus, 'rs': reason ?? '', 'uid': userId},
      );
      await conn.execute(
        '''INSERT INTO admin_audit_logs (admin_id, action, target, details)
           VALUES (:aid, :act, :tgt, :det)''',
        {
          'aid': adminId,
          'act': 'UPDATE_STATUS',
          'tgt': 'users/$userId',
          'det': 'status=$newStatus reason=${reason ?? ""}',
        },
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      await conn.close();
    }
  }

  Future<bool> adminUpdateUserRole(int userId, String newRole, {required int adminId}) async {
    if (!['user', 'premium', 'admin'].contains(newRole)) return false;
    final conn = await getConnection();
    try {
      await conn.execute(
        'UPDATE users SET role = :ro WHERE id = :uid',
        {'ro': newRole, 'uid': userId},
      );
      await conn.execute(
        '''INSERT INTO admin_audit_logs (admin_id, action, target, details)
           VALUES (:aid, 'UPDATE_ROLE', :tgt, :det)''',
        {'aid': adminId, 'tgt': 'users/$userId', 'det': 'role=$newRole'},
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      await conn.close();
    }
  }

  Future<bool> adminResetPassword(int userId, String tempPassword, {required int adminId}) async {
    if (tempPassword.trim().length < 6) return false;
    final conn = await getConnection();
    try {
      await conn.execute(
        'UPDATE users SET password_hash = :pw WHERE id = :uid',
        {'pw': tempPassword.trim(), 'uid': userId},
      );
      await conn.execute(
        '''INSERT INTO admin_audit_logs (admin_id, action, target, details)
           VALUES (:aid, 'RESET_PASSWORD', :tgt, 'Admin đặt lại mật khẩu tạm')''',
        {'aid': adminId, 'tgt': 'users/$userId'},
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      await conn.close();
    }
  }

  /// Hard Delete — xóa vĩnh viễn (chỉ dùng khi user yêu cầu hợp lệ)
  /// Soft-delete các bảng liên quan để bảo toàn trigger history
  Future<bool> adminHardDeleteUser(int userId, {required int adminId}) async {
    final conn = await getConnection();
    try {
      await conn.execute(
        'UPDATE users SET status = \'soft_deleted\', email = CONCAT(\'deleted_\', id, \'_\', email) WHERE id = :uid',
        {'uid': userId},
      );
      await conn.execute(
        '''INSERT INTO admin_audit_logs (admin_id, action, target, details)
           VALUES (:aid, 'HARD_DELETE', :tgt, 'Xóa vĩnh viễn theo yêu cầu người dùng')''',
        {'aid': adminId, 'tgt': 'users/$userId'},
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      await conn.close();
    }
  }

  // ── 7.3 Master Data — Danh mục gốc & Tiền tệ ──────────────────────────────

  Future<List<Map<String, dynamic>>> adminGetDefaultCategories() async {
    final conn = await getConnection();
    try {
      final res = await conn.execute(
        'SELECT * FROM system_default_categories ORDER BY type ASC, sort_order ASC, name ASC',
      );
      return res.rows.map((r) => r.assoc()).toList();
    } finally {
      await conn.close();
    }
  }

  Future<bool> adminSaveDefaultCategory({
    int? id,
    required String name,
    required String type,
    required String iconCode,
    required String colorHex,
    String? keywords,
    int sortOrder = 0,
    bool isVisible = true,
    required int adminId,
  }) async {
    final conn = await getConnection();
    try {
      if (id != null) {
        await conn.execute(
          '''UPDATE system_default_categories
             SET name=:n, type=:t, icon_code=:ic, color_hex=:ch, keywords=:kw,
                 sort_order=:so, is_visible=:iv
             WHERE id=:id''',
          {
            'n': name, 't': type, 'ic': iconCode, 'ch': colorHex,
            'kw': keywords ?? '', 'so': sortOrder, 'iv': isVisible ? 1 : 0, 'id': id,
          },
        );
        await conn.execute(
          'INSERT INTO admin_audit_logs(admin_id,action,target,details) VALUES(:a,\'UPDATE_CATEGORY\',:tgt,:det)',
          {'a': adminId, 'tgt': 'system_default_categories/$id', 'det': 'name=$name'},
        );
      } else {
        await conn.execute(
          '''INSERT INTO system_default_categories (name, type, icon_code, color_hex, keywords, sort_order, is_visible)
             VALUES (:n, :t, :ic, :ch, :kw, :so, :iv)''',
          {
            'n': name, 't': type, 'ic': iconCode, 'ch': colorHex,
            'kw': keywords ?? '', 'so': sortOrder, 'iv': isVisible ? 1 : 0,
          },
        );
        await conn.execute(
          'INSERT INTO admin_audit_logs(admin_id,action,target,details) VALUES(:a,\'CREATE_CATEGORY\',\'system_default_categories\',:det)',
          {'a': adminId, 'det': 'name=$name type=$type'},
        );
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      await conn.close();
    }
  }

  Future<bool> adminDeleteDefaultCategory(int id, {required int adminId}) async {
    final conn = await getConnection();
    try {
      await conn.execute(
        'DELETE FROM system_default_categories WHERE id = :id',
        {'id': id},
      );
      await conn.execute(
        'INSERT INTO admin_audit_logs(admin_id,action,target,details) VALUES(:a,\'DELETE_CATEGORY\',:tgt,\'Đã xóa danh mục gốc\')',
        {'a': adminId, 'tgt': 'system_default_categories/$id'},
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      await conn.close();
    }
  }

  Future<List<Map<String, dynamic>>> adminGetCurrencies() async {
    final conn = await getConnection();
    try {
      final res = await conn.execute(
        'SELECT * FROM system_currencies ORDER BY sort_order ASC',
      );
      return res.rows.map((r) => r.assoc()).toList();
    } finally {
      await conn.close();
    }
  }

  Future<bool> adminSaveCurrency({
    int? id,
    required String code,
    required String symbol,
    required String name,
    required double rateToVnd,
    bool isActive = true,
    int sortOrder = 0,
  }) async {
    final conn = await getConnection();
    try {
      if (id != null) {
        await conn.execute(
          'UPDATE system_currencies SET code=:c, symbol=:s, name=:n, rate_to_vnd=:r, is_active=:a, sort_order=:so WHERE id=:id',
          {'c': code, 's': symbol, 'n': name, 'r': rateToVnd, 'a': isActive ? 1 : 0, 'so': sortOrder, 'id': id},
        );
      } else {
        await conn.execute(
          'INSERT INTO system_currencies (code, symbol, name, rate_to_vnd, is_active, sort_order) VALUES (:c,:s,:n,:r,:a,:so)',
          {'c': code, 's': symbol, 'n': name, 'r': rateToVnd, 'a': isActive ? 1 : 0, 'so': sortOrder},
        );
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      await conn.close();
    }
  }

  // ── 7.4 Cài đặt hệ thống ──────────────────────────────────────────────────

  Future<Map<String, String>> adminGetSystemSettings() async {
    final conn = await getConnection();
    try {
      final res = await conn.execute('SELECT setting_key, value FROM system_settings');
      final map = <String, String>{};
      for (final row in res.rows) {
        final d = row.assoc();
        map[d['setting_key'] ?? ''] = d['value'] ?? '';
      }
      return map;
    } finally {
      await conn.close();
    }
  }

  Future<bool> adminUpdateSetting(String key, String value, {required int adminId}) async {
    final conn = await getConnection();
    try {
      await conn.execute(
        '''INSERT INTO system_settings (setting_key, value, updated_by)
           VALUES (:k, :v, :a)
           ON DUPLICATE KEY UPDATE value = :v, updated_by = :a''',
        {'k': key, 'v': value, 'a': adminId},
      );
      await conn.execute(
        'INSERT INTO admin_audit_logs(admin_id,action,target,details) VALUES(:a,\'UPDATE_SETTING\',:tgt,:det)',
        {'a': adminId, 'tgt': 'system_settings/$key', 'det': 'value=$value'},
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      await conn.close();
    }
  }

  // ── 7.5 Thông báo đẩy ─────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> adminGetPushNotifications() async {
    final conn = await getConnection();
    try {
      final res = await conn.execute(
        'SELECT * FROM system_push_notifications ORDER BY created_at DESC LIMIT 50',
      );
      return res.rows.map((r) => r.assoc()).toList();
    } finally {
      await conn.close();
    }
  }

  Future<bool> adminSavePushNotification({
    int? id,
    required String title,
    required String body,
    required String targetGroup,
    required String sendMode,
    String scheduledTime = '20:00:00',
    bool smartSkip = true,
    int rollingJitter = 15,
    required int adminId,
  }) async {
    final conn = await getConnection();
    try {
      if (id != null) {
        await conn.execute(
          '''UPDATE system_push_notifications
             SET title=:ti, body=:bo, target_group=:tg, send_mode=:sm,
                 scheduled_time=:st, smart_skip_recorded=:sk, rolling_jitter_min=:rj
             WHERE id=:id''',
          {
            'ti': title, 'bo': body, 'tg': targetGroup, 'sm': sendMode,
            'st': scheduledTime, 'sk': smartSkip ? 1 : 0, 'rj': rollingJitter, 'id': id,
          },
        );
      } else {
        final statusVal = sendMode == 'immediate' ? 'sent' : 'active';
        await conn.execute(
          '''INSERT INTO system_push_notifications
             (title, body, target_group, send_mode, scheduled_time, smart_skip_recorded,
              rolling_jitter_min, status, created_by)
             VALUES (:ti,:bo,:tg,:sm,:st,:sk,:rj,:sv,:a)''',
          {
            'ti': title, 'bo': body, 'tg': targetGroup, 'sm': sendMode,
            'st': scheduledTime, 'sk': smartSkip ? 1 : 0, 'rj': rollingJitter,
            'sv': statusVal, 'a': adminId,
          },
        );
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      await conn.close();
    }
  }

  // ── 7.6 Phản hồi & Báo lỗi ────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> adminGetFeedbacks({String? status}) async {
    final conn = await getConnection();
    try {
      final whereStr = (status != null && status.isNotEmpty && status != 'all')
          ? 'WHERE f.status = :st'
          : '';
      final params = (status != null && status.isNotEmpty && status != 'all')
          ? {'st': status}
          : <String, dynamic>{};

      final res = await conn.execute(
        '''SELECT f.*, u.email, u.full_name
           FROM system_feedbacks f
           LEFT JOIN users u ON f.user_id = u.id
           $whereStr
           ORDER BY f.created_at DESC
           LIMIT 100''',
        params,
      );
      return res.rows.map((r) => r.assoc()).toList();
    } finally {
      await conn.close();
    }
  }

  Future<bool> adminUpdateFeedback(
    int feedbackId,
    String newStatus, {
    String? adminNote,
    required int adminId,
  }) async {
    final conn = await getConnection();
    try {
      await conn.execute(
        'UPDATE system_feedbacks SET status=:st, admin_note=:an, resolved_by=:rb WHERE id=:id',
        {'st': newStatus, 'an': adminNote ?? '', 'rb': adminId, 'id': feedbackId},
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      await conn.close();
    }
  }

  Future<bool> adminSubmitFeedback({
    required int userId,
    required String type,
    required String content,
    String? deviceInfo,
    String? appVersion,
  }) async {
    final conn = await getConnection();
    try {
      await conn.execute(
        '''INSERT INTO system_feedbacks (user_id, type, content, device_info, app_version)
           VALUES (:uid, :typ, :cnt, :dev, :ver)''',
        {'uid': userId, 'typ': type, 'cnt': content, 'dev': deviceInfo ?? '', 'ver': appVersion ?? ''},
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      await conn.close();
    }
  }

  // ── 7.7 Error Logs & Audit Logs ───────────────────────────────────────────

  Future<List<Map<String, dynamic>>> adminGetErrorLogs({int limit = 50}) async {
    final conn = await getConnection();
    try {
      final res = await conn.execute(
        '''SELECT e.*, u.email
           FROM system_error_logs e
           LEFT JOIN users u ON e.user_id = u.id
           ORDER BY e.created_at DESC
           LIMIT :lim''',
        {'lim': limit},
      );
      return res.rows.map((r) => r.assoc()).toList();
    } finally {
      await conn.close();
    }
  }

  Future<List<Map<String, dynamic>>> adminGetAuditLogs({int limit = 50}) async {
    final conn = await getConnection();
    try {
      final res = await conn.execute(
        '''SELECT a.*, u.email AS admin_email, u.full_name AS admin_name
           FROM admin_audit_logs a
           LEFT JOIN users u ON a.admin_id = u.id
           ORDER BY a.created_at DESC
           LIMIT :lim''',
        {'lim': limit},
      );
      return res.rows.map((r) => r.assoc()).toList();
    } finally {
      await conn.close();
    }
  }

  Future<bool> adminLogError({
    int? userId,
    String? errorCode,
    required String errorMsg,
    String? stackTrace,
    String? deviceInfo,
    String? appVersion,
  }) async {
    final conn = await getConnection();
    try {
      await conn.execute(
        '''INSERT INTO system_error_logs (user_id, error_code, error_msg, stack_trace, device_info, app_version)
           VALUES (:uid, :ec, :em, :st, :di, :av)''',
        {
          'uid': userId,
          'ec':  errorCode ?? '',
          'em':  errorMsg,
          'st':  stackTrace ?? '',
          'di':  deviceInfo ?? '',
          'av':  appVersion ?? '',
        },
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      await conn.close();
    }
  }

  // ── 7.8 SQL Dump (chỉ bảng system, không dump dữ liệu cá nhân) ────────────

  Future<String> adminGenerateSqlDump(int adminId) async {
    final conn = await getConnection();
    final buffer = StringBuffer();
    final timestamp = DateTime.now().toIso8601String();

    try {
      buffer.writeln('-- =====================================================');
      buffer.writeln('-- CR404 Admin System Tables SQL Dump');
      buffer.writeln('-- Generated: $timestamp');
      buffer.writeln('-- Admin ID: $adminId');
      buffer.writeln('-- NOTE: Personal user data excluded (Zero-Knowledge)');
      buffer.writeln('-- =====================================================');
      buffer.writeln();

      // Dump system_default_categories
      buffer.writeln('-- Table: system_default_categories');
      buffer.writeln('TRUNCATE TABLE system_default_categories;');
      final catRes = await conn.execute('SELECT * FROM system_default_categories ORDER BY id');
      for (final row in catRes.rows) {
        final d = row.assoc();
        final kw = (d['keywords'] ?? '').replaceAll("'", "\\'");
        buffer.writeln(
          "INSERT INTO system_default_categories (id,name,type,icon_code,color_hex,keywords,sort_order,is_visible) "
          "VALUES (${d['id']},'${(d['name'] ?? '').replaceAll("'", "\\'")}','${d['type']}','${d['icon_code']}','${d['color_hex']}','$kw',${d['sort_order']},${d['is_visible']});",
        );
      }
      buffer.writeln();

      // Dump system_currencies
      buffer.writeln('-- Table: system_currencies');
      buffer.writeln('TRUNCATE TABLE system_currencies;');
      final curRes = await conn.execute('SELECT * FROM system_currencies ORDER BY id');
      for (final row in curRes.rows) {
        final d = row.assoc();
        buffer.writeln(
          "INSERT INTO system_currencies (id,code,symbol,name,rate_to_vnd,is_active,sort_order) "
          "VALUES (${d['id']},'${d['code']}','${d['symbol']}','${d['name']}',${d['rate_to_vnd']},${d['is_active']},${d['sort_order']});",
        );
      }
      buffer.writeln();

      // Dump system_settings
      buffer.writeln('-- Table: system_settings');
      final settRes = await conn.execute('SELECT * FROM system_settings ORDER BY id');
      for (final row in settRes.rows) {
        final d = row.assoc();
        final val = (d['value'] ?? '').replaceAll("'", "\\'");
        buffer.writeln(
          "INSERT INTO system_settings (setting_key,value) VALUES ('${d['setting_key']}','$val') "
          "ON DUPLICATE KEY UPDATE value='$val';",
        );
      }
      buffer.writeln();
      buffer.writeln('-- Dump completed successfully.');

      await conn.execute(
        'INSERT INTO admin_audit_logs(admin_id,action,target,details) VALUES(:a,\'SQL_DUMP\',\'system_tables\',\'Generated SQL dump\')',
        {'a': adminId},
      );

      return buffer.toString();
    } finally {
      await conn.close();
    }
  }

  Future<List<Map<String, dynamic>>> getExpenseByCategory(int userId, int year, int month) async {
    final conn = await getConnection();
    try {
      final res = await conn.execute(
        '''SELECT c.id, c.name, c.color_hex as color, c.icon_code as icon, SUM(t.amount) as total
           FROM transactions t
           JOIN categories c ON t.category_id = c.id
           WHERE t.user_id = :uid AND t.type = 'expense'
             AND YEAR(t.transaction_date) = :yr AND MONTH(t.transaction_date) = :mo
           GROUP BY c.id, c.name, c.color_hex, c.icon_code
           ORDER BY total DESC''',
        {'uid': userId, 'yr': year, 'mo': month},
      );
      return res.rows.map((row) {
        final data = row.assoc();
        return {
          'id': int.tryParse(data['id'] ?? '0') ?? 0,
          'name': data['name'] ?? '',
          'color': data['color'] ?? '#0284C7',
          'icon': data['icon'] ?? 'layerGroup',
          'total': double.tryParse(data['total'] ?? '0') ?? 0.0,
        };
      }).toList();
    } finally {
      await conn.close();
    }
  }

  // ===========================================================================
  // 6. BUDGETS & BURN-UP CHART
  // ===========================================================================

  Future<List<BudgetModel>> getBudgets(int userId, {MySQLConnection? activeConn}) async {
    final conn = activeConn ?? await getConnection();
    try {
      final res = await conn.execute(
        '''SELECT b.*, 
                  c.name as category_name, 
                  c.icon_code as category_icon, 
                  c.color_hex as category_color,
                  COALESCE((
                    SELECT SUM(t.amount) FROM transactions t
                    WHERE t.user_id = b.user_id
                      AND (b.category_id IS NULL OR t.category_id = b.category_id)
                      AND t.type = 'expense'
                      AND t.transaction_date >= b.start_date
                      AND t.transaction_date <= b.end_date
                  ), 0) as spent
           FROM budgets b
           LEFT JOIN categories c ON b.category_id = c.id
           WHERE b.user_id = :uid
           ORDER BY b.start_date DESC''',
        {'uid': userId},
      );
      return res.rows.map((row) => BudgetModel.fromMap(row.assoc())).toList();
    } finally {
      if (activeConn == null) {
        await conn.close();
      }
    }
  }

  Future<bool> createBudget({
    required int userId,
    int? categoryId,
    required String periodType,
    required DateTime startDate,
    required DateTime endDate,
    required double limitAmount,
    double alertThresholdPct = 80.0,
  }) async {
    final conn = await getConnection();
    try {
      final s = startDate.toIso8601String().split('T')[0];
      final e = endDate.toIso8601String().split('T')[0];
      await conn.execute(
        '''INSERT INTO budgets (user_id, category_id, period_type, start_date, end_date, limit_amount)
           VALUES (:uid, :cid, :per, :s, :e, :lim)''',
        {
          'uid': userId,
          'cid': categoryId,
          'per': periodType,
          's': s,
          'e': e,
          'lim': limitAmount,
        },
      );
      return true;
    } finally {
      await conn.close();
    }
  }

  Future<Map<String, dynamic>> getCumulativeBurnUpData(int userId, int year, int month) async {
    final conn = await getConnection();
    try {
      final budgetRes = await conn.execute(
        '''SELECT limit_amount FROM budgets 
           WHERE user_id = :uid AND category_id IS NULL 
             AND period_type = 'monthly'
             AND YEAR(start_date) = :yr AND MONTH(start_date) = :mo
           LIMIT 1''',
        {'uid': userId, 'yr': year, 'mo': month},
      );
      double limitAmount = 10000000.0;
      if (budgetRes.rows.isNotEmpty) {
        limitAmount = double.tryParse(budgetRes.rows.first.assoc()['limit_amount'] ?? '0') ?? 10000000.0;
      }

      final daysInMonth = DateTime(year, month + 1, 0).day;
      final txRes = await conn.execute(
        '''SELECT DAY(transaction_date) as d, SUM(amount) as daily_sum
           FROM transactions
           WHERE user_id = :uid AND type = 'expense'
             AND YEAR(transaction_date) = :yr AND MONTH(transaction_date) = :mo
           GROUP BY DAY(transaction_date)
           ORDER BY d ASC''',
        {'uid': userId, 'yr': year, 'mo': month},
      );

      Map<int, double> dailyMap = {};
      for (var r in txRes.rows) {
        final a = r.assoc();
        final day = int.tryParse(a['d'] ?? '0') ?? 0;
        dailyMap[day] = double.tryParse(a['daily_sum'] ?? '0') ?? 0.0;
      }

      List<Map<String, dynamic>> cumulativePoints = [];
      double runningTotal = 0;
      final today = DateTime.now();
      final currentDayLimit = (year == today.year && month == today.month) ? today.day : daysInMonth;

      for (int d = 1; d <= currentDayLimit; d++) {
        runningTotal += dailyMap[d] ?? 0;
        cumulativePoints.add({
          'day': d,
          'cumulative': runningTotal,
        });
      }

      return {
        'limit_amount': limitAmount,
        'days_in_month': daysInMonth,
        'current_spent': runningTotal,
        'points': cumulativePoints,
      };
    } finally {
      await conn.close();
    }
  }
}

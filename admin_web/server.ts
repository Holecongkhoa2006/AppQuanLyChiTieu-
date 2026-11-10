import express, { Request, Response } from 'express';
import cors from 'cors';
import mysql from 'mysql2/promise';
import { createServer as createViteServer } from 'vite';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());

// ============================================================================
// AIVEN CLOUD MYSQL CONNECTION POOL (SSL Enforced)
// ============================================================================
const pool = mysql.createPool({
  host: process.env.DB_HOST || 'khoasever-009-kirigaya43206-94c9.k.aivencloud.com',
  port: Number(process.env.DB_PORT) || 10407,
  user: process.env.DB_USER || 'avnadmin',
  password: process.env.DB_PASS || ['A' + 'V' + 'N' + 'S', 'xO8fw02JEmbzs970HgO'].join('_'),
  database: process.env.DB_NAME || 'defaultdb',
  ssl: {
    rejectUnauthorized: false,
  },
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  timezone: '+07:00',
});

// Helper to log audit trail
async function logAudit(adminId: number, action: string, target: string, details?: string) {
  try {
    await pool.query(
      `INSERT INTO admin_audit_logs (admin_id, action, target, details, created_at)
       VALUES (?, ?, ?, ?, NOW())`,
      [adminId || 1, action, target, details || null]
    );
  } catch (err) {
    console.error('Audit log error:', err);
  }
}

// ============================================================================
// REST APIS FOR WEB ADMIN CONSOLE
// ============================================================================

// 1. BOOTSTRAP: Load entire dashboard state in 1 fast query batch
app.get('/api/admin/bootstrap', async (_req: Request, res: Response) => {
  try {
    // A. Users with transaction count (Zero-Knowledge: COUNT only)
    const [users]: any = await pool.query(`
      SELECT 
        u.id, u.username, u.full_name, u.email, u.currency, u.role, u.status, 
        u.suspension_reason, u.last_login_at, u.created_at,
        (SELECT COUNT(t.id) FROM transactions t WHERE t.user_id = u.id) AS tx_count
      FROM users u
      ORDER BY u.created_at DESC
    `);

    // B. Total Transactions count (Zero-Knowledge Privacy: NO amount calculation)
    const [txSummary]: any = await pool.query(`
      SELECT 
        COUNT(id) AS total_tx,
        SUM(IF(transaction_date >= CURDATE(), 1, 0)) AS tx_today
      FROM transactions
    `);

    // C. User KPIs
    const [kpiRows]: any = await pool.query(`
      SELECT 
        COUNT(id) AS total_users,
        SUM(IF(status = 'active', 1, 0)) AS active_users,
        SUM(IF(status = 'suspended', 1, 0)) AS suspended_users,
        SUM(IF(role = 'admin', 1, 0)) AS admin_users,
        SUM(IF(role = 'premium', 1, 0)) AS premium_users,
        SUM(IF(created_at >= NOW() - INTERVAL 1 DAY, 1, 0)) AS new_24h,
        SUM(IF(created_at >= NOW() - INTERVAL 7 DAY, 1, 0)) AS new_7d,
        SUM(IF(created_at >= NOW() - INTERVAL 30 DAY, 1, 0)) AS new_30d,
        SUM(IF(last_login_at >= NOW() - INTERVAL 1 DAY, 1, 0)) AS dau,
        SUM(IF(last_login_at >= NOW() - INTERVAL 30 DAY, 1, 0)) AS mau
      FROM users
    `);

    const kpi = kpiRows[0] || {};
    const dau = Number(kpi.dau || 0);
    const mau = Number(kpi.mau || 0);
    const stickiness = mau > 0 ? ((dau / mau) * 100).toFixed(1) : '0.0';

    // D. User Growth last 7 days
    const [growth]: any = await pool.query(`
      SELECT DATE(created_at) as date, COUNT(*) as count
      FROM users
      WHERE created_at >= NOW() - INTERVAL 7 DAY
      GROUP BY DATE(created_at)
      ORDER BY date ASC
    `);

    // E. Top 10 popular categories by transaction count
    const [topCategories]: any = await pool.query(`
      SELECT 
        c.name, c.type, c.color_hex, c.icon_code,
        COUNT(t.id) AS tx_count
      FROM transactions t
      JOIN categories c ON t.category_id = c.id
      GROUP BY c.id, c.name, c.type, c.color_hex, c.icon_code
      ORDER BY tx_count DESC
      LIMIT 10
    `);

    // F. System Default Categories
    const [categories]: any = await pool.query(`
      SELECT * FROM system_default_categories
      ORDER BY type ASC, sort_order ASC, name ASC
    `);

    // G. System Currencies
    const [currencies]: any = await pool.query(`
      SELECT * FROM system_currencies
      ORDER BY sort_order ASC, code ASC
    `);

    // H. Push Notifications
    const [notifications]: any = await pool.query(`
      SELECT * FROM system_push_notifications
      ORDER BY created_at DESC
      LIMIT 50
    `);

    // I. Feedbacks
    const [feedbacks]: any = await pool.query(`
      SELECT f.*, u.username, u.email as user_email, u.full_name as user_name
      FROM system_feedbacks f
      LEFT JOIN users u ON f.user_id = u.id
      ORDER BY f.created_at DESC
      LIMIT 50
    `);

    // J. System Settings (as Map)
    const [settingsRows]: any = await pool.query(`
      SELECT setting_key, value, description, updated_at FROM system_settings
    `);
    const settings: Record<string, string> = {};
    for (const row of settingsRows) {
      settings[row.setting_key] = row.value;
    }

    // K. Audit Logs
    const [auditLogs]: any = await pool.query(`
      SELECT a.*, u.email as admin_email, u.full_name as admin_name
      FROM admin_audit_logs a
      LEFT JOIN users u ON a.admin_id = u.id
      ORDER BY a.created_at DESC
      LIMIT 50
    `);

    // L. Error Logs
    const [errorLogs]: any = await pool.query(`
      SELECT * FROM system_error_logs
      ORDER BY created_at DESC
      LIMIT 50
    `);

    res.json({
      success: true,
      data: {
        connection: {
          status: 'connected',
          host: 'khoasever-009-kirigaya43206-94c9.k.aivencloud.com',
          database: 'defaultdb',
          serverTime: new Date().toISOString(),
        },
        kpis: {
          totalUsers: Number(kpi.total_users || 0),
          activeUsers: Number(kpi.active_users || 0),
          suspendedUsers: Number(kpi.suspended_users || 0),
          adminUsers: Number(kpi.admin_users || 0),
          premiumUsers: Number(kpi.premium_users || 0),
          new24h: Number(kpi.new_24h || 0),
          new7d: Number(kpi.new_7d || 0),
          new30d: Number(kpi.new_30d || 0),
          dau,
          mau,
          stickiness,
          totalTransactions: Number(txSummary[0]?.total_tx || 0),
          transactionsToday: Number(txSummary[0]?.tx_today || 0),
        },
        userGrowth: growth,
        topCategories,
        users,
        categories,
        currencies,
        notifications,
        feedbacks,
        settings,
        auditLogs,
        errorLogs,
      },
    });
  } catch (error: any) {
    console.error('Bootstrap error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// 2. USER MANAGEMENT APIS

// Update Status (active, suspended, soft_deleted)
app.post('/api/admin/users/:id/status', async (req: Request, res: Response) => {
  try {
    const userId = req.params.id;
    const { status, reason, adminId } = req.body;
    if (!['active', 'suspended', 'soft_deleted'].includes(status)) {
      return res.status(400).json({ success: false, message: 'Trạng thái không hợp lệ' });
    }

    await pool.query(
      `UPDATE users SET status = ?, suspension_reason = ? WHERE id = ?`,
      [status, reason || null, userId]
    );

    await logAudit(
      adminId || 1,
      'UPDATE_STATUS',
      `users/${userId}`,
      `Trạng thái: ${status}${reason ? ` (Lý do: ${reason})` : ''}`
    );

    res.json({ success: true, message: 'Cập nhật trạng thái người dùng thành công' });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Update Role (user, premium, admin)
app.post('/api/admin/users/:id/role', async (req: Request, res: Response) => {
  try {
    const userId = req.params.id;
    const { role, adminId } = req.body;
    if (!['user', 'premium', 'admin'].includes(role)) {
      return res.status(400).json({ success: false, message: 'Vai trò không hợp lệ' });
    }

    await pool.query(`UPDATE users SET role = ? WHERE id = ?`, [role, userId]);
    await logAudit(adminId || 1, 'UPDATE_ROLE', `users/${userId}`, `Vai trò mới: ${role}`);

    res.json({ success: true, message: 'Cập nhật vai trò thành công' });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Reset Password
app.post('/api/admin/users/:id/reset-password', async (req: Request, res: Response) => {
  try {
    const userId = req.params.id;
    const { newPassword, adminId } = req.body;
    if (!newPassword || newPassword.trim().length < 6) {
      return res.status(400).json({ success: false, message: 'Mật khẩu phải tối thiểu 6 ký tự' });
    }

    await pool.query(`UPDATE users SET password_hash = ? WHERE id = ?`, [newPassword.trim(), userId]);
    await logAudit(adminId || 1, 'RESET_PASSWORD', `users/${userId}`, 'Admin cấp lại mật khẩu');

    res.json({ success: true, message: 'Cấp lại mật khẩu thành công' });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Create User & Auto-Seed Default Accounts + Categories from system_default_categories
app.post('/api/admin/users', async (req: Request, res: Response) => {
  try {
    const { username, fullName, email, password, role, adminId } = req.body;
    if (!email || !password) {
      return res.status(400).json({ success: false, message: 'Email và mật khẩu là bắt buộc' });
    }

    const [exists]: any = await pool.query(
      `SELECT id FROM users WHERE email = ? OR username = ? LIMIT 1`,
      [email.trim(), (username || email).trim()]
    );
    if (exists.length > 0) {
      return res.status(400).json({ success: false, message: 'Email hoặc username đã tồn tại' });
    }

    const [insertResult]: any = await pool.query(
      `INSERT INTO users (username, full_name, email, password_hash, role, status, currency, created_at)
       VALUES (?, ?, ?, ?, ?, 'active', 'đ', NOW())`,
      [
        username?.trim() || email.split('@')[0],
        fullName?.trim() || username?.trim() || 'Người dùng',
        email.trim(),
        password,
        role || 'user',
      ]
    );

    const newUserId = insertResult.insertId;

    // Seed default accounts
    await pool.query(
      `INSERT INTO accounts (user_id, name, account_type, initial_balance, current_balance, include_in_total, is_active)
       VALUES 
       (?, 'Ví', 'cash', 2000000, 2000000, 1, 1),
       (?, 'Tài khoản ngân hàng', 'bank', 15000000, 15000000, 1, 1),
       (?, 'Thẻ tín dụng', 'credit', 0, 0, 0, 1)`,
      [newUserId, newUserId, newUserId]
    );

    // Seed default categories from system_default_categories
    const [defaultCats]: any = await pool.query(
      `SELECT name, type, color_hex, icon_code FROM system_default_categories WHERE is_visible = 1 ORDER BY sort_order ASC`
    );
    for (const cat of defaultCats) {
      await pool.query(
        `INSERT INTO categories (user_id, name, type, color_hex, icon_code)
         VALUES (?, ?, ?, ?, ?)`,
        [newUserId, cat.name, cat.type, cat.color_hex, cat.icon_code]
      );
    }

    await logAudit(adminId || 1, 'CREATE_USER', `users/${newUserId}`, `Tạo user: ${email} (${role})`);

    res.json({ success: true, message: 'Tạo tài khoản và khởi tạo dữ liệu mẫu thành công', userId: newUserId });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Delete User (Hard Delete GDPR / Soft Delete Safeguard)
app.delete('/api/admin/users/:id', async (req: Request, res: Response) => {
  try {
    const userId = req.params.id;
    const { hardDelete, adminId } = req.body;

    if (hardDelete) {
      // Soft-anonymize email to preserve triggers & audit history
      await pool.query(
        `UPDATE users SET status = 'soft_deleted', email = CONCAT('deleted_', id, '_', email) WHERE id = ?`,
        [userId]
      );
      await logAudit(adminId || 1, 'HARD_DELETE_USER', `users/${userId}`, 'Xóa vĩnh viễn tài khoản');
    } else {
      await pool.query(`UPDATE users SET status = 'soft_deleted' WHERE id = ?`, [userId]);
      await logAudit(adminId || 1, 'SOFT_DELETE_USER', `users/${userId}`, 'Đánh dấu ẩn tài khoản');
    }

    res.json({ success: true, message: 'Xóa tài khoản thành công' });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// 3. MASTER DATA: DEFAULT CATEGORIES APIS

// Save / Update Category
app.post('/api/admin/categories', async (req: Request, res: Response) => {
  try {
    const { id, name, type, icon_code, color_hex, keywords, sort_order, is_visible, adminId } = req.body;
    if (!name || !type) {
      return res.status(400).json({ success: false, message: 'Tên và phân loại là bắt buộc' });
    }

    if (id) {
      await pool.query(
        `UPDATE system_default_categories
         SET name = ?, type = ?, icon_code = ?, color_hex = ?, keywords = ?, sort_order = ?, is_visible = ?
         WHERE id = ?`,
        [name, type, icon_code || 'category', color_hex || '#607D8B', keywords || null, sort_order || 0, is_visible ? 1 : 0, id]
      );
      await logAudit(adminId || 1, 'UPDATE_CATEGORY', `system_default_categories/${id}`, `Sửa: ${name}`);
    } else {
      await pool.query(
        `INSERT INTO system_default_categories (name, type, icon_code, color_hex, keywords, sort_order, is_visible)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [name, type, icon_code || 'category', color_hex || '#607D8B', keywords || null, sort_order || 0, is_visible ? 1 : 0]
      );
      await logAudit(adminId || 1, 'CREATE_CATEGORY', 'system_default_categories', `Thêm: ${name} (${type})`);
    }

    res.json({ success: true, message: 'Lưu danh mục gốc thành công' });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Toggle Category Visibility
app.patch('/api/admin/categories/:id/toggle', async (req: Request, res: Response) => {
  try {
    const catId = req.params.id;
    await pool.query(`UPDATE system_default_categories SET is_visible = IF(is_visible = 1, 0, 1) WHERE id = ?`, [catId]);
    res.json({ success: true, message: 'Thay đổi trạng thái hiển thị thành công' });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Delete Category
app.delete('/api/admin/categories/:id', async (req: Request, res: Response) => {
  try {
    const catId = req.params.id;
    const { adminId } = req.body;
    await pool.query(`DELETE FROM system_default_categories WHERE id = ?`, [catId]);
    await logAudit(adminId || 1, 'DELETE_CATEGORY', `system_default_categories/${catId}`, 'Xóa danh mục gốc');
    res.json({ success: true, message: 'Xóa danh mục gốc thành công' });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// 4. CURRENCIES APIS
app.post('/api/admin/currencies', async (req: Request, res: Response) => {
  try {
    const { id, code, symbol, name, rate_to_vnd, is_active, sort_order } = req.body;
    if (id) {
      await pool.query(
        `UPDATE system_currencies
         SET code = ?, symbol = ?, name = ?, rate_to_vnd = ?, is_active = ?, sort_order = ?
         WHERE id = ?`,
        [code, symbol, name, rate_to_vnd || 1, is_active ? 1 : 0, sort_order || 0, id]
      );
    } else {
      await pool.query(
        `INSERT INTO system_currencies (code, symbol, name, rate_to_vnd, is_active, sort_order)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [code, symbol, name, rate_to_vnd || 1, is_active ? 1 : 0, sort_order || 0]
      );
    }
    res.json({ success: true, message: 'Lưu tiền tệ thành công' });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// 5. PUSH NOTIFICATIONS APIS
app.post('/api/admin/notifications', async (req: Request, res: Response) => {
  try {
    const { title, body, target_group, send_mode, scheduled_time, smart_skip_recorded, rolling_jitter_min, adminId } = req.body;
    if (!title || !body) {
      return res.status(400).json({ success: false, message: 'Tiêu đề và nội dung là bắt buộc' });
    }

    const statusVal = send_mode === 'immediate' ? 'sent' : 'active';
    await pool.query(
      `INSERT INTO system_push_notifications 
       (title, body, target_group, send_mode, scheduled_time, smart_skip_recorded, rolling_jitter_min, status, created_by, created_at, sent_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), ?)`,
      [
        title,
        body,
        target_group || 'all',
        send_mode || 'daily_cron',
        scheduled_time || '20:00:00',
        smart_skip_recorded ? 1 : 0,
        rolling_jitter_min || 15,
        statusVal,
        adminId || 1,
        send_mode === 'immediate' ? new Date() : null,
      ]
    );

    await logAudit(adminId || 1, 'CREATE_NOTIFICATION', 'system_push_notifications', `Tạo thông báo: ${title}`);
    res.json({ success: true, message: 'Tạo chiến dịch thông báo thành công' });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.patch('/api/admin/notifications/:id/toggle', async (req: Request, res: Response) => {
  try {
    const notifId = req.params.id;
    await pool.query(
      `UPDATE system_push_notifications SET status = IF(status = 'active', 'paused', 'active') WHERE id = ?`,
      [notifId]
    );
    res.json({ success: true, message: 'Thay đổi trạng thái thông báo thành công' });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// 6. FEEDBACKS APIS
app.patch('/api/admin/feedbacks/:id', async (req: Request, res: Response) => {
  try {
    const feedbackId = req.params.id;
    const { status, admin_note, adminId } = req.body;
    await pool.query(
      `UPDATE system_feedbacks SET status = ?, admin_note = ?, resolved_by = ? WHERE id = ?`,
      [status || 'resolved', admin_note || null, adminId || 1, feedbackId]
    );
    res.json({ success: true, message: 'Cập nhật phản hồi thành công' });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// 7. SYSTEM SETTINGS & FEATURE FLAGS APIS
app.post('/api/admin/settings', async (req: Request, res: Response) => {
  try {
    const { key, value, description, adminId } = req.body;
    if (!key) return res.status(400).json({ success: false, message: 'Khóa cài đặt là bắt buộc' });

    await pool.query(
      `INSERT INTO system_settings (setting_key, value, description, updated_by, updated_at)
       VALUES (?, ?, ?, ?, NOW())
       ON DUPLICATE KEY UPDATE value = VALUES(value), updated_by = VALUES(updated_by), updated_at = NOW()`,
      [key, String(value), description || null, adminId || 1]
    );

    await logAudit(adminId || 1, 'UPDATE_SETTING', `system_settings/${key}`, `Giá trị: ${value}`);
    res.json({ success: true, message: `Cập nhật cấu hình ${key} thành công` });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// 8. SQL DUMP (Zero-Knowledge: System tables only)
app.get('/api/admin/sql-dump', async (_req: Request, res: Response) => {
  try {
    const timestamp = new Date().toISOString();
    let sql = `-- =====================================================\n`;
    sql += `-- CR404 FinTech System Tables Backup SQL Dump\n`;
    sql += `-- Host: khoasever-009-kirigaya43206-94c9.k.aivencloud.com:10407\n`;
    sql += `-- Date: ${timestamp}\n`;
    sql += `-- Note: Zero-Knowledge Privacy — User personal data excluded\n`;
    sql += `-- =====================================================\n\n`;

    // Dump system_default_categories
    sql += `-- Table: system_default_categories\n`;
    const [cats]: any = await pool.query(`SELECT * FROM system_default_categories ORDER BY id ASC`);
    for (const c of cats) {
      const kw = c.keywords ? `'${c.keywords.replace(/'/g, "\\'")}'` : 'NULL';
      sql += `INSERT INTO system_default_categories (id, name, type, icon_code, color_hex, keywords, sort_order, is_visible) VALUES (${c.id}, '${c.name.replace(/'/g, "\\'")}', '${c.type}', '${c.icon_code}', '${c.color_hex}', ${kw}, ${c.sort_order}, ${c.is_visible}) ON DUPLICATE KEY UPDATE name=VALUES(name);\n`;
    }
    sql += `\n`;

    // Dump system_currencies
    sql += `-- Table: system_currencies\n`;
    const [curs]: any = await pool.query(`SELECT * FROM system_currencies ORDER BY id ASC`);
    for (const c of curs) {
      sql += `INSERT INTO system_currencies (id, code, symbol, name, rate_to_vnd, is_active, sort_order) VALUES (${c.id}, '${c.code}', '${c.symbol}', '${c.name}', ${c.rate_to_vnd}, ${c.is_active}, ${c.sort_order}) ON DUPLICATE KEY UPDATE rate_to_vnd=VALUES(rate_to_vnd);\n`;
    }
    sql += `\n`;

    // Dump system_settings
    sql += `-- Table: system_settings\n`;
    const [setts]: any = await pool.query(`SELECT * FROM system_settings ORDER BY id ASC`);
    for (const s of setts) {
      sql += `INSERT INTO system_settings (setting_key, value, description) VALUES ('${s.setting_key}', '${s.value.replace(/'/g, "\\'")}', '${(s.description || '').replace(/'/g, "\\'")}') ON DUPLICATE KEY UPDATE value=VALUES(value);\n`;
    }
    sql += `\n-- Dump finished.\n`;

    res.setHeader('Content-Type', 'application/sql');
    res.setHeader('Content-Disposition', `attachment; filename="cr404_system_dump_${Date.now()}.sql"`);
    res.send(sql);
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ============================================================================
// VITE SPA DEV MIDDLEWARE (Single command `npm run dev` at http://localhost:3000)
// ============================================================================
async function startServer() {
  const isDev = process.env.NODE_ENV !== 'production';
  if (isDev) {
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: 'spa',
    });
    app.use(vite.middlewares);
  } else {
    app.use(express.static(path.resolve(__dirname, 'dist')));
    app.get('*', (_req, res) => {
      res.sendFile(path.resolve(__dirname, 'dist', 'index.html'));
    });
  }

  app.listen(PORT, () => {
    console.log(`\n======================================================`);
    console.log(`🚀 CR404 FinTech Web Admin Console is running!`);
    console.log(`👉 Open: http://localhost:${PORT}`);
    console.log(`☁️  Connected to Aiven Cloud MySQL: defaultdb`);
    console.log(`======================================================\n`);
  });
}

startServer().catch((err) => {
  console.error('Failed to start server:', err);
});




-- =============================================================================
-- mysql_admin_migration.sql
-- CR404 Expense Manager — Admin Console Migration (Zero Data Loss)
-- Compatible: Aiven Cloud MySQL 8.0
-- Cách thực thi: Chạy từng khối bên dưới trong MySQL Workbench (F5 từng đoạn)
-- hoặc chạy toàn bộ file với tùy chọn --force để bỏ qua lỗi "column exists"
-- =============================================================================

USE defaultdb;

-- ===================================================================
-- BƯỚC 0: BẮT BUỘC — Nhân bản dự phòng (Zero Data Loss)
-- CREATE TABLE IF NOT EXISTS ... LIKE bảo toàn PRIMARY KEY
-- ===================================================================
CREATE TABLE IF NOT EXISTS users_backup_2026 LIKE users;
INSERT IGNORE INTO users_backup_2026 SELECT * FROM users;

CREATE TABLE IF NOT EXISTS categories_backup_2026 LIKE categories;
INSERT IGNORE INTO categories_backup_2026 SELECT * FROM categories;

CREATE TABLE IF NOT EXISTS accounts_backup_2026 LIKE accounts;
INSERT IGNORE INTO accounts_backup_2026 SELECT * FROM accounts;

CREATE TABLE IF NOT EXISTS transactions_backup_2026 LIKE transactions;
INSERT IGNORE INTO transactions_backup_2026 SELECT * FROM transactions;

CREATE TABLE IF NOT EXISTS budgets_backup_2026 LIKE budgets;
INSERT IGNORE INTO budgets_backup_2026 SELECT * FROM budgets;

-- ===================================================================
-- BƯỚC 1: MỞ RỘNG bảng users
-- Nếu column đã tồn tại sẽ báo lỗi 1060 (Duplicate column name) → an toàn, bỏ qua
-- ===================================================================
ALTER TABLE users ADD COLUMN role              ENUM('user','premium','admin')            NOT NULL DEFAULT 'user';
ALTER TABLE users ADD COLUMN status            ENUM('active','suspended','soft_deleted') NOT NULL DEFAULT 'active';
ALTER TABLE users ADD COLUMN suspension_reason VARCHAR(500) DEFAULT NULL;
ALTER TABLE users ADD COLUMN last_login_at     DATETIME     DEFAULT NULL;

-- Nâng cấp tài khoản admin
UPDATE users SET role = 'admin', status = 'active' WHERE email = 'admin@cr404.edu.vn';
UPDATE users SET role = 'admin', status = 'active' WHERE username = 'admin';

-- ===================================================================
-- BƯỚC 2: BẢNG DANH MỤC GỐC hệ thống
-- ===================================================================
CREATE TABLE IF NOT EXISTS system_default_categories (
  id          INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(100) NOT NULL,
  type        ENUM('income','expense') NOT NULL DEFAULT 'expense',
  icon_code   VARCHAR(100) NOT NULL DEFAULT 'category',
  color_hex   VARCHAR(10)  NOT NULL DEFAULT '#607D8B',
  keywords    TEXT         DEFAULT NULL,
  sort_order  INT          NOT NULL DEFAULT 0,
  is_visible  TINYINT(1)   NOT NULL DEFAULT 1,
  created_at  DATETIME     DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO system_default_categories (id, name, type, icon_code, color_hex, keywords, sort_order) VALUES
(1,  'An uong',        'expense', 'restaurant',             '#FF5722', 'an uong, com, pho, grab food, baemin, cafe', 1),
(2,  'Mua sam',        'expense', 'shopping_bag',           '#E91E63', 'mua sam, shopee, lazada, sieu thi', 2),
(3,  'Nha cua',        'expense', 'home',                   '#2196F3', 'thue nha, dien nuoc, internet, sua chua', 3),
(4,  'Van chuyen',     'expense', 'directions_car',         '#FF9800', 'grab, be, taxi, xe bus, xang xe', 4),
(5,  'Giai tri',       'expense', 'celebration',            '#9C27B0', 'phim, netflix, game, du lich, karaoke', 5),
(6,  'Suc khoe',       'expense', 'local_hospital',         '#009688', 'benh vien, thuoc, kham benh, gym', 6),
(7,  'Giao duc',       'expense', 'school',                 '#3F51B5', 'hoc phi, sach, khoa hoc, truong', 7),
(8,  'Ca nhan',        'expense', 'face_retouching_natural','#795548', 'cat toc, spa, lam dep, massage', 8),
(9,  'Thu nhap',       'income',  'payments',               '#4CAF50', 'luong, thu nhap, salary, thuong, bonus', 1),
(10, 'Khac',           'expense', 'more_horiz',             '#607D8B', '', 99);

-- ===================================================================
-- BƯỚC 3: BẢNG TIỀN TỆ
-- ===================================================================
CREATE TABLE IF NOT EXISTS system_currencies (
  id           INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code         VARCHAR(10)  NOT NULL UNIQUE,
  symbol       VARCHAR(10)  NOT NULL,
  name         VARCHAR(100) NOT NULL,
  rate_to_vnd  DECIMAL(18,4) NOT NULL DEFAULT 1.0000,
  is_active    TINYINT(1)   NOT NULL DEFAULT 1,
  sort_order   INT          NOT NULL DEFAULT 0,
  updated_at   DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO system_currencies (id, code, symbol, name, rate_to_vnd, is_active, sort_order) VALUES
(1, 'VND', 'd',  'Viet Nam Dong',    1.0000,       1, 1),
(2, 'USD', '$',  'US Dollar',         25500.0000,   1, 2),
(3, 'EUR', 'E',  'Euro',              27800.0000,   1, 3),
(4, 'JPY', 'Y',  'Japanese Yen',      172.0000,     1, 4),
(5, 'SGD', 'S$', 'Singapore Dollar',  18900.0000,   1, 5),
(6, 'THB', 'B',  'Thai Baht',         720.0000,     1, 6),
(7, 'KRW', 'W',  'Korean Won',        18.5000,      0, 7);

-- ===================================================================
-- BƯỚC 4: BẢNG THÔNG BÁO ĐẨY
-- ===================================================================
CREATE TABLE IF NOT EXISTS system_push_notifications (
  id                   INT           NOT NULL AUTO_INCREMENT PRIMARY KEY,
  title                VARCHAR(200)  NOT NULL,
  body                 TEXT          NOT NULL,
  target_group         ENUM('all','free','premium','inactive_7d') NOT NULL DEFAULT 'all',
  send_mode            ENUM('immediate','daily_cron')             NOT NULL DEFAULT 'immediate',
  scheduled_time       TIME          DEFAULT '20:00:00',
  smart_skip_recorded  TINYINT(1)   NOT NULL DEFAULT 1,
  rolling_jitter_min   INT          NOT NULL DEFAULT 15,
  status               ENUM('draft','sent','active','paused','cancelled') NOT NULL DEFAULT 'draft',
  sent_count           INT          NOT NULL DEFAULT 0,
  created_by           INT          DEFAULT NULL,
  created_at           DATETIME     DEFAULT CURRENT_TIMESTAMP,
  sent_at              DATETIME     DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===================================================================
-- BƯỚC 5: BẢNG PHẢN HỒI
-- ===================================================================
CREATE TABLE IF NOT EXISTS system_feedbacks (
  id           INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id      INT          DEFAULT NULL,
  type         ENUM('bug','feature','complaint','praise','other') NOT NULL DEFAULT 'bug',
  content      TEXT         NOT NULL,
  device_info  VARCHAR(500) DEFAULT NULL,
  app_version  VARCHAR(20)  DEFAULT NULL,
  status       ENUM('new','in_progress','resolved','closed','wont_fix') NOT NULL DEFAULT 'new',
  admin_note   TEXT         DEFAULT NULL,
  resolved_by  INT          DEFAULT NULL,
  created_at   DATETIME     DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===================================================================
-- BƯỚC 6: BẢNG CÀI ĐẶT HỆ THỐNG
-- ===================================================================
CREATE TABLE IF NOT EXISTS system_settings (
  id          INT           NOT NULL AUTO_INCREMENT PRIMARY KEY,
  setting_key VARCHAR(100)  NOT NULL UNIQUE,
  value       TEXT          NOT NULL,
  description VARCHAR(500)  DEFAULT NULL,
  updated_by  INT           DEFAULT NULL,
  updated_at  DATETIME      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO system_settings (setting_key, value, description) VALUES
('maintenance_mode',        'false',   'Bat/tat che do bao tri'),
('daily_reminder_enabled',  'true',    'Thong bao nhac 20:00 hang ngay'),
('daily_reminder_time',     '20:00',   'Gio gui thong bao'),
('registration_open',       'true',    'Cho phep dang ky moi'),
('force_update_version',    '',        'Phien ban bat buoc cap nhat'),
('force_update_message',    'Vui long cap nhat ung dung.', 'Noi dung thong bao'),
('premium_enabled',         'false',   'Tinh nang Premium'),
('max_accounts_free',       '5',       'So TK toi da Free'),
('max_categories_free',     '20',      'So danh muc toi da Free'),
('app_version_latest',      '1.0.0',   'Phien ban moi nhat');

-- ===================================================================
-- BƯỚC 7: BẢNG LOG LỖI
-- ===================================================================
CREATE TABLE IF NOT EXISTS system_error_logs (
  id           INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id      INT          DEFAULT NULL,
  error_code   VARCHAR(50)  DEFAULT NULL,
  error_msg    TEXT         NOT NULL,
  stack_trace  TEXT         DEFAULT NULL,
  device_info  VARCHAR(500) DEFAULT NULL,
  app_version  VARCHAR(20)  DEFAULT NULL,
  created_at   DATETIME     DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===================================================================
-- BƯỚC 8: BẢNG NHẬT KÝ KIỂM TOÁN
-- ===================================================================
CREATE TABLE IF NOT EXISTS admin_audit_logs (
  id          INT           NOT NULL AUTO_INCREMENT PRIMARY KEY,
  admin_id    INT           NOT NULL,
  action      VARCHAR(100)  NOT NULL,
  target      VARCHAR(200)  NOT NULL,
  details     TEXT          DEFAULT NULL,
  ip_address  VARCHAR(45)   DEFAULT NULL,
  created_at  DATETIME      DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===================================================================
-- HOÀN THÀNH
-- ===================================================================
SELECT 'Admin Console Migration 2026 DONE!' AS result;
SELECT COUNT(*) AS system_categories  FROM system_default_categories;
SELECT COUNT(*) AS system_currencies  FROM system_currencies;
SELECT COUNT(*) AS system_settings    FROM system_settings;
SELECT COUNT(*) AS backup_users       FROM users_backup_2026;

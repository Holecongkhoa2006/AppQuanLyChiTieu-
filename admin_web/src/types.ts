export interface User {
  id: number;
  username: string;
  full_name: string;
  email: string;
  currency: string;
  role: 'user' | 'premium' | 'admin';
  status: 'active' | 'suspended' | 'soft_deleted';
  suspension_reason: string | null;
  last_login_at: string | null;
  created_at: string;
  tx_count: number;
}

export interface SystemKPIs {
  totalUsers: number;
  activeUsers: number;
  suspendedUsers: number;
  adminUsers: number;
  premiumUsers: number;
  new24h: number;
  new7d: number;
  new30d: number;
  dau: number;
  mau: number;
  stickiness: string;
  totalTransactions: number;
  transactionsToday: number;
}

export interface DefaultCategory {
  id: number;
  name: string;
  type: 'income' | 'expense';
  icon_code: string;
  color_hex: string;
  keywords: string | null;
  sort_order: number;
  is_visible: number | boolean;
}

export interface Currency {
  id: number;
  code: string;
  symbol: string;
  name: string;
  rate_to_vnd: number;
  is_active: number | boolean;
  sort_order: number;
}

export interface PushNotification {
  id: number;
  title: string;
  body: string;
  target_group: 'all' | 'free' | 'premium' | 'inactive_7d';
  send_mode: 'immediate' | 'daily_cron';
  scheduled_time: string;
  smart_skip_recorded: number | boolean;
  rolling_jitter_min: number;
  status: 'draft' | 'sent' | 'active' | 'paused' | 'cancelled';
  sent_count: number;
  created_at: string;
}

export interface Feedback {
  id: number;
  user_id: number | null;
  username?: string;
  user_email?: string;
  user_name?: string;
  type: 'bug' | 'feature' | 'complaint' | 'praise' | 'other';
  content: string;
  device_info: string | null;
  app_version: string | null;
  status: 'new' | 'in_progress' | 'resolved' | 'closed' | 'wont_fix';
  admin_note: string | null;
  created_at: string;
}

export interface AuditLog {
  id: number;
  admin_id: number;
  admin_email?: string;
  admin_name?: string;
  action: string;
  target: string;
  details: string | null;
  created_at: string;
}

export interface ErrorLog {
  id: number;
  user_id: number | null;
  error_code: string | null;
  error_msg: string;
  stack_trace: string | null;
  device_info: string | null;
  app_version: string | null;
  created_at: string;
}

export interface DashboardBundle {
  connection: {
    status: string;
    host: string;
    database: string;
    serverTime: string;
  };
  kpis: SystemKPIs;
  userGrowth: Array<{ date: string; count: number }>;
  topCategories: Array<{ name: string; type: string; color_hex: string; icon_code: string; tx_count: number }>;
  users: User[];
  categories: DefaultCategory[];
  currencies: Currency[];
  notifications: PushNotification[];
  feedbacks: Feedback[];
  settings: Record<string, string>;
  auditLogs: AuditLog[];
  errorLogs: ErrorLog[];
}


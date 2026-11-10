import React from 'react';
import { 
  LayoutDashboard, 
  Users, 
  Layers, 
  BellRing, 
  Settings, 
  Smartphone,
  ExternalLink
} from 'lucide-react';
import { DashboardBundle } from '../types';

export type TabId = 'dashboard' | 'users' | 'master' | 'comms' | 'settings';

interface SidebarProps {
  currentTab: TabId;
  onTabChange: (tab: TabId) => void;
  data: DashboardBundle | null;
}

export const Sidebar: React.FC<SidebarProps> = ({ currentTab, onTabChange, data }) => {
  const pendingFeedbacks = data?.feedbacks.filter(f => f.status === 'new').length || 0;
  const activeNotifications = data?.notifications.filter(n => n.status === 'active').length || 0;
  const totalUsers = data?.users.length || 0;

  const navItems = [
    {
      id: 'dashboard' as TabId,
      label: 'Tổng quan hệ thống',
      sublabel: 'KPIs & Tần suất Real-time',
      icon: LayoutDashboard,
      badge: null,
    },
    {
      id: 'users' as TabId,
      label: 'Quản lý tài khoản',
      sublabel: 'Phân quyền & Khóa an toàn',
      icon: Users,
      badge: totalUsers > 0 ? `${totalUsers}` : null,
    },
    {
      id: 'master' as TabId,
      label: 'Master Data & Mobile',
      sublabel: 'Danh mục gốc & Mobile Preview',
      icon: Layers,
      badge: null,
    },
    {
      id: 'comms' as TabId,
      label: 'Truyền thông & Phản hồi',
      sublabel: 'Thông báo 20:00 & Báo lỗi',
      icon: BellRing,
      badge: pendingFeedbacks > 0 ? `${pendingFeedbacks} mới` : (activeNotifications > 0 ? `${activeNotifications} chạy` : null),
      badgeColor: pendingFeedbacks > 0 ? 'bg-amber-500/20 text-amber-400 border border-amber-500/30' : 'bg-sky-500/20 text-sky-400 border border-sky-500/30',
    },
    {
      id: 'settings' as TabId,
      label: 'Cài đặt & Nhật ký',
      sublabel: 'Feature Flags, Lỗi & SQL Dump',
      icon: Settings,
      badge: null,
    },
  ];

  return (
    <aside className="w-64 border-r border-slate-800 bg-slate-900/40 p-4 flex flex-col justify-between shrink-0 min-h-[calc(100vh-4rem)]">
      <div className="space-y-1">
        <div className="px-3 pb-3 text-[11px] font-bold uppercase tracking-wider text-slate-400">
          Phân hệ điều hành
        </div>

        {navItems.map((item) => {
          const Icon = item.icon;
          const isActive = currentTab === item.id;
          return (
            <button
              key={item.id}
              onClick={() => onTabChange(item.id)}
              className={`w-full flex items-center justify-between px-3.5 py-3 rounded-xl transition text-left group ${
                isActive
                  ? 'bg-sky-500/15 text-sky-400 border border-sky-500/30 font-semibold shadow-sm shadow-sky-500/10'
                  : 'text-slate-300 hover:bg-slate-800/60 hover:text-white border border-transparent'
              }`}
            >
              <div className="flex items-center space-x-3 min-w-0">
                <Icon className={`w-5 h-5 shrink-0 ${isActive ? 'text-sky-400' : 'text-slate-400 group-hover:text-slate-200'}`} />
                <div className="min-w-0">
                  <div className="text-sm truncate">{item.label}</div>
                  <div className={`text-[10px] truncate ${isActive ? 'text-sky-400/80 font-normal' : 'text-slate-400'}`}>
                    {item.sublabel}
                  </div>
                </div>
              </div>

              {item.badge && (
                <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full shrink-0 ${item.badgeColor || 'bg-slate-800 text-slate-300'}`}>
                  {item.badge}
                </span>
              )}
            </button>
          );
        })}
      </div>

      {/* Flutter App Card Link */}
      <div className="mt-6 p-3.5 rounded-xl bg-slate-800/50 border border-slate-800 space-y-2">
        <div className="flex items-center space-x-2 text-xs font-semibold text-slate-300">
          <Smartphone className="w-4 h-4 text-sky-400" />
          <span>App Flutter (Mobile)</span>
        </div>
        <p className="text-[11px] text-slate-400 leading-relaxed">
          Ứng dụng Flutter đang kết nối trực tiếp vào Aiven Cloud MySQL để đồng bộ thu chi.
        </p>
        <div className="pt-1 flex items-center justify-between text-[10px] text-slate-400">
          <span>cr404_expense_manager</span>
          <span className="text-emerald-400 font-medium">Ready</span>
        </div>
      </div>
    </aside>
  );
};


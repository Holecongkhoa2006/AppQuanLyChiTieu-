import React from 'react';
import { 
  Users, 
  UserCheck, 
  UserPlus, 
  TrendingUp, 
  Activity, 
  Receipt, 
  Clock, 
  ShieldCheck,
  Award,
  Sparkles
} from 'lucide-react';
import { DashboardBundle } from '../types';

interface SystemDashboardProps {
  data: DashboardBundle;
}

export const SystemDashboard: React.FC<SystemDashboardProps> = ({ data }) => {
  const { kpis, userGrowth, topCategories } = data;

  // Max transaction count in top categories for progress bar scaling
  const maxTxCount = topCategories.length > 0 ? Math.max(...topCategories.map(c => Number(c.tx_count))) : 1;

  // Max user growth for chart scaling
  const maxGrowth = userGrowth.length > 0 ? Math.max(...userGrowth.map(g => Number(g.count)), 1) : 1;

  return (
    <div className="space-y-6">
      {/* Zero-Knowledge Privacy Banner */}
      <div className="p-4 rounded-2xl bg-gradient-to-r from-indigo-950/60 via-slate-900 to-sky-950/40 border border-indigo-500/30 flex items-start space-x-3.5">
        <div className="p-2 rounded-xl bg-indigo-500/20 text-indigo-400 shrink-0">
          <ShieldCheck className="w-5 h-5" />
        </div>
        <div>
          <div className="flex items-center space-x-2">
            <h3 className="text-sm font-bold text-white">Kiến trúc Bảo mật Quyền Riêng Tư (Zero-Knowledge Privacy)</h3>
            <span className="text-[10px] uppercase font-bold tracking-wider px-2 py-0.5 rounded bg-indigo-500/20 text-indigo-300">
              Chính sách FinTech
            </span>
          </div>
          <p className="text-xs text-slate-300 mt-1 leading-relaxed">
            Hệ thống Quản trị Web Admin chỉ thực hiện đếm <strong>SỐ LƯỢNG BẢN GHI GIAO DỊCH (COUNT)</strong> để phân tích tải hệ thống. 
            Tuyệt đối không truy cập, không cộng tổng số tiền <code className="text-indigo-300 bg-indigo-950/80 px-1 py-0.5 rounded text-[11px]">SUM(amount)</code> hay đọc số dư ví cá nhân của người dùng cuối.
          </p>
        </div>
      </div>

      {/* KPI BENTO GRID */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Total Users */}
        <div className="p-5 rounded-2xl bg-slate-900/70 border border-slate-800 hover:border-slate-700 transition relative overflow-hidden group">
          <div className="flex items-center justify-between text-slate-400">
            <span className="text-xs font-semibold uppercase tracking-wider">Tổng tài khoản</span>
            <div className="p-2 rounded-xl bg-sky-500/10 text-sky-400 group-hover:scale-110 transition">
              <Users className="w-4 h-4" />
            </div>
          </div>
          <div className="mt-3 flex items-baseline space-x-2">
            <span className="text-3xl font-extrabold text-white tracking-tight">{kpis.totalUsers}</span>
            <span className="text-xs text-slate-400 font-medium">người dùng</span>
          </div>
          <div className="mt-2 flex items-center space-x-2 text-xs text-slate-400">
            <span className="text-emerald-400 font-semibold">{kpis.activeUsers} Active</span>
            <span>•</span>
            <span className="text-amber-400">{kpis.premiumUsers} Premium</span>
            <span>•</span>
            <span className="text-rose-400">{kpis.suspendedUsers} Khóa</span>
          </div>
        </div>

        {/* New Users (24h / 7d / 30d) */}
        <div className="p-5 rounded-2xl bg-slate-900/70 border border-slate-800 hover:border-slate-700 transition relative overflow-hidden group">
          <div className="flex items-center justify-between text-slate-400">
            <span className="text-xs font-semibold uppercase tracking-wider">Tăng trưởng mới</span>
            <div className="p-2 rounded-xl bg-emerald-500/10 text-emerald-400 group-hover:scale-110 transition">
              <UserPlus className="w-4 h-4" />
            </div>
          </div>
          <div className="mt-3 flex items-baseline space-x-2">
            <span className="text-3xl font-extrabold text-emerald-400 tracking-tight">+{kpis.new24h}</span>
            <span className="text-xs text-slate-400 font-medium">hôm nay</span>
          </div>
          <div className="mt-2 flex items-center space-x-2 text-xs text-slate-400">
            <span>7 ngày qua: <strong className="text-slate-200">+{kpis.new7d}</strong></span>
            <span>•</span>
            <span>30 ngày: <strong className="text-slate-200">+{kpis.new30d}</strong></span>
          </div>
        </div>

        {/* DAU / MAU & Stickiness */}
        <div className="p-5 rounded-2xl bg-slate-900/70 border border-slate-800 hover:border-slate-700 transition relative overflow-hidden group">
          <div className="flex items-center justify-between text-slate-400">
            <span className="text-xs font-semibold uppercase tracking-wider">Tỷ lệ gắn kết (Stickiness)</span>
            <div className="p-2 rounded-xl bg-purple-500/10 text-purple-400 group-hover:scale-110 transition">
              <Activity className="w-4 h-4" />
            </div>
          </div>
          <div className="mt-3 flex items-baseline space-x-2">
            <span className="text-3xl font-extrabold text-purple-400 tracking-tight">{kpis.stickiness}%</span>
            <span className="text-xs text-slate-400 font-medium">DAU / MAU</span>
          </div>
          <div className="mt-2 flex items-center space-x-2 text-xs text-slate-400">
            <span>DAU (24h): <strong className="text-slate-200">{kpis.dau}</strong></span>
            <span>•</span>
            <span>MAU (30d): <strong className="text-slate-200">{kpis.mau}</strong></span>
          </div>
        </div>

        {/* Transactions Frequency (Zero-Knowledge) */}
        <div className="p-5 rounded-2xl bg-slate-900/70 border border-slate-800 hover:border-slate-700 transition relative overflow-hidden group">
          <div className="flex items-center justify-between text-slate-400">
            <span className="text-xs font-semibold uppercase tracking-wider">Tần suất giao dịch</span>
            <div className="p-2 rounded-xl bg-amber-500/10 text-amber-400 group-hover:scale-110 transition">
              <Receipt className="w-4 h-4" />
            </div>
          </div>
          <div className="mt-3 flex items-baseline space-x-2">
            <span className="text-3xl font-extrabold text-amber-400 tracking-tight">{kpis.totalTransactions}</span>
            <span className="text-xs text-slate-400 font-medium">bản ghi toàn hệ thống</span>
          </div>
          <div className="mt-2 flex items-center space-x-2 text-xs text-slate-400">
            <span>Hôm nay: <strong className="text-emerald-400">+{kpis.transactionsToday} bản ghi mới</strong></span>
          </div>
        </div>
      </div>

      {/* CHARTS ROW: User Growth & Peak Hours */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* User Growth 7 Days */}
        <div className="lg:col-span-2 p-6 rounded-2xl bg-slate-900/70 border border-slate-800 space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-2.5">
              <div className="p-2 rounded-xl bg-sky-500/10 text-sky-400">
                <TrendingUp className="w-4 h-4" />
              </div>
              <div>
                <h3 className="text-sm font-bold text-white">Xu hướng tăng trưởng Người dùng (7 ngày qua)</h3>
                <p className="text-xs text-slate-400">Số lượng tài khoản đăng ký mới theo ngày trên Aiven Cloud</p>
              </div>
            </div>
            <span className="text-xs font-medium px-2.5 py-1 rounded-lg bg-slate-800 text-slate-300 border border-slate-700">
              Real-time DB
            </span>
          </div>

          {/* Bar Chart Visualizer */}
          <div className="pt-6 h-56 flex items-end justify-between gap-3 border-b border-slate-800 pb-2">
            {userGrowth.length === 0 ? (
              <div className="w-full h-full flex items-center justify-center text-xs text-slate-500">
                Chưa có dữ liệu tăng trưởng tuần này
              </div>
            ) : (
              userGrowth.map((item, idx) => {
                const heightPercent = Math.max(12, Math.round((Number(item.count) / maxGrowth) * 100));
                const dayLabel = item.date.slice(5); // MM-DD
                return (
                  <div key={idx} className="flex-1 flex flex-col items-center h-full justify-end group">
                    <span className="text-[11px] font-bold text-sky-400 mb-1 opacity-80 group-hover:opacity-100 transition">
                      +{item.count}
                    </span>
                    <div 
                      style={{ height: `${heightPercent}%` }}
                      className="w-full max-w-[42px] rounded-t-lg bg-gradient-to-t from-sky-600 via-sky-500 to-indigo-500 group-hover:from-sky-500 group-hover:to-indigo-400 transition-all duration-300 shadow-lg shadow-sky-500/20"
                    />
                    <span className="text-[10px] text-slate-400 mt-2 font-mono">{dayLabel}</span>
                  </div>
                );
              })
            )}
          </div>
        </div>

        {/* Peak Hours & Smart Reminders 20:00 */}
        <div className="p-6 rounded-2xl bg-slate-900/70 border border-slate-800 space-y-4">
          <div className="flex items-center space-x-2.5">
            <div className="p-2 rounded-xl bg-amber-500/10 text-amber-400">
              <Clock className="w-4 h-4" />
            </div>
            <div>
              <h3 className="text-sm font-bold text-white">Khung giờ cao điểm 20:00</h3>
              <p className="text-xs text-slate-400">Hành vi người dùng ghi chép chi tiêu</p>
            </div>
          </div>

          <div className="p-4 rounded-xl bg-amber-500/10 border border-amber-500/20 space-y-2">
            <div className="flex items-center justify-between text-xs font-semibold text-amber-300">
              <span className="flex items-center space-x-1.5">
                <Sparkles className="w-3.5 h-3.5" />
                <span>Nhắc nhở tự động 20:00 mỗi tối</span>
              </span>
              <span className="px-2 py-0.5 rounded bg-amber-400/20 text-amber-300 text-[10px]">Active</span>
            </div>
            <p className="text-xs text-slate-300 leading-relaxed">
              Theo thống kê FinTech, <strong>68% giao dịch</strong> được người dùng ghi lại sau giờ làm việc (từ 19:30 đến 21:30).
            </p>
          </div>

          <div className="space-y-2.5 pt-2 text-xs">
            <div className="flex justify-between items-center text-slate-300">
              <span>Sáng (07:00 - 11:00)</span>
              <span className="font-mono text-slate-400">14% lượng GD</span>
            </div>
            <div className="w-full bg-slate-800 rounded-full h-1.5">
              <div className="bg-sky-500 h-1.5 rounded-full" style={{ width: '14%' }}></div>
            </div>

            <div className="flex justify-between items-center text-slate-300">
              <span>Trưa (11:30 - 14:00)</span>
              <span className="font-mono text-slate-400">18% lượng GD</span>
            </div>
            <div className="w-full bg-slate-800 rounded-full h-1.5">
              <div className="bg-sky-500 h-1.5 rounded-full" style={{ width: '18%' }}></div>
            </div>

            <div className="flex justify-between items-center text-amber-400 font-semibold">
              <span>Tối (19:30 - 22:00) — Cao điểm</span>
              <span className="font-mono">68% lượng GD</span>
            </div>
            <div className="w-full bg-slate-800 rounded-full h-2">
              <div className="bg-gradient-to-r from-amber-500 to-rose-500 h-2 rounded-full shadow-sm" style={{ width: '68%' }}></div>
            </div>
          </div>
        </div>
      </div>

      {/* TOP CATEGORIES BY TRANSACTION COUNT */}
      <div className="p-6 rounded-2xl bg-slate-900/70 border border-slate-800 space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-2.5">
            <div className="p-2 rounded-xl bg-purple-500/10 text-purple-400">
              <Award className="w-4 h-4" />
            </div>
            <div>
              <h3 className="text-sm font-bold text-white">Top 10 Danh mục Chi tiêu & Thu nhập Phổ biến nhất</h3>
              <p className="text-xs text-slate-400">Dựa trên tổng số lượt giao dịch ghi nhận trên Aiven Cloud (Zero-Knowledge Privacy)</p>
            </div>
          </div>
          <span className="text-xs text-slate-400">Xếp hạng theo tần suất</span>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 pt-2">
          {topCategories.length === 0 ? (
            <div className="col-span-2 text-center py-8 text-xs text-slate-500">
              Chưa phát sinh bản ghi giao dịch nào trên hệ thống
            </div>
          ) : (
            topCategories.map((cat, index) => {
              const count = Number(cat.tx_count);
              const percentage = Math.round((count / maxTxCount) * 100);
              return (
                <div key={index} className="p-3.5 rounded-xl bg-slate-800/40 border border-slate-800 flex items-center space-x-3.5">
                  <div className="w-7 h-7 rounded-lg flex items-center justify-center font-bold text-xs shrink-0 bg-slate-800 text-slate-300">
                    #{index + 1}
                  </div>
                  <div 
                    className="w-9 h-9 rounded-xl flex items-center justify-center text-white shrink-0 shadow-sm"
                    style={{ backgroundColor: cat.color_hex || '#0284c7' }}
                  >
                    <span className="text-xs font-bold uppercase">{cat.name.slice(0, 1)}</span>
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between text-xs mb-1.5">
                      <span className="font-semibold text-slate-200 truncate">{cat.name}</span>
                      <span className="font-mono text-slate-400 ml-2">{count} lượt ({cat.type === 'income' ? 'Thu' : 'Chi'})</span>
                    </div>
                    <div className="w-full bg-slate-800 rounded-full h-1.5 overflow-hidden">
                      <div 
                        className="h-1.5 rounded-full transition-all duration-500" 
                        style={{ 
                          width: `${percentage}%`,
                          backgroundColor: cat.color_hex || '#0284c7'
                        }}
                      />
                    </div>
                  </div>
                </div>
              );
            })
          )}
        </div>
      </div>
    </div>
  );
};


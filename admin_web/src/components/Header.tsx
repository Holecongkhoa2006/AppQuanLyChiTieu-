import React from 'react';
import { Database, ShieldCheck, RefreshCw, AlertTriangle, Radio } from 'lucide-react';
import { DashboardBundle } from '../types';

interface HeaderProps {
  data: DashboardBundle | null;
  loading: boolean;
  onRefresh: () => void;
}

export const Header: React.FC<HeaderProps> = ({ data, loading, onRefresh }) => {
  const isMaintenance = data?.settings?.maintenance_mode === '1' || data?.settings?.maintenance_mode === 'true';

  return (
    <header className="h-16 border-b border-slate-800 bg-slate-900/80 backdrop-blur px-6 flex items-center justify-between sticky top-0 z-30">
      {/* Brand & System Title */}
      <div className="flex items-center space-x-3">
        <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-sky-600 via-sky-500 to-indigo-600 flex items-center justify-center shadow-lg shadow-sky-500/20">
          <Database className="w-5 h-5 text-white" />
        </div>
        <div>
          <div className="flex items-center space-x-2">
            <h1 className="font-extrabold text-lg text-white tracking-tight">CR404 FinTech</h1>
            <span className="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-sky-500/10 text-sky-400 border border-sky-500/20">
              Admin Console
            </span>
          </div>
          <p className="text-xs text-slate-400 font-medium">Hệ thống Quản trị Trung tâm — Đồng bộ Real-time</p>
        </div>
      </div>

      {/* Cloud DB & Privacy Status Badges */}
      <div className="flex items-center space-x-3">
        {/* Aiven Cloud Status */}
        <div className="hidden md:flex items-center space-x-2 px-3 py-1.5 rounded-lg bg-slate-800/80 border border-slate-700/60 text-xs">
          <span className="relative flex h-2 w-2">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
            <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
          </span>
          <span className="text-slate-300 font-medium">Aiven Cloud MySQL 8.0</span>
          <span className="text-slate-500">|</span>
          <span className="text-slate-400 font-mono text-[11px]">defaultdb</span>
        </div>

        {/* Maintenance Indicator */}
        {isMaintenance ? (
          <div className="flex items-center space-x-1.5 px-3 py-1.5 rounded-lg bg-rose-500/10 border border-rose-500/30 text-rose-400 text-xs font-semibold animate-pulse">
            <AlertTriangle className="w-3.5 h-3.5" />
            <span>BẢO TRÌ ĐANG BẬT</span>
          </div>
        ) : (
          <div className="hidden sm:flex items-center space-x-1.5 px-3 py-1.5 rounded-lg bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-xs font-medium">
            <Radio className="w-3.5 h-3.5 text-emerald-400" />
            <span>App Online</span>
          </div>
        )}

        {/* Zero-Knowledge Privacy Badge */}
        <div className="hidden lg:flex items-center space-x-1.5 px-3 py-1.5 rounded-lg bg-indigo-500/10 border border-indigo-500/20 text-indigo-300 text-xs font-medium" title="Admin chỉ đếm số lượng bản ghi (COUNT), tuyệt đối không xem số tiền hoặc số dư cá nhân của user">
          <ShieldCheck className="w-3.5 h-3.5 text-indigo-400" />
          <span>Zero-Knowledge Privacy</span>
        </div>

        {/* Refresh Button */}
        <button
          onClick={onRefresh}
          disabled={loading}
          className="flex items-center space-x-2 px-3.5 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 active:scale-95 transition border border-slate-700 text-slate-200 text-xs font-medium disabled:opacity-50"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin text-sky-400' : ''}`} />
          <span className="hidden sm:inline">Làm mới</span>
        </button>
      </div>
    </header>
  );
};


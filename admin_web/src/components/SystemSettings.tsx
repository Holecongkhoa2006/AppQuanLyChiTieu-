import React, { useState } from 'react';
import { 
  Settings, 
  AlertTriangle, 
  Download, 
  ShieldCheck, 
  Sliders, 
  Terminal, 
  History, 
  AlertCircle,
  CheckCircle,
  Save,
  Radio
} from 'lucide-react';
import { DashboardBundle } from '../types';

interface SystemSettingsProps {
  data: DashboardBundle;
  onRefresh: () => void;
}

export const SystemSettings: React.FC<SystemSettingsProps> = ({ data, onRefresh }) => {
  const { settings, auditLogs, errorLogs } = data;
  const [subTab, setSubTab] = useState<'flags' | 'audit' | 'errors'>('flags');
  const [savingKey, setSavingKey] = useState<string | null>(null);

  // Settings State
  const [localSettings, setLocalSettings] = useState<Record<string, string>>({
    maintenance_mode: settings.maintenance_mode || 'false',
    registration_open: settings.registration_open || 'true',
    premium_enabled: settings.premium_enabled || 'false',
    min_required_version: settings.force_update_version || settings.min_required_version || '1.0.0',
    force_update_message: settings.force_update_message || 'Vui lòng cập nhật phiên bản mới nhất để tiếp tục sử dụng ứng dụng.',
    max_accounts_free: settings.max_accounts_free || '5',
    max_categories_free: settings.max_categories_free || '20',
  });

  const handleToggleSetting = async (key: string, currentVal: string) => {
    const newVal = currentVal === 'true' || currentVal === '1' ? 'false' : 'true';
    setSavingKey(key);
    try {
      const res = await fetch('/api/admin/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ key, value: newVal }),
      });
      const resData = await res.json();
      if (resData.success) {
        setLocalSettings(prev => ({ ...prev, [key]: newVal }));
        onRefresh();
      } else {
        alert(resData.message || 'Lỗi cập nhật');
      }
    } catch (err: any) {
      alert(err.message);
    } finally {
      setSavingKey(null);
    }
  };

  const handleSaveTextSetting = async (key: string, value: string) => {
    setSavingKey(key);
    try {
      const res = await fetch('/api/admin/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ key, value }),
      });
      const resData = await res.json();
      if (resData.success) {
        alert(`Đã lưu cấu hình ${key} thành công!`);
        onRefresh();
      } else {
        alert(resData.message || 'Lỗi cập nhật');
      }
    } catch (err: any) {
      alert(err.message);
    } finally {
      setSavingKey(null);
    }
  };

  const handleDownloadSqlDump = () => {
    window.location.href = '/api/admin/sql-dump';
  };

  const isMaintenanceActive = localSettings.maintenance_mode === 'true' || localSettings.maintenance_mode === '1';

  return (
    <div className="space-y-6">
      {/* Sub Tabs */}
      <div className="flex items-center space-x-2 border-b border-slate-800 pb-3">
        <button
          onClick={() => setSubTab('flags')}
          className={`flex items-center space-x-2 px-4 py-2 rounded-xl text-xs font-semibold transition ${
            subTab === 'flags'
              ? 'bg-sky-500/15 text-sky-400 border border-sky-500/30 shadow-sm'
              : 'text-slate-400 hover:text-slate-200 hover:bg-slate-900'
          }`}
        >
          <Sliders className="w-4 h-4" />
          <span>Cấu hình & Feature Flags</span>
        </button>

        <button
          onClick={() => setSubTab('audit')}
          className={`flex items-center space-x-2 px-4 py-2 rounded-xl text-xs font-semibold transition ${
            subTab === 'audit'
              ? 'bg-sky-500/15 text-sky-400 border border-sky-500/30 shadow-sm'
              : 'text-slate-400 hover:text-slate-200 hover:bg-slate-900'
          }`}
        >
          <History className="w-4 h-4" />
          <span>Nhật ký Kiểm toán Admin (Audit Trail) ({auditLogs.length})</span>
        </button>

        <button
          onClick={() => setSubTab('errors')}
          className={`flex items-center space-x-2 px-4 py-2 rounded-xl text-xs font-semibold transition ${
            subTab === 'errors'
              ? 'bg-sky-500/15 text-sky-400 border border-sky-500/30 shadow-sm'
              : 'text-slate-400 hover:text-slate-200 hover:bg-slate-900'
          }`}
        >
          <Terminal className="w-4 h-4" />
          <span>Nhật ký Lỗi Hệ thống (Error Logs) ({errorLogs.length})</span>
        </button>
      </div>

      {/* TAB 1: FEATURE FLAGS & SQL DUMP */}
      {subTab === 'flags' && (
        <div className="space-y-6">
          {/* SQL DUMP CARD */}
          <div className="p-5 rounded-2xl bg-gradient-to-r from-slate-900 via-sky-950/30 to-slate-900 border border-sky-500/30 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
            <div>
              <div className="flex items-center space-x-2">
                <Download className="w-4 h-4 text-sky-400" />
                <h4 className="text-sm font-bold text-white">Xuất Bản Sao Lưu Dữ Liệu Thực Tế (.sql)</h4>
              </div>
              <p className="text-xs text-slate-300 mt-1 max-w-2xl leading-relaxed">
                Tải về tệp sao lưu dữ liệu toàn diện các bảng quản trị (danh mục gốc, tiền tệ, cài đặt) để phục vụ sao lưu dự phòng theo chuẩn Zero-Knowledge Privacy.
              </p>
            </div>

            <button
              onClick={handleDownloadSqlDump}
              className="flex items-center space-x-2 px-4 py-2.5 rounded-xl bg-sky-600 hover:bg-sky-500 text-white text-xs font-bold transition shadow-lg shadow-sky-600/20 shrink-0 active:scale-95"
            >
              <Download className="w-4 h-4" />
              <span>Tải file Backup .SQL</span>
            </button>
          </div>

          {/* EMERGENCY MAINTENANCE MODE CARD */}
          <div className={`p-5 rounded-2xl border transition duration-300 ${
            isMaintenanceActive 
              ? 'bg-rose-950/40 border-rose-500/50 shadow-lg shadow-rose-950/50' 
              : 'bg-slate-900/60 border-slate-800'
          }`}>
            <div className="flex items-start justify-between">
              <div className="space-y-1">
                <div className="flex items-center space-x-2">
                  <AlertTriangle className={`w-5 h-5 ${isMaintenanceActive ? 'text-rose-400' : 'text-slate-400'}`} />
                  <h4 className="text-sm font-bold text-white">Chế độ Bảo trì Toàn hệ thống (Maintenance Mode)</h4>
                </div>
                <p className="text-xs text-slate-300 leading-relaxed max-w-2xl">
                  Khi bật, toàn bộ người dùng App Flutter mở ứng dụng sẽ lập tức thấy thông báo tạm dừng dịch vụ bảo trì và bị chặn mọi thao tác đọc/ghi vào Database.
                </p>
              </div>

              <button
                onClick={() => handleToggleSetting('maintenance_mode', localSettings.maintenance_mode)}
                disabled={savingKey === 'maintenance_mode'}
                className={`px-4 py-2 rounded-xl text-xs font-bold transition flex items-center space-x-2 ${
                  isMaintenanceActive
                    ? 'bg-rose-600 text-white hover:bg-rose-500 shadow-md shadow-rose-600/30'
                    : 'bg-slate-800 text-slate-300 hover:bg-slate-700'
                }`}
              >
                <span>{isMaintenanceActive ? 'BẢO TRÌ ĐANG BẬT' : 'BẢO TRÌ ĐANG TẮT'}</span>
              </button>
            </div>
          </div>

          {/* FEATURE FLAGS LIST */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {/* User Registration Toggle */}
            <div className="p-4 rounded-xl bg-slate-900/60 border border-slate-800 flex items-center justify-between">
              <div>
                <span className="font-semibold text-xs text-slate-200">Cho phép Đăng ký Mới</span>
                <p className="text-[11px] text-slate-400 mt-0.5">Bật/tắt quyền tạo tài khoản mới từ App Flutter</p>
              </div>
              <button
                onClick={() => handleToggleSetting('registration_open', localSettings.registration_open)}
                className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition ${
                  localSettings.registration_open === 'true'
                    ? 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30'
                    : 'bg-slate-800 text-slate-500'
                }`}
              >
                {localSettings.registration_open === 'true' ? 'Đang mở' : 'Đã đóng'}
              </button>
            </div>

            {/* Premium Features Toggle */}
            <div className="p-4 rounded-xl bg-slate-900/60 border border-slate-800 flex items-center justify-between">
              <div>
                <span className="font-semibold text-xs text-slate-200">Kích hoạt Tính năng Premium</span>
                <p className="text-[11px] text-slate-400 mt-0.5">Bật tính năng tài khoản cao cấp và nâng cấp ví</p>
              </div>
              <button
                onClick={() => handleToggleSetting('premium_enabled', localSettings.premium_enabled)}
                className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition ${
                  localSettings.premium_enabled === 'true'
                    ? 'bg-amber-500/20 text-amber-400 border border-amber-500/30'
                    : 'bg-slate-800 text-slate-500'
                }`}
              >
                {localSettings.premium_enabled === 'true' ? 'BẬT' : 'TẮT'}
              </button>
            </div>
          </div>

          {/* FORCE UPDATE CONFIGURATION */}
          <div className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 space-y-4">
            <h4 className="text-xs font-bold text-white uppercase tracking-wider">Cấu Hình Ép Buộc Cập Nhật (Force Update)</h4>
            
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-xs">
              <div>
                <label className="block text-slate-400 mb-1">Phiên bản tối thiểu bắt buộc</label>
                <div className="flex items-center space-x-2">
                  <input
                    type="text"
                    value={localSettings.min_required_version}
                    onChange={(e) => setLocalSettings({ ...localSettings, min_required_version: e.target.value })}
                    placeholder="1.0.0"
                    className="flex-1 px-3.5 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-200 font-mono font-bold"
                  />
                  <button
                    onClick={() => handleSaveTextSetting('force_update_version', localSettings.min_required_version)}
                    className="p-2 bg-sky-600 hover:bg-sky-500 text-white rounded-xl"
                  >
                    <Save className="w-4 h-4" />
                  </button>
                </div>
              </div>

              <div className="md:col-span-2">
                <label className="block text-slate-400 mb-1">Thông điệp hiển thị cho người dùng khi phiên bản cũ</label>
                <div className="flex items-center space-x-2">
                  <input
                    type="text"
                    value={localSettings.force_update_message}
                    onChange={(e) => setLocalSettings({ ...localSettings, force_update_message: e.target.value })}
                    className="flex-1 px-3.5 py-2 bg-slate-800 border border-slate-700 rounded-xl text-slate-200"
                  />
                  <button
                    onClick={() => handleSaveTextSetting('force_update_message', localSettings.force_update_message)}
                    className="p-2 bg-sky-600 hover:bg-sky-500 text-white rounded-xl"
                  >
                    <Save className="w-4 h-4" />
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* TAB 2: AUDIT LOGS */}
      {subTab === 'audit' && (
        <div className="rounded-2xl border border-slate-800 bg-slate-900/60 overflow-hidden">
          <div className="p-4 border-b border-slate-800">
            <h4 className="text-xs font-bold text-white uppercase tracking-wider">Nhật Ký Thao Tác Quản Trị Viên (Audit Trail)</h4>
            <p className="text-[11px] text-slate-400">Ghi vết toàn bộ hành vi sửa đổi dữ liệu của Admin trên Aiven Cloud</p>
          </div>

          <table className="w-full text-left text-xs">
            <thead className="bg-slate-900 text-slate-400 uppercase text-[11px] border-b border-slate-800">
              <tr>
                <th className="py-3 px-4">Thời gian</th>
                <th className="py-3 px-4">Hành động</th>
                <th className="py-3 px-4">Mục tiêu</th>
                <th className="py-3 px-4">Chi tiết thao tác</th>
                <th className="py-3 px-4 text-right">Admin</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/80">
              {auditLogs.length === 0 ? (
                <tr>
                  <td colSpan={5} className="text-center py-8 text-slate-500">Chưa có nhật ký nào</td>
                </tr>
              ) : (
                auditLogs.map((log) => (
                  <tr key={log.id} className="hover:bg-slate-800/40 transition">
                    <td className="py-3 px-4 font-mono text-[11px] text-slate-400">
                      {log.created_at ? log.created_at.replace('T', ' ').slice(0, 19) : 'N/A'}
                    </td>
                    <td className="py-3 px-4">
                      <span className="font-bold text-sky-400 font-mono text-[11px] px-2 py-0.5 rounded bg-sky-500/10 border border-sky-500/20">
                        {log.action}
                      </span>
                    </td>
                    <td className="py-3 px-4 text-slate-300 font-mono">{log.target}</td>
                    <td className="py-3 px-4 text-slate-400 max-w-xs truncate" title={log.details || ''}>
                      {log.details || '—'}
                    </td>
                    <td className="py-3 px-4 text-right text-slate-300 font-medium">
                      {log.admin_name || log.admin_email || `Admin #${log.admin_id}`}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      )}

      {/* TAB 3: ERROR LOGS */}
      {subTab === 'errors' && (
        <div className="rounded-2xl border border-slate-800 bg-slate-900/60 overflow-hidden">
          <div className="p-4 border-b border-slate-800">
            <h4 className="text-xs font-bold text-white uppercase tracking-wider">Nhật Ký Lỗi Hệ Thống (System Error Logs)</h4>
            <p className="text-[11px] text-slate-400">Ghi nhận các ngoại lệ và lỗi 500 từ ứng dụng gửi về</p>
          </div>

          <div className="divide-y divide-slate-800/80">
            {errorLogs.length === 0 ? (
              <div className="p-8 text-center text-xs text-slate-500">Hệ thống hoạt động ổn định, không có lỗi nào 🎉</div>
            ) : (
              errorLogs.map((err) => (
                <div key={err.id} className="p-4 space-y-1.5 text-xs hover:bg-slate-800/30 transition">
                  <div className="flex items-center justify-between text-slate-400 text-[11px]">
                    <span className="font-bold text-rose-400 font-mono">{err.error_code || 'EXCEPTION'}</span>
                    <span className="font-mono">{err.created_at ? err.created_at.replace('T', ' ').slice(0, 19) : ''}</span>
                  </div>
                  <p className="text-rose-300 font-mono text-xs">{err.error_msg}</p>
                  {err.stack_trace && (
                    <pre className="p-2.5 rounded-lg bg-slate-950 font-mono text-[10px] text-slate-400 overflow-x-auto max-h-32">
                      {err.stack_trace}
                    </pre>
                  )}
                </div>
              ))
            )}
          </div>
        </div>
      )}
    </div>
  );
};


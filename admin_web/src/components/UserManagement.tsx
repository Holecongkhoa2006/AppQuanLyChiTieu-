import React, { useState } from 'react';
import { 
  Search, 
  Filter, 
  UserPlus, 
  ShieldAlert, 
  KeyRound, 
  Trash2, 
  Lock, 
  Unlock, 
  CheckCircle, 
  XCircle, 
  AlertCircle,
  Crown,
  Shield,
  User as UserIcon,
  X
} from 'lucide-react';
import { User } from '../types';

interface UserManagementProps {
  users: User[];
  onRefresh: () => void;
}

export const UserManagement: React.FC<UserManagementProps> = ({ users, onRefresh }) => {
  const [search, setSearch] = useState('');
  const [roleFilter, setRoleFilter] = useState<string>('all');
  const [statusFilter, setStatusFilter] = useState<string>('all');

  // Modal States
  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [selectedUser, setSelectedUser] = useState<User | null>(null);
  const [modalType, setModalType] = useState<'status' | 'role' | 'password' | 'delete' | null>(null);

  // Form States
  const [newStatus, setNewStatus] = useState<'active' | 'suspended' | 'soft_deleted'>('suspended');
  const [statusReason, setStatusReason] = useState('');
  const [newRole, setNewRole] = useState<'user' | 'premium' | 'admin'>('user');
  const [newPassword, setNewPassword] = useState('');
  const [createForm, setCreateForm] = useState({
    username: '',
    fullName: '',
    email: '',
    password: '',
    role: 'user' as 'user' | 'premium' | 'admin',
  });
  const [submitting, setSubmitting] = useState(false);
  const [toast, setToast] = useState<{ type: 'success' | 'error'; message: string } | null>(null);

  const showToast = (message: string, type: 'success' | 'error' = 'success') => {
    setToast({ type, message });
    setTimeout(() => setToast(null), 3500);
  };

  // Filtered Users
  const filteredUsers = users.filter((u) => {
    const matchSearch = 
      u.email.toLowerCase().includes(search.toLowerCase()) ||
      u.username.toLowerCase().includes(search.toLowerCase()) ||
      u.full_name?.toLowerCase().includes(search.toLowerCase()) ||
      String(u.id).includes(search);
    const matchRole = roleFilter === 'all' || u.role === roleFilter;
    const matchStatus = statusFilter === 'all' || u.status === statusFilter;
    return matchSearch && matchRole && matchStatus;
  });

  // Action Handlers
  const handleUpdateStatus = async () => {
    if (!selectedUser) return;
    if (newStatus !== 'active' && !statusReason.trim()) {
      showToast('Vui lòng nhập lý do khóa hoặc ẩn tài khoản!', 'error');
      return;
    }
    setSubmitting(true);
    try {
      const res = await fetch(`/api/admin/users/${selectedUser.id}/status`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: newStatus, reason: statusReason.trim() }),
      });
      const data = await res.json();
      if (data.success) {
        showToast('Cập nhật trạng thái người dùng thành công!');
        setModalType(null);
        setSelectedUser(null);
        setStatusReason('');
        onRefresh();
      } else {
        showToast(data.message || 'Lỗi cập nhật', 'error');
      }
    } catch (err: any) {
      showToast(err.message, 'error');
    } finally {
      setSubmitting(false);
    }
  };

  const handleUpdateRole = async () => {
    if (!selectedUser) return;
    setSubmitting(true);
    try {
      const res = await fetch(`/api/admin/users/${selectedUser.id}/role`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ role: newRole }),
      });
      const data = await res.json();
      if (data.success) {
        showToast('Cập nhật quyền hạn thành công!');
        setModalType(null);
        setSelectedUser(null);
        onRefresh();
      } else {
        showToast(data.message, 'error');
      }
    } catch (err: any) {
      showToast(err.message, 'error');
    } finally {
      setSubmitting(false);
    }
  };

  const handleResetPassword = async () => {
    if (!selectedUser) return;
    if (newPassword.trim().length < 6) {
      showToast('Mật khẩu tối thiểu 6 ký tự!', 'error');
      return;
    }
    setSubmitting(true);
    try {
      const res = await fetch(`/api/admin/users/${selectedUser.id}/reset-password`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ newPassword: newPassword.trim() }),
      });
      const data = await res.json();
      if (data.success) {
        showToast('Cấp lại mật khẩu thành công!');
        setModalType(null);
        setSelectedUser(null);
        setNewPassword('');
        onRefresh();
      } else {
        showToast(data.message, 'error');
      }
    } catch (err: any) {
      showToast(err.message, 'error');
    } finally {
      setSubmitting(false);
    }
  };

  const handleCreateUser = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!createForm.email || !createForm.password) {
      showToast('Vui lòng nhập Email và Mật khẩu', 'error');
      return;
    }
    setSubmitting(true);
    try {
      const res = await fetch('/api/admin/users', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(createForm),
      });
      const data = await res.json();
      if (data.success) {
        showToast('Tạo tài khoản và khởi tạo ví + danh mục mẫu thành công!');
        setIsCreateOpen(false);
        setCreateForm({ username: '', fullName: '', email: '', password: '', role: 'user' });
        onRefresh();
      } else {
        showToast(data.message, 'error');
      }
    } catch (err: any) {
      showToast(err.message, 'error');
    } finally {
      setSubmitting(false);
    }
  };

  const handleDeleteUser = async (hardDelete: boolean) => {
    if (!selectedUser) return;
    setSubmitting(true);
    try {
      const res = await fetch(`/api/admin/users/${selectedUser.id}`, {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ hardDelete }),
      });
      const data = await res.json();
      if (data.success) {
        showToast(hardDelete ? 'Đã xóa vĩnh viễn tài khoản!' : 'Đã ẩn tài khoản khỏi hệ thống!');
        setModalType(null);
        setSelectedUser(null);
        onRefresh();
      } else {
        showToast(data.message, 'error');
      }
    } catch (err: any) {
      showToast(err.message, 'error');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Toast Alert */}
      {toast && (
        <div className={`fixed bottom-6 right-6 z-50 px-4 py-3 rounded-xl border shadow-xl flex items-center space-x-2.5 text-xs font-semibold animate-in slide-in-from-bottom-2 ${
          toast.type === 'success' ? 'bg-emerald-950 border-emerald-500/40 text-emerald-300' : 'bg-rose-950 border-rose-500/40 text-rose-300'
        }`}>
          {toast.type === 'success' ? <CheckCircle className="w-4 h-4 text-emerald-400" /> : <AlertCircle className="w-4 h-4 text-rose-400" />}
          <span>{toast.message}</span>
        </div>
      )}

      {/* Action Bar: Search, Filters & Create Button */}
      <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3">
        {/* Search */}
        <div className="relative flex-1 max-w-md">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Tìm theo Email, Username, Họ tên, ID..."
            className="w-full pl-10 pr-4 py-2 bg-slate-900 border border-slate-800 rounded-xl text-xs text-slate-200 placeholder-slate-500 focus:outline-none focus:border-sky-500 focus:ring-1 focus:ring-sky-500"
          />
        </div>

        {/* Filters & Add User */}
        <div className="flex items-center space-x-2.5">
          {/* Role Filter */}
          <select
            value={roleFilter}
            onChange={(e) => setRoleFilter(e.target.value)}
            className="px-3 py-2 bg-slate-900 border border-slate-800 rounded-xl text-xs text-slate-300 focus:outline-none focus:border-sky-500"
          >
            <option value="all">Tất cả vai trò</option>
            <option value="user">User thông thường</option>
            <option value="premium">Premium User</option>
            <option value="admin">Quản trị viên (Admin)</option>
          </select>

          {/* Status Filter */}
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="px-3 py-2 bg-slate-900 border border-slate-800 rounded-xl text-xs text-slate-300 focus:outline-none focus:border-sky-500"
          >
            <option value="all">Tất cả trạng thái</option>
            <option value="active">Active (Hoạt động)</option>
            <option value="suspended">Suspended (Bị khóa)</option>
            <option value="soft_deleted">Soft Deleted (Đã ẩn)</option>
          </select>

          {/* Add User Button */}
          <button
            onClick={() => setIsCreateOpen(true)}
            className="flex items-center space-x-1.5 px-3.5 py-2 bg-sky-600 hover:bg-sky-500 text-white rounded-xl text-xs font-semibold shadow-md shadow-sky-600/20 active:scale-95 transition"
          >
            <UserPlus className="w-3.5 h-3.5" />
            <span>Thêm tài khoản</span>
          </button>
        </div>
      </div>

      {/* Users Data Table */}
      <div className="rounded-2xl border border-slate-800 bg-slate-900/60 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-slate-900 text-slate-400 font-semibold uppercase text-[11px] tracking-wider border-b border-slate-800">
              <tr>
                <th className="py-3.5 px-4">Tài khoản & ID</th>
                <th className="py-3.5 px-4">Họ tên & Email</th>
                <th className="py-3.5 px-4">Vai trò</th>
                <th className="py-3.5 px-4">Trạng thái</th>
                <th className="py-3.5 px-4 text-center">Tần suất GD</th>
                <th className="py-3.5 px-4">Lần đăng nhập cuối</th>
                <th className="py-3.5 px-4 text-right">Thao tác</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/80">
              {filteredUsers.length === 0 ? (
                <tr>
                  <td colSpan={7} className="text-center py-10 text-slate-500">
                    Không tìm thấy người dùng phù hợp
                  </td>
                </tr>
              ) : (
                filteredUsers.map((u) => {
                  const roleBadge = 
                    u.role === 'admin' ? { bg: 'bg-indigo-500/10 border-indigo-500/20 text-indigo-400', label: 'Admin', icon: Shield } :
                    u.role === 'premium' ? { bg: 'bg-amber-500/10 border-amber-500/20 text-amber-400', label: 'Premium', icon: Crown } :
                    { bg: 'bg-slate-800 text-slate-400 border-slate-700', label: 'User', icon: UserIcon };

                  const statusBadge = 
                    u.status === 'active' ? { bg: 'bg-emerald-500/10 border-emerald-500/20 text-emerald-400', label: 'Active' } :
                    u.status === 'suspended' ? { bg: 'bg-rose-500/10 border-rose-500/20 text-rose-400', label: 'Bị khóa' } :
                    { bg: 'bg-slate-800 border-slate-700 text-slate-500', label: 'Đã ẩn' };

                  const RoleIcon = roleBadge.icon;

                  return (
                    <tr key={u.id} className="hover:bg-slate-800/40 transition">
                      {/* Username & ID */}
                      <td className="py-3 px-4">
                        <div className="font-bold text-slate-200">@{u.username}</div>
                        <div className="text-[10px] text-slate-500 font-mono">ID: #{u.id}</div>
                      </td>

                      {/* Full Name & Email */}
                      <td className="py-3 px-4">
                        <div className="text-slate-200 font-medium">{u.full_name || 'Chưa đặt tên'}</div>
                        <div className="text-slate-400 text-[11px] font-mono">{u.email}</div>
                      </td>

                      {/* Role */}
                      <td className="py-3 px-4">
                        <span className={`inline-flex items-center space-x-1 px-2.5 py-1 rounded-md text-[11px] font-semibold border ${roleBadge.bg}`}>
                          <RoleIcon className="w-3 h-3" />
                          <span>{roleBadge.label}</span>
                        </span>
                      </td>

                      {/* Status */}
                      <td className="py-3 px-4">
                        <span className={`inline-block px-2.5 py-1 rounded-md text-[11px] font-semibold border ${statusBadge.bg}`}>
                          {statusBadge.label}
                        </span>
                        {u.suspension_reason && (
                          <div className="text-[10px] text-rose-400/80 mt-1 max-w-[180px] truncate" title={u.suspension_reason}>
                            Lý do: {u.suspension_reason}
                          </div>
                        )}
                      </td>

                      {/* Transaction Count (Zero-Knowledge) */}
                      <td className="py-3 px-4 text-center">
                        <span className="font-mono font-bold text-sky-400 bg-sky-500/10 border border-sky-500/20 px-2.5 py-0.5 rounded-full text-xs">
                          {u.tx_count} GD
                        </span>
                      </td>

                      {/* Last Login */}
                      <td className="py-3 px-4 text-slate-400 font-mono text-[11px]">
                        {u.last_login_at ? u.last_login_at.replace('T', ' ').slice(0, 16) : 'Chưa đăng nhập'}
                      </td>

                      {/* Actions */}
                      <td className="py-3 px-4 text-right">
                        <div className="flex items-center justify-end space-x-1.5">
                          {/* Role switch */}
                          <button
                            onClick={() => { setSelectedUser(u); setNewRole(u.role); setModalType('role'); }}
                            title="Đổi vai trò người dùng"
                            className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition"
                          >
                            <Crown className="w-3.5 h-3.5" />
                          </button>

                          {/* Status toggle / suspend */}
                          <button
                            onClick={() => { setSelectedUser(u); setNewStatus(u.status === 'active' ? 'suspended' : 'active'); setStatusReason(u.suspension_reason || ''); setModalType('status'); }}
                            title={u.status === 'active' ? 'Khóa tài khoản' : 'Mở khóa tài khoản'}
                            className={`p-1.5 rounded-lg transition ${
                              u.status === 'active'
                                ? 'bg-slate-800 hover:bg-rose-500/20 text-slate-300 hover:text-rose-400'
                                : 'bg-emerald-500/20 text-emerald-400 hover:bg-emerald-500/30'
                            }`}
                          >
                            {u.status === 'active' ? <Lock className="w-3.5 h-3.5" /> : <Unlock className="w-3.5 h-3.5" />}
                          </button>

                          {/* Reset Password */}
                          <button
                            onClick={() => { setSelectedUser(u); setNewPassword(''); setModalType('password'); }}
                            title="Cấp lại mật khẩu"
                            className="p-1.5 rounded-lg bg-slate-800 hover:bg-amber-500/20 text-slate-300 hover:text-amber-400 transition"
                          >
                            <KeyRound className="w-3.5 h-3.5" />
                          </button>

                          {/* Delete Account */}
                          <button
                            onClick={() => { setSelectedUser(u); setModalType('delete'); }}
                            title="Xóa tài khoản"
                            className="p-1.5 rounded-lg bg-slate-800 hover:bg-rose-500/20 text-slate-400 hover:text-rose-400 transition"
                          >
                            <Trash2 className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* MODAL 1: CREATE USER (Auto-Seeds Accounts + Default Categories) */}
      {isCreateOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm animate-in fade-in">
          <div className="w-full max-w-md bg-slate-900 border border-slate-800 rounded-2xl p-6 shadow-2xl space-y-4">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <div className="flex items-center space-x-2">
                <UserPlus className="w-4 h-4 text-sky-400" />
                <h3 className="text-sm font-bold text-white">Thêm Tài Khoản Người Dùng Mới</h3>
              </div>
              <button onClick={() => setIsCreateOpen(false)} className="text-slate-400 hover:text-white">
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleCreateUser} className="space-y-3.5 text-xs">
              <div>
                <label className="block text-slate-400 mb-1">Email đăng nhập *</label>
                <input
                  type="email"
                  required
                  value={createForm.email}
                  onChange={(e) => setCreateForm({ ...createForm, email: e.target.value })}
                  placeholder="user@example.com"
                  className="w-full px-3.5 py-2 bg-slate-800/80 border border-slate-700 rounded-xl text-slate-200 focus:outline-none focus:border-sky-500"
                />
              </div>

              <div>
                <label className="block text-slate-400 mb-1">Tên tài khoản (Username)</label>
                <input
                  type="text"
                  value={createForm.username}
                  onChange={(e) => setCreateForm({ ...createForm, username: e.target.value })}
                  placeholder="Để trống tự lấy từ email"
                  className="w-full px-3.5 py-2 bg-slate-800/80 border border-slate-700 rounded-xl text-slate-200 focus:outline-none focus:border-sky-500"
                />
              </div>

              <div>
                <label className="block text-slate-400 mb-1">Họ và tên hiển thị</label>
                <input
                  type="text"
                  value={createForm.fullName}
                  onChange={(e) => setCreateForm({ ...createForm, fullName: e.target.value })}
                  placeholder="Nguyễn Văn A"
                  className="w-full px-3.5 py-2 bg-slate-800/80 border border-slate-700 rounded-xl text-slate-200 focus:outline-none focus:border-sky-500"
                />
              </div>

              <div>
                <label className="block text-slate-400 mb-1">Mật khẩu khởi tạo *</label>
                <input
                  type="password"
                  required
                  value={createForm.password}
                  onChange={(e) => setCreateForm({ ...createForm, password: e.target.value })}
                  placeholder="Tối thiểu 6 ký tự"
                  className="w-full px-3.5 py-2 bg-slate-800/80 border border-slate-700 rounded-xl text-slate-200 focus:outline-none focus:border-sky-500"
                />
              </div>

              <div>
                <label className="block text-slate-400 mb-1">Vai trò người dùng</label>
                <select
                  value={createForm.role}
                  onChange={(e: any) => setCreateForm({ ...createForm, role: e.target.value })}
                  className="w-full px-3.5 py-2 bg-slate-800/80 border border-slate-700 rounded-xl text-slate-200 focus:outline-none focus:border-sky-500"
                >
                  <option value="user">User thông thường (Free)</option>
                  <option value="premium">Premium User</option>
                  <option value="admin">Quản trị viên (Admin)</option>
                </select>
              </div>

              <div className="p-3 rounded-xl bg-sky-500/10 border border-sky-500/20 text-[11px] text-sky-300 leading-relaxed">
                ✨ Hệ thống sẽ <strong>tự động seed 3 Ví mặc định</strong> (Ví tiền mặt, Ngân hàng, Thẻ tín dụng) và nhân bản toàn bộ danh mục từ <code>system_default_categories</code>.
              </div>

              <div className="flex items-center justify-end space-x-2 pt-2 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setIsCreateOpen(false)}
                  className="px-4 py-2 rounded-xl bg-slate-800 text-slate-300 hover:bg-slate-700 transition"
                >
                  Hủy
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="px-4 py-2 rounded-xl bg-sky-600 hover:bg-sky-500 text-white font-semibold transition disabled:opacity-50"
                >
                  {submitting ? 'Đang tạo...' : 'Tạo tài khoản'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* MODAL 2: STATUS & SUSPEND REASON */}
      {modalType === 'status' && selectedUser && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm animate-in fade-in">
          <div className="w-full max-w-md bg-slate-900 border border-slate-800 rounded-2xl p-6 shadow-2xl space-y-4">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <h3 className="text-sm font-bold text-white">Kiểm soát trạng thái tài khoản: @{selectedUser.username}</h3>
              <button onClick={() => setModalType(null)} className="text-slate-400 hover:text-white">
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="space-y-3.5 text-xs">
              <div>
                <label className="block text-slate-400 mb-1">Trạng thái mới</label>
                <select
                  value={newStatus}
                  onChange={(e: any) => setNewStatus(e.target.value)}
                  className="w-full px-3.5 py-2 bg-slate-800/80 border border-slate-700 rounded-xl text-slate-200 focus:outline-none focus:border-sky-500"
                >
                  <option value="active">Active — Hoạt động bình thường</option>
                  <option value="suspended">Suspended — Khóa tạm thời (Chặn đăng nhập App)</option>
                  <option value="soft_deleted">Soft Deleted — Ẩn bảo toàn lịch sử giao dịch</option>
                </select>
              </div>

              {newStatus !== 'active' && (
                <div>
                  <label className="block text-slate-400 mb-1">Lý do khóa / ẩn tài khoản * (Hiển thị cho user khi mở App)</label>
                  <textarea
                    rows={3}
                    value={statusReason}
                    onChange={(e) => setStatusReason(e.target.value)}
                    placeholder="VD: Tài khoản có hành vi bất thường, vui lòng liên hệ admin@cr404.edu.vn..."
                    className="w-full px-3.5 py-2 bg-slate-800/80 border border-slate-700 rounded-xl text-slate-200 focus:outline-none focus:border-sky-500"
                  />
                </div>
              )}

              <div className="flex items-center justify-end space-x-2 pt-2 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setModalType(null)}
                  className="px-4 py-2 rounded-xl bg-slate-800 text-slate-300 hover:bg-slate-700 transition"
                >
                  Hủy
                </button>
                <button
                  type="button"
                  onClick={handleUpdateStatus}
                  disabled={submitting}
                  className="px-4 py-2 rounded-xl bg-sky-600 hover:bg-sky-500 text-white font-semibold transition disabled:opacity-50"
                >
                  {submitting ? 'Đang lưu...' : 'Lưu trạng thái'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* MODAL 3: ROLE CHANGE */}
      {modalType === 'role' && selectedUser && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm animate-in fade-in">
          <div className="w-full max-w-sm bg-slate-900 border border-slate-800 rounded-2xl p-6 shadow-2xl space-y-4">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <h3 className="text-sm font-bold text-white">Đổi vai trò: @{selectedUser.username}</h3>
              <button onClick={() => setModalType(null)} className="text-slate-400 hover:text-white">
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="space-y-3.5 text-xs">
              <div>
                <label className="block text-slate-400 mb-1">Vai trò mới</label>
                <select
                  value={newRole}
                  onChange={(e: any) => setNewRole(e.target.value)}
                  className="w-full px-3.5 py-2 bg-slate-800/80 border border-slate-700 rounded-xl text-slate-200 focus:outline-none focus:border-sky-500"
                >
                  <option value="user">User thông thường</option>
                  <option value="premium">Premium User (Không giới hạn)</option>
                  <option value="admin">Quản trị viên (Admin)</option>
                </select>
              </div>

              <div className="flex items-center justify-end space-x-2 pt-2 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setModalType(null)}
                  className="px-4 py-2 rounded-xl bg-slate-800 text-slate-300 hover:bg-slate-700 transition"
                >
                  Hủy
                </button>
                <button
                  type="button"
                  onClick={handleUpdateRole}
                  disabled={submitting}
                  className="px-4 py-2 rounded-xl bg-sky-600 hover:bg-sky-500 text-white font-semibold transition disabled:opacity-50"
                >
                  {submitting ? 'Đang lưu...' : 'Cập nhật'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* MODAL 4: RESET PASSWORD */}
      {modalType === 'password' && selectedUser && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm animate-in fade-in">
          <div className="w-full max-w-sm bg-slate-900 border border-slate-800 rounded-2xl p-6 shadow-2xl space-y-4">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <h3 className="text-sm font-bold text-white">Cấp lại mật khẩu: @{selectedUser.username}</h3>
              <button onClick={() => setModalType(null)} className="text-slate-400 hover:text-white">
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="space-y-3.5 text-xs">
              <div>
                <label className="block text-slate-400 mb-1">Mật khẩu mới (tối thiểu 6 ký tự)</label>
                <input
                  type="text"
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                  placeholder="Nhập mật khẩu tạm..."
                  className="w-full px-3.5 py-2 bg-slate-800/80 border border-slate-700 rounded-xl text-slate-200 focus:outline-none focus:border-sky-500 font-mono"
                />
              </div>

              <div className="flex items-center justify-end space-x-2 pt-2 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setModalType(null)}
                  className="px-4 py-2 rounded-xl bg-slate-800 text-slate-300 hover:bg-slate-700 transition"
                >
                  Hủy
                </button>
                <button
                  type="button"
                  onClick={handleResetPassword}
                  disabled={submitting}
                  className="px-4 py-2 rounded-xl bg-amber-600 hover:bg-amber-500 text-white font-semibold transition disabled:opacity-50"
                >
                  {submitting ? 'Đang cấp lại...' : 'Cấp lại mật khẩu'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* MODAL 5: DELETE CONFIRMATION (GDPR Compliant 2-Step) */}
      {modalType === 'delete' && selectedUser && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm animate-in fade-in">
          <div className="w-full max-w-md bg-slate-900 border border-rose-500/40 rounded-2xl p-6 shadow-2xl space-y-4">
            <div className="flex items-center space-x-2 text-rose-400 border-b border-slate-800 pb-3">
              <ShieldAlert className="w-5 h-5 shrink-0" />
              <h3 className="text-sm font-bold text-white">Xác nhận Xóa Tài Khoản: @{selectedUser.username}</h3>
            </div>

            <p className="text-xs text-slate-300 leading-relaxed">
              Bạn đang chuẩn bị thao tác xóa tài khoản của người dùng <strong>{selectedUser.email}</strong>. 
              Vui lòng chọn hình thức xóa:
            </p>

            <div className="space-y-2 text-xs">
              <div className="p-3 rounded-xl bg-slate-800/80 border border-slate-700">
                <div className="font-semibold text-sky-400">1. Xóa mềm an toàn (Khuyên dùng):</div>
                <p className="text-[11px] text-slate-400 mt-0.5">
                  Chuyển trạng thái sang <code>soft_deleted</code>. Người dùng không thể đăng nhập nhưng lịch sử giao dịch và số dư ví vẫn được bảo toàn nguyên vẹn.
                </p>
              </div>

              <div className="p-3 rounded-xl bg-rose-500/10 border border-rose-500/20">
                <div className="font-semibold text-rose-400">2. Xóa vĩnh viễn (Yêu cầu GDPR/Pháp lý):</div>
                <p className="text-[11px] text-slate-400 mt-0.5">
                  Ẩn danh hóa email và xóa quyền truy cập vĩnh viễn khỏi toàn hệ thống.
                </p>
              </div>
            </div>

            <div className="flex items-center justify-end space-x-2 pt-3 border-t border-slate-800">
              <button
                type="button"
                onClick={() => setModalType(null)}
                className="px-4 py-2 rounded-xl bg-slate-800 text-slate-300 hover:bg-slate-700 text-xs transition"
              >
                Hủy bỏ
              </button>
              <button
                type="button"
                onClick={() => handleDeleteUser(false)}
                disabled={submitting}
                className="px-3.5 py-2 rounded-xl bg-slate-700 hover:bg-slate-600 text-slate-200 text-xs font-semibold transition"
              >
                Xóa mềm (Soft Delete)
              </button>
              <button
                type="button"
                onClick={() => handleDeleteUser(true)}
                disabled={submitting}
                className="px-3.5 py-2 rounded-xl bg-rose-600 hover:bg-rose-500 text-white text-xs font-semibold transition shadow-md shadow-rose-600/20"
              >
                Xóa vĩnh viễn (Hard Delete)
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};


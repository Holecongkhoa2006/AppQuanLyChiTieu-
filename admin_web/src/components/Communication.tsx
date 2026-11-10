import React, { useState } from 'react';
import { 
  BellRing, 
  Send, 
  Clock, 
  MessageSquare, 
  Bug, 
  Lightbulb, 
  ThumbsUp, 
  CheckCircle2, 
  Play, 
  Pause, 
  Info, 
  Smartphone,
  Check,
  X
} from 'lucide-react';
import { PushNotification, Feedback } from '../types';

interface CommunicationProps {
  notifications: PushNotification[];
  feedbacks: Feedback[];
  onRefresh: () => void;
}

export const Communication: React.FC<CommunicationProps> = ({ notifications, feedbacks, onRefresh }) => {
  const [activeTab, setActiveTab] = useState<'notifications' | 'feedbacks'>('notifications');

  // Push Form State
  const [pushForm, setPushForm] = useState({
    title: 'Nhắc ghi chi tiêu hôm nay 💡',
    body: 'Bạn đã ghi lại các khoản chi tiêu và hóa đơn phát sinh trong ngày chưa? Mở app ngay để theo dõi ngân sách nhé!',
    target_group: 'all' as 'all' | 'free' | 'premium' | 'inactive_7d',
    send_mode: 'daily_cron' as 'immediate' | 'daily_cron',
    scheduled_time: '20:00:00',
    smart_skip_recorded: true,
    rolling_jitter_min: 15,
  });
  const [submittingPush, setSubmittingPush] = useState(false);

  // Feedback State
  const [selectedFeedback, setSelectedFeedback] = useState<Feedback | null>(null);
  const [feedbackStatus, setFeedbackStatus] = useState<string>('resolved');
  const [adminNote, setAdminNote] = useState('');
  const [submittingFeedback, setSubmittingFeedback] = useState(false);

  // Submit Push Notification
  const handleCreateNotification = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmittingPush(true);
    try {
      const res = await fetch('/api/admin/notifications', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(pushForm),
      });
      const data = await res.json();
      if (data.success) {
        alert('Tạo chiến dịch thông báo thành công!');
        onRefresh();
      } else {
        alert(data.message || 'Lỗi tạo thông báo');
      }
    } catch (err: any) {
      alert(err.message);
    } finally {
      setSubmittingPush(false);
    }
  };

  const handleToggleNotification = async (id: number) => {
    try {
      await fetch(`/api/admin/notifications/${id}/toggle`, { method: 'PATCH' });
      onRefresh();
    } catch (err: any) {
      alert(err.message);
    }
  };

  // Submit Feedback Resolution
  const handleUpdateFeedback = async () => {
    if (!selectedFeedback) return;
    setSubmittingFeedback(true);
    try {
      const res = await fetch(`/api/admin/feedbacks/${selectedFeedback.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          status: feedbackStatus,
          admin_note: adminNote,
        }),
      });
      const data = await res.json();
      if (data.success) {
        setSelectedFeedback(null);
        setAdminNote('');
        onRefresh();
      } else {
        alert(data.message || 'Lỗi cập nhật');
      }
    } catch (err: any) {
      alert(err.message);
    } finally {
      setSubmittingFeedback(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Tab Switcher */}
      <div className="flex items-center space-x-2 border-b border-slate-800 pb-3">
        <button
          onClick={() => setActiveTab('notifications')}
          className={`flex items-center space-x-2 px-4 py-2 rounded-xl text-xs font-semibold transition ${
            activeTab === 'notifications'
              ? 'bg-sky-500/15 text-sky-400 border border-sky-500/30 shadow-sm'
              : 'text-slate-400 hover:text-slate-200 hover:bg-slate-900'
          }`}
        >
          <BellRing className="w-4 h-4" />
          <span>Thông báo đẩy & Lịch nhắc 20:00 ({notifications.length})</span>
        </button>

        <button
          onClick={() => setActiveTab('feedbacks')}
          className={`flex items-center space-x-2 px-4 py-2 rounded-xl text-xs font-semibold transition ${
            activeTab === 'feedbacks'
              ? 'bg-sky-500/15 text-sky-400 border border-sky-500/30 shadow-sm'
              : 'text-slate-400 hover:text-slate-200 hover:bg-slate-900'
          }`}
        >
          <MessageSquare className="w-4 h-4" />
          <span>Hòm thư Báo lỗi & Góp ý ({feedbacks.length})</span>
        </button>
      </div>

      {/* SECTION 1: PUSH NOTIFICATIONS & 20:00 CRON */}
      {activeTab === 'notifications' && (
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
          {/* Left: Compose Form (5 Cols) */}
          <div className="lg:col-span-5 p-5 rounded-2xl bg-slate-900/80 border border-slate-800 space-y-4">
            <div className="flex items-center space-x-2 border-b border-slate-800 pb-3">
              <Send className="w-4 h-4 text-sky-400" />
              <h4 className="text-xs font-bold text-white uppercase tracking-wider">Soạn Thông Báo & Hẹn Giờ</h4>
            </div>

            <form onSubmit={handleCreateNotification} className="space-y-3.5 text-xs">
              <div>
                <label className="block text-slate-400 mb-1">Tiêu đề thông báo *</label>
                <input
                  type="text"
                  required
                  value={pushForm.title}
                  onChange={(e) => setPushForm({ ...pushForm, title: e.target.value })}
                  className="w-full px-3.5 py-2 bg-slate-800/80 border border-slate-700 rounded-xl text-slate-200 focus:outline-none focus:border-sky-500"
                />
              </div>

              <div>
                <label className="block text-slate-400 mb-1">Nội dung thông điệp *</label>
                <textarea
                  rows={3}
                  required
                  value={pushForm.body}
                  onChange={(e) => setPushForm({ ...pushForm, body: e.target.value })}
                  className="w-full px-3.5 py-2 bg-slate-800/80 border border-slate-700 rounded-xl text-slate-200 focus:outline-none focus:border-sky-500 leading-relaxed"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-slate-400 mb-1">Đối tượng nhận</label>
                  <select
                    value={pushForm.target_group}
                    onChange={(e: any) => setPushForm({ ...pushForm, target_group: e.target.value })}
                    className="w-full px-3 py-2 bg-slate-800/80 border border-slate-700 rounded-xl text-slate-200 focus:outline-none focus:border-sky-500"
                  >
                    <option value="all">Tất cả người dùng</option>
                    <option value="free">Người dùng Free</option>
                    <option value="premium">Người dùng Premium</option>
                    <option value="inactive_7d">Chưa mở app 7 ngày</option>
                  </select>
                </div>

                <div>
                  <label className="block text-slate-400 mb-1">Chế độ gửi</label>
                  <select
                    value={pushForm.send_mode}
                    onChange={(e: any) => setPushForm({ ...pushForm, send_mode: e.target.value })}
                    className="w-full px-3 py-2 bg-slate-800/80 border border-slate-700 rounded-xl text-slate-200 focus:outline-none focus:border-sky-500"
                  >
                    <option value="daily_cron">Lặp lại lúc 20:00 (Mặc định)</option>
                    <option value="immediate">Gửi ngay tức thì</option>
                  </select>
                </div>
              </div>

              {pushForm.send_mode === 'daily_cron' && (
                <div className="p-3.5 rounded-xl bg-slate-800/50 border border-slate-800 space-y-3">
                  <div className="flex items-center justify-between">
                    <span className="text-slate-300 font-semibold">Giờ bắn thông báo hàng ngày:</span>
                    <input
                      type="text"
                      value={pushForm.scheduled_time}
                      onChange={(e) => setPushForm({ ...pushForm, scheduled_time: e.target.value })}
                      className="w-24 px-2 py-1 bg-slate-900 border border-slate-700 rounded-lg text-center font-mono font-bold text-sky-400"
                    />
                  </div>

                  {/* Smart Skip */}
                  <label className="flex items-start space-x-2.5 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={pushForm.smart_skip_recorded}
                      onChange={(e) => setPushForm({ ...pushForm, smart_skip_recorded: e.target.checked })}
                      className="mt-0.5 rounded bg-slate-900 border-slate-700 text-sky-600 focus:ring-0"
                    />
                    <div>
                      <span className="font-semibold text-slate-200">Smart Skip (Bỏ qua người đã ghi chép)</span>
                      <p className="text-[10px] text-slate-400 leading-normal">
                        Tự động bỏ qua không nhắc nếu trong ngày hôm đó người dùng đã tạo ít nhất 1 bản ghi chi tiêu.
                      </p>
                    </div>
                  </label>

                  {/* Rolling Jitter */}
                  <div className="flex items-center justify-between pt-1 text-[11px] text-slate-400">
                    <span>Rải đều Rolling Delivery (tránh nghẽn DB):</span>
                    <span className="font-mono text-sky-400 font-bold">{pushForm.rolling_jitter_min} phút</span>
                  </div>
                </div>
              )}

              <button
                type="submit"
                disabled={submittingPush}
                className="w-full py-2.5 rounded-xl bg-sky-600 hover:bg-sky-500 text-white font-bold transition shadow-md shadow-sky-600/20 disabled:opacity-50"
              >
                {submittingPush ? 'Đang kích hoạt...' : 'Phát Sóng / Lên Lịch Chiến Dịch'}
              </button>
            </form>
          </div>

          {/* Right: Existing Campaigns (7 Cols) */}
          <div className="lg:col-span-7 rounded-2xl border border-slate-800 bg-slate-900/60 overflow-hidden">
            <div className="p-4 border-b border-slate-800">
              <h4 className="text-xs font-bold text-white uppercase tracking-wider">Chiến Dịch Đang Chạy</h4>
              <p className="text-[11px] text-slate-400">Danh sách thông báo hệ thống được quản lý tập trung</p>
            </div>

            <div className="divide-y divide-slate-800/80">
              {notifications.length === 0 ? (
                <div className="p-8 text-center text-xs text-slate-500">Chưa có thông báo nào</div>
              ) : (
                notifications.map((n) => (
                  <div key={n.id} className="p-4 space-y-2 hover:bg-slate-800/30 transition text-xs">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center space-x-2">
                        <span className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                          n.status === 'active' || n.status === 'sent' ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' : 'bg-slate-800 text-slate-400'
                        }`}>
                          {n.status === 'active' ? 'Đang chạy hàng ngày' : (n.status === 'sent' ? 'Đã bắn ngay' : 'Tạm dừng')}
                        </span>
                        <span className="font-bold text-slate-200">{n.title}</span>
                      </div>
                      
                      <button
                        onClick={() => handleToggleNotification(n.id)}
                        className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 transition"
                      >
                        {n.status === 'active' ? <Pause className="w-3.5 h-3.5" /> : <Play className="w-3.5 h-3.5" />}
                      </button>
                    </div>

                    <p className="text-slate-300 text-[11px] leading-relaxed">{n.body}</p>

                    <div className="flex items-center space-x-3 text-[10px] text-slate-400 pt-1 font-mono">
                      <span>Lịch: {n.scheduled_time || 'Gửi ngay'}</span>
                      <span>•</span>
                      <span>Smart Skip: {n.smart_skip_recorded ? 'BẬT' : 'TẮT'}</span>
                      <span>•</span>
                      <span>Nhóm: {n.target_group}</span>
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      )}

      {/* SECTION 2: FEEDBACKS & BUG REPORTS */}
      {activeTab === 'feedbacks' && (
        <div className="rounded-2xl border border-slate-800 bg-slate-900/60 overflow-hidden">
          <div className="p-4 border-b border-slate-800 flex items-center justify-between">
            <div>
              <h4 className="text-xs font-bold text-white uppercase tracking-wider">Hòm Thư Phản Hồi Từ App Flutter</h4>
              <p className="text-[11px] text-slate-400">Mọi báo lỗi hoặc góp ý từ người dùng trên điện thoại sẽ đổ về đây thời gian thực</p>
            </div>
          </div>

          <div className="divide-y divide-slate-800/80">
            {feedbacks.length === 0 ? (
              <div className="p-10 text-center text-xs text-slate-500">Chưa có phản hồi nào được gửi lên</div>
            ) : (
              feedbacks.map((f) => {
                const typeBadge = 
                  f.type === 'bug' ? { bg: 'bg-rose-500/10 text-rose-400 border-rose-500/20', icon: Bug, label: 'Báo lỗi' } :
                  f.type === 'feature' ? { bg: 'bg-sky-500/10 text-sky-400 border-sky-500/20', icon: Lightbulb, label: 'Tính năng mới' } :
                  { bg: 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20', icon: ThumbsUp, label: 'Khen ngợi' };

                const TypeIcon = typeBadge.icon;

                return (
                  <div key={f.id} className="p-4 hover:bg-slate-800/30 transition text-xs space-y-2">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center space-x-2">
                        <span className={`inline-flex items-center space-x-1 px-2.5 py-0.5 rounded text-[10px] font-bold border ${typeBadge.bg}`}>
                          <TypeIcon className="w-3 h-3" />
                          <span>{typeBadge.label}</span>
                        </span>
                        <span className="font-semibold text-slate-200">
                          {f.user_name || f.username || f.user_email || `Khách (#${f.user_id || 'N/A'})`}
                        </span>
                      </div>

                      <div className="flex items-center space-x-2">
                        <span className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                          f.status === 'resolved' ? 'bg-emerald-500/10 text-emerald-400' : (f.status === 'new' ? 'bg-amber-500/10 text-amber-400' : 'bg-slate-800 text-slate-400')
                        }`}>
                          {f.status === 'new' ? 'Chưa xử lý' : (f.status === 'resolved' ? 'Đã giải quyết' : f.status)}
                        </span>
                        <button
                          onClick={() => { setSelectedFeedback(f); setFeedbackStatus(f.status); setAdminNote(f.admin_note || ''); }}
                          className="px-2.5 py-1 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded-lg text-[11px] transition"
                        >
                          Xử lý
                        </button>
                      </div>
                    </div>

                    <p className="text-slate-300 text-xs leading-relaxed bg-slate-950/60 p-3 rounded-xl border border-slate-800/80">
                      {f.content}
                    </p>

                    <div className="flex flex-wrap items-center gap-3 text-[10px] text-slate-400 pt-1">
                      {f.device_info && (
                        <span className="flex items-center space-x-1">
                          <Smartphone className="w-3 h-3 text-slate-400" />
                          <span>Thiết bị: {f.device_info}</span>
                        </span>
                      )}
                      <span>Gửi lúc: {f.created_at ? f.created_at.replace('T', ' ').slice(0, 16) : 'N/A'}</span>
                      {f.admin_note && (
                        <span className="text-sky-400 font-semibold">Admin Note: {f.admin_note}</span>
                      )}
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>
      )}

      {/* FEEDBACK RESOLUTION MODAL */}
      {selectedFeedback && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm animate-in fade-in">
          <div className="w-full max-w-md bg-slate-900 border border-slate-800 rounded-2xl p-6 shadow-2xl space-y-4">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <h3 className="text-sm font-bold text-white">Xử lý phản hồi #{selectedFeedback.id}</h3>
              <button onClick={() => setSelectedFeedback(null)} className="text-slate-400 hover:text-white">
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="space-y-3.5 text-xs">
              <div className="p-3 bg-slate-800/60 rounded-xl border border-slate-800 text-slate-300 text-[11px]">
                {selectedFeedback.content}
              </div>

              <div>
                <label className="block text-slate-400 mb-1">Cập nhật trạng thái</label>
                <select
                  value={feedbackStatus}
                  onChange={(e) => setFeedbackStatus(e.target.value)}
                  className="w-full px-3.5 py-2 bg-slate-800/80 border border-slate-700 rounded-xl text-slate-200 focus:outline-none focus:border-sky-500"
                >
                  <option value="new">Mới (Chưa xử lý)</option>
                  <option value="in_progress">Đang điều tra / Xử lý</option>
                  <option value="resolved">Đã giải quyết</option>
                  <option value="closed">Đóng / Lưu trữ</option>
                  <option value="wont_fix">Không xử lý (Wont Fix)</option>
                </select>
              </div>

              <div>
                <label className="block text-slate-400 mb-1">Ghi chú phản hồi của Admin</label>
                <textarea
                  rows={3}
                  value={adminNote}
                  onChange={(e) => setAdminNote(e.target.value)}
                  placeholder="VD: Đã sửa lỗi trong bản cập nhật v1.0.1..."
                  className="w-full px-3.5 py-2 bg-slate-800/80 border border-slate-700 rounded-xl text-slate-200 focus:outline-none focus:border-sky-500"
                />
              </div>

              <div className="flex items-center justify-end space-x-2 pt-2 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setSelectedFeedback(null)}
                  className="px-4 py-2 rounded-xl bg-slate-800 text-slate-300 hover:bg-slate-700 transition"
                >
                  Hủy
                </button>
                <button
                  type="button"
                  onClick={handleUpdateFeedback}
                  disabled={submittingFeedback}
                  className="px-4 py-2 rounded-xl bg-sky-600 hover:bg-sky-500 text-white font-semibold transition disabled:opacity-50"
                >
                  {submittingFeedback ? 'Đang lưu...' : 'Lưu xử lý'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};


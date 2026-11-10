import React, { useState } from 'react';
import { 
  Layers, 
  Plus, 
  Edit3, 
  Eye, 
  EyeOff, 
  Trash2, 
  DollarSign, 
  Smartphone, 
  Sun, 
  Moon, 
  Sparkles,
  Check,
  X,
  Tag,
  Coins
} from 'lucide-react';
import { DefaultCategory, Currency } from '../types';

interface MasterDataProps {
  categories: DefaultCategory[];
  currencies: Currency[];
  onRefresh: () => void;
}

export const MasterData: React.FC<MasterDataProps> = ({ categories, currencies, onRefresh }) => {
  const [activeTab, setActiveTab] = useState<'categories' | 'currencies'>('categories');
  const [previewTab, setPreviewTab] = useState<'both' | 'light' | 'dark'>('both');

  // Category Form State
  const [isCatModalOpen, setIsCatModalOpen] = useState(false);
  const [editingCat, setEditingCat] = useState<DefaultCategory | null>(null);
  const [catForm, setCatForm] = useState({
    name: '',
    type: 'expense' as 'expense' | 'income',
    icon_code: 'category',
    color_hex: '#FF5722',
    keywords: '',
    sort_order: 0,
    is_visible: 1,
  });

  // Currency Form State
  const [isCurModalOpen, setIsCurModalOpen] = useState(false);
  const [editingCur, setEditingCur] = useState<Currency | null>(null);
  const [curForm, setCurForm] = useState({
    code: '',
    symbol: '',
    name: '',
    rate_to_vnd: 1,
    is_active: 1,
    sort_order: 0,
  });

  const [submitting, setSubmitting] = useState(false);

  // Category Actions
  const handleOpenCatModal = (cat?: DefaultCategory) => {
    if (cat) {
      setEditingCat(cat);
      setCatForm({
        name: cat.name,
        type: cat.type,
        icon_code: cat.icon_code,
        color_hex: cat.color_hex,
        keywords: cat.keywords || '',
        sort_order: cat.sort_order,
        is_visible: cat.is_visible ? 1 : 0,
      });
    } else {
      setEditingCat(null);
      setCatForm({
        name: '',
        type: 'expense',
        icon_code: 'category',
        color_hex: '#FF5722',
        keywords: '',
        sort_order: categories.length + 1,
        is_visible: 1,
      });
    }
    setIsCatModalOpen(true);
  };

  const handleSaveCategory = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      const res = await fetch('/api/admin/categories', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          id: editingCat ? editingCat.id : undefined,
          ...catForm,
        }),
      });
      const data = await res.json();
      if (data.success) {
        setIsCatModalOpen(false);
        onRefresh();
      } else {
        alert(data.message || 'Lỗi khi lưu danh mục');
      }
    } catch (err: any) {
      alert(err.message);
    } finally {
      setSubmitting(false);
    }
  };

  const handleToggleCatVisibility = async (id: number) => {
    try {
      await fetch(`/api/admin/categories/${id}/toggle`, { method: 'PATCH' });
      onRefresh();
    } catch (err: any) {
      alert(err.message);
    }
  };

  const handleDeleteCategory = async (id: number) => {
    if (!confirm('Bạn chắc chắn muốn xóa danh mục gốc này?')) return;
    try {
      await fetch(`/api/admin/categories/${id}`, { method: 'DELETE' });
      onRefresh();
    } catch (err: any) {
      alert(err.message);
    }
  };

  // Currency Actions
  const handleOpenCurModal = (cur?: Currency) => {
    if (cur) {
      setEditingCur(cur);
      setCurForm({
        code: cur.code,
        symbol: cur.symbol,
        name: cur.name,
        rate_to_vnd: Number(cur.rate_to_vnd),
        is_active: cur.is_active ? 1 : 0,
        sort_order: cur.sort_order,
      });
    } else {
      setEditingCur(null);
      setCurForm({
        code: '',
        symbol: '',
        name: '',
        rate_to_vnd: 25000,
        is_active: 1,
        sort_order: currencies.length + 1,
      });
    }
    setIsCurModalOpen(true);
  };

  const handleSaveCurrency = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      const res = await fetch('/api/admin/currencies', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          id: editingCur ? editingCur.id : undefined,
          ...curForm,
        }),
      });
      const data = await res.json();
      if (data.success) {
        setIsCurModalOpen(false);
        onRefresh();
      } else {
        alert(data.message || 'Lỗi khi lưu tiền tệ');
      }
    } catch (err: any) {
      alert(err.message);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Tab Switcher */}
      <div className="flex items-center justify-between border-b border-slate-800 pb-3">
        <div className="flex items-center space-x-2">
          <button
            onClick={() => setActiveTab('categories')}
            className={`flex items-center space-x-2 px-4 py-2 rounded-xl text-xs font-semibold transition ${
              activeTab === 'categories'
                ? 'bg-sky-500/15 text-sky-400 border border-sky-500/30 shadow-sm'
                : 'text-slate-400 hover:text-slate-200 hover:bg-slate-900'
            }`}
          >
            <Layers className="w-4 h-4" />
            <span>Danh mục mặc định hệ thống ({categories.length})</span>
          </button>

          <button
            onClick={() => setActiveTab('currencies')}
            className={`flex items-center space-x-2 px-4 py-2 rounded-xl text-xs font-semibold transition ${
              activeTab === 'currencies'
                ? 'bg-sky-500/15 text-sky-400 border border-sky-500/30 shadow-sm'
                : 'text-slate-400 hover:text-slate-200 hover:bg-slate-900'
            }`}
          >
            <Coins className="w-4 h-4" />
            <span>Tiền tệ & Tỷ giá quy đổi ({currencies.length})</span>
          </button>
        </div>

        <div>
          {activeTab === 'categories' ? (
            <button
              onClick={() => handleOpenCatModal()}
              className="flex items-center space-x-1.5 px-3.5 py-2 bg-sky-600 hover:bg-sky-500 text-white rounded-xl text-xs font-semibold shadow-md shadow-sky-600/20 active:scale-95 transition"
            >
              <Plus className="w-3.5 h-3.5" />
              <span>Thêm danh mục gốc</span>
            </button>
          ) : (
            <button
              onClick={() => handleOpenCurModal()}
              className="flex items-center space-x-1.5 px-3.5 py-2 bg-sky-600 hover:bg-sky-500 text-white rounded-xl text-xs font-semibold shadow-md shadow-sky-600/20 active:scale-95 transition"
            >
              <Plus className="w-3.5 h-3.5" />
              <span>Thêm loại tiền tệ</span>
            </button>
          )}
        </div>
      </div>

      {/* SECTION 1: CATEGORIES & LIVE MOBILE PREVIEW */}
      {activeTab === 'categories' && (
        <div className="grid grid-cols-1 xl:grid-cols-12 gap-6 items-start">
          {/* Left Column: Categories List (7 Cols) */}
          <div className="xl:col-span-7 space-y-4">
            <div className="rounded-2xl border border-slate-800 bg-slate-900/60 overflow-hidden">
              <div className="p-4 border-b border-slate-800 flex items-center justify-between">
                <div>
                  <h4 className="text-xs font-bold text-white uppercase tracking-wider">Danh sách Master Categories</h4>
                  <p className="text-[11px] text-slate-400">Các danh mục này sẽ tự động seed cho mọi tài khoản mới đăng ký trên App</p>
                </div>
              </div>

              <div className="divide-y divide-slate-800/80">
                {categories.map((cat) => {
                  const isVisible = cat.is_visible === 1 || cat.is_visible === true;
                  return (
                    <div key={cat.id} className="p-3.5 flex items-center justify-between hover:bg-slate-800/40 transition text-xs">
                      <div className="flex items-center space-x-3 min-w-0">
                        <div
                          className="w-8 h-8 rounded-xl flex items-center justify-center text-white shrink-0 shadow-sm"
                          style={{ backgroundColor: cat.color_hex || '#607D8B' }}
                        >
                          <span className="font-bold uppercase text-xs">{cat.name.slice(0, 1)}</span>
                        </div>
                        <div className="min-w-0">
                          <div className="flex items-center space-x-2">
                            <span className="font-semibold text-slate-200 truncate">{cat.name}</span>
                            <span className={`text-[10px] font-bold px-1.5 py-0.2 rounded ${
                              cat.type === 'income' ? 'bg-emerald-500/10 text-emerald-400' : 'bg-rose-500/10 text-rose-400'
                            }`}>
                              {cat.type === 'income' ? 'Thu nhập' : 'Chi phí'}
                            </span>
                          </div>
                          {cat.keywords ? (
                            <div className="text-[10px] text-slate-400 truncate mt-0.5" title={cat.keywords}>
                              Từ khóa: <span className="text-sky-400/90">{cat.keywords}</span>
                            </div>
                          ) : (
                            <div className="text-[10px] text-slate-500 mt-0.5">Chưa cài từ khóa tự động</div>
                          )}
                        </div>
                      </div>

                      <div className="flex items-center space-x-2 shrink-0 ml-3">
                        <button
                          onClick={() => handleToggleCatVisibility(cat.id)}
                          title={isVisible ? 'Đang hiển thị' : 'Đang ẩn'}
                          className={`p-1.5 rounded-lg transition ${
                            isVisible ? 'text-emerald-400 hover:bg-emerald-500/10' : 'text-slate-500 hover:bg-slate-800'
                          }`}
                        >
                          {isVisible ? <Eye className="w-3.5 h-3.5" /> : <EyeOff className="w-3.5 h-3.5" />}
                        </button>

                        <button
                          onClick={() => handleOpenCatModal(cat)}
                          title="Sửa danh mục"
                          className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition"
                        >
                          <Edit3 className="w-3.5 h-3.5" />
                        </button>

                        <button
                          onClick={() => handleDeleteCategory(cat.id)}
                          title="Xóa danh mục"
                          className="p-1.5 rounded-lg text-slate-400 hover:text-rose-400 hover:bg-rose-500/10 transition"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          </div>

          {/* Right Column: LIVE MOBILE PREVIEW (5 Cols) */}
          <div className="xl:col-span-5 space-y-4">
            <div className="p-4 rounded-2xl bg-slate-900/80 border border-slate-800 space-y-4 sticky top-20">
              <div className="flex items-center justify-between">
                <div className="flex items-center space-x-2">
                  <Smartphone className="w-4 h-4 text-sky-400" />
                  <h4 className="text-xs font-bold text-white uppercase tracking-wider">Khung Mô Phỏng Mobile Live</h4>
                </div>
                <div className="flex items-center space-x-1 p-1 bg-slate-800 rounded-lg text-[10px]">
                  <button
                    onClick={() => setPreviewTab('both')}
                    className={`px-2 py-0.5 rounded ${previewTab === 'both' ? 'bg-sky-500 text-white font-bold' : 'text-slate-400'}`}
                  >
                    Cả hai
                  </button>
                  <button
                    onClick={() => setPreviewTab('light')}
                    className={`px-2 py-0.5 rounded flex items-center space-x-1 ${previewTab === 'light' ? 'bg-sky-500 text-white font-bold' : 'text-slate-400'}`}
                  >
                    <Sun className="w-3 h-3" />
                    <span>Sáng</span>
                  </button>
                  <button
                    onClick={() => setPreviewTab('dark')}
                    className={`px-2 py-0.5 rounded flex items-center space-x-1 ${previewTab === 'dark' ? 'bg-sky-500 text-white font-bold' : 'text-slate-400'}`}
                  >
                    <Moon className="w-3 h-3" />
                    <span>Tối</span>
                  </button>
                </div>
              </div>

              <p className="text-[11px] text-slate-400 leading-relaxed">
                Kiểm tra độ tương phản màu sắc và hiển thị chip danh mục thực tế trên điện thoại của người dùng cuối.
              </p>

              {/* Mobile Frames Container */}
              <div className={`grid gap-4 ${previewTab === 'both' ? 'grid-cols-2' : 'grid-cols-1 max-w-[280px] mx-auto'}`}>
                {/* 1. LIGHT MODE PHONE FRAME */}
                {(previewTab === 'both' || previewTab === 'light') && (
                  <div className="rounded-3xl border-4 border-slate-700 bg-white shadow-2xl p-3 flex flex-col h-[380px] overflow-hidden text-slate-900">
                    {/* Phone Notch */}
                    <div className="w-16 h-3 bg-slate-300 rounded-full mx-auto mb-2 shrink-0"></div>

                    {/* App Header simulation */}
                    <div className="border-b border-slate-100 pb-2 mb-2 flex items-center justify-between">
                      <span className="text-[10px] font-extrabold text-slate-800">Chọn danh mục</span>
                      <span className="text-[9px] px-1.5 py-0.5 rounded bg-sky-50 text-sky-600 font-bold">Light</span>
                    </div>

                    {/* Chips scroll list */}
                    <div className="flex-1 overflow-y-auto space-y-1.5 pr-1">
                      {categories.filter(c => c.is_visible).map((c) => (
                        <div
                          key={c.id}
                          className="flex items-center space-x-2 p-1.5 rounded-xl border border-slate-100 shadow-xs hover:border-slate-300 transition"
                        >
                          <div
                            className="w-5 h-5 rounded-lg flex items-center justify-center text-white shrink-0 text-[10px] font-bold"
                            style={{ backgroundColor: c.color_hex }}
                          >
                            {c.name.slice(0, 1)}
                          </div>
                          <span className="text-[11px] font-medium text-slate-700 truncate">{c.name}</span>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* 2. DARK MODE PHONE FRAME */}
                {(previewTab === 'both' || previewTab === 'dark') && (
                  <div className="rounded-3xl border-4 border-slate-700 bg-slate-950 shadow-2xl p-3 flex flex-col h-[380px] overflow-hidden text-white">
                    {/* Phone Notch */}
                    <div className="w-16 h-3 bg-slate-800 rounded-full mx-auto mb-2 shrink-0"></div>

                    {/* App Header simulation */}
                    <div className="border-b border-slate-900 pb-2 mb-2 flex items-center justify-between">
                      <span className="text-[10px] font-extrabold text-slate-200">Chọn danh mục</span>
                      <span className="text-[9px] px-1.5 py-0.5 rounded bg-indigo-950 text-indigo-400 font-bold border border-indigo-900">Dark</span>
                    </div>

                    {/* Chips scroll list */}
                    <div className="flex-1 overflow-y-auto space-y-1.5 pr-1">
                      {categories.filter(c => c.is_visible).map((c) => (
                        <div
                          key={c.id}
                          className="flex items-center space-x-2 p-1.5 rounded-xl border border-slate-900 bg-slate-900/60 hover:border-slate-700 transition"
                        >
                          <div
                            className="w-5 h-5 rounded-lg flex items-center justify-center text-white shrink-0 text-[10px] font-bold"
                            style={{ backgroundColor: c.color_hex }}
                          >
                            {c.name.slice(0, 1)}
                          </div>
                          <span className="text-[11px] font-medium text-slate-300 truncate">{c.name}</span>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* SECTION 2: CURRENCIES LIST */}
      {activeTab === 'currencies' && (
        <div className="rounded-2xl border border-slate-800 bg-slate-900/60 overflow-hidden max-w-4xl">
          <div className="p-4 border-b border-slate-800">
            <h4 className="text-xs font-bold text-white uppercase tracking-wider">Bảng cấu hình Tiền tệ & Tỷ giá quy đổi</h4>
            <p className="text-[11px] text-slate-400">Tỷ giá cơ sở quy đổi sang VND để tính toán báo cáo hợp nhất</p>
          </div>

          <table className="w-full text-left text-xs">
            <thead className="bg-slate-900 text-slate-400 uppercase text-[11px] border-b border-slate-800">
              <tr>
                <th className="py-3 px-4">Ký hiệu</th>
                <th className="py-3 px-4">Mã tiền tệ</th>
                <th className="py-3 px-4">Tên đầy đủ</th>
                <th className="py-3 px-4">Tỷ giá quy đổi (1 Đơn vị = ... VND)</th>
                <th className="py-3 px-4 text-center">Trạng thái</th>
                <th className="py-3 px-4 text-right">Thao tác</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800">
              {currencies.map((cur) => (
                <tr key={cur.id} className="hover:bg-slate-800/40 transition">
                  <td className="py-3 px-4 font-extrabold text-base text-sky-400 font-mono">{cur.symbol}</td>
                  <td className="py-3 px-4 font-bold text-white">{cur.code}</td>
                  <td className="py-3 px-4 text-slate-300">{cur.name}</td>
                  <td className="py-3 px-4 font-mono font-semibold text-emerald-400">
                    {Number(cur.rate_to_vnd).toLocaleString('vi-VN')} đ
                  </td>
                  <td className="py-3 px-4 text-center">
                    <span className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                      cur.is_active ? 'bg-emerald-500/10 text-emerald-400' : 'bg-slate-800 text-slate-500'
                    }`}>
                      {cur.is_active ? 'Kích hoạt' : 'Tắt'}
                    </span>
                  </td>
                  <td className="py-3 px-4 text-right">
                    <button
                      onClick={() => handleOpenCurModal(cur)}
                      className="px-2.5 py-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition"
                    >
                      Sửa tỷ giá
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* CATEGORY EDIT MODAL */}
      {isCatModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm animate-in fade-in">
          <div className="w-full max-w-md bg-slate-900 border border-slate-800 rounded-2xl p-6 shadow-2xl space-y-4">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <h3 className="text-sm font-bold text-white">
                {editingCat ? `Sửa danh mục: ${editingCat.name}` : 'Thêm danh mục gốc mới'}
              </h3>
              <button onClick={() => setIsCatModalOpen(false)} className="text-slate-400 hover:text-white">
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleSaveCategory} className="space-y-3.5 text-xs">
              <div>
                <label className="block text-slate-400 mb-1">Tên danh mục *</label>
                <input
                  type="text"
                  required
                  value={catForm.name}
                  onChange={(e) => setCatForm({ ...catForm, name: e.target.value })}
                  placeholder="VD: Ăn uống, Di chuyển..."
                  className="w-full px-3.5 py-2 bg-slate-800/80 border border-slate-700 rounded-xl text-slate-200 focus:outline-none focus:border-sky-500"
                />
              </div>

              <div>
                <label className="block text-slate-400 mb-1">Phân nhóm *</label>
                <select
                  value={catForm.type}
                  onChange={(e: any) => setCatForm({ ...catForm, type: e.target.value })}
                  className="w-full px-3.5 py-2 bg-slate-800/80 border border-slate-700 rounded-xl text-slate-200 focus:outline-none focus:border-sky-500"
                >
                  <option value="expense">Khoản Chi (Expense)</option>
                  <option value="income">Khoản Thu (Income)</option>
                </select>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-slate-400 mb-1">Mã màu HEX *</label>
                  <div className="flex items-center space-x-2">
                    <input
                      type="color"
                      value={catForm.color_hex}
                      onChange={(e) => setCatForm({ ...catForm, color_hex: e.target.value })}
                      className="w-8 h-8 rounded border-0 cursor-pointer bg-transparent"
                    />
                    <input
                      type="text"
                      value={catForm.color_hex}
                      onChange={(e) => setCatForm({ ...catForm, color_hex: e.target.value })}
                      className="flex-1 px-3 py-1.5 bg-slate-800/80 border border-slate-700 rounded-xl text-slate-200 font-mono uppercase"
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-slate-400 mb-1">Mã Icon Code</label>
                  <input
                    type="text"
                    value={catForm.icon_code}
                    onChange={(e) => setCatForm({ ...catForm, icon_code: e.target.value })}
                    placeholder="restaurant, home..."
                    className="w-full px-3.5 py-2 bg-slate-800/80 border border-slate-700 rounded-xl text-slate-200 focus:outline-none focus:border-sky-500 font-mono"
                  />
                </div>
              </div>

              <div>
                <label className="block text-slate-400 mb-1">
                  Từ khóa gợi ý tự động (Keywords cách nhau bởi dấu phẩy)
                </label>
                <textarea
                  rows={2}
                  value={catForm.keywords}
                  onChange={(e) => setCatForm({ ...catForm, keywords: e.target.value })}
                  placeholder="grab, be, xanh sm, taxi, đổ xăng, gửi xe..."
                  className="w-full px-3.5 py-2 bg-slate-800/80 border border-slate-700 rounded-xl text-slate-200 focus:outline-none focus:border-sky-500"
                />
                <p className="text-[10px] text-slate-500 mt-1">
                  💡 Giúp người dùng khi gõ ghi chú giao dịch trên App Flutter sẽ được tự động gợi ý danh mục này.
                </p>
              </div>

              <div className="flex items-center justify-end space-x-2 pt-2 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setIsCatModalOpen(false)}
                  className="px-4 py-2 rounded-xl bg-slate-800 text-slate-300 hover:bg-slate-700 transition"
                >
                  Hủy
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="px-4 py-2 rounded-xl bg-sky-600 hover:bg-sky-500 text-white font-semibold transition disabled:opacity-50"
                >
                  {submitting ? 'Đang lưu...' : 'Lưu danh mục'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* CURRENCY EDIT MODAL */}
      {isCurModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm animate-in fade-in">
          <div className="w-full max-w-sm bg-slate-900 border border-slate-800 rounded-2xl p-6 shadow-2xl space-y-4">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <h3 className="text-sm font-bold text-white">
                {editingCur ? `Sửa tỷ giá: ${editingCur.code}` : 'Thêm loại tiền tệ'}
              </h3>
              <button onClick={() => setIsCurModalOpen(false)} className="text-slate-400 hover:text-white">
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleSaveCurrency} className="space-y-3.5 text-xs">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-slate-400 mb-1">Mã (ISO) *</label>
                  <input
                    type="text"
                    required
                    value={curForm.code}
                    onChange={(e) => setCurForm({ ...curForm, code: e.target.value.toUpperCase() })}
                    placeholder="USD"
                    className="w-full px-3.5 py-2 bg-slate-800/80 border border-slate-700 rounded-xl text-slate-200 uppercase font-bold"
                  />
                </div>
                <div>
                  <label className="block text-slate-400 mb-1">Ký hiệu *</label>
                  <input
                    type="text"
                    required
                    value={curForm.symbol}
                    onChange={(e) => setCurForm({ ...curForm, symbol: e.target.value })}
                    placeholder="$"
                    className="w-full px-3.5 py-2 bg-slate-800/80 border border-slate-700 rounded-xl text-slate-200 font-bold"
                  />
                </div>
              </div>

              <div>
                <label className="block text-slate-400 mb-1">Tên tiền tệ *</label>
                <input
                  type="text"
                  required
                  value={curForm.name}
                  onChange={(e) => setCurForm({ ...curForm, name: e.target.value })}
                  placeholder="US Dollar"
                  className="w-full px-3.5 py-2 bg-slate-800/80 border border-slate-700 rounded-xl text-slate-200"
                />
              </div>

              <div>
                <label className="block text-slate-400 mb-1">Tỷ giá quy đổi sang VND *</label>
                <input
                  type="number"
                  step="any"
                  required
                  value={curForm.rate_to_vnd}
                  onChange={(e) => setCurForm({ ...curForm, rate_to_vnd: parseFloat(e.target.value) || 1 })}
                  className="w-full px-3.5 py-2 bg-slate-800/80 border border-slate-700 rounded-xl text-slate-200 font-mono font-bold"
                />
              </div>

              <div className="flex items-center justify-end space-x-2 pt-2 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setIsCurModalOpen(false)}
                  className="px-4 py-2 rounded-xl bg-slate-800 text-slate-300 hover:bg-slate-700 transition"
                >
                  Hủy
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="px-4 py-2 rounded-xl bg-sky-600 hover:bg-sky-500 text-white font-semibold transition disabled:opacity-50"
                >
                  {submitting ? 'Đang lưu...' : 'Lưu tỷ giá'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};


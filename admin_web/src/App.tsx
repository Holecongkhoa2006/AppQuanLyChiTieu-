import React, { useState, useEffect } from 'react';
import { Header } from './components/Header';
import { Sidebar, TabId } from './components/Sidebar';
import { SystemDashboard } from './components/SystemDashboard';
import { UserManagement } from './components/UserManagement';
import { MasterData } from './components/MasterData';
import { Communication } from './components/Communication';
import { SystemSettings } from './components/SystemSettings';
import { DashboardBundle } from './types';
import { Loader2, AlertCircle } from 'lucide-react';

export default function App() {
  const [currentTab, setCurrentTab] = useState<TabId>('dashboard');
  const [data, setData] = useState<DashboardBundle | null>(null);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  const fetchBootstrapData = async () => {
    try {
      setLoading(true);
      setError(null);
      const res = await fetch('/api/admin/bootstrap');
      const json = await res.json();
      if (json.success) {
        setData(json.data);
      } else {
        setError(json.message || 'Không thể tải dữ liệu từ Aiven Cloud MySQL');
      }
    } catch (err: any) {
      setError(err.message || 'Lỗi kết nối máy chủ Express Web Admin');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchBootstrapData();
    // Auto-refresh every 60 seconds
    const interval = setInterval(fetchBootstrapData, 60000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col font-sans">
      {/* Top Header */}
      <Header data={data} loading={loading} onRefresh={fetchBootstrapData} />

      {/* Main Layout: Sidebar + Content */}
      <div className="flex-1 flex overflow-hidden">
        {/* Navigation Sidebar */}
        <Sidebar currentTab={currentTab} onTabChange={setCurrentTab} data={data} />

        {/* Content Pane */}
        <main className="flex-1 overflow-y-auto p-6 max-w-7xl mx-auto w-full">
          {error ? (
            <div className="p-6 rounded-2xl bg-rose-500/10 border border-rose-500/30 text-rose-300 flex items-start space-x-3">
              <AlertCircle className="w-5 h-5 text-rose-400 shrink-0 mt-0.5" />
              <div>
                <h3 className="font-bold text-sm text-white">Lỗi kết nối Cơ sở dữ liệu Aiven Cloud</h3>
                <p className="text-xs text-rose-200 mt-1">{error}</p>
                <button
                  onClick={fetchBootstrapData}
                  className="mt-3 px-3.5 py-1.5 rounded-lg bg-rose-600 hover:bg-rose-500 text-white text-xs font-semibold"
                >
                  Thử kết nối lại
                </button>
              </div>
            </div>
          ) : !data && loading ? (
            <div className="h-96 flex flex-col items-center justify-center space-y-3">
              <Loader2 className="w-8 h-8 text-sky-400 animate-spin" />
              <p className="text-xs text-slate-400 font-medium">Đang đồng bộ dữ liệu thời gian thực từ Aiven Cloud MySQL...</p>
            </div>
          ) : data ? (
            <div className="animate-in fade-in duration-300">
              {currentTab === 'dashboard' && <SystemDashboard data={data} />}
              {currentTab === 'users' && <UserManagement users={data.users} onRefresh={fetchBootstrapData} />}
              {currentTab === 'master' && (
                <MasterData categories={data.categories} currencies={data.currencies} onRefresh={fetchBootstrapData} />
              )}
              {currentTab === 'comms' && (
                <Communication notifications={data.notifications} feedbacks={data.feedbacks} onRefresh={fetchBootstrapData} />
              )}
              {currentTab === 'settings' && <SystemSettings data={data} onRefresh={fetchBootstrapData} />}
            </div>
          ) : null}
        </main>
      </div>
    </div>
  );
}


import { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { db, auth } from '../firebase';
import { onSnapshot, doc, collection, query, deleteDoc } from 'firebase/firestore';
import { Bell, AlertTriangle, ShieldCheck, Clock, Trash2 } from 'lucide-react';

const Alerts = () => {
  const { t } = useTranslation();
  const [pairingCode, setPairingCode] = useState(null);
  const [alerts, setAlerts] = useState([]);

  useEffect(() => {
    const user = auth.currentUser;
    if (!user) return;
    const unsubUser = onSnapshot(doc(db, 'users', user.uid), (docSnap) => {
      setPairingCode(docSnap.data()?.pairingCode);
    });
    return () => unsubUser();
  }, []);

  useEffect(() => {
    if (!pairingCode) return;
    // We cannot use orderBy('timestamp') without a composite index often, 
    // but for a simple sub-collection query, it might work if already indexed by Firestore console.
    // I'll stick to a simple query to ensure it always works for the demo.
    const q = collection(db, 'alerts', pairingCode, 'items');
    const unsubAlerts = onSnapshot(q, (snap) => {
      const items = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      // Sort manually in JS for safety
      items.sort((a, b) => {
        const timeA = a.createdAt?.seconds || 0;
        const timeB = b.createdAt?.seconds || 0;
        return timeB - timeA;
      });
      setAlerts(items);
    });
    return () => unsubAlerts();
  }, [pairingCode]);

  const handleDelete = async (alertId) => {
    if (!window.confirm(t('deleteAlertConfirm'))) return;
    try {
      await deleteDoc(doc(db, 'alerts', pairingCode, 'items', alertId));
    } catch (err) {
      console.error("Error deleting alert:", err);
    }
  };

  const formatTime = (ts) => {
    if (!ts) return 'Just now';
    try {
      const date = ts.toDate ? ts.toDate() : new Date(ts);
      return date.toLocaleString([], { 
        hour: '2-digit', 
        minute: '2-digit', 
        month: 'short', 
        day: 'numeric' 
      });
    } catch (e) {
      return 'Recent';
    }
  };

  return (
    <div className="p-10 pl-32 max-w-6xl mx-auto transition-colors duration-300">
      <div className="flex items-center justify-between mb-10">
        <div>
          <h1 className="text-3xl font-extrabold text-slate-900 dark:text-white transition-colors duration-300">{t('safetyAlerts')}</h1>
          <p className="text-slate-500 dark:text-slate-400 mt-1 transition-colors duration-300">{t('monitorEvents')}</p>
        </div>
        <div className="flex gap-3">
          <div className="px-4 py-2 bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700/50 text-slate-900 dark:text-white text-sm font-semibold flex items-center gap-2 shadow-sm transition-colors duration-300">
            <span className="w-3 h-3 bg-danger rounded-full animate-pulse" />
            {t('liveMonitoring')}
          </div>
        </div>
      </div>

      <div className="bg-white dark:bg-slate-800 rounded-[32px] shadow-xl border border-slate-100 dark:border-slate-700/50 overflow-hidden transition-colors duration-300">
        <table className="w-full text-left">
          <thead>
            <tr className="bg-slate-50 dark:bg-slate-800/50 border-b border-slate-100 dark:border-slate-700/50">
              <th className="px-8 py-5 text-sm font-bold text-slate-400 dark:text-slate-500 uppercase tracking-widest">{t('event')}</th>
              <th className="px-8 py-5 text-sm font-bold text-slate-400 dark:text-slate-500 uppercase tracking-widest">{t('alertType')}</th>
              <th className="px-8 py-5 text-sm font-bold text-slate-400 dark:text-slate-500 uppercase tracking-widest">{t('time')}</th>
              <th className="px-8 py-5 text-sm font-bold text-slate-400 dark:text-slate-500 uppercase tracking-widest text-center">{t('status')}</th>
              <th className="px-8 py-5 text-sm font-bold text-slate-400 dark:text-slate-500 uppercase tracking-widest text-right">{t('actions')}</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-50 dark:divide-slate-700/50">
            {alerts.map((alert) => (
              <tr key={alert.id} className="hover:bg-slate-50 dark:hover:bg-slate-700/30 transition-colors">
                <td className="px-8 py-6">
                  <div className="flex items-center gap-4">
                    <div className={`p-3 rounded-2xl ${alert.type === 'SOS' ? 'bg-danger/10 text-danger' : 'bg-secondary/10 text-secondary'}`}>
                      {alert.type === 'SOS' ? <AlertTriangle className="w-5 h-5" /> : <ShieldCheck className="w-5 h-5" />}
                    </div>
                    <div>
                      <p className="font-bold text-slate-900 dark:text-white transition-colors">{alert.title}</p>
                      <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5 transition-colors">{alert.message}</p>
                    </div>
                  </div>
                </td>
                <td className="px-8 py-6">
                  <span className={`px-3 py-1 rounded-full text-[10px] font-black uppercase tracking-widest ${
                    alert.type === 'SOS' ? 'bg-danger text-white' : 'bg-slate-100 dark:bg-slate-700 text-slate-500 dark:text-slate-300'
                  }`}>
                    {alert.type}
                  </span>
                </td>
                <td className="px-8 py-6">
                  <div className="flex items-center gap-2 text-slate-500 dark:text-slate-400 text-sm">
                    <Clock className="w-4 h-4" />
                    {formatTime(alert.createdAt)}
                  </div>
                </td>
                <td className="px-8 py-6 text-center">
                  <span className={`px-4 py-2 rounded-xl text-sm font-bold ${
                    alert.status === 'active' 
                      ? 'bg-danger/10 text-danger animate-pulse' 
                      : 'bg-green-100 text-green-700'
                  }`}>
                    {alert.status === 'active' ? t('active') : t('resolved')}
                  </span>
                </td>
                <td className="px-8 py-6 text-right">
                  <button 
                    onClick={() => handleDelete(alert.id)}
                    className="p-2 text-slate-400 hover:text-danger hover:bg-danger/10 rounded-lg transition-all"
                  >
                    <Trash2 className="w-5 h-5" />
                  </button>
                </td>
              </tr>
            ))}

            {alerts.length === 0 && (
              <tr>
                <td colSpan="4" className="px-8 py-20 text-center">
                  <div className="w-20 h-20 bg-slate-50 dark:bg-slate-700/50 rounded-full flex items-center justify-center mx-auto mb-4 transition-colors duration-300">
                    <Bell className="text-slate-300 dark:text-slate-500 w-10 h-10" />
                  </div>
                  <p className="text-slate-400 dark:text-slate-500 font-medium transition-colors">{t('noAlerts')}</p>
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default Alerts;

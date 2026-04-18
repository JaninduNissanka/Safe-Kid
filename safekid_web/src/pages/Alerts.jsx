import { useState, useEffect } from 'react';
import { db, auth } from '../firebase';
import { onSnapshot, doc, collection, query, deleteDoc } from 'firebase/firestore';
import { Bell, AlertTriangle, ShieldCheck, Clock, Trash2 } from 'lucide-react';

const Alerts = () => {
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
    if (!window.confirm("Are you sure you want to remove this alert from history?")) return;
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
    <div className="p-10 max-w-6xl mx-auto">
      <div className="flex items-center justify-between mb-10">
        <div>
          <h1 className="text-3xl font-extrabold text-slate-900">Safety Alerts</h1>
          <p className="text-slate-500 mt-1">Monitor all emergency and geofence events</p>
        </div>
        <div className="flex gap-3">
          <div className="px-4 py-2 bg-white rounded-xl border border-slate-200 text-sm font-semibold flex items-center gap-2">
            <span className="w-3 h-3 bg-danger rounded-full animate-pulse" />
            Live Monitoring
          </div>
        </div>
      </div>

      <div className="bg-white rounded-[32px] shadow-xl border border-slate-100 overflow-hidden">
        <table className="w-full text-left">
          <thead>
            <tr className="bg-slate-50 border-b border-slate-100">
              <th className="px-8 py-5 text-sm font-bold text-slate-400 uppercase tracking-widest">Event</th>
              <th className="px-8 py-5 text-sm font-bold text-slate-400 uppercase tracking-widest">Alert Type</th>
              <th className="px-8 py-5 text-sm font-bold text-slate-400 uppercase tracking-widest">Time</th>
              <th className="px-8 py-5 text-sm font-bold text-slate-400 uppercase tracking-widest text-center">Status</th>
              <th className="px-8 py-5 text-sm font-bold text-slate-400 uppercase tracking-widest text-right">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-50">
            {alerts.map((alert) => (
              <tr key={alert.id} className="hover:bg-slate-50 transition-colors">
                <td className="px-8 py-6">
                  <div className="flex items-center gap-4">
                    <div className={`p-3 rounded-2xl ${alert.type === 'SOS' ? 'bg-danger/10 text-danger' : 'bg-secondary/10 text-secondary'}`}>
                      {alert.type === 'SOS' ? <AlertTriangle className="w-5 h-5" /> : <ShieldCheck className="w-5 h-5" />}
                    </div>
                    <div>
                      <p className="font-bold text-slate-900">{alert.title}</p>
                      <p className="text-xs text-slate-500 mt-0.5">{alert.message}</p>
                    </div>
                  </div>
                </td>
                <td className="px-8 py-6">
                  <span className={`px-3 py-1 rounded-full text-[10px] font-black uppercase tracking-widest ${
                    alert.type === 'SOS' ? 'bg-danger text-white' : 'bg-slate-100 text-slate-500'
                  }`}>
                    {alert.type}
                  </span>
                </td>
                <td className="px-8 py-6">
                  <div className="flex items-center gap-2 text-slate-500 text-sm">
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
                    {alert.status === 'active' ? 'ACTIVE' : 'RESOLVED'}
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
                  <div className="w-20 h-20 bg-slate-50 rounded-full flex items-center justify-center mx-auto mb-4">
                    <Bell className="text-slate-300 w-10 h-10" />
                  </div>
                  <p className="text-slate-400 font-medium">No safety alerts captured yet.</p>
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

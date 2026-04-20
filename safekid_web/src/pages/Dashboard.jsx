import { useState, useEffect } from 'react';
import { GoogleMap, useJsApiLoader, Marker, Circle } from '@react-google-maps/api';
import { db, auth } from '../firebase';
import { doc, onSnapshot, collection, query, where } from 'firebase/firestore';
import { Smartphone, MapPin, Signal, Battery, Crosshair, Loader2, AlertTriangle, Navigation } from 'lucide-react';

const containerStyle = { width: '100%', height: '100%' };

const Dashboard = () => {
  const { isLoaded } = useJsApiLoader({
    id: 'google-map-script',
    googleMapsApiKey: "AIzaSyAPzTmlDUga-B7olx8p9-ai2BbRNl6v4S4"
  });

  const [pairingCode, setPairingCode] = useState(null);
  const [childData, setChildData] = useState(null);
  const [zones, setZones] = useState([]);
  const [activeAlerts, setActiveAlerts] = useState([]);
  const [map, setMap] = useState(null);

  useEffect(() => {
    const user = auth.currentUser;
    if (!user) return;

    const unsubUser = onSnapshot(doc(db, 'users', user.uid), (docSnap) => {
      const code = docSnap.data()?.pairingCode;
      if (code) setPairingCode(code);
    });

    return () => unsubUser();
  }, []);

  useEffect(() => {
    if (!pairingCode) return;

    const unsubLoc = onSnapshot(doc(db, 'locations', pairingCode), (docSnap) => {
      if (docSnap.exists()) {
        const data = docSnap.data();
        setChildData({
          ...data,
          latitude: Number(data.latitude),
          longitude: Number(data.longitude)
        });
      }
    });

    const q = query(collection(db, 'zones', pairingCode, 'items'));
    const unsubZones = onSnapshot(q, (snap) => {
      const items = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      setZones(items.filter(z => z.isActive !== false));
    });

    // 🚨 Listen for ACTIVE Geofence Alerts
    const alertQuery = query(
      collection(db, 'alerts', pairingCode, 'items'),
      where('status', '==', 'active'),
      where('type', '==', 'GEOFENCE_EXIT')
    );
    const unsubAlerts = onSnapshot(alertQuery, (snap) => {
      setActiveAlerts(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    });

    return () => { unsubLoc(); unsubZones(); unsubAlerts(); };
  }, [pairingCode]);

  const isOutside = activeAlerts.length > 0;

  const centerOnChild = () => {
    if (map && childData?.latitude) {
      const pos = { lat: childData.latitude, lng: childData.longitude };
      map.panTo(pos);
      map.setZoom(17);
    }
  };

  if (!isLoaded) return (
    <div className="flex items-center justify-center h-screen bg-slate-900 text-white">
      <Loader2 className="animate-spin mr-2" /> Initializing Map Engine...
    </div>
  );

  const getMapCenter = () => {
    if (childData?.latitude) return { lat: childData.latitude, lng: childData.longitude };
    if (zones.length > 0) return { lat: Number(zones[0].centerLat), lng: Number(zones[0].centerLng) };
    return { lat: 6.9271, lng: 79.8612 };
  };

  return (
    <div className="h-screen w-full bg-slate-50 relative overflow-hidden">
      {/* 🚨 EMERGENCY TOP BANNER (Mirrors Mobile App) */}
      {isOutside && (
        <div className="absolute top-6 left-1/2 -translate-x-1/2 z-20 w-fit">
          <div className="bg-red-600 text-white px-8 py-3 rounded-2xl shadow-[0_20px_50px_rgba(220,38,38,0.4)] flex items-center gap-4 animate-bounce border-2 border-red-400">
            <AlertTriangle className="w-6 h-6 animate-pulse" />
            <div className="flex flex-col">
              <span className="font-black text-sm uppercase tracking-tighter italic">GEOFENCE BREACH DETECTED!</span>
              <span className="text-[10px] font-bold opacity-80 uppercase tracking-widest">Child is currently outside the safe perimeter</span>
            </div>
            <button 
              onClick={centerOnChild}
              className="ml-4 bg-white text-red-600 px-4 py-1.5 rounded-xl font-black text-xs hover:bg-red-50 transition-colors flex items-center gap-1 shadow-sm"
            >
              <Navigation className="w-3 h-3" /> LOCATE
            </button>
          </div>
        </div>
      )}

      {/* 🚀 STATUS OVERLAY */}
      <div className="absolute top-8 left-8 z-10 flex flex-col gap-4 w-80">
        <div className={`bg-white/95 backdrop-blur-md p-6 rounded-[32px] shadow-2xl border-2 transition-all duration-500 ${isOutside ? 'border-red-500 ring-4 ring-red-500/20' : 'border-white/50 ring-1 ring-black/5'}`}>
          <div className="flex items-center gap-4 mb-6">
            <div className={`relative w-14 h-14 rounded-2xl flex items-center justify-center shadow-lg transition-colors ${isOutside ? 'bg-red-100' : (childData ? 'bg-primary/20 animate-pulse' : 'bg-slate-100')}`}>
              <Smartphone className={`w-8 h-8 ${isOutside ? 'text-red-600' : (childData ? 'text-primary' : 'text-slate-400')}`} />
              {isOutside && <span className="absolute -top-1 -right-1 flex h-4 w-4"><span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-red-400 opacity-75"></span><span className="relative inline-flex rounded-full h-4 w-4 bg-red-500"></span></span>}
            </div>
            <div>
              <h3 className={`font-black text-xl tracking-tight leading-none ${isOutside ? 'text-red-700' : 'text-slate-900'}`}>
                {childData?.name || (pairingCode ? 'SafeKid Active' : 'Setup Required')}
              </h3>
              <p className={`text-[10px] font-black uppercase tracking-[0.2em] mt-2 flex items-center gap-2 ${isOutside ? 'text-red-500' : 'text-slate-400'}`}>
                <span className={`w-2 h-2 rounded-full ${isOutside ? 'bg-red-600 animate-pulse' : (childData ? 'bg-green-500' : 'bg-slate-300')}`} />
                {isOutside ? 'OUTSIDE ZONE' : (childData ? 'Live Tracking' : 'Awaiting Signal')}
              </p>
            </div>
          </div>
          
          <div className="space-y-4 pt-4 border-t border-slate-100">
            <StatusItem icon={Signal} label="Signal" value={isOutside ? "Alert" : (childData ? "High" : "None")} color={isOutside ? "text-red-600" : (childData ? "text-green-500" : "text-danger")} />
            <StatusItem icon={Battery} label="Battery" value={childData?.battery ? `${childData.battery}%` : 'Offline'} color="text-slate-600" />
            <StatusItem icon={MapPin} label="Last Signal" value={childData?.lastUpdated ? new Date(childData.lastUpdated.seconds * 1000).toLocaleTimeString() : 'Awaiting...'} color="text-slate-400" />
          </div>

          <button 
            onClick={centerOnChild}
            className={`mt-6 w-full py-4 rounded-2xl font-bold flex items-center justify-center gap-2 transition-all shadow-xl active:scale-95 disabled:opacity-50 disabled:grayscale ${isOutside ? 'bg-red-600 text-white shadow-red-200 hover:bg-red-700' : 'bg-primary text-white shadow-primary/30 hover:bg-primary-dark'}`}
            disabled={!childData?.latitude}
          >
            <Crosshair className="w-6 h-6" /> {isOutside ? 'FORCE RE-CENTER' : 'Re-Center View'}
          </button>
        </div>
      </div>

      <div className="w-full h-full border-4 border-primary/5">
        <GoogleMap
          mapContainerStyle={{ width: '100%', height: '100%' }}
          center={getMapCenter()}
          zoom={14}
          onLoad={m => setMap(m)}
          options={{
            disableDefaultUI: false,
            zoomControl: true,
            mapTypeControl: true,
            streetViewControl: false,
            mapId: "f40e06059d33261a" 
          }}
        >
          {childData?.latitude && (
            <Marker
              position={{ lat: childData.latitude, lng: childData.longitude }}
              zIndex={999}
              label={{
                text: "📍 Child Point",
                className: `bg-white px-3 py-1.5 rounded-full border-2 font-black text-[10px] -mt-16 shadow-2xl uppercase tracking-tighter ${isOutside ? 'border-red-600 text-red-600 ring-4 ring-red-100' : 'border-primary text-primary shadow-primary/40'}`
              }}
            />
          )}

          {zones.map(z => (
            <Circle
              key={z.id}
              center={{ lat: Number(z.centerLat), lng: Number(z.centerLng) }}
              radius={Number(z.radiusMeters)}
              options={{
                fillColor: '#6366f1',
                fillOpacity: 0.15,
                strokeColor: '#6366f1',
                strokeOpacity: 0.4,
                strokeWeight: 2,
              }}
            />
          ))}
        </GoogleMap>
      </div>
    </div>
  );
};

const StatusItem = ({ icon: Icon, label, value, color }) => (
  <div className="flex items-center justify-between">
    <div className="flex items-center gap-3 text-slate-400">
      <Icon className="w-4 h-4" />
      <span className="text-[10px] font-bold uppercase tracking-widest">{label}</span>
    </div>
    <span className={`text-xs font-black ${color}`}>{value}</span>
  </div>
);

export default Dashboard;

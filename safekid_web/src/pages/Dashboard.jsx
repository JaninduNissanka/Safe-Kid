import { useState, useEffect } from 'react';
import { GoogleMap, useJsApiLoader, Marker, Circle } from '@react-google-maps/api';
import { db, auth } from '../firebase';
import { doc, onSnapshot, collection, query } from 'firebase/firestore';
import { Smartphone, MapPin, Signal, Battery, Crosshair } from 'lucide-react';

const containerStyle = { 
  width: '100%', 
  height: 'calc(100vh - 48px)', // Hard height to prevent flex collapse
  minHeight: '500px',
  borderRadius: '32px'
};

const Dashboard = () => {
  const { isLoaded } = useJsApiLoader({
    id: 'google-map-script',
    // Using the verified unrestricted key
    googleMapsApiKey: "AIzaSyAPzTmlDUga-B7olx8p9-ai2BbRNl6v4S4"
  });

  const [pairingCode, setPairingCode] = useState(null);
  const [childData, setChildData] = useState(null);
  const [zones, setZones] = useState([]);
  const [map, setMap] = useState(null);

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

    const unsubLoc = onSnapshot(doc(db, 'locations', pairingCode), (docSnap) => {
      if (docSnap.exists()) {
        setChildData(docSnap.data());
      }
    });

    const q = query(collection(db, 'zones', pairingCode, 'items'));
    const unsubZones = onSnapshot(q, (snap) => {
      const items = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      setZones(items.filter(z => z.isActive !== false));
    });

    return () => { unsubLoc(); unsubZones(); };
  }, [pairingCode]);

  const centerOnChild = () => {
    if (map && childData) {
      map.panTo({ lat: childData.latitude, lng: childData.longitude });
      map.setZoom(16);
    }
  };

  if (!isLoaded) return <div className="p-10 font-bold text-slate-400">Initializing Live Tracking...</div>;

  const defaultCenter = { lat: 6.9271, lng: 79.8612 };
  const mapCenter = childData ? { lat: childData.latitude, lng: childData.longitude } : defaultCenter;

  return (
    <div className="h-screen w-full bg-slate-50 relative overflow-hidden">
      {/* Dynamic Status Overlay */}
      <div className="absolute top-8 left-8 z-10 flex flex-col gap-4 w-72">
        <div className="bg-white/95 backdrop-blur-md p-6 rounded-[32px] shadow-2xl border border-white/50 ring-1 ring-black/5">
          <div className="flex items-center gap-3 mb-5">
            <div className="w-12 h-12 bg-primary/20 rounded-2xl flex items-center justify-center">
              <Smartphone className="text-primary w-7 h-7" />
            </div>
            <div>
              <h3 className="font-bold text-slate-900 text-lg leading-tight">{childData?.name || (pairingCode ? 'Searching...' : 'Account Setup')}</h3>
              <p className="text-[10px] text-slate-500 font-extrabold uppercase tracking-widest mt-0.5">
                {childData ? 'Live & Active' : 'Waiting for GPS'}
              </p>
            </div>
          </div>
          
          <div className="space-y-4 pt-4 border-t border-slate-100">
            <StatusItem icon={Signal} label="Signal" value={childData ? "High" : "Low"} color={childData ? "text-green-500" : "text-amber-500"} />
            <StatusItem icon={Battery} label="Battery" value={childData?.battery ? `${childData.battery}%` : 'Searching...'} color="text-slate-600" />
            <StatusItem icon={MapPin} label="Source" value={childData ? "GPS Direct" : "Satellite"} color="text-slate-600" />
          </div>

          <button 
            onClick={centerOnChild}
            className="mt-6 w-full py-4 bg-primary text-white rounded-2xl font-bold flex items-center justify-center gap-2 hover:bg-primary-dark transition-all shadow-xl shadow-primary/30 active:scale-95 disabled:opacity-50"
            disabled={!childData}
          >
            <Crosshair className="w-5 h-5" /> Re-Center View
          </button>
        </div>
      </div>

      <div className="w-full h-full border-4 border-primary/10">
        <GoogleMap
          mapContainerStyle={{ width: '100%', height: '100%' }}
          center={mapCenter}
          zoom={14}
          onLoad={m => setMap(m)}
          options={{
            disableDefaultUI: false,
            zoomControl: true,
            mapTypeControl: true,
            streetViewControl: false,
          }}
        >
          {childData?.latitude && (
            <Marker
              position={{ lat: childData.latitude, lng: childData.longitude }}
              title={childData.name || 'Child'}
              label={{
                text: "📍 " + (childData.name?.split(' ')[0] || 'Child'),
                className: "bg-white/80 px-2 py-1 rounded-lg border border-danger text-danger font-bold text-xs -mt-12 shadow-lg",
              }}
            />
          )}

          {zones.map(z => (
            <Circle
              key={z.id}
              center={{ lat: z.centerLat, lng: z.centerLng }}
              radius={z.radiusMeters}
              options={{
                fillColor: '#3b82f6',
                fillOpacity: 0.1,
                strokeColor: '#3b82f6',
                strokeOpacity: 0.5,
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
    <div className="flex items-center gap-2 text-slate-400">
      <Icon className="w-4 h-4" />
      <span className="text-xs font-semibold">{label}</span>
    </div>
    <span className={`text-xs font-bold ${color}`}>{value}</span>
  </div>
);

export default Dashboard;

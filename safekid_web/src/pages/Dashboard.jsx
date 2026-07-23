import { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { GoogleMap, useJsApiLoader, OverlayView, Circle } from '@react-google-maps/api';
import { db, auth } from '../firebase';
import { doc, onSnapshot, collection, query, orderBy, where } from 'firebase/firestore';
import { Smartphone, Signal, Battery, BatteryCharging, Wifi, WifiOff, Crosshair, Loader2, Shield, Map as MapIcon, CheckCircle2, AlertCircle, Activity, BellRing } from 'lucide-react';

const Dashboard = () => {
  const { t } = useTranslation();
  const { isLoaded } = useJsApiLoader({
    id: 'google-map-script',
    googleMapsApiKey: import.meta.env.VITE_GOOGLE_MAPS_API_KEY
  });

  const [pairingCode, setPairingCode] = useState(null);
  const [devices, setDevices] = useState([]);
  const [selectedChildId, setSelectedChildId] = useState(null);
  const [childData, setChildData] = useState(null);
  const [zones, setZones] = useState([]);
  const [activeAlerts, setActiveAlerts] = useState([]);
  const [map, setMap] = useState(null);
  const [isInsideLocal, setIsInsideLocal] = useState(true);
  const [timelineEvents, setTimelineEvents] = useState([]);

  // 1. Fetch User Pairing Code
  useEffect(() => {
    const user = auth.currentUser;
    if (!user) return;
    const unsubUser = onSnapshot(doc(db, 'users', user.uid), (docSnap) => {
      if (docSnap.exists()) setPairingCode(docSnap.data().pairingCode);
    });
    return () => unsubUser();
  }, []);

  // 2. Fetch All Data
  useEffect(() => {
    if (!pairingCode) return;

    const unsubLoc = onSnapshot(collection(db, 'locations', pairingCode, 'devices'), (snap) => {
      const devicesList = snap.docs.map(d => {
        const data = d.data();
        return {
          id: d.id,
          ...data,
          latitude: Number(data.latitude),
          longitude: Number(data.longitude),
          battery: Number(data.battery) || 0,
          batteryStatus: data.batteryStatus || 'unknown',
          connectionType: data.connectionType || 'unknown',
        };
      });
      setDevices(devicesList);
    });

    const unsubZones = onSnapshot(query(collection(db, 'zones', pairingCode, 'items'), orderBy('createdAt', 'desc')), (snap) => {
      setZones(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    });

    const unsubAlerts = onSnapshot(query(collection(db, 'alerts', pairingCode, 'items'), where('status', '==', 'active')), (snap) => {
      setActiveAlerts(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    });

    return () => { unsubLoc(); unsubZones(); unsubAlerts(); };
  }, [pairingCode]);

  // Sync selected child data
  useEffect(() => {
    if (devices.length === 0) {
      setChildData(null);
      return;
    }
    let selectedId = selectedChildId;
    if (!selectedId || !devices.find(d => d.id === selectedId)) {
      selectedId = devices[0].id;
      setSelectedChildId(selectedId);
    }
    const activeChild = devices.find(d => d.id === selectedId);
    if (activeChild) {
      setChildData(activeChild);
    }
  }, [devices, selectedChildId]);

  // 3. Fetch Timeline Events
  useEffect(() => {
    if (!pairingCode || !selectedChildId) return;

    const todayDateStr = (() => {
      const d = new Date();
      return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
    })();

    const q = query(
      collection(db, 'locations', pairingCode, 'devices', selectedChildId, 'timeline'),
      where('dateStr', '==', todayDateStr),
      orderBy('timestamp', 'asc')
    );

    const unsubTimeline = onSnapshot(q, (snap) => {
      setTimelineEvents(snap.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
        timestamp: doc.data().timestamp?.toDate()
      })));
    });

    return () => unsubTimeline();
  }, [pairingCode, selectedChildId]);

  // SMART SAFETY CHECK: Local distance verification
  useEffect(() => {
    if (!childData || zones.length === 0) return;
    
    const activeZone = zones.find(z => z.isActive);
    if (!activeZone) return;

    const dist = calculateDistance(
      childData.latitude, childData.longitude,
      Number(activeZone.centerLat), Number(activeZone.centerLng)
    );

    setIsInsideLocal(dist <= Number(activeZone.radiusMeters));
  }, [childData, zones]);

  const calculateDistance = (lat1, lon1, lat2, lon2) => {
    const p = 0.017453292519943295;
    const a = 0.5 - Math.cos((lat2 - lat1) * p) / 2 +
              Math.cos(lat1 * p) * Math.cos(lat2 * p) *
              (1 - Math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * Math.asin(Math.sqrt(a)) * 1000;
  };

  const centerOnChild = () => {
    if (map && childData) map.panTo({ lat: childData.latitude, lng: childData.longitude });
  };

  const formatTime = (date) => {
    if (!date) return '--:--';
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  };

  if (!isLoaded) return <div className="h-screen bg-slate-900 text-white flex items-center justify-center"><Loader2 className="animate-spin" /></div>;

  const isActuallyOutside = activeAlerts.length > 0 && !isInsideLocal;
  const isSafe = !isActuallyOutside;

  return (
    <div className="h-screen w-full relative overflow-hidden font-['Outfit']">
      
      {/* MAP VIEW (Full Bleed Background) */}
      <div className="absolute inset-0 z-0">
        <GoogleMap
          mapContainerStyle={{ width: '100%', height: '100%' }}
          center={childData ? { lat: childData.latitude, lng: childData.longitude } : { lat: 6.9271, lng: 79.8612 }}
          zoom={14}
          onLoad={m => setMap(m)}
          options={{ disableDefaultUI: false, mapId: "f40e06059d33261a" }}
        >
          {devices.map(child => {
            const isChildSelected = child.id === selectedChildId;
            const activeZone = zones.find(z => z.isActive);
            const dist = activeZone 
              ? calculateDistance(child.latitude, child.longitude, Number(activeZone.centerLat), Number(activeZone.centerLng))
              : 0;
            const childIsOutside = activeZone && dist > Number(activeZone.radiusMeters);
            const isChildSosActive = child.isSosActive;

            const markerBgColor = isChildSosActive 
              ? 'bg-red-600 animate-bounce' 
              : childIsOutside 
                ? 'bg-orange-500' 
                : 'bg-blue-500';

            return (
              <OverlayView
                key={child.id}
                position={{ lat: child.latitude, lng: child.longitude }}
                mapPaneName={OverlayView.OVERLAY_MOUSE_TARGET}
                getPixelPositionOffset={(width, height) => ({
                  x: -(width / 2),
                  y: -height,
                })}
              >
                <div 
                  onClick={() => setSelectedChildId(child.id)}
                  className={`flex flex-col items-center cursor-pointer hover:scale-110 transition-transform origin-bottom drop-shadow-2xl ${isChildSelected ? 'scale-105 z-10' : 'opacity-80'}`}
                >
                  <div className={`w-14 h-14 rounded-full border-4 ${isChildSelected ? 'border-indigo-400' : 'border-white'} shadow-lg flex items-center justify-center text-2xl ${markerBgColor}`}>
                    👦
                  </div>
                  <div className={`px-4 py-1 rounded-full mt-1 shadow-md border-2 border-white ${isChildSosActive ? 'bg-red-600 text-white' : childIsOutside ? 'bg-orange-500 text-white' : 'bg-blue-500 text-white'}`}>
                    <span className="text-[10px] font-black uppercase tracking-widest">{child.name}</span>
                  </div>
                </div>
              </OverlayView>
            );
          })}

          {zones.map(z => (
            <Circle 
              key={z.id}
              center={{ lat: Number(z.centerLat), lng: Number(z.centerLng) }}
              radius={Number(z.radiusMeters)}
              options={{ 
                fillColor: z.isActive ? (isActuallyOutside ? '#dc2626' : '#4f46e5') : '#94a3b8', 
                fillOpacity: z.isActive ? 0.1 : 0.05, 
                strokeColor: z.isActive ? (isActuallyOutside ? '#dc2626' : '#4f46e5') : '#cbd5e1', 
                strokeWeight: z.isActive ? 2 : 1 
              }}
            />
          ))}
        </GoogleMap>
      </div>

      {/* FLOATING COMMAND PANEL (Glassmorphism) */}
      <div className="absolute top-6 bottom-6 left-36 w-[400px] bg-white/85 dark:bg-slate-800/85 backdrop-blur-2xl border border-white/50 dark:border-slate-700/50 p-8 flex flex-col gap-8 shadow-[0_8px_40px_rgba(0,0,0,0.12)] z-10 overflow-y-auto rounded-[32px] transition-colors duration-300">
        
        {/* CHILD SELECTOR TABS */}
        {devices.length > 0 && (
          <section className="flex flex-wrap gap-2 px-2 shrink-0">
            {devices.map(child => {
              const isChildSelected = child.id === selectedChildId;
              const isChildSosActive = child.isSosActive;
              const activeZone = zones.find(z => z.isActive);
              const dist = activeZone 
                ? calculateDistance(child.latitude, child.longitude, Number(activeZone.centerLat), Number(activeZone.centerLng))
                : 0;
              const childIsOutside = activeZone && dist > Number(activeZone.radiusMeters);

              let statusColor = 'border-slate-200 text-slate-600 dark:text-slate-400 bg-white/50 dark:bg-slate-850';
              if (isChildSelected) {
                statusColor = isChildSosActive 
                  ? 'border-red-500 bg-red-500/10 text-red-600' 
                  : childIsOutside 
                    ? 'border-orange-500 bg-orange-500/10 text-orange-600' 
                    : 'border-indigo-600 bg-indigo-600/10 text-indigo-600';
              }

              return (
                <button
                  key={child.id}
                  onClick={() => setSelectedChildId(child.id)}
                  className={`px-4 py-2 rounded-full border text-xs font-black uppercase tracking-wider transition-all duration-300 hover:scale-105 active:scale-95 ${statusColor}`}
                >
                  <span className="flex items-center gap-1.5">
                    {isChildSosActive ? '🚨 ' : childIsOutside ? '⚠️ ' : '👦 '}
                    {child.name}
                  </span>
                </button>
              );
            })}
          </section>
        )}
        
        {/* REFINED STATUS CARD */}
        <section className={`p-6 rounded-[28px] border transition-all duration-500 ${isSafe ? 'bg-indigo-50/80 dark:bg-indigo-500/10 border-indigo-100 dark:border-indigo-500/20 shadow-sm' : 'bg-red-50 dark:bg-red-500/10 border-red-100 dark:border-red-500/20 shadow-sm'}`}>
          <div className="flex items-center gap-5">
            <div className={`w-14 h-14 rounded-[20px] flex items-center justify-center shadow-md shrink-0 ${isSafe ? 'bg-indigo-600 text-white' : 'bg-red-600 text-white'}`}>
              {isSafe ? <CheckCircle2 className="w-7 h-7" /> : <AlertCircle className="w-7 h-7" />}
            </div>
            <div>
              <h2 className="font-black text-xl text-slate-900 dark:text-white tracking-tight leading-none mb-1">{childData?.name || t('monitoring')}</h2>
              <p className={`text-[10px] font-black uppercase tracking-[0.15em] mb-3 ${isSafe ? 'text-green-600' : 'text-red-600'}`}>
                {isSafe ? t('perfectlySafe') : t('outsideSafeZone')}
              </p>
              
              {/* COMPACT PILLS */}
              <div className="flex items-center gap-2">
                <div className="flex items-center gap-1.5 px-3 py-1.5 bg-white dark:bg-slate-800 rounded-full shadow-sm border border-slate-100 dark:border-slate-700/50 transition-colors duration-300">
                  {childData?.batteryStatus === 'charging' ? (
                    <BatteryCharging className="w-3.5 h-3.5 text-green-500" />
                  ) : (
                    <Battery className={`w-3.5 h-3.5 ${
                      childData?.battery <= 20 
                        ? 'text-red-500' 
                        : childData?.battery <= 50 
                          ? 'text-orange-500' 
                          : 'text-green-500'
                    }`} />
                  )}
                  <span className="text-[10px] font-bold text-slate-700 dark:text-slate-300">
                    {childData?.battery !== undefined ? `${childData.battery}%` : '---'}
                    {childData?.batteryStatus === 'charging' && ' (Charging)'}
                  </span>
                </div>
                <div className="flex items-center gap-1.5 px-3 py-1.5 bg-white dark:bg-slate-800 rounded-full shadow-sm border border-slate-100 dark:border-slate-700/50 transition-colors duration-300">
                  {!childData?.isOnline || childData?.connectionType === 'offline' ? (
                    <WifiOff className="w-3.5 h-3.5 text-slate-400" />
                  ) : childData?.connectionType === 'wifi' ? (
                    <Wifi className="w-3.5 h-3.5 text-green-500" />
                  ) : childData?.connectionType === 'cellular' ? (
                    <Signal className="w-3.5 h-3.5 text-green-500" />
                  ) : (
                    <Wifi className="w-3.5 h-3.5 text-green-500" />
                  )}
                  <span className="text-[10px] font-bold text-slate-700 dark:text-slate-300">
                    {!childData?.isOnline || childData?.connectionType === 'offline' 
                      ? t('offline') 
                      : childData?.connectionType === 'wifi' 
                        ? 'WiFi' 
                        : childData?.connectionType === 'cellular' 
                          ? 'Cellular' 
                          : t('strong')
                    }
                  </span>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* ZONES LIST */}
        <section>
          <div className="flex items-center gap-2 mb-4 px-2">
            <Shield className="w-4 h-4 text-slate-400" />
            <h3 className="text-[10px] font-black text-slate-400 uppercase tracking-[0.2em]">{t('safetyPerimeterSettings')}</h3>
          </div>
          
          <div className="space-y-3">
            {zones.map(z => (
              <div key={z.id} className={`p-4 rounded-[24px] border transition-all ${z.isActive ? 'border-indigo-200 dark:border-indigo-500/20 bg-white dark:bg-slate-800/50 shadow-md shadow-indigo-100/20' : 'border-slate-100 dark:border-slate-700/50 opacity-40 grayscale'}`}>
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-4">
                    <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${z.isActive ? 'bg-indigo-100 dark:bg-indigo-500/20 text-indigo-600 dark:text-indigo-400' : 'bg-slate-100 dark:bg-slate-800 text-slate-400'}`}>
                      <MapIcon className="w-5 h-5" />
                    </div>
                    <div>
                      <p className="text-sm font-black text-slate-800 dark:text-slate-200">{t('zoneRadius', { radius: z.radiusMeters })}</p>
                      <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mt-0.5">
                        {z.isActive ? t('activelyMonitoring') : t('inactive')}
                      </p>
                    </div>
                  </div>
                  {z.isActive && <div className="w-2.5 h-2.5 rounded-full bg-indigo-600 animate-pulse shadow-[0_0_10px_rgba(79,70,229,0.5)]" />}
                </div>
              </div>
            ))}
          </div>
        </section>

        {/* DAY TIMELINE FEED */}
        <section>
          <div className="flex items-center gap-2 mb-4 px-2">
            <Activity className="w-4 h-4 text-slate-400" />
            <h3 className="text-[10px] font-black text-slate-400 uppercase tracking-[0.2em]">Day Timeline Log</h3>
          </div>
          
          <div className="p-6 rounded-[28px] border border-slate-100 dark:border-slate-700/50 bg-slate-50/80 dark:bg-slate-800/80 max-h-[220px] overflow-y-auto flex flex-col gap-4">
            {timelineEvents.length > 0 ? (
              <div className="flex flex-col gap-4 relative">
                {/* Timeline vertical bar */}
                <div className="absolute left-3 top-2 bottom-2 w-0.5 bg-slate-200 dark:bg-slate-700" />
                
                {timelineEvents.map((event, idx) => {
                  let icon = <Activity className="w-3.5 h-3.5" />;
                  let colorClass = 'text-indigo-600 dark:text-indigo-400 bg-indigo-50 dark:bg-indigo-950/50';
                  
                  if (event.type === 'alert_sos') {
                    colorClass = 'text-red-600 dark:text-red-400 bg-red-50 dark:bg-red-950/50';
                  } else if (event.type === 'sos_resolved') {
                    colorClass = 'text-green-600 dark:text-green-400 bg-green-50 dark:bg-green-950/50';
                  } else if (event.type === 'alert_geofence') {
                    colorClass = 'text-orange-600 dark:text-orange-400 bg-orange-50 dark:bg-orange-950/50';
                  } else if (event.type === 'geofence_return') {
                    colorClass = 'text-blue-600 dark:text-blue-400 bg-blue-50 dark:bg-blue-950/50';
                  } else if (event.type === 'alert_speed') {
                    colorClass = 'text-amber-600 dark:text-amber-400 bg-amber-50 dark:bg-amber-950/50';
                  } else if (event.type === 'alert_anomaly') {
                    colorClass = 'text-purple-600 dark:text-purple-400 bg-purple-50 dark:bg-purple-950/50';
                  }

                  const hasCoords = event.latitude && event.longitude;

                  return (
                    <div 
                      key={event.id} 
                      className={`flex items-start gap-4 pl-1 relative group ${hasCoords ? 'cursor-pointer' : ''}`}
                      onClick={() => {
                        if (hasCoords && map) {
                          map.panTo({ lat: Number(event.latitude), lng: Number(event.longitude) });
                          map.setZoom(16);
                        }
                      }}
                    >
                      {/* Circle indicator */}
                      <div className={`w-6 h-6 rounded-full flex items-center justify-center shrink-0 z-10 border-2 border-white dark:border-slate-800 ${colorClass}`}>
                        {icon}
                      </div>
                      
                      {/* Text details */}
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between gap-2">
                          <p className="text-xs font-black text-slate-800 dark:text-slate-200 truncate">{event.title}</p>
                          <span className="text-[9px] font-bold text-slate-400 shrink-0">{formatTime(event.timestamp)}</span>
                        </div>
                        <p className="text-[10px] font-medium text-slate-500 dark:text-slate-400 mt-0.5 leading-tight">{event.message}</p>
                        {hasCoords && (
                          <span className="text-[8px] font-black text-indigo-500 hover:text-indigo-600 dark:text-indigo-400 tracking-wider uppercase mt-1 inline-block opacity-0 group-hover:opacity-100 transition-opacity">
                            Click to show location
                          </span>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            ) : (
              <div className="flex flex-col items-center justify-center py-6 text-center">
                <p className="text-xs font-black text-slate-700 dark:text-slate-300">No events logged today</p>
                <p className="text-[10px] font-bold text-slate-400 dark:text-slate-500 mt-1 uppercase tracking-wider">Waiting for telemetry logs...</p>
              </div>
            )}
          </div>
        </section>

        {/* QUICK ACTIONS */}
        <section className="grid grid-cols-2 gap-4">
          <button className="flex flex-col items-center justify-center p-5 rounded-[28px] bg-white dark:bg-slate-800 hover:bg-indigo-50 dark:hover:bg-slate-700 transition-all border border-slate-100 dark:border-slate-700/50 shadow-sm group">
            <div className="w-12 h-12 rounded-[18px] bg-slate-50 dark:bg-slate-900 flex items-center justify-center mb-3 group-hover:bg-indigo-100 dark:group-hover:bg-indigo-500/20 group-hover:text-indigo-600 dark:group-hover:text-indigo-400 text-slate-400 transition-colors shadow-inner">
              <Smartphone className="w-6 h-6" />
            </div>
            <span className="text-[10px] font-black uppercase tracking-widest text-slate-500 dark:text-slate-400 group-hover:text-indigo-600 dark:group-hover:text-indigo-400 transition-colors">{t('pingDevice')}</span>
          </button>
          
          <button className="flex flex-col items-center justify-center p-5 rounded-[28px] bg-white dark:bg-slate-800 hover:bg-red-50 dark:hover:bg-slate-700 transition-all border border-slate-100 dark:border-slate-700/50 shadow-sm group">
            <div className="w-12 h-12 rounded-[18px] bg-slate-50 dark:bg-slate-900 flex items-center justify-center mb-3 group-hover:bg-red-100 dark:group-hover:bg-red-500/20 group-hover:text-red-600 dark:group-hover:text-red-400 text-slate-400 transition-colors shadow-inner">
              <BellRing className="w-6 h-6" />
            </div>
            <span className="text-[10px] font-black uppercase tracking-widest text-slate-500 dark:text-slate-400 group-hover:text-red-600 dark:group-hover:text-red-400 transition-colors">{t('soundAlarm')}</span>
          </button>
        </section>

        {/* SYSTEM STATUS / ALERTS */}
        <section className="mt-auto">
          <div className="flex items-center gap-2 mb-4 px-2">
            <Activity className="w-4 h-4 text-slate-400" />
            <h3 className="text-[10px] font-black text-slate-400 uppercase tracking-[0.2em]">{t('liveTelemetry')}</h3>
          </div>
          
          <div className="p-6 rounded-[28px] border border-slate-100 dark:border-slate-700/50 bg-slate-50/80 dark:bg-slate-800/80 transition-colors duration-300">
            {activeAlerts.length > 0 ? (
              <div className="space-y-4">
                 {activeAlerts.map(alert => (
                    <div key={alert.id} className="flex items-start gap-3">
                       <div className="w-2.5 h-2.5 rounded-full bg-red-500 mt-1 shadow-[0_0_8px_rgba(239,68,68,0.6)] animate-pulse" />
                       <div>
                         <p className="text-sm font-black text-slate-800 dark:text-slate-200 leading-tight">{t('securityAlertTriggered')}</p>
                         <p className="text-[10px] font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider mt-1">{alert.type || 'GEOFENCE BREACH'}</p>
                       </div>
                    </div>
                 ))}
              </div>
            ) : (
              <div className="flex flex-col items-center justify-center py-4 text-center">
                <div className="w-12 h-12 rounded-full bg-green-50 dark:bg-green-500/10 flex items-center justify-center mb-3">
                  <CheckCircle2 className="w-6 h-6 text-green-500 dark:text-green-400" />
                </div>
                <p className="text-xs font-black text-slate-700 dark:text-slate-300">{t('allSystemsOperational')}</p>
                <p className="text-[10px] font-bold text-slate-400 dark:text-slate-500 mt-1 uppercase tracking-wider">{t('noActiveThreats')}</p>
              </div>
            )}
          </div>
        </section>
      </div>

      {/* FLOATING ACTION BUTTON (Snap to Location) */}
      <button 
        onClick={centerOnChild}
        className="absolute bottom-10 right-10 z-10 bg-white dark:bg-slate-800 text-slate-900 dark:text-white px-6 py-4 rounded-full font-black text-xs uppercase tracking-[0.15em] hover:bg-indigo-50 dark:hover:bg-slate-700 transition-all flex items-center gap-3 shadow-[0_8px_30px_rgba(0,0,0,0.12)] border border-slate-100 dark:border-slate-700/50 active:scale-95"
      >
        <Crosshair className="w-5 h-5 text-indigo-600" /> {t('snapToLocation')}
      </button>

    </div>
  );
};

export default Dashboard;

import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';

const resources = {
  en: {
    translation: {
      // Settings
      theme: "Theme",
      language: "Language",
      accountSecurity: "Account Security",
      changePassword: "Change Password",
      twoFactor: "Two-Factor Authentication",
      preferences: "Preferences",
      dangerZone: "Danger Zone",
      signOut: "Sign Out",
      deleteAccount: "Delete Account",
      
      // Dashboard
      perfectlySafe: "Perfectly Safe",
      outsideSafeZone: "Outside Safe Zone",
      monitoring: "Monitoring...",
      strong: "Strong",
      offline: "Offline",
      safetyPerimeterSettings: "Safety Perimeter Settings",
      zoneRadius: "{{radius}}m Zone",
      activelyMonitoring: "Actively Monitoring",
      inactive: "Inactive",
      pingDevice: "Ping Device",
      soundAlarm: "Sound Alarm",
      liveTelemetry: "Live Telemetry",
      securityAlertTriggered: "Security Alert Triggered",
      allSystemsOperational: "All Systems Operational",
      noActiveThreats: "No Active Threats",
      snapToLocation: "Snap to Location",

      // Alerts
      safetyAlerts: "Safety Alerts",
      monitorEvents: "Monitor all emergency and geofence events",
      liveMonitoring: "Live Monitoring",
      event: "Event",
      alertType: "Alert Type",
      time: "Time",
      status: "Status",
      actions: "Actions",
      active: "ACTIVE",
      resolved: "RESOLVED",
      noAlerts: "No safety alerts captured yet.",
      childPlaceholder: "Child",
      deleteAlertConfirm: "Are you sure you want to remove this alert from history?"
    }
  },
  si: {
    translation: {
      // Settings
      theme: "තේමාව",
      language: "භාෂාව",
      accountSecurity: "ගිණුම් ආරක්ෂාව",
      changePassword: "මුරපදය වෙනස් කරන්න",
      twoFactor: "ද්වි-සාධක සත්‍යාපනය",
      preferences: "මනාපයන්",
      dangerZone: "අනතුරුදායක කලාපය",
      signOut: "ඉවත් වන්න",
      deleteAccount: "ගිණුම මකන්න",

      // Dashboard
      perfectlySafe: "පූර්ණ ආරක්ෂිතයි",
      outsideSafeZone: "ආරක්ෂිත කලාපයෙන් පිටත",
      monitoring: "නිරීක්ෂණය කරමින්...",
      strong: "ප්‍රබලයි",
      offline: "නොබැඳි",
      safetyPerimeterSettings: "ආරක්ෂිත පරිමිතිය සැකසුම්",
      zoneRadius: "මීටර {{radius}} කලාපය",
      activelyMonitoring: "සක්‍රීයව නිරීක්ෂණය කරමින්",
      inactive: "අක්‍රියයි",
      pingDevice: "උපාංගයට සංඥාවක් යවන්න",
      soundAlarm: "අනතුරු ඇඟවීමක් නාද කරන්න",
      liveTelemetry: "සජීවී ටෙලිමෙට්‍රි",
      securityAlertTriggered: "ආරක්ෂක අනතුරු ඇඟවීමක් ක්‍රියාත්මක විය",
      allSystemsOperational: "සියලුම පද්ධති ක්‍රියාත්මකයි",
      noActiveThreats: "ක්‍රියාකාරී තර්ජන නොමැත",
      snapToLocation: "ස්ථානයට යන්න",

      // Alerts
      safetyAlerts: "ආරක්ෂක අනතුරු ඇඟවීම්",
      monitorEvents: "සියලුම හදිසි සහ භූ-කලාප සිදුවීම් නිරීක්ෂණය කරන්න",
      liveMonitoring: "සජීවී නිරීක්ෂණය",
      event: "සිදුවීම",
      alertType: "අනතුරු ඇඟවීමේ වර්ගය",
      time: "වේලාව",
      status: "තත්වය",
      actions: "ක්‍රියාමාර්ග",
      active: "සක්‍රීයයි",
      resolved: "විසඳා ඇත",
      noAlerts: "තවමත් ආරක්ෂක අනතුරු ඇඟවීම් කිසිවක් හමු නොවීය.",
      childPlaceholder: "දරුවා",
      deleteAlertConfirm: "මෙම අනතුරු ඇඟවීම ඉතිහාසයෙන් ඉවත් කිරීමට ඔබට විශ්වාසද?"
    }
  }
};

i18n
  .use(initReactI18next)
  .init({
    resources,
    lng: "en", 
    fallbackLng: "en",
    interpolation: {
      escapeValue: false 
    }
  });

export default i18n;

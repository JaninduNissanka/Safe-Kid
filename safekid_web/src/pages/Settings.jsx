import { useState, useEffect } from 'react';
import { auth, db } from '../firebase';
import { signOut } from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';
import { useNavigate } from 'react-router-dom';
import { 
  User, Lock, ShieldCheck, Bell, LogOut, Trash2, 
  ChevronRight, Moon, Sun, Languages 
} from 'lucide-react';

const Settings = () => {
  const navigate = useNavigate();
  const [userName, setUserName] = useState("Guardian User");
  const [email, setEmail] = useState("");
  const [isDarkMode, setIsDarkMode] = useState(() => document.documentElement.classList.contains('dark'));
  const [isSinhala, setIsSinhala] = useState(false);
  const [twoFactor, setTwoFactor] = useState(false);

  useEffect(() => {
    const user = auth.currentUser;
    if (user) {
      setEmail(user.email || "");
      setUserName(user.displayName || "Guardian User");
      const fetchUserData = async () => {
         try {
           const docRef = doc(db, 'users', user.uid);
           const docSnap = await getDoc(docRef);
           if(docSnap.exists() && docSnap.data().name) {
             setUserName(docSnap.data().name);
           }
         } catch(e) {}
      };
      fetchUserData();
    }
  }, []);

  const handleLogout = async () => {
    await signOut(auth);
    navigate('/');
  };

  const toggleTheme = () => {
    const newTheme = !isDarkMode;
    setIsDarkMode(newTheme);
    if (newTheme) {
      document.documentElement.classList.add('dark');
      localStorage.setItem('theme', 'dark');
    } else {
      document.documentElement.classList.remove('dark');
      localStorage.setItem('theme', 'light');
    }
  };

  return (
    <div className="h-screen w-full overflow-y-auto bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-slate-200 font-['Outfit'] relative p-8 pl-36 transition-colors duration-300">
      
      {/* Background ambient light */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-3/4 h-64 bg-indigo-600/10 blur-[100px] pointer-events-none rounded-full" />

      <div className="max-w-3xl mx-auto relative z-10 pt-10 pb-20">
        
        {/* HEADER */}
        <div className="flex flex-col items-center mb-12">
          <div className="w-28 h-28 rounded-full bg-gradient-to-tr from-indigo-500 to-purple-500 p-1 mb-4 shadow-[0_0_40px_rgba(99,102,241,0.3)]">
            <div className="w-full h-full rounded-full bg-white dark:bg-slate-800 flex items-center justify-center border-4 border-slate-50 dark:border-slate-900 transition-colors duration-300">
              <User className="w-12 h-12 text-indigo-500 dark:text-indigo-400" />
            </div>
          </div>
          <h1 className="text-3xl font-black text-slate-900 dark:text-white tracking-tight">{userName}</h1>
          <p className="text-sm font-bold text-slate-500 dark:text-slate-400 mt-1 tracking-wider">{email}</p>
        </div>

        {/* QUICK TOGGLES */}
        <div className="grid grid-cols-2 gap-6 mb-12">
          <div 
            onClick={toggleTheme}
            className="bg-white/80 dark:bg-slate-800/60 backdrop-blur-xl border border-slate-200 dark:border-slate-700/50 rounded-3xl p-6 flex items-center justify-between cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-800 transition-all shadow-lg"
          >
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 rounded-full bg-indigo-500/10 dark:bg-indigo-500/20 flex items-center justify-center text-indigo-600 dark:text-indigo-400">
                {isDarkMode ? <Moon className="w-6 h-6" /> : <Sun className="w-6 h-6" />}
              </div>
              <span className="font-bold text-lg text-slate-900 dark:text-white tracking-wide">Theme</span>
            </div>
            <div className={`w-14 h-7 rounded-full p-1 shadow-inner transition-colors duration-300 ${isDarkMode ? 'bg-indigo-500' : 'bg-slate-600'}`}>
              <div className={`w-5 h-5 rounded-full bg-white transition-transform duration-300 shadow-sm ${isDarkMode ? 'translate-x-7' : 'translate-x-0'}`} />
            </div>
          </div>

          <div 
            onClick={() => setIsSinhala(!isSinhala)}
            className="bg-white/80 dark:bg-slate-800/60 backdrop-blur-xl border border-slate-200 dark:border-slate-700/50 rounded-3xl p-6 flex items-center justify-between cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-800 transition-all shadow-lg"
          >
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 rounded-full bg-emerald-500/10 dark:bg-emerald-500/20 flex items-center justify-center text-emerald-600 dark:text-emerald-400">
                <Languages className="w-6 h-6" />
              </div>
              <span className="font-bold text-lg text-slate-900 dark:text-white tracking-wide">Language</span>
            </div>
            <div className="flex items-center gap-3 font-black text-sm">
              <span className={!isSinhala ? 'text-emerald-400' : 'text-slate-500'}>EN</span>
              <div className={`w-14 h-7 rounded-full p-1 shadow-inner transition-colors duration-300 bg-emerald-500`}>
                <div className={`w-5 h-5 rounded-full bg-white transition-transform duration-300 shadow-sm ${isSinhala ? 'translate-x-7' : 'translate-x-0'}`} />
              </div>
              <span className={isSinhala ? 'text-emerald-400' : 'text-slate-500'}>SI</span>
            </div>
          </div>
        </div>

        {/* SETTINGS SECTIONS */}
        <div className="space-y-10">
          
          {/* ACCOUNT SECURITY */}
          <section>
            <h3 className="text-xs text-slate-500 dark:text-slate-400 font-black tracking-[0.2em] uppercase mb-4 pl-4">Account Security</h3>
            <div className="bg-white/80 dark:bg-slate-800/60 backdrop-blur-xl border border-slate-200 dark:border-slate-700/50 rounded-[32px] overflow-hidden shadow-lg transition-colors duration-300">
              <div className="flex items-center justify-between p-6 border-b border-slate-200 dark:border-slate-700/50 cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-700/40 transition-colors">
                <div className="flex items-center gap-5">
                  <div className="w-12 h-12 rounded-2xl bg-blue-500/10 flex items-center justify-center text-blue-600 dark:text-blue-400">
                    <Lock className="w-6 h-6" />
                  </div>
                  <span className="font-bold text-lg text-slate-900 dark:text-white">Change Password</span>
                </div>
                <ChevronRight className="w-6 h-6 text-slate-400 dark:text-slate-500" />
              </div>
              
              <div 
                onClick={() => setTwoFactor(!twoFactor)}
                className="flex items-center justify-between p-6 cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-700/40 transition-colors"
              >
                <div className="flex items-center gap-5">
                  <div className="w-12 h-12 rounded-2xl bg-purple-500/10 flex items-center justify-center text-purple-600 dark:text-purple-400">
                    <ShieldCheck className="w-6 h-6" />
                  </div>
                  <span className="font-bold text-lg text-slate-900 dark:text-white">Two-Factor Authentication</span>
                </div>
                <div className={`w-14 h-7 rounded-full p-1 shadow-inner transition-colors duration-300 ${twoFactor ? 'bg-purple-500' : 'bg-slate-600'}`}>
                  <div className={`w-5 h-5 rounded-full bg-white transition-transform duration-300 shadow-sm ${twoFactor ? 'translate-x-7' : 'translate-x-0'}`} />
                </div>
              </div>
            </div>
          </section>

          {/* PREFERENCES */}
          <section>
            <h3 className="text-xs text-slate-500 dark:text-slate-400 font-black tracking-[0.2em] uppercase mb-4 pl-4">Preferences</h3>
            <div className="bg-white/80 dark:bg-slate-800/60 backdrop-blur-xl border border-slate-200 dark:border-slate-700/50 rounded-[32px] overflow-hidden shadow-lg transition-colors duration-300">
              <div className="flex items-center justify-between p-6 cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-700/40 transition-colors">
                <div className="flex items-center gap-5">
                  <div className="w-12 h-12 rounded-2xl bg-amber-500/10 flex items-center justify-center text-amber-600 dark:text-amber-400">
                    <Bell className="w-6 h-6" />
                  </div>
                  <span className="font-bold text-lg text-slate-900 dark:text-white">Notification Settings</span>
                </div>
                <ChevronRight className="w-6 h-6 text-slate-400 dark:text-slate-500" />
              </div>
            </div>
          </section>

          {/* DANGER ZONE */}
          <section>
            <h3 className="text-xs text-red-500 font-black tracking-[0.2em] uppercase mb-4 pl-4">Danger Zone</h3>
            <div className="bg-white/80 dark:bg-slate-800/60 backdrop-blur-xl border border-red-200 dark:border-red-900/30 rounded-[32px] overflow-hidden shadow-lg transition-colors duration-300">
              <div 
                onClick={handleLogout}
                className="flex items-center justify-between p-6 border-b border-slate-200 dark:border-slate-700/50 cursor-pointer hover:bg-red-50 dark:hover:bg-red-500/10 transition-colors group"
              >
                <div className="flex items-center gap-5">
                  <div className="w-12 h-12 rounded-2xl bg-red-500/10 flex items-center justify-center text-red-600 dark:text-red-500 group-hover:bg-red-500 group-hover:text-white transition-colors">
                    <LogOut className="w-6 h-6" />
                  </div>
                  <span className="font-bold text-lg text-red-600 dark:text-red-400 group-hover:text-red-700 dark:group-hover:text-red-300 transition-colors">Sign Out</span>
                </div>
              </div>
              
              <div className="flex items-center justify-between p-6 cursor-pointer hover:bg-red-50 dark:hover:bg-red-500/10 transition-colors group">
                <div className="flex items-center gap-5">
                  <div className="w-12 h-12 rounded-2xl bg-red-500/10 flex items-center justify-center text-red-600 dark:text-red-500 group-hover:bg-red-500 group-hover:text-white transition-colors">
                    <Trash2 className="w-6 h-6" />
                  </div>
                  <span className="font-bold text-lg text-red-600 dark:text-red-400 group-hover:text-red-700 dark:group-hover:text-red-300 transition-colors">Delete Account</span>
                </div>
              </div>
            </div>
          </section>

        </div>
      </div>
    </div>
  );
};

export default Settings;

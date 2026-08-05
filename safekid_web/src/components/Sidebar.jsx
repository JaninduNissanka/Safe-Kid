import { NavLink, useNavigate } from 'react-router-dom';
import { auth } from '../firebase';
import { signOut } from 'firebase/auth';
import { LayoutDashboard, Bell, User, LogOut, ShieldCheck } from 'lucide-react';

const Sidebar = () => {
  const navigate = useNavigate();

  const handleLogout = async () => {
    await signOut(auth);
    navigate('/');
  };

  const navItems = [
    { icon: LayoutDashboard, label: 'Dashboard', path: '/dashboard' },
    { icon: Bell, label: 'Alerts', path: '/alerts' },
    { icon: User, label: 'Profile', path: '/settings' },
  ];

  return (
    <div className="fixed left-6 top-6 bottom-6 w-20 bg-white/90 dark:bg-slate-800/90 backdrop-blur-2xl border border-white/60 dark:border-slate-700/60 rounded-[28px] flex flex-col items-center py-6 shadow-[0_8px_30px_rgba(0,0,0,0.12)] z-50 transition-colors duration-300">
      <div 
        className="mb-8 text-indigo-600 dark:text-indigo-400 hover:scale-110 transition-transform cursor-pointer"
        onClick={() => navigate('/dashboard')}
      >
        <ShieldCheck className="w-9 h-9" />
      </div>

      <nav className="flex-1 flex flex-col gap-4 w-full px-3">
        {navItems.map((item) => (
          <NavLink
            key={item.path}
            to={item.path}
            title={item.label}
            className={({ isActive }) => `
              p-3.5 rounded-[18px] flex items-center justify-center transition-all duration-300
              ${isActive 
                ? 'bg-indigo-600 text-white shadow-lg shadow-indigo-200 dark:shadow-indigo-900/50' 
                : 'text-slate-400 hover:bg-indigo-50 dark:hover:bg-slate-700/50 hover:text-indigo-600 dark:hover:text-indigo-400'}
            `}
          >
            <item.icon className="w-5 h-5" />
          </NavLink>
        ))}
      </nav>

      <button
        onClick={handleLogout}
        title="Logout"
        className="p-3.5 rounded-[18px] text-slate-400 hover:bg-red-50 dark:hover:bg-red-500/10 hover:text-red-600 transition-all duration-300"
      >
        <LogOut className="w-5 h-5" />
      </button>
    </div>
  );
};

export default Sidebar;

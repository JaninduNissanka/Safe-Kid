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
    <div className="absolute left-6 top-6 bottom-6 w-24 bg-white/85 dark:bg-slate-800/80 backdrop-blur-2xl border border-white/50 dark:border-slate-700/50 rounded-[32px] flex flex-col items-center py-8 shadow-[0_8px_30px_rgba(0,0,0,0.12)] z-50 transition-colors duration-300">
      <div className="mb-10 text-indigo-600 dark:text-indigo-400">
        <ShieldCheck className="w-10 h-10" />
      </div>

      <nav className="flex-1 flex flex-col gap-6 w-full px-4">
        {navItems.map((item) => (
          <NavLink
            key={item.path}
            to={item.path}
            title={item.label}
            className={({ isActive }) => `
              p-4 rounded-[20px] flex items-center justify-center transition-all duration-300
              ${isActive 
                ? 'bg-indigo-600 text-white shadow-lg shadow-indigo-200' 
                : 'text-slate-400 hover:bg-indigo-50 hover:text-indigo-600'}
            `}
          >
            <item.icon className="w-6 h-6" />
          </NavLink>
        ))}
      </nav>

    </div>
  );
};

export default Sidebar;

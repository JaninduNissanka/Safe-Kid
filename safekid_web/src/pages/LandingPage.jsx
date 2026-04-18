import { Link } from 'react-router-dom';
import { ShieldCheck, Map, Bell, Smartphone, ArrowRight } from 'lucide-react';

const LandingPage = () => {
  return (
    <div className="min-h-screen">
      {/* Hero Section */}
      <header className="container mx-auto px-6 pt-20 pb-16 flex flex-col items-center text-center">
        <div className="inline-flex items-center gap-2 px-4 py-2 bg-primary/10 text-primary rounded-full mb-8 font-semibold animate-fade-in">
          <ShieldCheck className="w-5 h-5" />
          Production-Grade Child Safety
        </div>
        <h1 className="text-5xl md:text-7xl font-extrabold text-slate-900 mb-6 leading-tight">
          Enterprise-Grade Safety <br/>
          <span className="text-primary">For Your Child</span>
        </h1>
        <p className="text-xl text-slate-600 mb-10 max-w-2xl mx-auto">
          Monitor live locations, set intelligent geofences, and receive instant 
          emergency alerts from anywhere in the world.
        </p>
        <div className="flex gap-4">
          <Link 
            to="/login" 
            className="px-8 py-4 bg-primary text-white font-bold rounded-2xl hover:bg-primary-dark transition-all flex items-center gap-2 border-b-4 border-primary-dark"
          >
            Guardian Login <ArrowRight className="w-5 h-5" />
          </Link>
          <button className="px-8 py-4 bg-white text-slate-900 font-bold rounded-2xl border-2 border-slate-200 hover:border-primary transition-all">
            View App Demo
          </button>
        </div>
      </header>

      {/* Features Grid */}
      <section className="bg-slate-50 py-24 border-y border-slate-200">
        <div className="container mx-auto px-6 grid md:grid-cols-3 gap-12 text-center">
          <FeatureCard 
            icon={Map} 
            title="Real-time Tracking" 
            desc="Watch your child's movement live on high-precision maps with minimal latency." 
          />
          <FeatureCard 
            icon={ShieldCheck} 
            title="Smart Geofences" 
            desc="Define safe zones and get notified instantly if boundaries are crossed." 
          />
          <FeatureCard 
            icon={Bell} 
            title="Instant SOS" 
            desc="One-tap emergency signaling that bypasses silent modes and reaches you fast." 
          />
        </div>
      </section>

      {/* Footer */}
      <footer className="py-12 text-center text-slate-400">
        <p>&copy; 2026 SafeKid Pro. All rights reserved.</p>
      </footer>
    </div>
  );
};

const FeatureCard = ({ icon: Icon, title, desc }) => (
  <div className="p-8 bg-white rounded-3xl border border-slate-200 shadow-sm hover:shadow-xl transition-all group">
    <div className="w-16 h-16 bg-primary/10 rounded-2xl flex items-center justify-center mx-auto mb-6 group-hover:scale-110 transition-transform">
      <Icon className="text-primary w-8 h-8" />
    </div>
    <h3 className="text-xl font-bold mb-4 text-slate-900">{title}</h3>
    <p className="text-slate-600 leading-relaxed">{desc}</p>
  </div>
);

export default LandingPage;

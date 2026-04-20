import { Link } from 'react-router-dom';
import { 
  ShieldCheck, Map, Bell, Smartphone, ArrowRight, 
  CheckCircle, Zap, Globe, Lock, Play, Menu, X,
  Heart, Users, Star
} from 'lucide-react';
import { useState, useEffect } from 'react';

const LandingPage = () => {
  const [isScrolled, setIsScrolled] = useState(false);
  const [isMenuOpen, setIsMenuOpen] = useState(false);

  useEffect(() => {
    const handleScroll = () => setIsScrolled(window.scrollY > 50);
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  return (
    <div className="min-h-screen bg-mesh selection:bg-primary/30">
      {/* 🧭 NAVIGATION */}
      <nav className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 ${isScrolled ? 'glass py-3 shadow-sm' : 'py-6'}`}>
        <div className="container mx-auto px-6 flex items-center justify-between">
          <Link to="/" className="flex items-center gap-2 group">
            <div className="w-10 h-10 bg-primary rounded-xl flex items-center justify-center shadow-lg group-hover:rotate-6 transition-transform">
              <ShieldCheck className="text-white w-6 h-6" />
            </div>
            <span className="text-2xl font-black tracking-tighter text-slate-900">SAFE<span className="text-primary">KID</span></span>
          </Link>

          <div className="hidden md:flex items-center gap-10">
            <NavLink href="#features">Features</NavLink>
            <NavLink href="#how-it-works">How it Works</NavLink>
            <NavLink href="#pricing">Pricing</NavLink>
            <Link 
              to="/login" 
              className="px-6 py-2.5 bg-slate-900 text-white rounded-full font-bold hover:bg-primary transition-all shadow-xl hover:shadow-primary/40 active:scale-95"
            >
              Dashboard Login
            </Link>
          </div>

          <button className="md:hidden text-slate-900" onClick={() => setIsMenuOpen(!isMenuOpen)}>
            {isMenuOpen ? <X /> : <Menu />}
          </button>
        </div>
      </nav>

      {/* 🚀 HERO SECTION */}
      <section className="pt-32 pb-20 md:pt-48 md:pb-32 overflow-hidden">
        <div className="container mx-auto px-6 flex flex-col lg:flex-row items-center gap-16">
          <div className="lg:w-1/2 text-center lg:text-left">
            <div className="inline-flex items-center gap-2 px-4 py-2 bg-primary/10 text-primary rounded-full mb-8 font-bold text-sm tracking-wide uppercase">
              <Star className="w-4 h-4 fill-primary" /> Rated #1 Child Safety App 2026
            </div>
            <h1 className="text-5xl md:text-7xl font-black text-slate-900 mb-8 leading-[1.1] tracking-tight">
              Peace of mind for <br/>
              <span className="text-gradient">Every Parent.</span>
            </h1>
            <p className="text-lg md:text-xl text-slate-600 mb-12 leading-relaxed max-w-xl mx-auto lg:mx-0">
              SafeKid gives you real-time tracking, intelligent geofences, and panic alerts 
              that bypass silent modes. Trusted by 5M+ families worldwide.
            </p>
            <div className="flex flex-col sm:flex-row gap-4 justify-center lg:justify-start">
              <Link 
                to="/login" 
                className="group px-8 py-5 bg-primary text-white font-black rounded-2xl hover:bg-primary-dark transition-all flex items-center justify-center gap-3 shadow-2xl shadow-primary/40 active:scale-95"
              >
                Get Started Now <ArrowRight className="w-5 h-5 group-hover:translate-x-1 transition-transform" />
              </Link>
              <button className="px-8 py-5 bg-white text-slate-900 font-bold rounded-2xl border-2 border-slate-100 hover:border-primary transition-all flex items-center justify-center gap-3 shadow-md hover:shadow-xl active:scale-95">
                <Play className="w-5 h-5 fill-slate-900" /> Watch the Film
              </button>
            </div>
            <div className="mt-12 flex items-center justify-center lg:justify-start gap-4">
              <div className="flex -space-x-3">
                {[1,2,3,4].map(i => (
                  <div key={i} className="w-10 h-10 rounded-full border-2 border-white bg-slate-200 overflow-hidden shadow-sm">
                    <img src={`https://i.pravatar.cc/100?u=${i}`} alt="Avatar" />
                  </div>
                ))}
              </div>
              <p className="text-sm font-bold text-slate-500 underline underline-offset-4 decoration-primary/30">
                Joined by 1.2k+ families this week
              </p>
            </div>
          </div>

          {/* 📱 HERO MOCKUP */}
          <div className="lg:w-1/2 relative flex justify-center lg:justify-end">
            <div className="relative animate-float z-10 w-full max-w-lg">
              {/* Dashboard Preview UI */}
              <div className="bg-white rounded-[40px] shadow-[0_50px_100px_rgba(0,0,0,0.15)] overflow-hidden border-8 border-slate-900">
                <div className="bg-slate-900 h-6 flex justify-center py-1">
                  <div className="w-20 h-2 bg-slate-800 rounded-full"></div>
                </div>
                <div className="p-4 bg-slate-50 aspect-video relative flex items-center justify-center overflow-hidden">
                  <div className="absolute inset-0 bg-blue-100/50">
                    <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-32 h-32 bg-primary/10 rounded-full flex items-center justify-center animate-pulse">
                      <div className="w-20 h-20 bg-primary/20 rounded-full flex items-center justify-center">
                        <div className="w-8 h-8 bg-primary rounded-full border-4 border-white shadow-lg animate-bounce"></div>
                      </div>
                    </div>
                  </div>
                  <div className="glass p-4 rounded-2xl absolute bottom-4 left-4 right-4 shadow-xl">
                    <div className="flex items-center gap-3 text-slate-900 font-bold text-sm">
                      <Smartphone className="w-4 h-4 text-primary" /> Tracking JR · Active
                    </div>
                  </div>
                </div>
                <div className="p-6 space-y-4">
                  <div className="h-4 w-3/4 bg-slate-100 rounded-full"></div>
                  <div className="h-4 w-1/2 bg-slate-100 rounded-full"></div>
                  <div className="grid grid-cols-2 gap-4 mt-6">
                    <div className="h-12 bg-slate-50 rounded-xl border border-slate-100 border-b-4 border-b-primary/30"></div>
                    <div className="h-12 bg-slate-50 rounded-xl border border-slate-100 border-b-4 border-b-secondary/30"></div>
                  </div>
                </div>
              </div>
              {/* Decorative elements */}
              <div className="absolute -top-10 -right-10 w-40 h-40 bg-secondary/20 rounded-full blur-3xl -z-10"></div>
              <div className="absolute -bottom-10 -left-10 w-60 h-60 bg-primary/20 rounded-full blur-3xl -z-10"></div>
            </div>
          </div>
        </div>
      </section>

      {/* 📊 TRUST STATS */}
      <section className="py-20 bg-white border-y border-slate-100">
        <div className="container mx-auto px-6 flex flex-wrap justify-center gap-12 md:gap-32 text-center">
          <Stat value="5M+" label="Active Users" />
          <Stat value="99.9%" label="Reliability" />
          <Stat value="142" label="Countries" />
          <Stat value="4.9/5" label="App Rating" />
        </div>
      </section>

      {/* ✨ FEATURES SECTION */}
      <section id="features" className="py-24 md:py-32 bg-slate-50 relative overflow-hidden">
        <div className="container mx-auto px-6 relative z-10">
          <div className="text-center max-w-3xl mx-auto mb-20">
            <h2 className="text-4xl md:text-5xl font-black text-slate-900 mb-6 tracking-tight">
              Safety is not a feature. <br/>
              <span className="text-primary italic">It's a promise.</span>
            </h2>
            <p className="text-slate-500 text-lg">
              We built SafeKid with military-grade encryption and aerospace-level tracking accuracy.
            </p>
          </div>

          <div className="grid md:grid-cols-3 gap-8">
            <FeatureCard 
              icon={Map} 
              color="bg-primary/10 text-primary"
              title="Real-time Radar" 
              desc="Military-grade GPS tracking that updates every 5 seconds. Know exactly where they are, always." 
            />
            <FeatureCard 
              icon={ShieldCheck} 
              color="bg-secondary/10 text-secondary"
              title="Smart Perimeters" 
              desc="Set as many safe zones as you like. We'll alert you the second they cross a boundary." 
            />
            <FeatureCard 
              icon={Bell} 
              color="bg-accent/10 text-accent"
              title="Hyper-Alert SOS" 
              desc="Crisis alerts that bypass silent mode, Do Not Disturb, and maximize speaker volume." 
            />
          </div>
        </div>
      </section>

      {/* 🛡️ SECURITY PROMISE */}
      <section className="py-24 bg-slate-900 text-white overflow-hidden relative">
        <div className="absolute top-0 right-0 w-1/2 h-full opacity-10 bg-[radial-gradient(circle_at_center,_white_1px,_transparent_1px)] bg-[length:40px_40px]"></div>
        <div className="container mx-auto px-6 grid lg:grid-cols-2 items-center gap-16">
          <div className="relative">
            <div className="grid grid-cols-2 gap-4">
              <SecurityBox icon={Lock} label="End-to-End Encrypted" />
              <SecurityBox icon={Globe} label="Global Coverage" />
              <SecurityBox icon={Users} label="Family Accounts" />
              <SecurityBox icon={Zap} label="Low-Latency Sync" />
            </div>
          </div>
          <div>
            <h2 className="text-4xl md:text-5xl font-black mb-8 leading-tight">
              Privacy First. <br/>
              Security Always.
            </h2>
            <div className="space-y-6">
              <CheckItem text="AES-256 Bank-Grade Encryption" />
              <CheckItem text="No data sharing with third parties" />
              <CheckItem text="GDPR & COPPA Compliant" />
              <CheckItem text="Self-destructing logs option" />
            </div>
            <button className="mt-12 px-8 py-5 bg-primary text-white font-black rounded-2xl hover:bg-primary-dark transition-all shadow-xl shadow-primary/20">
              Read our Security Whitepaper
            </button>
          </div>
        </div>
      </section>

      {/* 🧡 CALL TO ACTION */}
      <section className="py-24 relative overflow-hidden flex justify-center">
        <div className="container mx-auto px-6 relative z-10 text-center">
          <div className="glass p-12 md:p-24 rounded-[60px] shadow-2xl relative overflow-hidden border-2 border-white">
            <div className="absolute inset-0 bg-primary/5 -z-10"></div>
            <h2 className="text-5xl md:text-7xl font-black text-slate-900 mb-8 tracking-tighter">
              Start Protecting your <br/>
              <span className="text-gradient">Family Today.</span>
            </h2>
            <p className="text-xl text-slate-600 mb-12 max-w-2xl mx-auto">
              Join 5 million+ parents who trust SafeKid Pro for their daily safety routines.
            </p>
            <div className="flex flex-col sm:flex-row gap-6 justify-center">
              <Link 
                to="/login" 
                className="px-10 py-6 bg-slate-900 text-white font-black rounded-2xl hover:bg-primary transition-all shadow-2xl active:scale-95"
              >
                Go to Dashboard
              </Link>
              <button className="px-10 py-6 bg-white text-slate-900 border-2 border-slate-100 font-black rounded-2xl hover:border-primary transition-all active:scale-95">
                Download Mobile App
              </button>
            </div>
          </div>
        </div>
      </section>

      {/* 🏁 FOOTER */}
      <footer className="bg-white pt-20 pb-12 border-t border-slate-100">
        <div className="container mx-auto px-6 grid md:grid-cols-4 gap-12 mb-20 text-center md:text-left">
          <div className="col-span-2 md:col-span-1">
             <Link to="/" className="flex items-center gap-2 mb-6 justify-center md:justify-start">
              <ShieldCheck className="text-primary w-8 h-8" />
              <span className="text-2xl font-black tracking-tighter">SAFEKID</span>
            </Link>
            <p className="text-slate-500 mb-6">
              The world's most advanced child safety application. Designed with love and built with power.
            </p>
            <div className="flex gap-4 justify-center md:justify-start text-primary">
               {/* Social Icons would go here */}
               <div className="w-10 h-10 rounded-full bg-slate-50 flex items-center justify-center hover:bg-primary hover:text-white transition-colors cursor-pointer"><Globe size={18}/></div>
               <div className="w-10 h-10 rounded-full bg-slate-50 flex items-center justify-center hover:bg-primary hover:text-white transition-colors cursor-pointer"><Users size={18}/></div>
               <div className="w-10 h-10 rounded-full bg-slate-50 flex items-center justify-center hover:bg-primary hover:text-white transition-colors cursor-pointer"><Star size={18}/></div>
            </div>
          </div>
          <div>
            <h4 className="font-black mb-6 text-slate-900">Product</h4>
            <div className="flex flex-col gap-4 text-slate-500 font-bold">
              <FooterLink>Mobile App</FooterLink>
              <FooterLink>Web Dashboard</FooterLink>
              <FooterLink>Developer API</FooterLink>
              <FooterLink>Security Guide</FooterLink>
            </div>
          </div>
          <div>
            <h4 className="font-black mb-6 text-slate-900">Company</h4>
            <div className="flex flex-col gap-4 text-slate-500 font-bold">
              <FooterLink>About Us</FooterLink>
              <FooterLink>Our Mission</FooterLink>
              <FooterLink>Press Kit</FooterLink>
              <FooterLink>Contact</FooterLink>
            </div>
          </div>
          <div>
            <h4 className="font-black mb-6 text-slate-900">Legal</h4>
            <div className="flex flex-col gap-4 text-slate-500 font-bold">
              <FooterLink>Privacy Policy</FooterLink>
              <FooterLink>Terms of Use</FooterLink>
              <FooterLink>Safety Center</FooterLink>
              <FooterLink>Cookie Policy</FooterLink>
            </div>
          </div>
        </div>
        <div className="container mx-auto px-6 pt-12 border-t border-slate-50 flex flex-col md:flex-row justify-between items-center gap-6 text-slate-400 font-bold text-sm">
          <p>&copy; 2026 SafeKid Global Inc. All rights reserved.</p>
          <div className="flex gap-8">
            <span className="hover:text-primary cursor-pointer transition-colors">Safety Report</span>
            <span className="hover:text-primary cursor-pointer transition-colors">Ethics Panel</span>
          </div>
        </div>
      </footer>
    </div>
  );
};

const NavLink = ({ href, children }) => (
  <a href={href} className="text-slate-500 hover:text-primary font-black text-sm tracking-wide transition-colors uppercase">
    {children}
  </a>
);

const FeatureCard = ({ icon: Icon, title, desc, color }) => (
  <div className="p-8 md:p-12 bg-white rounded-[40px] shadow-2xl shadow-slate-200 border border-slate-100 hover:-translate-y-2 transition-all duration-300 group">
    <div className={`w-16 h-16 rounded-2xl flex items-center justify-center mb-10 ${color} group-hover:scale-110 transition-transform`}>
      <Icon className="w-8 h-8" />
    </div>
    <h3 className="text-2xl font-black mb-6 text-slate-900">{title}</h3>
    <p className="text-slate-500 leading-relaxed font-medium">{desc}</p>
  </div>
);

const Stat = ({ value, label }) => (
  <div className="flex flex-col gap-2">
    <div className="text-4xl md:text-5xl font-black text-slate-900 italic tracking-tighter">{value}</div>
    <div className="text-slate-400 font-bold uppercase tracking-widest text-[10px]">{label}</div>
  </div>
);

const SecurityBox = ({ icon: Icon, label }) => (
  <div className="p-6 md:p-10 bg-slate-800/50 backdrop-blur-md rounded-[32px] border border-white/5 flex flex-col items-center text-center">
    <Icon className="w-8 h-8 text-primary mb-4" />
    <span className="font-bold text-sm">{label}</span>
  </div>
);

const CheckItem = ({ text }) => (
  <div className="flex items-center gap-4 group">
    <div className="w-6 h-6 rounded-full bg-primary/20 flex items-center justify-center group-hover:bg-primary transition-colors">
      <CheckCircle className="w-4 h-4 text-primary group-hover:text-white" />
    </div>
    <span className="font-bold text-slate-300 group-hover:text-white transition-colors">{text}</span>
  </div>
);

const FooterLink = ({ children }) => (
  <span className="hover:text-primary cursor-pointer transition-colors">
    {children}
  </span>
);

export default LandingPage;

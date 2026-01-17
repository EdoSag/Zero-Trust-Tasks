import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { Lock, ShieldCheck, Eye, EyeOff, Key, Cloud, Fingerprint } from 'lucide-react';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { useAuth } from '../contexts/AuthContext';
import { useVault } from '../contexts/VaultContext';
import { useNavigate } from 'react-router-dom';
import { toast } from 'sonner';

const LandingPage = () => {
  const { loginWithGoogle, isAuthenticated } = useAuth();
  const { hasPassword, createMasterPassword, unlock, isUnlocked, validatePasswordStrength } = useVault();
  const navigate = useNavigate();
  
  const [showPasswordSetup, setShowPasswordSetup] = useState(false);
  const [showUnlock, setShowUnlock] = useState(false);
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const passwordStrength = validatePasswordStrength(password);

  const getStrengthColor = (score) => {
    if (score <= 1) return 'bg-red-500';
    if (score === 2) return 'bg-orange-500';
    if (score === 3) return 'bg-yellow-500';
    return 'bg-green-500';
  };

  const getStrengthText = (score) => {
    if (score <= 1) return 'Weak';
    if (score === 2) return 'Fair';
    if (score === 3) return 'Good';
    return 'Strong';
  };

  const handleCreatePassword = async (e) => {
    e.preventDefault();
    if (password.length < 8) {
      toast.error('Password must be at least 8 characters');
      return;
    }
    if (password !== confirmPassword) {
      toast.error('Passwords do not match');
      return;
    }
    
    setIsSubmitting(true);
    const success = await createMasterPassword(password);
    setIsSubmitting(false);
    
    if (success) {
      navigate('/dashboard');
    }
  };

  const handleUnlock = async (e) => {
    e.preventDefault();
    setIsSubmitting(true);
    const success = await unlock(password);
    setIsSubmitting(false);
    
    if (success) {
      navigate('/dashboard');
    }
  };

  // If already unlocked, redirect
  if (isUnlocked && isAuthenticated) {
    navigate('/dashboard');
    return null;
  }

  return (
    <div className="min-h-screen bg-[#050505] relative overflow-hidden">
      {/* Background image with overlay */}
      <div 
        className="absolute inset-0 bg-cover bg-center opacity-30"
        style={{ 
          backgroundImage: 'url(https://images.unsplash.com/photo-1759267190499-cf3ce2bef9bc?crop=entropy&cs=srgb&fm=jpg&q=85)'
        }}
      />
      <div className="absolute inset-0 bg-gradient-to-b from-[#050505]/80 via-[#050505]/90 to-[#050505]" />
      
      <div className="relative z-10 min-h-screen flex flex-col">
        {/* Header */}
        <header className="p-6 md:p-12">
          <motion.div 
            initial={{ opacity: 0, y: -20 }}
            animate={{ opacity: 1, y: 0 }}
            className="flex items-center gap-3"
          >
            <div className="p-2 rounded-lg bg-[#8B5CF6]/20 border border-[#8B5CF6]/30">
              <Lock className="w-6 h-6 text-[#8B5CF6]" strokeWidth={1.5} />
            </div>
            <h1 className="font-mono text-xl font-bold text-white tracking-tight">
              Obsidian Vault
            </h1>
          </motion.div>
        </header>

        {/* Main content */}
        <main className="flex-1 flex items-center justify-center px-6 pb-12">
          <div className="w-full max-w-lg">
            {!showPasswordSetup && !showUnlock ? (
              // Landing view
              <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.1 }}
                className="text-center"
              >
                <div className="mb-8">
                  <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-[#0A0A0A] border border-[#27272A] mb-6">
                    <div className="w-2 h-2 rounded-full bg-[#00FF94] encryption-indicator" />
                    <span className="font-mono text-xs text-[#A1A1AA] tracking-widest uppercase">
                      AES-256-GCM Encrypted
                    </span>
                  </div>
                  
                  <h2 className="font-mono text-4xl md:text-5xl font-bold text-white mb-4 tracking-tight">
                    Zero-Trust<br />Task Management
                  </h2>
                  
                  <p className="text-[#A1A1AA] max-w-md mx-auto">
                    Your data is encrypted locally before it leaves your device. 
                    We never see your tasks, notes, or personal information.
                  </p>
                </div>

                {/* Features */}
                <div className="grid grid-cols-3 gap-4 mb-8">
                  {[
                    { icon: ShieldCheck, label: 'Zero-Knowledge' },
                    { icon: Key, label: 'Client-Side Encryption' },
                    { icon: Cloud, label: 'Secure Backup' }
                  ].map(({ icon: Icon, label }) => (
                    <div 
                      key={label}
                      className="p-4 rounded-lg bg-[#0A0A0A] border border-[#27272A] hover:border-[#8B5CF6]/50 transition-colors"
                    >
                      <Icon className="w-6 h-6 text-[#8B5CF6] mx-auto mb-2" strokeWidth={1.5} />
                      <p className="text-xs text-[#A1A1AA]">{label}</p>
                    </div>
                  ))}
                </div>

                {/* Actions */}
                <div className="space-y-4">
                  {!isAuthenticated ? (
                    <Button
                      data-testid="login-google-btn"
                      onClick={loginWithGoogle}
                      className="w-full h-12 bg-[#8B5CF6] hover:bg-[#7C3AED] text-white font-medium btn-glow"
                    >
                      <svg className="w-5 h-5 mr-2" viewBox="0 0 24 24">
                        <path fill="currentColor" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
                        <path fill="currentColor" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
                        <path fill="currentColor" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
                        <path fill="currentColor" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
                      </svg>
                      Continue with Google
                    </Button>
                  ) : hasPassword ? (
                    <Button
                      data-testid="unlock-vault-btn"
                      onClick={() => setShowUnlock(true)}
                      className="w-full h-12 bg-[#8B5CF6] hover:bg-[#7C3AED] text-white font-medium btn-glow"
                    >
                      <Lock className="w-5 h-5 mr-2" />
                      Unlock Vault
                    </Button>
                  ) : (
                    <Button
                      data-testid="setup-vault-btn"
                      onClick={() => setShowPasswordSetup(true)}
                      className="w-full h-12 bg-[#8B5CF6] hover:bg-[#7C3AED] text-white font-medium btn-glow"
                    >
                      <Key className="w-5 h-5 mr-2" />
                      Create Master Password
                    </Button>
                  )}
                </div>

                <p className="mt-6 text-xs text-[#52525B]">
                  Your master password is never stored. If you forget it, your data cannot be recovered.
                </p>
              </motion.div>
            ) : showPasswordSetup ? (
              // Password setup view
              <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                className="bg-[#0A0A0A] border border-[#27272A] rounded-xl p-8"
              >
                <div className="text-center mb-6">
                  <div className="p-3 rounded-full bg-[#8B5CF6]/20 border border-[#8B5CF6]/30 inline-block mb-4">
                    <Key className="w-8 h-8 text-[#8B5CF6]" strokeWidth={1.5} />
                  </div>
                  <h3 className="font-mono text-2xl font-bold text-white mb-2">
                    Create Master Password
                  </h3>
                  <p className="text-sm text-[#A1A1AA]">
                    This password encrypts all your data. Choose something strong and memorable.
                  </p>
                </div>

                <form onSubmit={handleCreatePassword} className="space-y-4">
                  <div>
                    <label className="block text-sm text-[#A1A1AA] mb-2">Master Password</label>
                    <div className="relative">
                      <Input
                        data-testid="master-password-input"
                        type={showPassword ? 'text' : 'password'}
                        value={password}
                        onChange={(e) => setPassword(e.target.value)}
                        placeholder="Enter master password"
                        className="w-full h-12 bg-black/50 border-[#27272A] focus:border-[#8B5CF6] font-mono pr-10"
                      />
                      <button
                        type="button"
                        onClick={() => setShowPassword(!showPassword)}
                        className="absolute right-3 top-1/2 -translate-y-1/2 text-[#52525B] hover:text-white"
                      >
                        {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                      </button>
                    </div>
                    
                    {/* Password strength indicator */}
                    {password && (
                      <div className="mt-3">
                        <div className="flex gap-1 mb-2">
                          {[...Array(4)].map((_, i) => (
                            <div
                              key={i}
                              className={`h-1 flex-1 rounded-full transition-colors ${
                                i < passwordStrength.score ? getStrengthColor(passwordStrength.score) : 'bg-[#27272A]'
                              }`}
                            />
                          ))}
                        </div>
                        <p className={`text-xs ${
                          passwordStrength.score <= 1 ? 'text-red-500' :
                          passwordStrength.score === 2 ? 'text-orange-500' :
                          passwordStrength.score === 3 ? 'text-yellow-500' : 'text-green-500'
                        }`}>
                          {getStrengthText(passwordStrength.score)}
                        </p>
                        {passwordStrength.feedback.length > 0 && (
                          <ul className="mt-2 space-y-1">
                            {passwordStrength.feedback.map((tip, i) => (
                              <li key={i} className="text-xs text-[#52525B]">• {tip}</li>
                            ))}
                          </ul>
                        )}
                      </div>
                    )}
                  </div>

                  <div>
                    <label className="block text-sm text-[#A1A1AA] mb-2">Confirm Password</label>
                    <Input
                      data-testid="confirm-password-input"
                      type="password"
                      value={confirmPassword}
                      onChange={(e) => setConfirmPassword(e.target.value)}
                      placeholder="Confirm master password"
                      className="w-full h-12 bg-black/50 border-[#27272A] focus:border-[#8B5CF6] font-mono"
                    />
                    {confirmPassword && password !== confirmPassword && (
                      <p className="text-xs text-red-500 mt-1">Passwords do not match</p>
                    )}
                  </div>

                  <div className="flex gap-3 pt-4">
                    <Button
                      type="button"
                      variant="outline"
                      onClick={() => setShowPasswordSetup(false)}
                      className="flex-1 h-12 border-[#27272A] text-white hover:bg-white/5"
                    >
                      Back
                    </Button>
                    <Button
                      data-testid="create-vault-btn"
                      type="submit"
                      disabled={isSubmitting || password.length < 8 || password !== confirmPassword}
                      className="flex-1 h-12 bg-[#8B5CF6] hover:bg-[#7C3AED] text-white btn-glow disabled:opacity-50"
                    >
                      {isSubmitting ? (
                        <span className="flex items-center gap-2">
                          <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                          Creating...
                        </span>
                      ) : (
                        'Create Vault'
                      )}
                    </Button>
                  </div>
                </form>

                <div className="mt-6 p-4 rounded-lg bg-[#8B5CF6]/10 border border-[#8B5CF6]/20">
                  <p className="text-xs text-[#8B5CF6]">
                    <strong>⚠️ Important:</strong> This password cannot be recovered. 
                    Store it safely - if you forget it, your data will be permanently lost.
                  </p>
                </div>
              </motion.div>
            ) : (
              // Unlock view
              <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                className="bg-[#0A0A0A] border border-[#27272A] rounded-xl p-8"
              >
                <div className="text-center mb-6">
                  <div className="p-3 rounded-full bg-[#8B5CF6]/20 border border-[#8B5CF6]/30 inline-block mb-4">
                    <Lock className="w-8 h-8 text-[#8B5CF6]" strokeWidth={1.5} />
                  </div>
                  <h3 className="font-mono text-2xl font-bold text-white mb-2">
                    Unlock Vault
                  </h3>
                  <p className="text-sm text-[#A1A1AA]">
                    Enter your master password to access your encrypted data.
                  </p>
                </div>

                <form onSubmit={handleUnlock} className="space-y-4">
                  <div>
                    <label className="block text-sm text-[#A1A1AA] mb-2">Master Password</label>
                    <div className="relative">
                      <Input
                        data-testid="unlock-password-input"
                        type={showPassword ? 'text' : 'password'}
                        value={password}
                        onChange={(e) => setPassword(e.target.value)}
                        placeholder="Enter master password"
                        className="w-full h-12 bg-black/50 border-[#27272A] focus:border-[#8B5CF6] font-mono pr-10"
                        autoFocus
                      />
                      <button
                        type="button"
                        onClick={() => setShowPassword(!showPassword)}
                        className="absolute right-3 top-1/2 -translate-y-1/2 text-[#52525B] hover:text-white"
                      >
                        {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                      </button>
                    </div>
                  </div>

                  <div className="flex gap-3 pt-4">
                    <Button
                      type="button"
                      variant="outline"
                      onClick={() => setShowUnlock(false)}
                      className="flex-1 h-12 border-[#27272A] text-white hover:bg-white/5"
                    >
                      Back
                    </Button>
                    <Button
                      data-testid="unlock-submit-btn"
                      type="submit"
                      disabled={isSubmitting || !password}
                      className="flex-1 h-12 bg-[#8B5CF6] hover:bg-[#7C3AED] text-white btn-glow disabled:opacity-50"
                    >
                      {isSubmitting ? (
                        <span className="flex items-center gap-2">
                          <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                          Unlocking...
                        </span>
                      ) : (
                        <>
                          <Lock className="w-4 h-4 mr-2" />
                          Unlock
                        </>
                      )}
                    </Button>
                  </div>
                </form>

                {/* Biometric option placeholder */}
                <div className="mt-6 pt-6 border-t border-[#27272A]">
                  <button
                    type="button"
                    className="w-full flex items-center justify-center gap-2 py-3 text-[#52525B] hover:text-[#A1A1AA] transition-colors"
                    onClick={() => toast.info('Biometric unlock available in settings after first login')}
                  >
                    <Fingerprint size={18} />
                    <span className="text-sm">Use biometric unlock</span>
                  </button>
                </div>
              </motion.div>
            )}
          </div>
        </main>

        {/* Footer */}
        <footer className="p-6 text-center">
          <p className="text-xs text-[#52525B]">
            Built with zero-trust architecture. Your data, your keys.
          </p>
        </footer>
      </div>
    </div>
  );
};

export default LandingPage;

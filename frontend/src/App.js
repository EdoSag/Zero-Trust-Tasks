import React, { useEffect, useRef } from 'react';
import { BrowserRouter, Routes, Route, Navigate, useLocation, useNavigate } from 'react-router-dom';
import { Toaster } from 'sonner';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import { VaultProvider, useVault } from './contexts/VaultContext';
import LandingPage from './pages/LandingPage';
import Dashboard from './pages/Dashboard';
import './App.css';

// Auth callback handler
const AuthCallback = () => {
  const { processSession } = useAuth();
  const navigate = useNavigate();
  const hasProcessed = useRef(false);

  useEffect(() => {
    if (hasProcessed.current) return;
    hasProcessed.current = true;

    const hash = window.location.hash;
    const params = new URLSearchParams(hash.replace('#', ''));
    const sessionId = params.get('session_id');

    if (sessionId) {
      processSession(sessionId)
        .then((user) => {
          navigate('/dashboard', { replace: true, state: { user } });
        })
        .catch(() => {
          navigate('/', { replace: true });
        });
    } else {
      navigate('/', { replace: true });
    }
  }, [processSession, navigate]);

  return (
    <div className="min-h-screen bg-[#050505] flex items-center justify-center">
      <div className="flex flex-col items-center gap-4">
        <div className="w-8 h-8 border-2 border-[#8B5CF6] border-t-transparent rounded-full animate-spin" />
        <p className="text-[#A1A1AA] font-mono">Authenticating...</p>
      </div>
    </div>
  );
};

// Protected route wrapper
const ProtectedRoute = ({ children }) => {
  const { isAuthenticated, isLoading } = useAuth();
  const { isUnlocked, hasPassword, isLoading: vaultLoading } = useVault();
  const location = useLocation();

  if (isLoading || vaultLoading) {
    return (
      <div className="min-h-screen bg-[#050505] flex items-center justify-center">
        <div className="flex flex-col items-center gap-4">
          <div className="w-8 h-8 border-2 border-[#8B5CF6] border-t-transparent rounded-full animate-spin" />
          <p className="text-[#A1A1AA] font-mono">Loading vault...</p>
        </div>
      </div>
    );
  }

  // If user came from AuthCallback with user data, they're authenticated
  if (location.state?.user) {
    return children;
  }

  if (!isAuthenticated) {
    return <Navigate to="/" replace />;
  }

  return children;
};

// App router with session_id detection
const AppRouter = () => {
  const location = useLocation();

  // Check for session_id in URL hash (from OAuth callback) - synchronous check
  if (location.hash?.includes('session_id=')) {
    return <AuthCallback />;
  }

  return (
    <Routes>
      <Route path="/" element={<LandingPage />} />
      <Route
        path="/dashboard"
        element={
          <ProtectedRoute>
            <Dashboard />
          </ProtectedRoute>
        }
      />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
};

function App() {
  return (
    <AuthProvider>
      <VaultProvider>
        <BrowserRouter>
          <div className="App">
            {/* Noise texture overlay */}
            <div className="noise-overlay" />
            <AppRouter />
            <Toaster
              position="bottom-right"
              toastOptions={{
                style: {
                  background: '#0A0A0A',
                  border: '1px solid #27272A',
                  color: '#FAFAFA'
                }
              }}
            />
          </div>
        </BrowserRouter>
      </VaultProvider>
    </AuthProvider>
  );
}

export default App;

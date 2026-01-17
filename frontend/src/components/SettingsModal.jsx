import React, { useState } from 'react';
import { Switch } from './ui/switch';
import { Slider } from './ui/slider';
import { Label } from './ui/label';
import { Button } from './ui/button';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from './ui/dialog';
import { useVault } from '../contexts/VaultContext';
import { toast } from 'sonner';
import { Fingerprint, Clock, Shield, Trash2 } from 'lucide-react';
import { clearAllData } from '../lib/db';
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle, AlertDialogTrigger } from './ui/alert-dialog';

const SettingsModal = ({ open, onClose }) => {
  const { settings, saveUserSettings, lock } = useVault();
  const [localSettings, setLocalSettings] = useState(settings);
  const [isDeleting, setIsDeleting] = useState(false);

  const handleSave = async () => {
    await saveUserSettings(localSettings);
    toast.success('Settings saved');
    onClose();
  };

  const handleBiometricSetup = async () => {
    // Check if WebAuthn is available
    if (!window.PublicKeyCredential) {
      toast.error('Biometric authentication not supported on this device');
      return;
    }

    try {
      // Check if platform authenticator is available
      const available = await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable();
      if (!available) {
        toast.error('No biometric hardware detected');
        return;
      }

      // For now, just toggle the setting
      // Full WebAuthn implementation would require server-side challenge
      setLocalSettings(s => ({ ...s, biometricEnabled: !s.biometricEnabled }));
      toast.success(localSettings.biometricEnabled ? 'Biometric disabled' : 'Biometric enabled');
    } catch (error) {
      console.error('Biometric error:', error);
      toast.error('Failed to setup biometric authentication');
    }
  };

  const handleDeleteAllData = async () => {
    setIsDeleting(true);
    try {
      await clearAllData();
      toast.success('All data deleted');
      lock();
      onClose();
      window.location.reload();
    } catch (error) {
      console.error('Delete error:', error);
      toast.error('Failed to delete data');
    } finally {
      setIsDeleting(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="bg-[#0A0A0A] border-[#27272A] text-white max-w-md glass">
        <DialogHeader>
          <DialogTitle className="font-mono text-xl flex items-center gap-2">
            <Shield className="w-5 h-5 text-[#8B5CF6]" />
            Security Settings
          </DialogTitle>
        </DialogHeader>

        <div className="space-y-6 mt-4">
          {/* Auto-lock */}
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="p-2 rounded-lg bg-[#8B5CF6]/20">
                  <Clock className="w-4 h-4 text-[#8B5CF6]" />
                </div>
                <div>
                  <Label className="text-white">Auto-lock</Label>
                  <p className="text-xs text-[#52525B]">Lock vault after inactivity</p>
                </div>
              </div>
              <Switch
                data-testid="autolock-switch"
                checked={localSettings.autoLockEnabled}
                onCheckedChange={(checked) => 
                  setLocalSettings(s => ({ ...s, autoLockEnabled: checked }))
                }
              />
            </div>

            {localSettings.autoLockEnabled && (
              <div className="pl-12">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-sm text-[#A1A1AA]">Lock after</span>
                  <span className="font-mono text-sm text-white">
                    {localSettings.autoLockTimeout} min
                  </span>
                </div>
                <Slider
                  data-testid="autolock-slider"
                  value={[localSettings.autoLockTimeout]}
                  onValueChange={([value]) => 
                    setLocalSettings(s => ({ ...s, autoLockTimeout: value }))
                  }
                  min={1}
                  max={60}
                  step={1}
                  className="w-full"
                />
                <div className="flex justify-between text-xs text-[#52525B] mt-1">
                  <span>1 min</span>
                  <span>60 min</span>
                </div>
              </div>
            )}
          </div>

          {/* Biometric unlock */}
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-lg bg-[#8B5CF6]/20">
                <Fingerprint className="w-4 h-4 text-[#8B5CF6]" />
              </div>
              <div>
                <Label className="text-white">Biometric Unlock</Label>
                <p className="text-xs text-[#52525B]">Use fingerprint or Face ID</p>
              </div>
            </div>
            <Button
              data-testid="biometric-btn"
              variant="outline"
              size="sm"
              onClick={handleBiometricSetup}
              className={`border-[#27272A] ${
                localSettings.biometricEnabled 
                  ? 'bg-[#10B981]/20 border-[#10B981]/30 text-[#10B981]' 
                  : 'text-white hover:bg-white/5'
              }`}
            >
              {localSettings.biometricEnabled ? 'Enabled' : 'Setup'}
            </Button>
          </div>

          {/* Danger zone */}
          <div className="pt-6 border-t border-[#27272A]">
            <h4 className="font-mono text-sm text-[#EF4444] mb-4">Danger Zone</h4>
            
            <AlertDialog>
              <AlertDialogTrigger asChild>
                <Button
                  data-testid="delete-all-btn"
                  variant="outline"
                  className="w-full border-[#EF4444]/30 text-[#EF4444] hover:bg-[#EF4444]/10"
                >
                  <Trash2 className="w-4 h-4 mr-2" />
                  Delete All Data
                </Button>
              </AlertDialogTrigger>
              <AlertDialogContent className="bg-[#0A0A0A] border-[#27272A]">
                <AlertDialogHeader>
                  <AlertDialogTitle className="text-white">Are you absolutely sure?</AlertDialogTitle>
                  <AlertDialogDescription className="text-[#A1A1AA]">
                    This will permanently delete all your tasks, settings, and encryption keys.
                    This action cannot be undone.
                  </AlertDialogDescription>
                </AlertDialogHeader>
                <AlertDialogFooter>
                  <AlertDialogCancel className="bg-transparent border-[#27272A] text-white hover:bg-white/5">
                    Cancel
                  </AlertDialogCancel>
                  <AlertDialogAction
                    onClick={handleDeleteAllData}
                    disabled={isDeleting}
                    className="bg-[#EF4444] hover:bg-[#DC2626] text-white"
                  >
                    {isDeleting ? 'Deleting...' : 'Delete Everything'}
                  </AlertDialogAction>
                </AlertDialogFooter>
              </AlertDialogContent>
            </AlertDialog>
          </div>

          {/* Save button */}
          <div className="flex gap-3 pt-4">
            <Button
              variant="outline"
              onClick={onClose}
              className="flex-1 border-[#27272A] text-white hover:bg-white/5"
            >
              Cancel
            </Button>
            <Button
              data-testid="settings-save-btn"
              onClick={handleSave}
              className="flex-1 bg-[#8B5CF6] hover:bg-[#7C3AED] text-white btn-glow"
            >
              Save Settings
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
};

export default SettingsModal;

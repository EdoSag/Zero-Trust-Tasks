import React, { useState } from 'react';
import { Button } from './ui/button';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from './ui/dialog';
import { useVault } from '../contexts/VaultContext';
import { useAuth } from '../contexts/AuthContext';
import { toast } from 'sonner';
import { Download, Upload, Cloud, FileKey, Loader2, CheckCircle2 } from 'lucide-react';
import { exportAllData } from '../lib/db';

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL;
const API = `${BACKEND_URL}/api`;

const BackupModal = ({ open, onClose }) => {
  const { exportBackup, salt, encryptionKey } = useVault();
  const { isAuthenticated, loginWithGoogle } = useAuth();
  const [isExporting, setIsExporting] = useState(false);
  const [isUploading, setIsUploading] = useState(false);
  const [lastBackup, setLastBackup] = useState(null);

  // Export for Proton Drive (download encrypted file)
  const handleProtonExport = async () => {
    setIsExporting(true);
    try {
      const data = await exportAllData();
      
      if (!data.encryptedData) {
        toast.error('No data to export');
        setIsExporting(false);
        return;
      }

      // Create a JSON blob with all encrypted data
      const exportData = {
        type: 'obsidian-vault-backup',
        version: 1,
        ...data,
        salt,
        exportedAt: new Date().toISOString()
      };

      const blob = new Blob([JSON.stringify(exportData, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      
      const a = document.createElement('a');
      a.href = url;
      a.download = `obsidian-vault-backup-${new Date().toISOString().split('T')[0]}.json`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);

      toast.success('Backup file downloaded');
      setLastBackup(new Date());
    } catch (error) {
      console.error('Export error:', error);
      toast.error('Failed to export backup');
    } finally {
      setIsExporting(false);
    }
  };

  // Upload to Google Drive (via backend)
  const handleGoogleDriveBackup = async () => {
    if (!isAuthenticated) {
      toast.info('Please sign in with Google first');
      loginWithGoogle();
      return;
    }

    setIsUploading(true);
    try {
      const backupData = await exportBackup();
      
      if (!backupData?.encryptedData) {
        toast.error('No data to backup');
        setIsUploading(false);
        return;
      }

      // Send encrypted data to backend for Google Drive upload
      const response = await fetch(`${API}/backup/create?backup_type=google_drive`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({
          encrypted_data: backupData.encryptedData,
          iv: backupData.iv,
          salt: backupData.salt
        })
      });

      if (!response.ok) {
        throw new Error('Backup upload failed');
      }

      toast.success('Backup uploaded to Google Drive');
      setLastBackup(new Date());
    } catch (error) {
      console.error('Google Drive backup error:', error);
      toast.error('Failed to upload backup');
    } finally {
      setIsUploading(false);
    }
  };

  // Import backup file
  const handleImport = async (event) => {
    const file = event.target.files?.[0];
    if (!file) return;

    try {
      const text = await file.text();
      const data = JSON.parse(text);

      if (data.type !== 'obsidian-vault-backup') {
        toast.error('Invalid backup file');
        return;
      }

      // For now, just show success - full import would require password re-entry
      toast.info('Import feature requires unlocking with the original master password');
    } catch (error) {
      console.error('Import error:', error);
      toast.error('Failed to read backup file');
    }
  };

  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="bg-[#0A0A0A] border-[#27272A] text-white max-w-md glass">
        <DialogHeader>
          <DialogTitle className="font-mono text-xl flex items-center gap-2">
            <FileKey className="w-5 h-5 text-[#8B5CF6]" />
            Encrypted Backup
          </DialogTitle>
        </DialogHeader>

        <div className="space-y-6 mt-4">
          {/* Info box */}
          <div className="p-4 rounded-lg bg-[#8B5CF6]/10 border border-[#8B5CF6]/20">
            <p className="text-sm text-[#8B5CF6]">
              <strong>Zero-Knowledge Backup:</strong> Your data is encrypted before leaving your device. 
              Neither Google nor Proton can read your tasks.
            </p>
          </div>

          {/* Google Drive backup */}
          <div className="p-4 rounded-lg bg-[#050505] border border-[#27272A]">
            <div className="flex items-center gap-3 mb-3">
              <div className="p-2 rounded-lg bg-[#4285F4]/20">
                <Cloud className="w-5 h-5 text-[#4285F4]" />
              </div>
              <div>
                <h4 className="font-medium text-white">Google Drive</h4>
                <p className="text-xs text-[#52525B]">Automatic cloud backup</p>
              </div>
            </div>
            <Button
              data-testid="google-drive-backup-btn"
              onClick={handleGoogleDriveBackup}
              disabled={isUploading}
              className="w-full bg-[#4285F4] hover:bg-[#3367D6] text-white"
            >
              {isUploading ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  Uploading...
                </>
              ) : (
                <>
                  <Upload className="w-4 h-4 mr-2" />
                  Backup to Google Drive
                </>
              )}
            </Button>
          </div>

          {/* Proton Drive export */}
          <div className="p-4 rounded-lg bg-[#050505] border border-[#27272A]">
            <div className="flex items-center gap-3 mb-3">
              <div className="p-2 rounded-lg bg-[#6D4AFF]/20">
                <FileKey className="w-5 h-5 text-[#6D4AFF]" />
              </div>
              <div>
                <h4 className="font-medium text-white">Proton Drive</h4>
                <p className="text-xs text-[#52525B]">Download for manual upload</p>
              </div>
            </div>
            <Button
              data-testid="proton-export-btn"
              onClick={handleProtonExport}
              disabled={isExporting}
              variant="outline"
              className="w-full border-[#6D4AFF]/30 text-[#6D4AFF] hover:bg-[#6D4AFF]/10"
            >
              {isExporting ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  Exporting...
                </>
              ) : (
                <>
                  <Download className="w-4 h-4 mr-2" />
                  Export for Proton Drive
                </>
              )}
            </Button>
          </div>

          {/* Import */}
          <div className="pt-4 border-t border-[#27272A]">
            <h4 className="text-sm text-[#A1A1AA] mb-3">Restore from backup</h4>
            <label className="block">
              <input
                type="file"
                accept=".json"
                onChange={handleImport}
                className="hidden"
              />
              <Button
                variant="outline"
                className="w-full border-[#27272A] text-white hover:bg-white/5"
                asChild
              >
                <span className="cursor-pointer">
                  <Upload className="w-4 h-4 mr-2" />
                  Import Backup File
                </span>
              </Button>
            </label>
          </div>

          {/* Last backup indicator */}
          {lastBackup && (
            <div className="flex items-center gap-2 text-xs text-[#10B981]">
              <CheckCircle2 size={14} />
              Last backup: {lastBackup.toLocaleTimeString()}
            </div>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
};

export default BackupModal;

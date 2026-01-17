import React, { createContext, useContext, useState, useCallback, useEffect, useRef } from 'react';
import { deriveKey, encrypt, decrypt, hashPassword, generateSalt, validatePasswordStrength } from '../lib/crypto';
import { saveCryptoMeta, getCryptoMeta, saveEncryptedData, getEncryptedData, hasMasterPassword, saveSettings, getSettings } from '../lib/db';
import { sanitizeTask } from '../lib/sanitize';
import { toast } from 'sonner';

const VaultContext = createContext(null);

export const useVault = () => {
  const context = useContext(VaultContext);
  if (!context) {
    throw new Error('useVault must be used within VaultProvider');
  }
  return context;
};

const DEFAULT_SETTINGS = {
  autoLockEnabled: true,
  autoLockTimeout: 5, // minutes
  biometricEnabled: false,
  theme: 'dark'
};

export const VaultProvider = ({ children }) => {
  const [isUnlocked, setIsUnlocked] = useState(false);
  const [isInitialized, setIsInitialized] = useState(false);
  const [hasPassword, setHasPassword] = useState(false);
  const [encryptionKey, setEncryptionKey] = useState(null);
  const [tasks, setTasks] = useState([]);
  const [categories, setCategories] = useState(['Work', 'Personal', 'Shopping', 'Health']);
  const [settings, setSettings] = useState(DEFAULT_SETTINGS);
  const [isLoading, setIsLoading] = useState(true);
  const [salt, setSalt] = useState(null);
  
  const lockTimeoutRef = useRef(null);
  const lastActivityRef = useRef(Date.now());

  // Initialize - check if master password exists
  useEffect(() => {
    const init = async () => {
      try {
        const hasPass = await hasMasterPassword();
        setHasPassword(hasPass);
        setIsInitialized(true);
      } catch (error) {
        console.error('Init error:', error);
        toast.error('Failed to initialize vault');
      } finally {
        setIsLoading(false);
      }
    };
    init();
  }, []);

  // Auto-lock timer
  useEffect(() => {
    if (!isUnlocked || !settings.autoLockEnabled) return;

    const checkInactivity = () => {
      const now = Date.now();
      const elapsed = (now - lastActivityRef.current) / 1000 / 60; // minutes
      
      if (elapsed >= settings.autoLockTimeout) {
        lock();
        toast.info('Vault locked due to inactivity');
      }
    };

    lockTimeoutRef.current = setInterval(checkInactivity, 10000); // Check every 10s

    return () => {
      if (lockTimeoutRef.current) {
        clearInterval(lockTimeoutRef.current);
      }
    };
  }, [isUnlocked, settings.autoLockEnabled, settings.autoLockTimeout]);

  // Track activity
  useEffect(() => {
    const updateActivity = () => {
      lastActivityRef.current = Date.now();
    };

    window.addEventListener('mousemove', updateActivity);
    window.addEventListener('keydown', updateActivity);
    window.addEventListener('click', updateActivity);
    window.addEventListener('touchstart', updateActivity);

    return () => {
      window.removeEventListener('mousemove', updateActivity);
      window.removeEventListener('keydown', updateActivity);
      window.removeEventListener('click', updateActivity);
      window.removeEventListener('touchstart', updateActivity);
    };
  }, []);

  // Create master password
  const createMasterPassword = useCallback(async (password) => {
    try {
      const newSalt = generateSalt();
      const hash = await hashPassword(password, newSalt);
      const key = await deriveKey(password, newSalt);
      
      await saveCryptoMeta(newSalt, hash);
      
      setSalt(newSalt);
      setEncryptionKey(key);
      setHasPassword(true);
      setIsUnlocked(true);
      
      // Save initial empty data
      const initialData = JSON.stringify({ tasks: [], categories: ['Work', 'Personal', 'Shopping', 'Health'] });
      const { encrypted, iv } = await encrypt(initialData, key);
      await saveEncryptedData(encrypted, iv, newSalt);
      
      // Save default settings
      const settingsData = JSON.stringify(DEFAULT_SETTINGS);
      const settingsEncrypted = await encrypt(settingsData, key);
      await saveSettings(settingsEncrypted.encrypted, settingsEncrypted.iv, newSalt);
      
      toast.success('Vault created successfully');
      return true;
    } catch (error) {
      console.error('Create password error:', error);
      toast.error('Failed to create vault');
      return false;
    }
  }, []);

  // Unlock vault
  const unlock = useCallback(async (password) => {
    try {
      const meta = await getCryptoMeta();
      if (!meta) {
        toast.error('No vault found');
        return false;
      }
      
      const hash = await hashPassword(password, meta.salt);
      if (hash !== meta.passwordHash) {
        toast.error('Incorrect password');
        return false;
      }
      
      const key = await deriveKey(password, meta.salt);
      setSalt(meta.salt);
      setEncryptionKey(key);
      
      // Load encrypted data
      const data = await getEncryptedData();
      if (data) {
        const decrypted = await decrypt(data.encryptedData, data.iv, key);
        const parsed = JSON.parse(decrypted);
        setTasks(parsed.tasks || []);
        setCategories(parsed.categories || ['Work', 'Personal', 'Shopping', 'Health']);
      }
      
      // Load settings
      const settingsData = await getSettings();
      if (settingsData) {
        try {
          const decryptedSettings = await decrypt(settingsData.encryptedSettings, settingsData.iv, key);
          setSettings(JSON.parse(decryptedSettings));
        } catch {
          setSettings(DEFAULT_SETTINGS);
        }
      }
      
      setIsUnlocked(true);
      lastActivityRef.current = Date.now();
      toast.success('Vault unlocked');
      return true;
    } catch (error) {
      console.error('Unlock error:', error);
      toast.error('Failed to unlock vault');
      return false;
    }
  }, []);

  // Lock vault
  const lock = useCallback(() => {
    setIsUnlocked(false);
    setEncryptionKey(null);
    setTasks([]);
    setSettings(DEFAULT_SETTINGS);
  }, []);

  // Save data (encrypted)
  const saveData = useCallback(async (newTasks, newCategories) => {
    if (!encryptionKey || !salt) return;
    
    try {
      const data = JSON.stringify({ 
        tasks: newTasks || tasks, 
        categories: newCategories || categories 
      });
      const { encrypted, iv } = await encrypt(data, encryptionKey);
      await saveEncryptedData(encrypted, iv, salt);
    } catch (error) {
      console.error('Save error:', error);
      toast.error('Failed to save data');
    }
  }, [encryptionKey, salt, tasks, categories]);

  // Save settings
  const saveUserSettings = useCallback(async (newSettings) => {
    if (!encryptionKey || !salt) return;
    
    try {
      setSettings(newSettings);
      const data = JSON.stringify(newSettings);
      const { encrypted, iv } = await encrypt(data, encryptionKey);
      await saveSettings(encrypted, iv, salt);
    } catch (error) {
      console.error('Save settings error:', error);
      toast.error('Failed to save settings');
    }
  }, [encryptionKey, salt]);

  // Task CRUD operations
  const addTask = useCallback(async (task) => {
    const sanitized = sanitizeTask({
      id: crypto.randomUUID(),
      ...task,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      completed: false,
      subtasks: []
    });
    
    const newTasks = [...tasks, sanitized];
    setTasks(newTasks);
    await saveData(newTasks);
    return sanitized;
  }, [tasks, saveData]);

  const updateTask = useCallback(async (taskId, updates, parentPath = []) => {
    const updateTaskRecursive = (taskList, path, idx = 0) => {
      if (path.length === 0) {
        return taskList.map(t => 
          t.id === taskId 
            ? sanitizeTask({ ...t, ...updates, updatedAt: new Date().toISOString() })
            : t
        );
      }
      
      return taskList.map(t => {
        if (t.id === path[idx]) {
          if (idx === path.length - 1) {
            return {
              ...t,
              subtasks: t.subtasks.map(st => 
                st.id === taskId 
                  ? sanitizeTask({ ...st, ...updates, updatedAt: new Date().toISOString() })
                  : st
              )
            };
          }
          return {
            ...t,
            subtasks: updateTaskRecursive(t.subtasks, path, idx + 1)
          };
        }
        return t;
      });
    };
    
    const newTasks = updateTaskRecursive(tasks, parentPath);
    setTasks(newTasks);
    await saveData(newTasks);
  }, [tasks, saveData]);

  const deleteTask = useCallback(async (taskId, parentPath = []) => {
    const deleteTaskRecursive = (taskList, path, idx = 0) => {
      if (path.length === 0) {
        return taskList.filter(t => t.id !== taskId);
      }
      
      return taskList.map(t => {
        if (t.id === path[idx]) {
          if (idx === path.length - 1) {
            return {
              ...t,
              subtasks: t.subtasks.filter(st => st.id !== taskId)
            };
          }
          return {
            ...t,
            subtasks: deleteTaskRecursive(t.subtasks, path, idx + 1)
          };
        }
        return t;
      });
    };
    
    const newTasks = deleteTaskRecursive(tasks, parentPath);
    setTasks(newTasks);
    await saveData(newTasks);
  }, [tasks, saveData]);

  const addSubtask = useCallback(async (parentId, subtask, parentPath = []) => {
    const newSubtask = sanitizeTask({
      id: crypto.randomUUID(),
      ...subtask,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      completed: false,
      subtasks: []
    });
    
    const addSubtaskRecursive = (taskList, path, idx = 0) => {
      return taskList.map(t => {
        if (path.length === 0 && t.id === parentId) {
          return {
            ...t,
            subtasks: [...(t.subtasks || []), newSubtask]
          };
        }
        if (t.id === path[idx]) {
          if (idx === path.length - 1) {
            return {
              ...t,
              subtasks: t.subtasks.map(st => 
                st.id === parentId 
                  ? { ...st, subtasks: [...(st.subtasks || []), newSubtask] }
                  : st
              )
            };
          }
          return {
            ...t,
            subtasks: addSubtaskRecursive(t.subtasks, path, idx + 1)
          };
        }
        return t;
      });
    };
    
    const newTasks = addSubtaskRecursive(tasks, parentPath);
    setTasks(newTasks);
    await saveData(newTasks);
    return newSubtask;
  }, [tasks, saveData]);

  // Category operations
  const addCategory = useCallback(async (category) => {
    if (categories.includes(category)) return;
    const newCategories = [...categories, category];
    setCategories(newCategories);
    await saveData(tasks, newCategories);
  }, [categories, tasks, saveData]);

  const removeCategory = useCallback(async (category) => {
    const newCategories = categories.filter(c => c !== category);
    setCategories(newCategories);
    await saveData(tasks, newCategories);
  }, [categories, tasks, saveData]);

  // Export encrypted backup
  const exportBackup = useCallback(async () => {
    if (!encryptionKey || !salt) return null;
    
    const data = await getEncryptedData();
    const settingsData = await getSettings();
    
    return {
      encryptedData: data?.encryptedData,
      iv: data?.iv,
      settings: settingsData?.encryptedSettings,
      settingsIv: settingsData?.iv,
      salt,
      exportedAt: new Date().toISOString(),
      version: 1
    };
  }, [encryptionKey, salt]);

  const value = {
    isUnlocked,
    isInitialized,
    hasPassword,
    isLoading,
    tasks,
    categories,
    settings,
    encryptionKey,
    salt,
    createMasterPassword,
    unlock,
    lock,
    addTask,
    updateTask,
    deleteTask,
    addSubtask,
    addCategory,
    removeCategory,
    saveUserSettings,
    exportBackup,
    validatePasswordStrength
  };

  return (
    <VaultContext.Provider value={value}>
      {children}
    </VaultContext.Provider>
  );
};

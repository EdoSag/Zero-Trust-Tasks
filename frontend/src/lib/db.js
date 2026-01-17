/**
 * IndexedDB wrapper for local encrypted storage
 * All data stored here is already encrypted
 */

import { openDB } from 'idb';

const DB_NAME = 'obsidian-vault';
const DB_VERSION = 1;

let dbPromise = null;

const getDB = async () => {
  if (!dbPromise) {
    dbPromise = openDB(DB_NAME, DB_VERSION, {
      upgrade(db) {
        // Store for encrypted task data
        if (!db.objectStoreNames.contains('encrypted_data')) {
          db.createObjectStore('encrypted_data', { keyPath: 'id' });
        }
        
        // Store for encryption metadata (salt, hash for password verification)
        if (!db.objectStoreNames.contains('crypto_meta')) {
          db.createObjectStore('crypto_meta', { keyPath: 'id' });
        }
        
        // Store for settings
        if (!db.objectStoreNames.contains('settings')) {
          db.createObjectStore('settings', { keyPath: 'id' });
        }
        
        // Store for WebAuthn credentials
        if (!db.objectStoreNames.contains('webauthn')) {
          db.createObjectStore('webauthn', { keyPath: 'id' });
        }
      }
    });
  }
  return dbPromise;
};

// ============ Crypto Metadata ============

export const saveCryptoMeta = async (salt, passwordHash) => {
  const db = await getDB();
  await db.put('crypto_meta', {
    id: 'master',
    salt,
    passwordHash,
    createdAt: new Date().toISOString()
  });
};

export const getCryptoMeta = async () => {
  const db = await getDB();
  return db.get('crypto_meta', 'master');
};

export const hasMasterPassword = async () => {
  const meta = await getCryptoMeta();
  return !!meta;
};

// ============ Encrypted Data ============

export const saveEncryptedData = async (encryptedData, iv, salt) => {
  const db = await getDB();
  await db.put('encrypted_data', {
    id: 'tasks',
    encryptedData,
    iv,
    salt,
    updatedAt: new Date().toISOString()
  });
};

export const getEncryptedData = async () => {
  const db = await getDB();
  return db.get('encrypted_data', 'tasks');
};

// ============ Settings ============

export const saveSettings = async (encryptedSettings, iv, salt) => {
  const db = await getDB();
  await db.put('settings', {
    id: 'user_settings',
    encryptedSettings,
    iv,
    salt,
    updatedAt: new Date().toISOString()
  });
};

export const getSettings = async () => {
  const db = await getDB();
  return db.get('settings', 'user_settings');
};

// ============ WebAuthn ============

export const saveWebAuthnCredential = async (credential) => {
  const db = await getDB();
  await db.put('webauthn', {
    id: credential.id,
    ...credential
  });
};

export const getWebAuthnCredentials = async () => {
  const db = await getDB();
  return db.getAll('webauthn');
};

export const deleteWebAuthnCredential = async (id) => {
  const db = await getDB();
  await db.delete('webauthn', id);
};

// ============ Clear All Data ============

export const clearAllData = async () => {
  const db = await getDB();
  const tx = db.transaction(['encrypted_data', 'crypto_meta', 'settings', 'webauthn'], 'readwrite');
  await Promise.all([
    tx.objectStore('encrypted_data').clear(),
    tx.objectStore('crypto_meta').clear(),
    tx.objectStore('settings').clear(),
    tx.objectStore('webauthn').clear(),
    tx.done
  ]);
};

// ============ Export for Backup ============

export const exportAllData = async () => {
  const db = await getDB();
  const [encryptedData, settings] = await Promise.all([
    db.get('encrypted_data', 'tasks'),
    db.get('settings', 'user_settings')
  ]);
  
  return {
    encryptedData,
    settings,
    exportedAt: new Date().toISOString(),
    version: DB_VERSION
  };
};

export const importData = async (data) => {
  const db = await getDB();
  const tx = db.transaction(['encrypted_data', 'settings'], 'readwrite');
  
  if (data.encryptedData) {
    await tx.objectStore('encrypted_data').put(data.encryptedData);
  }
  if (data.settings) {
    await tx.objectStore('settings').put(data.settings);
  }
  
  await tx.done;
};

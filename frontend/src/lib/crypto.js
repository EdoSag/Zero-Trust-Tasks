/**
 * Zero-Knowledge Cryptography Module
 * All encryption/decryption happens client-side only
 * Backend NEVER sees raw data
 */

// Convert string to ArrayBuffer
const stringToBuffer = (str) => {
  return new TextEncoder().encode(str);
};

// Convert ArrayBuffer to string
const bufferToString = (buffer) => {
  return new TextDecoder().decode(buffer);
};

// Convert ArrayBuffer to base64
const bufferToBase64 = (buffer) => {
  const bytes = new Uint8Array(buffer);
  let binary = '';
  bytes.forEach(b => binary += String.fromCharCode(b));
  return btoa(binary);
};

// Convert base64 to ArrayBuffer
const base64ToBuffer = (base64) => {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
};

// Generate random salt
export const generateSalt = () => {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  return bufferToBase64(salt);
};

// Generate random IV for AES-GCM
export const generateIV = () => {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  return bufferToBase64(iv);
};

/**
 * Derive encryption key from master password using PBKDF2
 * @param {string} password - Master password
 * @param {string} saltBase64 - Base64 encoded salt
 * @returns {Promise<CryptoKey>} - Derived AES-GCM key
 */
export const deriveKey = async (password, saltBase64) => {
  const salt = base64ToBuffer(saltBase64);
  
  // Import password as key material
  const keyMaterial = await crypto.subtle.importKey(
    'raw',
    stringToBuffer(password),
    'PBKDF2',
    false,
    ['deriveKey']
  );
  
  // Derive AES-256-GCM key using PBKDF2
  const key = await crypto.subtle.deriveKey(
    {
      name: 'PBKDF2',
      salt: salt,
      iterations: 100000, // High iteration count for security
      hash: 'SHA-256'
    },
    keyMaterial,
    { name: 'AES-GCM', length: 256 },
    false, // Non-extractable for security
    ['encrypt', 'decrypt']
  );
  
  return key;
};

/**
 * Encrypt data using AES-256-GCM
 * @param {string} plaintext - Data to encrypt
 * @param {CryptoKey} key - Derived encryption key
 * @returns {Promise<{encrypted: string, iv: string}>} - Base64 encoded ciphertext and IV
 */
export const encrypt = async (plaintext, key) => {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const data = stringToBuffer(plaintext);
  
  const encrypted = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv },
    key,
    data
  );
  
  return {
    encrypted: bufferToBase64(encrypted),
    iv: bufferToBase64(iv)
  };
};

/**
 * Decrypt data using AES-256-GCM
 * @param {string} ciphertextBase64 - Base64 encoded ciphertext
 * @param {string} ivBase64 - Base64 encoded IV
 * @param {CryptoKey} key - Derived encryption key
 * @returns {Promise<string>} - Decrypted plaintext
 */
export const decrypt = async (ciphertextBase64, ivBase64, key) => {
  const ciphertext = base64ToBuffer(ciphertextBase64);
  const iv = base64ToBuffer(ivBase64);
  
  const decrypted = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv },
    key,
    ciphertext
  );
  
  return bufferToString(decrypted);
};

/**
 * Hash password for verification (not for storage!)
 * Used to verify master password without storing it
 * @param {string} password - Master password
 * @param {string} saltBase64 - Base64 encoded salt
 * @returns {Promise<string>} - Base64 encoded hash
 */
export const hashPassword = async (password, saltBase64) => {
  const salt = base64ToBuffer(saltBase64);
  const data = stringToBuffer(password + bufferToString(salt));
  
  const hash = await crypto.subtle.digest('SHA-256', data);
  return bufferToBase64(hash);
};

/**
 * Validate password strength
 * @param {string} password - Password to validate
 * @returns {{score: number, feedback: string[]}} - Strength score (0-4) and feedback
 */
export const validatePasswordStrength = (password) => {
  const feedback = [];
  let score = 0;
  
  if (password.length >= 8) score++;
  else feedback.push('At least 8 characters required');
  
  if (password.length >= 12) score++;
  if (password.length >= 16) score++;
  
  if (/[a-z]/.test(password) && /[A-Z]/.test(password)) score++;
  else if (!/[A-Z]/.test(password)) feedback.push('Add uppercase letters');
  
  if (/\d/.test(password)) score++;
  else feedback.push('Add numbers');
  
  if (/[!@#$%^&*(),.?":{}|<>]/.test(password)) score++;
  else feedback.push('Add special characters');
  
  // Cap at 4
  score = Math.min(score, 4);
  
  return { score, feedback };
};

/**
 * Generate a strong random password
 * @param {number} length - Password length
 * @returns {string} - Generated password
 */
export const generateStrongPassword = (length = 20) => {
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()';
  const array = crypto.getRandomValues(new Uint8Array(length));
  return Array.from(array, b => chars[b % chars.length]).join('');
};

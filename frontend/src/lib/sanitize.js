/**
 * Input sanitization to prevent XSS attacks
 */

import DOMPurify from 'dompurify';

/**
 * Sanitize HTML content
 * @param {string} dirty - Potentially unsafe HTML
 * @returns {string} - Sanitized HTML
 */
export const sanitizeHTML = (dirty) => {
  return DOMPurify.sanitize(dirty, {
    ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'a', 'p', 'br', 'ul', 'ol', 'li'],
    ALLOWED_ATTR: ['href', 'target', 'rel']
  });
};

/**
 * Sanitize plain text (remove all HTML)
 * @param {string} dirty - Potentially unsafe text
 * @returns {string} - Plain text
 */
export const sanitizeText = (dirty) => {
  if (!dirty) return '';
  return DOMPurify.sanitize(dirty, { ALLOWED_TAGS: [] });
};

/**
 * Validate and sanitize task data
 * @param {object} task - Task object to sanitize
 * @returns {object} - Sanitized task
 */
export const sanitizeTask = (task) => {
  return {
    ...task,
    title: sanitizeText(task.title || ''),
    description: sanitizeHTML(task.description || ''),
    category: sanitizeText(task.category || ''),
    tags: (task.tags || []).map(tag => sanitizeText(tag)),
    subtasks: (task.subtasks || []).map(subtask => sanitizeTask(subtask))
  };
};

/**
 * Validate file for attachment
 * @param {File} file - File to validate
 * @param {number} maxSize - Max size in bytes (default 10MB)
 * @returns {{valid: boolean, error?: string}}
 */
export const validateFile = (file, maxSize = 10 * 1024 * 1024) => {
  if (!file) {
    return { valid: false, error: 'No file provided' };
  }
  
  if (file.size > maxSize) {
    return { valid: false, error: `File too large. Max size: ${maxSize / 1024 / 1024}MB` };
  }
  
  // Blocked file types (executable, scripts)
  const blockedExtensions = ['.exe', '.bat', '.cmd', '.sh', '.ps1', '.vbs', '.js', '.msi'];
  const fileName = file.name.toLowerCase();
  
  for (const ext of blockedExtensions) {
    if (fileName.endsWith(ext)) {
      return { valid: false, error: `File type ${ext} is not allowed` };
    }
  }
  
  return { valid: true };
};

/**
 * Escape special regex characters
 * @param {string} str - String to escape
 * @returns {string} - Escaped string
 */
export const escapeRegex = (str) => {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
};

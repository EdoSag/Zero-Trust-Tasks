# Obsidian Vault - Zero-Trust Task Manager PRD

## Original Problem Statement
Build a high-security, local-first task management application with Zero-Trust architecture featuring:
- CRUD Operations for tasks with Categories, Priorities (Low/Med/High/Critical), Due Dates, and unlimited nested Sub-tasks
- Dashboard with visual overview by status and priority
- Zero-Knowledge Architecture with client-side AES-256-GCM encryption
- PBKDF2 key derivation from master password (never stored)
- Google Drive encrypted backups and Proton Drive export
- Auto-lock with configurable timeout and biometric unlock (WebAuthn)
- Purple & black elegant UI theme

## User Personas
1. **Security-Conscious Professional** - Needs encrypted task management that doesn't compromise privacy
2. **Privacy Advocate** - Wants zero-knowledge architecture where even the service provider can't read data
3. **Mobile User** - Needs responsive design that works on both desktop and mobile with biometric unlock

## Core Requirements (Static)
| Requirement | Priority | Status |
|-------------|----------|--------|
| Client-side AES-256-GCM encryption | P0 | ✅ Implemented |
| PBKDF2 key derivation from master password | P0 | ✅ Implemented |
| Google OAuth authentication | P0 | ✅ Implemented |
| Task CRUD operations | P0 | ✅ Implemented |
| Unlimited nested subtasks | P0 | ✅ Implemented |
| Priority levels (Low/Med/High/Critical) | P0 | ✅ Implemented |
| Categories/tags | P0 | ✅ Implemented |
| Due dates with calendar picker | P0 | ✅ Implemented |
| Dashboard with stats | P0 | ✅ Implemented |
| Auto-lock with timeout | P1 | ✅ Implemented |
| Proton Drive export | P1 | ✅ Implemented |
| Google Drive backup | P1 | ✅ Implemented |
| Biometric unlock (WebAuthn) | P1 | ✅ Implemented |
| XSS prevention (DOMPurify) | P0 | ✅ Implemented |
| Password strength indicator | P1 | ✅ Implemented |

## What's Been Implemented (January 17, 2026)

### Backend (FastAPI)
- `/api/auth/session` - Exchange Emergent OAuth session for local session
- `/api/auth/me` - Get current authenticated user
- `/api/auth/logout` - Clear session and logout
- `/api/data` - GET/POST encrypted task data
- `/api/settings` - GET/POST encrypted settings
- `/api/webauthn/*` - WebAuthn credential management
- `/api/backup/create` - Create encrypted backup
- `/api/backup/list` - List backups

### Frontend (React)
- **Landing Page** - OAuth login, master password creation with strength indicator
- **Dashboard** - Bento grid layout with stats (total, pending, completed, critical)
- **Task List** - Search, filter by priority/category, expandable subtasks
- **Task Modal** - Create/edit tasks with priority, category, due date
- **Settings Modal** - Auto-lock timeout, biometric setup, delete all data
- **Backup Modal** - Google Drive upload, Proton Drive export download

### Security Features
- AES-256-GCM encryption via Web Crypto API
- PBKDF2 with 100,000 iterations for key derivation
- IndexedDB for local encrypted storage
- DOMPurify for XSS sanitization
- WebAuthn for biometric authentication
- Zero-knowledge architecture (backend never sees raw data)

## Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                        FRONTEND (React)                      │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │ Master Password │  │ AES-256-GCM     │  │ IndexedDB    │ │
│  │ → PBKDF2       │→ │ Encrypt/Decrypt │→ │ Local Store  │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
│                              │                               │
│                    Encrypted Blobs Only                      │
│                              ↓                               │
└──────────────────────────────┼───────────────────────────────┘
                               │
                    HTTPS (Encrypted in Transit)
                               │
┌──────────────────────────────┼───────────────────────────────┐
│                        BACKEND (FastAPI)                      │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │ Auth Routes     │  │ Encrypted Data  │  │ MongoDB      │ │
│  │ (OAuth, Session)│  │ Storage         │→ │ (Opaque Blobs│ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
│                                                              │
│         Backend NEVER sees raw task data!                    │
└──────────────────────────────────────────────────────────────┘
```

## Prioritized Backlog

### P0 - Critical (Done)
- [x] Client-side encryption
- [x] Task CRUD
- [x] OAuth authentication
- [x] Dashboard
- [x] XSS prevention

### P1 - High (Done)
- [x] Nested subtasks
- [x] Auto-lock
- [x] Backup export
- [x] Biometric unlock setup

### P2 - Future Enhancements
- [ ] Full WebAuthn challenge-response flow (currently simplified)
- [ ] Encrypted file attachments storage
- [ ] Google Drive restore from backup
- [ ] Task reminders/notifications
- [ ] Recurring tasks
- [ ] Task sharing with end-to-end encryption
- [ ] Offline sync with conflict resolution
- [ ] Export to other formats (PDF, CSV)

## Next Tasks
1. **Test real Google OAuth flow** - Login with Google account
2. **Create master password** - Set up encryption vault
3. **Add tasks** - Test task creation with all metadata
4. **Test backup** - Export to Proton Drive format
5. **Consider** - Adding file attachments with client-side encryption

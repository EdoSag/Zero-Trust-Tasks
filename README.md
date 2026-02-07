# 🛡️ Zero-Trust Tasks

A privacy-first, local-first task manager built with **Flutter**.

## 🌟 Key Features

- **Client-side encryption:** Tasks are encrypted locally before storage/sync.
- **Authenticated encryption:** Uses **AES-256-GCM**.
- **Password-based key derivation:** Uses **PBKDF2-HMAC-SHA256** with a high iteration count.
- **Secure secret storage:** Salt and verification blob are stored in **iOS Keychain / Android Keystore** via `flutter_secure_storage`.
- **Cloud Sync (encrypted backup):** Upload/download encrypted backup blobs to Google Drive `appDataFolder`.
- **Session hardening:** In-memory session key with idle timeout and login backoff.

---

## 🔒 Security Architecture

1. **Derive key** from master password using PBKDF2-HMAC-SHA256 + random 32-byte salt.
2. **Encrypt/decrypt task JSON** using AES-256-GCM (nonce + auth tag).
3. **Persist encrypted data** in SharedPreferences as ciphertext blob.
4. **Store security metadata** in secure storage (salt + verification payload).
5. **Cloud backup** uploads only encrypted payloads.

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.0+)
- Google Cloud / Google Sign-In setup for Drive backup sync

### Installation

```bash
git clone https://github.com/EdoSag/Zero-Trust-Tasks.git
cd Zero-Trust-Tasks
flutter pub get
flutter run
```

For Google Drive sync, add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) per Flutter Google Sign-In docs.

---

## 🛠️ Built With

- Flutter
- pointycastle (PBKDF2 + AES-GCM primitives)
- flutter_secure_storage
- google_sign_in + googleapis (Drive app data backup)


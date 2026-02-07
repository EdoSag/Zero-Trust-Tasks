# Security Review: Zero-Trust-Tasks

## Current Status
Security-critical gaps from the previous review have been remediated in code:

- Replaced custom crypto with PBKDF2-HMAC-SHA256 key derivation and AES-256-GCM authenticated encryption.
- Moved salt/verification metadata to hardware-backed secure storage via `flutter_secure_storage`.
- Added session idle timeout and unlock backoff protection.
- Added encrypted Google Drive backup sync (upload/download from appDataFolder).

## Remaining Recommendations
- Add automated unit/integration tests for crypto known-answer vectors and tamper detection.
- Add optional biometric re-unlock flow.
- Add CI security checks and dependency auditing.

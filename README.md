# 🛡️ Zero-Trust Tasks

A privacy-first, local-first task manager built with **Flutter**. This project follows a **Zero-Knowledge architecture**, ensuring that your data is never accessible to anyone but you—not even your cloud storage provider.

## 🌟 Key Features

* **Zero-Knowledge Encryption:** Your data is encrypted locally before ever leaving your device.
* **Military-Grade Crypto:** Utilizes **AES-256-GCM** for authenticated encryption, ensuring data integrity and confidentiality.
* **Hardened Key Derivation:** Uses **PBKDF2 with HMAC-SHA256** and 100,000+ iterations to protect your master password against brute-force attacks.
* **Secure Hardware Storage:** Sensitive metadata (salts and verification tags) is stored in the device's secure enclave (**iOS Keychain / Android Keystore**).
* **Cloud Sync (Zero-Trust):** Seamlessly sync encrypted backups to Google Drive using the "Least Privilege" scope.
* **Cross-Device Portability:** Export and import your encrypted "Migration Packages" to move your tasks between devices securely.

---

## 🔒 Security Architecture

The core philosophy of this project is **"Never Trust, Always Verify."**

### 1. Key Derivation
When you enter your master password, the app doesn't store it. Instead, it uses a unique 32-byte salt and the **PBKDF2** algorithm to "stretch" your password into a 256-bit cryptographic key. This process is computationally expensive, making it extremely difficult for attackers to guess your password.

### 2. Encryption (AES-GCM)
Unlike standard encryption, **AES-GCM** (Galois/Counter Mode) provides both encryption and authentication. This means if the encrypted data is tampered with (even a single bit), the app will detect it and refuse to decrypt the corrupted data.

### 3. Storage Pipeline
* **Local:** Tasks are stored in `SharedPreferences` as an encrypted Base64 blob.
* **Secrets:** The salt and verification data are stored in hardware-backed **Secure Storage**.
* **Sync:** Encrypted blobs are uploaded to a private Google Drive folder accessible only to the app.

---

## 🚀 Getting Started

### Prerequisites
* **Flutter SDK** (v3.0.0 or higher)
* A **Google Cloud Project** (for Google Drive Sync)

### Installation

1. **Clone the repo:**
   ```bash
   git clone [https://github.com/EdoSag/Zero-Trust-Tasks.git](https://github.com/EdoSag/Zero-Trust-Tasks.git)
   cd Zero-Trust-Tasks
   ### Installation (Continued)

2. **Install dependencies:**
   ```bash
   flutter pub get
   3. **Configure Google Sign-In:** Follow the official Flutter guide to add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) to the project.

4. **Run the app:**
   ```bash
   flutter run
   
## 📂 Project Structure

```plaintext
lib/
├── components/            # Reusable UI widgets (AuthWrapper, TaskCards)
├── globals/               # State management (TaskManager, AppState)
├── models/                # Data structures (Task, SubTask)
├── pages/                 # App screens (Login, Setup, Main, Details)
└── encryption_service.dart # The cryptographic heart of the app
```
## 🛠️ Built With

* **Flutter** - UI Framework
* **Cryptography** - AES-GCM & PBKDF2 implementation
* **Flutter Secure Storage** - Hardware-backed secret storage
* **Google APIs** - Google Drive integration

---

## 🤝 Contributing

Security audits and contributions are welcome! If you find a vulnerability, please open an issue or submit a pull request with a detailed description of the fix.

---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.


   

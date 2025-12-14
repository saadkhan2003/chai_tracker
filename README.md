# ☕ Chai Tracker

A beautiful, modern Flutter app for tracking daily chai duty among friend groups. Never forget whose turn it is to bring chai!

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.7.2-02569B?logo=flutter)
![Firebase](https://img.shields.io/badge/Firebase-Enabled-orange?logo=firebase)

## ✨ Features

### Core Functionality
- 🔐 **User Authentication** - Secure login and registration with Firebase
- 👥 **Group Management** - Create and join groups with unique invite codes
- ☕ **Automatic Rotation** - Smart daily chai duty assignment
- 📊 **History Tracking** - Complete history with search and date filters
- 💰 **Debt Management** - Track shared expenses and settle debts
- 🔔 **Push Notifications** - Daily reminders for chai duty (Android only)
- 🎨 **Dark Theme** - Beautiful glassmorphism UI with gold accents

### Advanced Features
- ⚡ **Real-time Sync** - Firebase Firestore for instant updates
- 🔄 **Auto-Updates** - In-app update notifications via Firebase Remote Config
- 🌐 **Multi-Platform** - Android APK + Web version (Netlify)
- 📱 **Pull to Refresh** - Manual data refresh on home screen
- 🎯 **Session Persistence** - Stay logged in across app restarts

## 📸 Screenshots

> Add your screenshots here after deployment

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.7.2 or higher
- Firebase project with Authentication and Firestore enabled
- Android Studio / VS Code

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/chai_tracker.git
   cd chai_tracker
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Create a Firebase project at https://console.firebase.google.com
   - Add Android app with package name: `com.angaargrp.chai_tracker`
   - Download `google-services.json` to `android/app/`
   - Update `lib/firebase_options.dart` with your Firebase config

4. **Run the app**
   ```bash
   flutter run
   ```

## 🏗️ Build

### Android APK
```bash
flutter build apk --release
```
APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

### Web
```bash
flutter build web --release
```
Output: `build/web/`

## 🔧 Configuration

### Firebase Remote Config (Auto-Updates)
Set these parameters in Firebase Console → Remote Config:
- `latest_version`: "1.0.0"
- `update_url`: "your-apk-download-link"
- `force_update`: false

## 📦 Project Structure

```
lib/
├── main.dart                 # App entry point
├── firebase_options.dart     # Firebase configuration
├── models/                   # Data models
├── providers/                # State management (Provider)
├── screens/                  # UI screens
│   ├── auth/                # Login & Register
│   ├── home/                # Main home screen
│   └── debts/               # Debt management
├── services/                # Business logic
│   ├── auth_service.dart
│   ├── chai_service.dart
│   ├── debt_service.dart
│   ├── group_service.dart
│   ├── notification_service.dart
│   └── update_service.dart
├── theme/                   # App theme & colors
└── widgets/                 # Reusable widgets
```

## 🎨 Design

- **Theme**: Dark mode with glassmorphism
- **Primary Color**: Amber Gold (#FFC107)
- **Font**: Google Fonts (Poppins)
- **UI Pattern**: Material Design 3

## 🔐 Security

- Firebase Authentication for user management
- Firestore security rules for data access control
- All sensitive data stored in Firebase (not in client)

## 📱 Supported Platforms

- ✅ Android (APK)
- ✅ Web (PWA ready)
- ⚠️ iOS (code ready, needs Xcode build)

## 🤝 Contributing

This is a personal project for friend groups. Feel free to fork and customize for your needs!

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

## 👨‍💻 Author

**Muhammad Saad Khan**
- GitHub: [@saadkhan2003](https://github.com/saadkhan2003)

## 🙏 Acknowledgments

- Built with Flutter & Firebase
- Icons from Material Design
- Deployed on Netlify

## 📞 Support

For issues or questions, please open an issue on GitHub.

---

**Note**: This app was built for personal use among friends. Firebase credentials in the code are for demonstration; please use your own Firebase project for production use.

# Aether Setup Guide

This guide will help you set up the Aether project on your local machine.

## Prerequisites

- Flutter SDK (3.0 or higher)
- Android Studio / VS Code
- Firebase account
- Groq API account (free)

## Step 1: Clone the Repository

```bash
git clone <your-repo-url>
cd aether
```

## Step 2: Install Dependencies

```bash
flutter pub get
```

## Step 3: Configure Firebase

### Option A: Use FlutterFire CLI (Recommended)

1. Install FlutterFire CLI:
```bash
dart pub global activate flutterfire_cli
```

2. Login to Firebase:
```bash
firebase login
```

3. Configure Firebase for your project:
```bash
flutterfire configure
```

This will automatically create `lib/firebase_options.dart` with your Firebase configuration.

### Option B: Manual Configuration

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or use an existing one
3. Add Android/Web apps to your Firebase project
4. Download the configuration
5. Copy `lib/firebase_options.dart.example` to `lib/firebase_options.dart`
6. Replace the placeholder values with your actual Firebase configuration

## Step 4: Configure Groq API

1. Get a free API key from [Groq Console](https://console.groq.com/keys)
2. Copy `assets/.env.example` to `assets/.env`
3. Replace `your-groq-api-key-here` with your actual API key:

```
GROQ_API_KEY=gsk_your_actual_key_here
```

## Step 5: Enable Firebase Services

In your Firebase Console, enable:

1. **Authentication**
   - Email/Password
   - Google Sign-In

2. **Firestore Database**
   - Create database in production mode
   - Set up security rules (see below)

### Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Step 6: Run the App

### Android
```bash
flutter run
```

### Web
```bash
flutter run -d chrome
```

## Troubleshooting

### "API key not found" error
- Make sure `assets/.env` exists and contains your Groq API key
- Rebuild the app: `flutter clean && flutter pub get && flutter run`

### Firebase errors
- Verify `lib/firebase_options.dart` exists and has correct configuration
- Check Firebase Console for enabled services
- Ensure you're using the correct Firebase project

### Build errors
- Run `flutter clean`
- Delete `pubspec.lock` and run `flutter pub get`
- Check Flutter version: `flutter --version`

## Project Structure

```
lib/
├── main.dart                  # App entry point
├── firebase_options.dart      # Firebase config (not in git)
├── models/                    # Data models
├── providers/                 # State management
├── screens/                   # UI screens
├── services/                  # API services
├── utils/                     # Helper functions
└── widgets/                   # Reusable widgets

assets/
└── .env                       # API keys (not in git)
```

## Important Notes

⚠️ **Never commit these files:**
- `lib/firebase_options.dart` (contains Firebase API keys)
- `assets/.env` (contains Groq API key)

These files are in `.gitignore` for security reasons.

## Need Help?

- Check the [Flutter documentation](https://docs.flutter.dev/)
- Check the [Firebase documentation](https://firebase.google.com/docs)
- Check the [Groq documentation](https://console.groq.com/docs)

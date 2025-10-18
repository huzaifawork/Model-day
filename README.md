# ModelDay - Professional Modeling Career Manager

<div align="center">
  <img src="assets/images/model_day_logo.png" alt="ModelDay Logo" width="200"/>
  <p><strong>A comprehensive Flutter-based platform for managing modeling careers, bookings, and industry connections</strong></p>
</div>

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Installation & Setup](#installation--setup)
- [Firebase Configuration](#firebase-configuration)
- [Running the Application](#running-the-application)
- [Building & Deployment](#building--deployment)
- [Backend Integration](#backend-integration)
- [Troubleshooting](#troubleshooting)

---

## Overview

ModelDay is a full-featured modeling career management platform built with Flutter, supporting web, Android, and iOS platforms. It provides models, agents, and agencies with tools to manage bookings, castings, events, and industry connections in one centralized application.

### Use Cases

- **Models**: Manage portfolio, track bookings, view calendar events, connect with agents
- **Agents**: Organize model rosters, schedule castings, manage client relationships
- **Agencies**: Oversee operations, track analytics, manage multiple agents and models
- **Admins**: Platform administration, user management, support ticket handling

---

## Features

### Authentication & Authorization

- **Email/Password Authentication** - Traditional sign-up and login
- **Google OAuth 2.0** - One-click Google Sign-In with calendar integration
- **Admin Dashboard Access** - Role-based access control
- **Password Reset** - Secure password recovery via email
- **Session Management** - Secure token storage and refresh

### Calendar & Event Management

- **Google Calendar Integration** - Sync events with Google Calendar
- **Event Types**: Jobs, Castings, Tests, Polaroids, Meetings, Shootings, On-Stay events
- **Calendar View** - Interactive calendar with event filtering
- **Event CRUD Operations** - Create, read, update, delete events
- **Time Zone Support** - UTC-based event scheduling

### Contact & Relationship Management

- **Industry Contacts** - Manage clients, photographers, stylists
- **Agencies** - Track agency relationships and details
- **Agents** - Organize agent contacts and portfolios
- **Models** - Comprehensive model profiles with portfolios

### Booking Management

- **Direct Bookings** - Manage confirmed modeling jobs
- **Options** - Track tentative bookings and availability holds
- **Job Gallery** - Visual portfolio of completed work
- **AI Job Matching** - Intelligent job recommendations

### AI Chatbot Assistant

- **Context-Aware Responses** - Understands user data and history
- **Backend API Integration** - Powered by external AI service
- **Natural Language Processing** - Conversational interface
- **Career Guidance** - Provides modeling industry insights

### Admin Dashboard

- **User Management** - View and manage all platform users
- **Analytics & Statistics** - Platform usage metrics and insights
- **Support System** - Handle user support tickets
- **Activity Monitoring** - Track recent platform activities
- **Admin Role Management** - Add/remove admin privileges

### Community Features

- **Community Board** - Share posts and updates
- **Comments & Interactions** - Engage with community content
- **Notifications** - Real-time updates on activities
- **Approval System** - Content moderation workflow

### Document Management

- **OCR Integration** - Extract text from images and documents
- **File Upload** - Support for images and documents
- **Firebase Storage** - Secure cloud file storage
- **Export Functionality** - Export data to various formats

---

## Tech Stack

### Frontend

- **Flutter** 3.24.3 (Dart SDK >=3.2.3 <4.0.0)
- **Provider** - State management
- **Material Design 3** - UI framework

### Backend & Services

- **Firebase Core** 3.8.0 - Backend infrastructure
- **Firebase Auth** 5.3.3 - Authentication
- **Cloud Firestore** 5.5.0 - NoSQL database
- **Firebase Storage** 12.3.7 - File storage
- **External API** - AI chatbot backend (https://modelday-backend.vercel.app)

### Authentication & OAuth

- **Google Sign-In** 6.2.1 - Google OAuth integration
- **Google APIs** 11.4.0 - Calendar API access
- **Flutter Secure Storage** 9.0.0 - Secure token storage

### UI & Visualization

- **FL Chart** 1.0.0 - Data visualization
- **Table Calendar** 3.2.0 - Calendar widget
- **Cached Network Image** 3.3.1 - Image caching
- **Flutter Animate** 4.5.0 - Animations
- **Font Awesome Flutter** 10.7.0 - Icon library

### Utilities

- **Image Picker** 1.0.4 - Gallery/camera access
- **File Picker** 10.1.9 - Document selection
- **Google ML Kit** 0.15.0 - OCR text recognition
- **HTTP** 1.1.0 - API communication
- **Mailer** 6.1.2 - Email functionality
- **Share Plus** 11.0.0 - Content sharing
- **URL Launcher** 6.3.2 - External links

---

## Project Structure

```
ModelDay/
├── android/                    # Android platform files
│   ├── app/
│   │   ├── google-services.json   # Firebase Android config
│   │   └── build.gradle.kts       # Android build configuration
│   └── gradle/                    # Gradle wrapper
├── ios/                        # iOS platform files
│   ├── Runner/
│   │   └── GoogleService-Info.plist  # Firebase iOS config
│   └── Runner.xcodeproj/
├── web/                        # Web platform files
│   ├── index.html                 # Main HTML entry point
│   ├── firebase-storage-cors.js   # CORS handling
│   └── email_bridge.js            # Email service bridge
├── lib/                        # Flutter application code
│   ├── models/                    # Data models
│   │   ├── user.dart
│   │   ├── event.dart
│   │   ├── agent.dart
│   │   ├── agency.dart
│   │   ├── job.dart
│   │   └── ...
│   ├── pages/                     # UI screens
│   │   ├── landing_page.dart
│   │   ├── sign_in_page.dart
│   │   ├── calendar_page.dart
│   │   ├── admin_dashboard_page.dart
│   │   ├── ai_chat_page.dart
│   │   └── ...
│   ├── services/                  # Business logic & API services
│   │   ├── auth_service.dart         # Authentication
│   │   ├── google_calendar_service.dart  # Calendar integration
│   │   ├── http_chat_service.dart    # AI chatbot API
│   │   ├── firebase_storage_service.dart
│   │   └── ...
│   ├── providers/                 # State management
│   │   ├── events_provider.dart
│   │   ├── agents_provider.dart
│   │   └── ...
│   ├── widgets/                   # Reusable UI components
│   │   ├── admin/                    # Admin-specific widgets
│   │   ├── common/                   # Shared widgets
│   │   └── ui/                       # UI components
│   ├── utils/                     # Utility functions
│   ├── theme/                     # App theming
│   ├── firebase_options.dart      # Firebase configuration
│   └── main.dart                  # Application entry point
├── assets/                     # Static assets
│   └── images/
│       ├── model_day_logo.png
│       └── hero_sec.png
├── codemagic.yaml              # CI/CD configuration
├── pubspec.yaml                # Flutter dependencies
├── vercel.json                 # Vercel deployment config
├── build.sh                    # Build script for Vercel
└── deploy.sh                   # Deployment script
```

---

## Prerequisites

### Required Software

- **Flutter SDK** 3.24.3 or higher ([Install Flutter](https://docs.flutter.dev/get-started/install))
- **Dart SDK** 3.2.3 or higher (included with Flutter)
- **Git** ([Download Git](https://git-scm.com/downloads))
- **Chrome Browser** (for web development)
- **Android Studio** (for Android development)
- **Xcode** (for iOS development - macOS only)

### Required Accounts

- **Firebase Account** ([Firebase Console](https://console.firebase.google.com/))
- **Google Cloud Account** (for OAuth and Calendar API)
- **Vercel Account** (optional - for web deployment)
- **Codemagic Account** (optional - for mobile CI/CD)

### System Requirements

- **OS**: Windows 10+, macOS 10.14+, or Linux
- **RAM**: 8GB minimum (16GB recommended)
- **Storage**: 10GB free space
- **Internet**: Stable connection for Firebase and API access

---

## Installation & Setup

### 1. Clone the Repository

```bash
git clone https://github.com/huzaifawork/modelDay-Frontend.git
cd ModelDay
```

### 2. Install Flutter Dependencies

```bash
flutter pub get
```

### 3. Verify Flutter Installation

```bash
flutter doctor
```

Resolve any issues reported by Flutter Doctor before proceeding.

---

## Firebase Configuration

### Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" and follow the setup wizard
3. Project ID: `modelday-d4781` (or your custom ID)

### Step 2: Enable Firebase Services

#### Authentication

1. Navigate to **Authentication** → **Sign-in method**
2. Enable **Email/Password** provider
3. Enable **Google** provider
   - Add your OAuth 2.0 Client ID
   - Configure authorized domains

#### Cloud Firestore

1. Navigate to **Firestore Database**
2. Click "Create database"
3. Start in **production mode** (or test mode for development)
4. Choose a location (e.g., `us-central1`)

#### Firebase Storage

1. Navigate to **Storage**
2. Click "Get started"
3. Configure security rules (see `firebase_storage_rules.txt`)

### Step 3: Configure Firestore Collections

Create the following collections in Firestore:

- `users` - User profiles and authentication data
- `events` - Calendar events (jobs, castings, meetings)
- `community_posts` - Community board posts
- `comments` - Post comments
- `agents` - Agent profiles
- `agencies` - Agency information
- `models` - Model portfolios
- `industry_contacts` - Client and industry contacts
- `direct_bookings` - Confirmed bookings
- `options` - Tentative bookings
- `notifications` - User notifications
- `admins` - Admin user records
- `support_messages` - Support tickets

### Step 4: Configure Firestore Security Rules

Apply security rules from `firestore.rules` or `firestore_rules_complete.txt`:

```bash
firebase deploy --only firestore:rules
```

### Step 5: Platform-Specific Configuration

#### Web Configuration

1. Register web app in Firebase Console
2. Copy Firebase config to `web/index.html`
3. Update `lib/firebase_options.dart` with web credentials

#### Android Configuration

1. Register Android app in Firebase Console
   - Package name: `com.example.new_flutter`
2. Download `google-services.json`
3. Place in `android/app/google-services.json`
4. Add SHA-1 and SHA-256 fingerprints:
   ```bash
   cd android
   ./gradlew signingReport
   ```
5. Add fingerprints to Firebase Console

#### iOS Configuration

1. Register iOS app in Firebase Console
   - Bundle ID: `com.example.newFlutter`
2. Download `GoogleService-Info.plist`
3. Place in `ios/Runner/GoogleService-Info.plist`
4. Open `ios/Runner.xcworkspace` in Xcode
5. Add `GoogleService-Info.plist` to project

### Step 6: Google Cloud Console Setup

#### Enable APIs

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your Firebase project
3. Navigate to **APIs & Services** → **Library**
4. Enable:
   - Google Calendar API
   - Google Sign-In API

#### Configure OAuth Consent Screen

1. Navigate to **APIs & Services** → **OAuth consent screen**
2. Configure app information
3. Add scopes:
   - `email`
   - `profile`
   - `https://www.googleapis.com/auth/calendar`
4. Add test users (for development)

#### Create OAuth 2.0 Credentials

1. Navigate to **APIs & Services** → **Credentials**
2. Create credentials for each platform:
   - **Web**: OAuth 2.0 Client ID
   - **Android**: OAuth 2.0 Client ID (with SHA-1)
   - **iOS**: OAuth 2.0 Client ID (with Bundle ID)
3. Update `web/index.html` with Web Client ID

---

## Running the Application

### Web Development

```bash
# Run in Chrome
flutter run -d chrome

# Run with hot reload
flutter run -d chrome --hot
```

### Android Development

```bash
# List available devices
flutter devices

# Run on connected device/emulator
flutter run -d <device-id>

# Run in debug mode
flutter run --debug
```

### iOS Development (macOS only)

```bash
# Install CocoaPods dependencies
cd ios
pod install
cd ..

# Run on simulator
flutter run -d "iPhone 14 Pro"

# Run on physical device
flutter run -d <device-id>
```

### Desktop Development

```bash
# Windows
flutter run -d windows

# macOS
flutter run -d macos

# Linux
flutter run -d linux
```

---

## Building & Deployment

### Web Build & Deployment

#### Build for Production

```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build web app
flutter build web --release --web-renderer html
```

Output: `build/web/`

#### Deploy to Vercel

**Option 1: Using Vercel CLI**

```bash
# Install Vercel CLI
npm install -g vercel

# Deploy
vercel --prod
```

**Option 2: Using Deployment Script**

```bash
# Make script executable (Unix/Linux/macOS)
chmod +x deploy.sh

# Run deployment
./deploy.sh
```

**Option 3: GitHub Integration**

1. Push code to GitHub
2. Connect repository to Vercel
3. Configure build settings:
   - Build Command: `npm run vercel-build`
   - Output Directory: `.`
4. Deploy automatically on push

#### Deploy to Firebase Hosting

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize hosting
firebase init hosting

# Deploy
firebase deploy --only hosting
```

### Android Build & Deployment

#### Build APK (Debug)

```bash
flutter build apk --debug
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`

#### Build APK (Release)

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

#### Build App Bundle (for Play Store)

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

#### Using Codemagic CI/CD

This project includes `codemagic.yaml` for automated builds:

1. **Sign up** at [Codemagic](https://codemagic.io/)
2. **Connect repository** to Codemagic
3. **Configure workflow**:
   - Select `android-workflow` for Android builds
   - Select `ios-workflow` for iOS builds
4. **Add environment variables** (if needed):
   - Firebase credentials
   - Signing certificates
5. **Trigger build**:
   - Automatic: Push to repository
   - Manual: Click "Start new build"

**Codemagic Configuration** (`codemagic.yaml`):

- **Instance**: Mac Mini M1
- **Flutter**: Stable channel
- **Build command**: `flutter build apk --release`
- **Artifacts**: APK, AAB, mapping files
- **Publishing**: Email notifications

### iOS Build & Deployment

#### Build IPA (Release)

```bash
flutter build ios --release
```

#### Build for App Store

```bash
flutter build ipa --release
```

Output: `build/ios/ipa/`

#### Using Codemagic for iOS

1. Configure signing certificates in Codemagic
2. Add provisioning profiles
3. Use `ios-workflow` in `codemagic.yaml`
4. Build and deploy to TestFlight/App Store

---

## Backend Integration

### AI Chatbot Backend

**Endpoint**: `https://modelday-backend.vercel.app/api/chat`

**Service**: `lib/services/http_chat_service.dart`

**Request Format**:

```json
{
  "message": "User question",
  "context": {
    "userId": "user123",
    "events": [...],
    "contacts": [...]
  }
}
```

**Response Format**:

```json
{
  "response": "AI-generated response"
}
```

**Features**:

- Context-aware responses using user data
- Rate limiting and error handling
- Timeout management (30 seconds)
- Automatic retry logic

### Firebase Backend Services

**Authentication**: `lib/services/auth_service.dart`

- Email/password authentication
- Google OAuth integration
- Session management
- Token refresh

**Firestore**: Direct Firestore SDK integration

- Real-time data synchronization
- Offline persistence
- Query optimization

**Storage**: `lib/services/firebase_storage_service.dart`

- File upload/download
- Image optimization
- CORS handling

**Calendar**: `lib/services/google_calendar_service.dart`

- Google Calendar API integration
- Event synchronization
- OAuth token management

---

## Troubleshooting

### Common Issues

#### Build Failures

```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build <platform>
```

#### Firebase Authentication Issues

- Verify `google-services.json` (Android) is up to date
- Verify `GoogleService-Info.plist` (iOS) is up to date
- Check SHA-1 fingerprints in Firebase Console
- Ensure OAuth client IDs are correctly configured

#### Google Sign-In Not Working

- **Web**: Check authorized JavaScript origins in Google Cloud Console
- **Android**: Verify SHA-1 fingerprint matches
- **iOS**: Verify Bundle ID matches
- Clear browser cache and cookies

#### Calendar Integration Issues

- Ensure Google Calendar API is enabled
- Check OAuth scopes include calendar access
- Verify tokens are not expired
- Re-authenticate if necessary

#### CORS Errors (Web)

- Check `web/_headers` configuration
- Verify Firebase Storage CORS rules
- Use `firebase-storage-cors.js` workaround

#### Firestore Permission Denied

- Review Firestore security rules
- Ensure user is authenticated
- Check collection/document permissions

#### APK Installation Issues

- Enable "Install from Unknown Sources" on Android
- Check minimum SDK version (Android 21+)
- Verify signing configuration

### Debug Commands

```bash
# Check Flutter installation
flutter doctor -v

# Analyze code for issues
flutter analyze

# Run tests
flutter test

# View logs
flutter logs

# Clear cache
flutter clean

# Update dependencies
flutter pub upgrade
```

### Platform-Specific Issues

#### Android

```bash
# Rebuild Gradle
cd android
./gradlew clean
./gradlew build

# Check signing report
./gradlew signingReport
```

#### iOS

```bash
# Update CocoaPods
cd ios
pod repo update
pod install

# Clean build
rm -rf Pods Podfile.lock
pod install
```

#### Web

```bash
# Clear browser cache
# Use incognito mode for testing
# Check browser console for errors
```

### Getting Help

- **Firebase Documentation**: https://firebase.google.com/docs
- **Flutter Documentation**: https://docs.flutter.dev
- **Google Calendar API**: https://developers.google.com/calendar
- **GitHub Issues**: Report bugs in the repository

---

---

<div align="center">
  <p>Built with  using Flutter</p>
  <p>Version 1.0.0+2</p>
</div>

<div align="center">

<img src="assets/branding/app_icon.png" alt="MedBridge logo" width="140" />

# MedBridge

**Bridging Care. Connecting Lives.**

A smart healthcare appointment and medical records app that connects patients and doctors, built with Flutter and Firebase.

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.5+-0175C2?logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore%20%7C%20FCM-FFCA28?logo=firebase&logoColor=black)
![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20Web-0E7C86)
![Plan](https://img.shields.io/badge/Firebase%20plan-Spark%20(free)-brightgreen)
![License](https://img.shields.io/badge/License-MIT-blue)

</div>

---

## Overview

MedBridge gives patients a simple way to find a doctor, book a time slot, message them and keep their medical history in one place. Doctors get a dashboard to manage requests, set their own working hours, write prescriptions and bill their consultations.

The whole app runs on the **free Firebase Spark plan**: no Cloud Functions and no Firebase Storage are needed.

## Features

### For patients
- **Find doctors** by name or specialization and read their profile, experience, fee and reviews
- **Book appointments** from the doctor's real availability. Only their working days and open slots are shown, and a slot can never be double-booked
- **Track appointments** (pending, accepted, completed, cancelled) and cancel when plans change
- **Chat** with doctors in real time
- **Medical records**: store notes and images, and view records the doctor adds
- **Prescriptions** issued by your doctor
- **Billing and invoices** generated automatically when a visit is completed
- **Reviews and ratings** for doctors
- **Notifications** for bookings, confirmations, prescriptions and records

### For doctors
- **Dashboard** with pending requests, today's appointments and patient count
- **Accept, reject or complete** appointment requests
- **Availability editor**: choose working days, clinic hours, lunch break and minutes per slot, with a live slot preview
- **Patient details**: view a patient's records and add diagnoses
- **Prescriptions**: create multi-medicine prescriptions
- **Invoices**: see billed and paid totals
- **Chat** with patients in real time

### General
- Email and password sign-up, login, password reset and email verification
- Role-based home screens (patient or doctor)
- Light and dark theme
- Responsive layout for phone and web

## Tech stack

| Layer | Technology |
|---|---|
| App | Flutter, Dart (Material 3) |
| Authentication | Firebase Authentication (email and password) |
| Database | Cloud Firestore with security rules |
| Notifications | Firestore listeners, `flutter_local_notifications`, Firebase Cloud Messaging |
| Other packages | `table_calendar`, `pdf`, `printing`, `image_picker`, `shared_preferences`, `google_fonts`, `intl` |

## Project structure

```text
lib/
├── main.dart                    # App entry point
├── constants.dart               # Date, slot and availability helpers
├── models.dart                  # Doctor, Appointment, ChatMessage, Invoice, ...
├── theme.dart                   # Colors and light/dark themes
├── backend/
│   ├── chat_service.dart        # Conversations, messages, read state
│   ├── invoice_service.dart     # Invoice creation and payment
│   └── fcm_service.dart         # Push notification tokens
├── services/
│   ├── auth_service.dart        # Sign-in, registration, profile
│   ├── db_service.dart          # Appointments, records, prescriptions, reviews
│   └── notification_service.dart
├── screens/
│   ├── patient/                 # Home, search, booking, appointments, records
│   ├── doctor/                  # Dashboard, requests, patients, availability
│   └── ...                      # Login, register, chat, invoices, settings
└── widgets/                     # Shared UI components

firestore.rules                  # Firestore security rules
tests/rules/                     # Firestore rules tests (emulator)
test/                            # Dart unit tests
assets/branding/                 # Logo and app icon
```

## Getting started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart 3.5 or newer)
- A Firebase project with **Email/Password** sign-in and **Cloud Firestore** enabled
- [Firebase CLI](https://firebase.google.com/docs/cli) and [FlutterFire CLI](https://firebase.flutter.dev/docs/cli)
- Android Studio or a device with USB debugging, for Android builds

### Setup

1. **Get the dependencies**

   ```bash
   flutter pub get
   ```

2. **Connect your Firebase project**

   ```bash
   firebase login
   flutterfire configure
   ```

   Select your project and tick **Android** and **Web**. This regenerates `lib/firebase_options.dart` and `android/app/google-services.json` with your own keys.

3. **Publish the security rules**

   ```bash
   firebase deploy --only firestore:rules --project <your-project-id>
   ```

   You can also paste `firestore.rules` into the Firebase console under Firestore Database, then Rules.

4. **Android notifications** (needed for local notifications)
   - Enable core library desugaring in `android/app/build.gradle.kts` and add `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`
   - Make sure `AndroidManifest.xml` has the `INTERNET` and `POST_NOTIFICATIONS` permissions
   - If the build complains about `minSdk`, set `minSdk = 23`

### Run

```bash
flutter run -d chrome          # web
flutter devices                # list connected devices
flutter run -d <device-id>     # Android
```

### Build

```bash
flutter build apk --release        # installable APK
flutter build appbundle --release  # Play Store bundle (set up release signing first)
flutter build web                  # web build
```

The release APK is created at `build/app/outputs/flutter-apk/app-release.apk`.

## Quick demo

1. Register a **Doctor** account, then a **Patient** account (a second browser or a phone works).
2. As the doctor, open **Set Availability** and choose your working days and hours.
3. As the patient, open the doctor's profile, then **Book Appointment**, pick a date and slot, and confirm.
4. As the doctor, open **Requests** and **Accept**, then use **Mark completed** from the dashboard. An invoice is created for both sides.
5. Open **Chat** from either profile and exchange messages in real time.
6. As the doctor, open the patient's details to add a record and a prescription.

## Data model

| Collection | Purpose |
|---|---|
| `users` | Account profile and role (`patient` or `doctor`) |
| `doctors` | Public doctor profile, fee, rating and availability |
| `appointments` | Bookings and their status |
| `bookedSlots` | One document per taken slot (prevents double booking) |
| `records` | Medical notes and images |
| `prescriptions` | Prescriptions issued by doctors |
| `invoices` | Billing for completed appointments |
| `chats` and `chats/{id}/messages` | Conversations. The ID is `{smallerUid}_{largerUid}` |
| `reviews`, `notifications` | Ratings and in-app notifications |

## Security

Access is enforced by Firestore security rules in [`firestore.rules`](firestore.rules):

- Users can read and change only their own data, with role-based rules for doctors.
- A chat can be created only between one patient and one doctor, and only its two participants can read or write messages. Participants and sender identity can't be changed or forged.
- Appointment, invoice and prescription access is limited to the people involved.

Known limits of the free-plan design:
- Any signed-in doctor can read patient records (demo level). A production system should restrict this to doctors with an appointment.
- Availability is checked in the app at booking time, not by the rules.
- Notifications are created by the client, so true push when the app is closed needs Cloud Functions and FCM on the Blaze plan.
- Medical record images are stored as small base64 strings in Firestore (about 600 KB each).

## Testing

```bash
flutter analyze
flutter test
```

Firestore rules tests use the Firebase Emulator and need Java installed:

```bash
cd tests/rules
npm install
npm test
```

## Roadmap

- Restrict chat and record access to doctors with an appointment
- Appointment reminders
- Cloud Functions for server-side push notifications and ratings
- Firebase Storage for larger files and images
- Release signing and Play Store publishing

## Contributing

Issues and pull requests are welcome. Run `flutter analyze` and `flutter test` before submitting.

## License

Released under the [MIT License](LICENSE).

---

<div align="center">
Built with Flutter and Firebase.
</div>

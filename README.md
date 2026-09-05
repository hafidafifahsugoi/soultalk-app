# SoulTalk AI — Flutter

A calm, premium mobile mental-wellness app: an AI companion you can talk to via video sessions, with mood tracking and gentle conversation summaries.

This is the **Flutter / Dart** port of the SoulTalk AI design (the same product also ships as a Next.js web prototype in this project).

## Screens

| Screen | File |
| --- | --- |
| Splash | `lib/screens/splash_screen.dart` |
| Login | `lib/screens/login_screen.dart` |
| Main shell + bottom nav | `lib/screens/main_shell.dart` |
| Home (mood check-in, start session, quick tools) | `lib/screens/home_screen.dart` |
| AI Video Call (animated orb, live transcript, controls) | `lib/screens/video_call_screen.dart` |
| Conversation Summary | `lib/screens/summary_screen.dart` |
| Profile & Settings | `lib/screens/profile_screen.dart` |

## Design system

- **Palette:** calm soft-blue primary, pastel-purple accent, off-white background, soft neutrals — defined in `lib/theme/app_theme.dart`.
- **Fonts:** Quicksand for headings, Nunito for body (via `google_fonts`).
- **Look:** rounded corners (20px radius), soft shadows, breathing animated AI orb (`lib/widgets/ai_orb.dart`).

## Flow

Splash → Login → Home → (Start session) → Video Call → (End call) → Summary → Back to Home.
Bottom nav switches between Home, Journal (summary), and Profile. Logout returns to Login.

## Run it

```bash
flutter pub get
flutter run
```

Requires Flutter 3.3+ (Dart 3). No backend is needed — interactions are mocked for the UI prototype.

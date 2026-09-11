# AURA readiness baseline

## Local tooling

Required for the Windows Android/ML workstation:

- Flutter SDK and Android Studio/SDK.
- Android `platform-tools` on `PATH` (`adb` must resolve).
- Python 3.12 with a fresh project virtual environment.
- FFmpeg for audio normalization.
- Node.js 22+ and npm.
- Supabase CLI and Vercel CLI.
- Docker Desktop for local Supabase development.

iOS builds, signing, and physical device tests run on a Mac with Xcode and CocoaPods.

## Data gate

No dataset may be used for a production model until its manifest records source, licence, eligibility, label, split, duration, checksum, and provenance. Non-commercial or unverified files are excluded. The existing ESC-50 corpus is not production-cleared; its non-commercial licence makes it reference/evaluation-only unless a clip has a separately verified commercial licence.

The launch training set must cover gunshot, glass break, high-impact collision, explosion, and representative neutral sound. It must also include Nigerian ambient audio and a disjoint device/noise evaluation set.

## Hosted services

Create and configure: Supabase, Termii, Firebase Cloud Messaging, MapTiler, OpenRouteService, Vercel, Google Play Console, Apple Developer, and a production domain. Secrets live only in their appropriate server-side secret stores.

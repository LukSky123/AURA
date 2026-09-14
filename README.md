# AURA — Acoustic Urgency Recognition Assistant

> **Edge AI Acoustic Threat Detection & Offline-Resilient Personal Safety Platform**  
> *Engineered for high-risk urban environments, transit vulnerabilities, and intermittent connectivity.*

---

## 🌟 Executive Overview

**AURA (Acoustic Urgency Recognition Assistant)** is an intelligent, privacy-first personal safety and incident response system. Designed from the ground up for environments with unpredictable security dynamics and fragile telecommunication infrastructure (such as Nigeria and emerging markets), AURA combines **on-device acoustic machine learning**, **covert hardware duress triggers**, and **dual-channel dispatch resilience**.

AURA continuously monitors ambient acoustics for acute physical danger signatures—specifically **gunshots**, **glass breakage**, and **explosions**—completely on-device without recording or transmitting private conversations. When a high-confidence threat or physical duress trigger is detected, AURA initiates an automated emergency protocol, broadcasting the user's live GPS coordinates to designated trusted contacts via **cloud SMS (Termii)** or **autonomous local SIM SMS fallback**.

---

## ⚡ Core Capabilities

### 1. On-Device Edge Acoustic AI
- **Low-Latency Neural Audio Classification**: Powered by a custom transfer-learned YAMNet architecture quantized for mobile edge inference with TensorFlow Lite.
- **16 kHz Sliding-Window Analysis**: Evaluates 15,600-sample PCM audio windows (0.975s) in real time using memory-efficient circular ring buffers.
- **Privacy by Design**: Ambient audio is processed entirely in volatile memory and instantly overwritten. Raw audio is **never** recorded, stored on disk, or streamed to any remote server.
- **Adaptive False-Alarm Backoff**: Following an alert dismissed by the user, the detection threshold automatically increases from the baseline (80%) to 95% for 15 minutes to suppress repetitive ambient noise false positives.

### 2. Covert Physical Hardware Triggers
- **Eyes-Free Emergency Dispatch**: Integrated Android Accessibility Service enables users to discreetly trigger an SOS alert by **double-pressing the Volume Up key** while the device is in a pocket, bag, or locked state.
- **Volume Down Cancellation**: Immediate false-alarm cancellation directly from the physical rocker within a 20-second safety window.
- **Persistent Sticky Foreground Service**: Uninterruptible background operation protected with Android wake locks and battery-optimization exemption routines.

### 3. Dual-Channel Offline Resilience (Nigeria First)
- **Zero-Internet Fallback**: If cellular data or Wi-Fi is unavailable or disrupted, AURA bypasses the cloud and autonomously fires direct emergency SMS alerts with live GPS coordinates using the device's native carrier SIM card.
- **Offline Incident Queue**: GPS breadcrumbs and status changes recorded during connectivity blackouts are safely buffered in local storage and automatically flushed to Supabase when network connectivity is restored.
- **Hyper-Localized Integrations**: Native integration with Nigerian telecommunications infrastructure via **Termii** for bulk and transactional SMS delivery.

### 4. Real-Time Tracking & Responder Coordination
- **PostGIS Spatial Breadcrumbs**: High-frequency streaming location fixes ingest coordinate accuracy, speed, and heading.
- **Live Responder Web Portal**: Trusted contacts receive a signed, secure incident link allowing them to track the user's real-time trajectory on an interactive MapTiler/OpenRouteService map via Supabase Realtime subscriptions.
- **Contact Action Logging**: Trusted contacts can acknowledge alerts, mark arrival, or flag status directly from any modern web browser without installing an app.

### 5. Sustainable Freemium & Diaspora Sponsorship
- **Tiered Protection**:
  - **Free Tier**: Local acoustic AI detection, hardware button triggers, and autonomous SIM SMS alerting to 2 emergency contacts.
  - **Pro & Family Tiers**: Unlimited contacts, automated cloud Termii SMS dispatch, real-time live map tracking, and geofenced safe-zone alerts.
- **Diaspora Sponsorship Engine**: Integrated **Paystack** subscription portal allowing relatives living abroad (US, UK, Canada, Europe) to sponsor and maintain safety subscriptions for family members residing in Nigeria.

---

## 🏗️ System Architecture

```mermaid
flowchart TD
    subgraph Device ["User Device (apps/mobile)"]
        MIC[Microphone Stream 16kHz] --> BUF[Circular Audio Buffer]
        BUF --> TFL[TensorFlow Lite YAMNet Engine]
        TFL --> DET{Threat Detected?\nConfidence >= 80%}
        
        VOL[Hardware Volume Keys] --> ACC[AuraAccessibilityService]
        ACC -->|Double Vol Up| DURESS[Instant SOS Duress]
        ACC -->|Vol Down| CANCEL[Cancel Countdown]

        DET -->|Yes| COUNTDOWN[20-Second Audio Countdown]
        DURESS --> DISPATCH[Emergency Dispatch Router]
        COUNTDOWN -->|Not Cancelled| DISPATCH

        DISPATCH --> NET{Internet Available?}
        NET -->|Yes| SUPA_CLIENT[Supabase Edge Client]
        NET -->|No| SIM_SMS[Native SIM SMS Dispatcher]
        NET -->|No| OFF_QUEUE[Offline Incident Queue]
        OFF_QUEUE -.->|Network Restored| SUPA_CLIENT
    end

    subgraph Cloud ["AURA Cloud Platform (supabase/)"]
        SUPA_CLIENT --> EDGE_CREATE[create-incident Edge Function]
        SUPA_CLIENT --> EDGE_LOC[ingest-location Edge Function]
        
        EDGE_CREATE --> DB[(PostgreSQL + PostGIS)]
        EDGE_LOC --> DB
        
        EDGE_CREATE --> TERMII[Termii Nigerian SMS Gateway]
        DB --> REALTIME[Supabase Realtime Engine]
    end

    subgraph Contacts ["Trusted Contacts & Responders"]
        SIM_SMS -->|Direct Carrier SMS| PHONE[Contact Mobile Phone]
        TERMII -->|Cloud SMS with Live Link| PHONE
        PHONE -->|Click Secure Link| PORTAL[Web Portal (apps/portal)\nNext.js 15 + MapTiler]
        REALTIME -->|Live Location Stream| PORTAL
    end
```

---

## 📁 Repository Structure

```text
AURA/
├── apps/
│   ├── mobile/                  # Flutter 3.47+ client application (Android & iOS)
│   │   ├── android/             # Native Kotlin Foreground & Accessibility Services
│   │   ├── assets/models/       # Quantized aura_model.tflite acoustic classifier
│   │   ├── lib/
│   │   │   ├── domain.dart      # Normalized incident, location, and contact models
│   │   │   ├── services/        # Audio detection, SIM SMS, GPS, and Supabase repo
│   │   │   └── main.dart        # Core UI, state machines, and background lifecycles
│   │   └── test/                # Unit and integration test suites
│   │
│   └── portal/                  # Next.js 15 App Router web application
│       ├── app/
│       │   ├── incident/[id]/   # Live tracking map for trusted contacts
│       │   └── sponsor/         # Diaspora sponsorship & Paystack checkout portal
│       └── components/          # MapTiler integration and responsive emergency UI
│
├── supabase/
│   ├── migrations/              # Production PostgreSQL migrations (PostGIS, RLS, Realtime)
│   │   ├── 202609100001_initial_schema.sql
│   │   ├── 202609110001_monetization_schema.sql
│   │   └── 202609120001_realtime_sync.sql
│   └── functions/               # Deno TypeScript Edge Functions
│       ├── create-incident/     # Incident ingestion and dispatch orchestration
│       ├── ingest-location/     # High-frequency GPS fix ingestion
│       ├── cancel-incident/     # False-alarm revocation and token expiry
│       ├── resolve-incident/    # Incident closure and responder notification
│       ├── contact-action/      # Responder acknowledgment endpoint
│       ├── paystack-webhook/    # African subscription & sponsorship webhooks
│       └── revenuecat-webhook/  # In-app purchase sync
│
├── ml/                          # Machine learning tooling and data pipelines
│   ├── training/                # YAMNet transfer learning scripts
│   └── manifests/               # Audited dataset manifests and licensing metadata
│
├── docs/                        # Operational guidelines, legal specs, and readiness audits
│   ├── READINESS.md
│   └── SAFETY_AND_PLATFORM_LIMITS.md
│
├── .env.example                 # Template for environment configurations
└── README.md                    # Project documentation
```

---

## 💻 Tech Stack

| Layer | Technology | Purpose |
|---|---|---|
| **Mobile Client** | **Flutter 3.47+ / Dart 3.13+** | Cross-platform high-performance client engine |
| **Edge AI Engine** | **TensorFlow Lite (`tflite_flutter`)** | Quantized 4-class acoustic inference (Gunshot, Glass, Explosion, Neutral) |
| **Native Android** | **Kotlin / MethodChannel** | Hardware accessibility buttons, direct SIM SMS, sticky foreground service |
| **Backend & Database** | **Supabase / PostgreSQL 15+** | Relational data, PostGIS geospatial indexes, Row-Level Security |
| **Realtime Sync** | **Supabase Realtime** | Sub-second coordinate and incident state synchronization |
| **Cloud Compute** | **Deno / Supabase Edge Functions** | Serverless TypeScript orchestration for dispatch and webhooks |
| **Web Portal** | **Next.js 15 (React 19, Tailwind CSS)** | Responder tracking portal & diaspora sponsorship checkout |
| **Telecommunications**| **Termii API** | Direct-to-carrier SMS gateway for Nigeria & West Africa |
| **Payment Gateway** | **Paystack & RevenueCat** | NGN/USD recurring subscription billing and sponsorship management |
| **Mapping & Routing** | **MapTiler / OpenRouteService** | High-performance vector tiles and safe navigation routing |

---

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK**: `^3.47.0` (with Dart `^3.13.0`)
- **Android Studio / Android SDK**: API Level 34+
- **Node.js**: `v20.x` or `v22.x` and `npm`
- **Supabase CLI**: Latest release (`npm install -g supabase` or `brew install supabase/tap/supabase`)
- **Python 3.10+**: (Optional, for ML pipeline development)

---

### 1. Environment Configuration

Copy `.env.example` to your local environment file:

```bash
cp .env.example .env
```

Key environment variables:
- `SUPABASE_URL`: Your Supabase project URL (`https://your-project.supabase.co`)
- `SUPABASE_ANON_KEY`: Public anonymous API key for client communication
- `SUPABASE_SERVICE_ROLE_KEY`: Server-side service key for Edge Functions
- `TERMII_API_KEY`: API key for Nigerian SMS dispatch
- `PAYSTACK_SECRET_KEY`: Paystack secret for payment and sponsorship processing

> [!NOTE]
> When `SUPABASE_URL` is omitted or unconfigured in the mobile client, AURA automatically boots in **resilient offline mode**, utilizing local on-device ML and direct carrier SIM SMS dispatch.

---

### 2. Backend Setup (Supabase)

```bash
# Link to your remote Supabase project
supabase link --project-ref <your-project-ref>

# Apply database migrations (Schema, PostGIS, Realtime, RLS)
supabase db push

# Deploy Edge Functions
supabase functions deploy create-incident
supabase functions deploy ingest-location
supabase functions deploy cancel-incident
supabase functions deploy resolve-incident
supabase functions deploy contact-action
supabase functions deploy paystack-webhook
supabase functions deploy revenuecat-webhook

# Set function secrets
supabase secrets set TERMII_API_KEY=your_key TERMII_SENDER_ID=AURA
```

---

### 3. Mobile Client Setup (`apps/mobile`)

```bash
cd apps/mobile

# Install Flutter dependencies
flutter pub get

# Run static analysis and automated test suites
flutter analyze
flutter test

# Run on a connected Android device
flutter run
```

---

### 4. Web Portal Setup (`apps/portal`)

```bash
cd apps/portal

# Install dependencies
npm install

# Start local Next.js development server
npm run dev
```

Visit `http://localhost:3000/sponsor` to view the diaspora sponsorship portal or `http://localhost:3000/incident/<id>` for the live tracking interface.

---

## 🔒 Security, Privacy & Ethics

1. **Zero Raw Audio Retention**: The microphone pipeline processes raw PCM audio strictly in an in-memory rolling circular buffer. Audio frames that do not trigger threat classification are immediately purged.
2. **Voluntary User Opt-In**: Hardware button accessibility shortcuts and background services require explicit, informed user consent.
3. **Emergency Token Security**: Web portal incident links are protected by cryptographically signed, short-lived tokens that expire immediately upon incident resolution or cancellation.
4. **Platform Disclaimer**: AURA is a personal emergency alerting and coordination tool designed to inform trusted contacts. It is **not** a dispatch replacement for official state emergency services (e.g., Police, Fire, Ambulance).

---

## 📄 License

Distributed under the Proprietary / Commercial License. See `LICENSE` for more information.
All machine learning evaluation sets and datasets are audited for strict commercial licensing compliance (see `docs/READINESS.md`).

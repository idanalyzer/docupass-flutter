# DocuPass Flutter SDK — Native In-App ID Verification, KYC & Liveness

[![pub](https://img.shields.io/pub/v/docupass_flutter)](https://pub.dev/packages/docupass_flutter)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![ID Analyzer](https://img.shields.io/badge/by-ID%20Analyzer-0b5cff)](https://www.idanalyzer.com)

Add **identity verification and KYC** to your Flutter app — ID document scanning,
biometric **face match**, and **active liveness** — running **natively on-device**
with **no external browser and no WebView**. One `DocuPassView` widget, one
`onResult` callback.

This plugin embeds the native
**[Android](https://github.com/idanalyzer/docupass-android)** and
**[iOS](https://github.com/idanalyzer/docupass-ios)** DocuPass SDKs as a platform
view (CameraX / AVFoundation + **Google MediaPipe** liveness) — true native capture,
not a wrapped web page.

Built by **[ID Analyzer](https://www.idanalyzer.com)** — identity verification for
190+ countries and 14,000+ document types.

**📚 Full documentation:** [developer.idanalyzer.com/help/docupass-flutter-sdk](https://developer.idanalyzer.com/help/docupass-flutter-sdk)
· **🌐 Product:** [DocuPass](https://www.idanalyzer.com/products/docupass.html)
· **📦 Other platforms:** [Android](https://github.com/idanalyzer/docupass-android) ·
[iOS](https://github.com/idanalyzer/docupass-ios) ·
[React Native](https://github.com/idanalyzer/docupass-react-native)

---

## Features

- 📱 **True native capture** — no WebView, no `getUserMedia` permission issues.
- 🧠 **On-device active liveness** (MediaPipe) + biometric **face match**.
- 🪪 **Global documents** — passports, driver licenses, ID cards, 190+ countries.
- ✍️ Full DocuPass flow: document capture, face match, custom forms, phone OTP, **e-signature**.
- 🎨 **White-label** — `brandColor`, `logoUrl`, and full `labels` overrides (any language).
- 🔒 Your API key never touches the device — only a short-lived `reference`.

## How it works

**Your API key is secret and lives only on your backend** — the app never creates a
session or reads results directly. The device only ever holds a short-lived `reference`.

1. **Server → create a session.** `POST /docupass` with your API key (any
   [ID Analyzer server SDK](https://developer.idanalyzer.com/help)) using a
   [KYC profile](https://developer.idanalyzer.com/help/profiles); set a **webhook URL**
   on the profile. You get a **`reference`**.
2. **App → render `DocuPassView(reference: ...)`.** The SDK runs capture + liveness
   on-device and calls `onResult` when the flow ends — a **UX signal**, not the result.
3. **Server → receive the verified result**:
   - **Recommended — webhook (push).** On completion, ID Analyzer `POST`s the full
     transaction (name, DOB, document number, face-match, AML, decision, warnings,
     images) to your webhook URL, with retries.
   - **Or pull it server-side** with `GET /docupass/{reference}` (your API key).

> 🔒 **Never put your API key in the app**, and never call `POST /docupass` or
> `GET /docupass/{reference}` from the app — both need your secret key. `onResult` is
> a UI cue only; **your backend is the source of truth**.

## Installation

```yaml
# pubspec.yaml
dependencies:
  docupass_flutter: ^0.1.1
```

Then `flutter pub get`. Native dependencies resolve automatically:

- **iOS** (15+) — the `DocuPass` CocoaPod (pulls in `MediaPipeTasksVision`). Add a
  camera usage string to `ios/Runner/Info.plist`:
  ```xml
  <key>NSCameraUsageDescription</key>
  <string>Required to verify your identity.</string>
  ```
- **Android** (minSdk 24) — `com.idanalyzer:docupass`; the `CAMERA` permission is
  declared by the native core.

## Usage

Put `DocuPassView` on a full-screen route (it's a platform view that wants the space):

```dart
import 'package:docupass_flutter/docupass_flutter.dart';

DocuPassView(
  reference: 'US...your-reference...', // create server-side via POST /docupass
  onResult: (result) {
    switch (result.status) {
      case DocuPassStatus.completed:
        // Flow finished — update your UI. Verified data arrives on your
        // server via webhook (or GET /docupass/{result.reference}), not here.
        break;
      case DocuPassStatus.failed:    break; // rejected
      case DocuPassStatus.cancelled: break; // user dismissed
      case DocuPassStatus.error:     break; // network / fatal
    }
  },
)
```

### Getting a `reference` (server side, Node.js example)

```javascript
import { DocuPass } from "idanalyzer2";

const docupass = new DocuPass("YOUR_API_KEY", "YOUR_PROFILE_ID", "US");
const session = await docupass.createDocuPass();
// Send session.reference to the app.
```

## Customization — labels, languages & branding

```dart
DocuPassView(
  reference: reference,
  brandColor: '#1565C0',
  logoUrl: 'https://yourbrand.example.com/logo.png',
  labels: const {
    'selectDocumentTitle': 'Sélectionnez votre document',
    'phoneTitle': 'Vérifiez votre téléphone',
    'phoneSendSms': 'Envoyer le SMS',
    'faceForward': 'Regardez droit devant et ne bougez pas',
  },
  onResult: (result) { /* ... */ },
)
```

`labels` keys are the label names (re-word or localize to any language). See the
[full label list](https://developer.idanalyzer.com/help/docupass-flutter-sdk). Need a
completely custom UI? Use the native
[Android](https://github.com/idanalyzer/docupass-android) /
[iOS](https://github.com/idanalyzer/docupass-ios) headless API.

## API

`DocuPassView`:

| Param | Type | Notes |
|---|---|---|
| `reference` | `String` | **required** — the DocuPass reference |
| `partyId` | `String?` | party sign-token (multi-party contract flows) |
| `baseUrl` | `String?` | base URL override (on-prem ID Fort) |
| `brandColor` | `String?` | brand color, hex (e.g. `'#1565C0'`) |
| `logoUrl` | `String?` | logo for the welcome screen |
| `labels` | `Map<String,String>?` | label overrides (any language) |
| `onResult` | `void Function(DocuPassResult)` | terminal callback |

`DocuPassResult`: `{ status: DocuPassStatus, reference, code?, message?, redirectUrl? }`.

`onResult` only tells your **app** that the flow ended — it carries no verified
identity data. The verified data and decision arrive on your **server**: via the
**webhook** on your DocuPass profile (recommended, with retries), or `GET /docupass/{reference}`
server-side with your API key. Never use a client-side result as the decision.

## Links

- 🌐 ID Analyzer: [www.idanalyzer.com](https://www.idanalyzer.com)
- 🪪 DocuPass product: [idanalyzer.com/products/docupass.html](https://www.idanalyzer.com/products/docupass.html)
- 📚 Developer docs & KB: [developer.idanalyzer.com/help](https://developer.idanalyzer.com/help)
- 📱 This SDK's guide: [developer.idanalyzer.com/help/docupass-flutter-sdk](https://developer.idanalyzer.com/help/docupass-flutter-sdk)
- 🔑 Customer portal / API keys: [portal2.idanalyzer.com](https://portal2.idanalyzer.com)

## License

[MIT](LICENSE) © [ID Analyzer](https://www.idanalyzer.com)

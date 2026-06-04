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

1. **Server → create a session.** `POST /docupass` with your API key (any
   [ID Analyzer server SDK](https://developer.idanalyzer.com/help)) → get a **`reference`**.
2. **App → render `DocuPassView(reference: ...)`.** The SDK runs capture + liveness
   on-device and calls `onResult`.
3. **Server → fetch the result.** `GET /docupass/{reference}` with your API key.

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
        // Verified. Fetch data server-side: GET /docupass/{result.reference}
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

The verification **data and decision live server-side** — fetch them with your API
key via `GET /docupass/{reference}`.

## Links

- 🌐 ID Analyzer: [www.idanalyzer.com](https://www.idanalyzer.com)
- 🪪 DocuPass product: [idanalyzer.com/products/docupass.html](https://www.idanalyzer.com/products/docupass.html)
- 📚 Developer docs & KB: [developer.idanalyzer.com/help](https://developer.idanalyzer.com/help)
- 📱 This SDK's guide: [developer.idanalyzer.com/help/docupass-flutter-sdk](https://developer.idanalyzer.com/help/docupass-flutter-sdk)
- 🔑 Customer portal / API keys: [portal2.idanalyzer.com](https://portal2.idanalyzer.com)

## License

[MIT](LICENSE) © [ID Analyzer](https://www.idanalyzer.com)

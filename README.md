# DocuPass Flutter SDK — in-app ID verification & KYC

[![pub](https://img.shields.io/badge/pub-docupass__flutter-blue)](https://pub.dev/packages/docupass_flutter)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Embed [ID Analyzer **DocuPass**](https://www.idanalyzer.com/products/docupass.html)
identity verification **inside your Flutter app** — document scanning, face match,
and on-device active liveness — with **no external browser and no WebView**.

This plugin embeds the native [Android](https://github.com/idanalyzer/docupass-android)
and [iOS](https://github.com/idanalyzer/docupass-ios) DocuPass SDKs as a platform
view (CameraX / AVFoundation + MediaPipe liveness) — true native capture, not a
wrapped web page.

## Install

```yaml
dependencies:
  docupass_flutter: ^0.1.0
```

Native dependencies resolve automatically:
- **iOS**: the `DocuPass` pod (depends on `MediaPipeTasksVision`); add
  `NSCameraUsageDescription` to `Info.plist`.
- **Android**: `com.idanalyzer:docupass` (the `CAMERA` permission is declared by
  the native core).

## Usage

```dart
import 'package:docupass_flutter/docupass_flutter.dart';

DocuPassView(
  reference: 'US…',                 // create server-side via POST /docupass
  onResult: (result) {
    switch (result.status) {
      case DocuPassStatus.completed: break; // verified — fetch result server-side
      case DocuPassStatus.failed:    break;
      case DocuPassStatus.cancelled: break;
      case DocuPassStatus.error:     break;
    }
  },
)
```

Put it in a full-screen route (it's a platform view that wants real estate). The
verification *data* lives server-side — fetch it with `GET /docupass/{reference}`
using your API key; the device only holds the `reference`.

## API

`DocuPassView`:

| Param | Type | Notes |
|---|---|---|
| `reference` | `String` | **required** — the DocuPass reference |
| `partyId` | `String?` | party sign-token (multi-party contract flows) |
| `baseUrl` | `String?` | base URL override (on-prem ID Fort) |
| `onResult` | `void Function(DocuPassResult)` | terminal callback |

## Links

- DocuPass: https://www.idanalyzer.com/products/docupass.html
- Developer docs: https://developer.idanalyzer.com/help

## License

[MIT](LICENSE) © ID Analyzer

# DocuPass Flutter SDK

Flutter SDK for running an ID Analyzer DocuPass verification flow inside your
app. The SDK includes:

- A ready-to-use Flutter Quick UI through `DocuPassView`
- An event-driven controller API for building your own UI
- Document country and type selection
- Document camera capture in the Quick UI
- Active face verification in the Quick UI
- Phone, custom form, document, face, contract, and pending-party flow handling

This package is implemented in Flutter/Dart. It does not wrap or host
`docupass-android`, `docupass-ios`, or native DocuPass SDK screens.

The mobile app only needs a short-lived DocuPass `reference`. Your ID Analyzer
API key must stay on your backend.

## Installation

Add the SDK to your Flutter app:

```yaml
dependencies:
  docupass_flutter: ^0.2.0
```

For local development from this repository:

```yaml
dependencies:
  docupass_flutter:
    path: ../docupass-flutter
```

The package requires:

| Runtime | Requirement |
| --- | --- |
| Dart | `>=3.3.0 <4.0.0` |
| Flutter | `>=3.19.0` |
| Android | Android 7.0 or newer is recommended. Set `minSdk 24`. |

Android host app example:

```gradle
android {
    defaultConfig {
        minSdk 24
    }
}
```

## Platform Setup

### Android

Add required permissions in the host app manifest:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
```

If your DocuPass profile requires GPS, obtain location in your app and pass it
as `geolocation = "lat,lng,accuracy"`. Add location permissions only when your
host app collects location:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

The Quick UI requests camera permission when document or face capture is needed.
The SDK does not automatically fetch GPS coordinates.

### iOS

Add camera permission text in the host app `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required to capture your document and selfie.</string>
```

If your host app collects GPS to pass into DocuPass, also add the appropriate
location permission text:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Location is required for identity verification.</string>
```

## Create a Reference

Create a DocuPass session on your server, then pass the returned `reference` to
your Flutter app. Do not create sessions from the mobile app, and do not put
your ID Analyzer API key in the app bundle.

Example server-side flow:

1. Your backend calls ID Analyzer to create a DocuPass session.
2. Your backend sends the returned `reference` to your Flutter app.
3. The Flutter app runs the SDK with that reference.
4. Your backend receives the final verification result through webhook or a
   server-side result lookup.

The SDK finish callback is a UI signal. Your backend remains the source of truth
for the final verification decision and identity data.

Multi-party references can be passed in either form:

```dart
DocuPassView(reference: 'DOCUPASS_REFERENCE/PARTY_ID');

DocuPassView(
  reference: 'DOCUPASS_REFERENCE',
  partyId: 'PARTY_ID',
);
```

When both are provided, the explicit `partyId` parameter wins.

## Quick UI

Use `DocuPassView` when you want the SDK to render the complete verification
flow.

```dart
import 'package:docupass_flutter/docupass_flutter.dart';
import 'package:flutter/material.dart';

class VerifyScreen extends StatelessWidget {
  const VerifyScreen({super.key, required this.reference});

  final String reference;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: DocuPassView(
          reference: reference,
          onBackAtFirstStep: () => Navigator.of(context).maybePop(),
          onResult: (result) {
            if (result.isCompleted) {
              debugPrint('DocuPass completed: ${result.sessionId}');
            }
            if (result.isFailed) {
              debugPrint(result.error?.toDisplayMessage());
            }
          },
        ),
      ),
    );
  }
}
```

`DocuPassView` handles:

- Loading the server-driven DocuPass task
- Document country and type selection
- Document capture and upload
- Face verification with randomized actions
- Phone verification
- Custom form submission
- Contract review and signature submission
- Back navigation between non-terminal steps
- Final success or failure screen

`onResult` is called only after the user taps the final `FINISH` button. It is
not called immediately when the server reaches a terminal state.

Quick UI arguments:

| Argument | Type | When to use |
| --- | --- | --- |
| `reference` | `String?` | Required for normal API use. The short-lived DocuPass reference created by your backend. |
| `partyId` | `String?` | Optional. Use for a specific party in a multi-party signing flow. |
| `baseUrl` | `String?` | Optional API endpoint override. Most apps should leave this unset. |
| `sessionId` | `String?` | Optional existing DocuPass session id. Normally discovered from the API response. |
| `authorization` | `String?` | Optional full `Authorization` header value. Overrides generated DocuPass authorization. |
| `geolocation` | `String?` | Optional `"lat,lng,accuracy"` value sent as the `Geolocation` header. |
| `enabled` | `bool` | Defaults to `true`. Set `false` only for local demo/testing without API calls. |
| `disableSslValidation` | `bool` | Defaults to `false`. Advanced testing option for custom endpoints. |
| `connectTimeoutMs` | `int` | Connect timeout in milliseconds. Defaults to `20000`. |
| `readTimeoutMs` | `int` | Read timeout in milliseconds. Defaults to `20000`. |
| `maskCircleRadius` | `double` | Face capture mask radius as a screen-width ratio. Defaults to `0.42`. |
| `maskCircleY` | `double` | Face capture mask vertical position as a screen-height ratio. Defaults to `0.45`. |
| `turnTimeSeconds` | `double` | Seconds each liveness action must be held. Defaults to `2.0`. |
| `onResult` | `void Function(DocuPassResult)?` | Called when the user taps `FINISH` on success or failure. |
| `onBackAtFirstStep` | `VoidCallback?` | Called when system back or the SDK back button is pressed on the first non-terminal step. |

You can also pass a config object:

```dart
final config = DocupassApiConfig.fromReference(
  reference,
  partyId: partyId,
  geolocation: '25.0330,121.5654,20',
);

DocuPassView.config(
  config: config,
  onResult: handleResult,
);
```

## Event API

Use the event API when you want to build your own UI. The SDK owns the DocuPass
state machine and API calls; your app renders screens and provides captured
data. The event API does not own camera UI, liveness UI, WebView rendering, or
signature drawing.

```dart
import 'dart:async';

import 'package:docupass_flutter/docupass_flutter.dart';
import 'package:flutter/material.dart';

class CustomVerifyScreen extends StatefulWidget {
  const CustomVerifyScreen({super.key, required this.reference});

  final String reference;

  @override
  State<CustomVerifyScreen> createState() => _CustomVerifyScreenState();
}

class _CustomVerifyScreenState extends State<CustomVerifyScreen> {
  late final DocupassKycController controller;

  @override
  void initState() {
    super.initState();
    controller = DocupassKycController(
      config: DocupassApiConfig.fromReference(widget.reference),
    );
    unawaited(controller.start());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final uiState = controller.state;

        if (uiState.error != null) {
          // Show uiState.error!.message, then call controller.clearError()
          // after the user dismisses it.
        }

        return switch (uiState.event) {
          DocupassKycLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
          DocupassKycDocumentCountrySelection(:final filterCodes) => CountryStep(
              filterCodes: filterCodes,
              isBusy: uiState.isBusy,
              onSelected: controller.selectDocumentCountry,
            ),
          DocupassKycDocumentSelection(
            :final country,
            :final documentTypes,
          ) =>
            DocumentTypeStep(
              country: country,
              documentTypes: documentTypes,
              isBusy: uiState.isBusy,
              onSelected: controller.selectDocumentType,
            ),
          DocupassKycDocumentCapture(
            :final documentSide,
            :final allowFileUpload,
          ) =>
            DocumentCaptureStep(
              documentSide: documentSide,
              allowFileUpload: allowFileUpload,
              isBusy: uiState.isBusy,
              onCaptured: controller.uploadDocument,
            ),
          DocupassKycFaceVerification(:final actions) => FaceStep(
              actions: actions,
              isBusy: uiState.isBusy,
              onComplete: controller.uploadFace,
            ),
          DocupassKycPhoneVerification(
            state: final sessionState,
            :final codeSent,
            :final currentNumber,
          ) =>
            PhoneStep(
              sessionState: sessionState,
              codeSent: codeSent,
              currentNumber: currentNumber,
              isBusy: uiState.isBusy,
              onSendCode: controller.sendPhoneCode,
              onVerifyCode: controller.verifyPhoneCode,
            ),
          DocupassKycCustomForm(:final fields) => CustomFormStep(
              fields: fields,
              isBusy: uiState.isBusy,
              onSubmit: controller.saveCustomForm,
            ),
          DocupassKycContract(
            :final html,
            :final signatureFields,
          ) =>
            ContractStep(
              html: html,
              signatureFields: signatureFields,
              isBusy: uiState.isBusy,
              onSubmit: controller.submitContract,
            ),
          DocupassKycPartyPending() => PendingStep(
              isBusy: uiState.isBusy,
              onRefresh: controller.refresh,
            ),
          DocupassKycCompleted(:final result) => CompletedStep(result: result),
          DocupassKycFailed(:final result, :final error) => FailedStep(
              result: result,
              error: error,
            ),
        };
      },
    );
  }
}
```

The `CountryStep`, `DocumentTypeStep`, `DocumentCaptureStep`, `FaceStep`,
`PhoneStep`, `CustomFormStep`, `ContractStep`, `PendingStep`, `CompletedStep`,
and `FailedStep` widgets in the example above are placeholders for your own UI.

### Controller Lifecycle

Create one `DocupassKycController` for one verification screen or custom UI
flow. Listen before or immediately after `start()` so your UI receives state
updates.

```dart
final controller = DocupassKycController(
  config: DocupassApiConfig.fromReference(
    reference,
    partyId: null,
    geolocation: null,
  ),
);

controller.addListener(() {
  final state = controller.state;
  debugPrint('Current DocuPass event: ${state.event.runtimeType}');
});

unawaited(controller.start());
```

Call `controller.dispose()` when your screen, widget, provider, or bloc is
destroyed.

### Configuration

Most apps should create config with `DocupassApiConfig.fromReference(...)` or
`docupassConfigFromReference(...)`.

| API | Use |
| --- | --- |
| `DocupassApiConfig.fromReference(reference, partyId, geolocation, enabled)` | Recommended config factory for normal app usage. |
| `docupassConfigFromReference(reference, partyId, geolocation, enabled)` | Top-level helper equivalent to `DocupassApiConfig.fromReference`. |
| `DocupassApiConfig(...)` | Advanced/manual config when you need to override endpoint, authorization, session id, or timeouts. |

`DocupassApiConfig` fields:

| Field | Default | Meaning |
| --- | --- | --- |
| `enabled` | `true` | `true` calls the DocuPass API. `false` runs local fallback workflow only; use for demos/tests. |
| `baseUrl` | Resolved from reference | Optional API base URL override. References starting with `EU` use the EU endpoint; others use the US endpoint. |
| `reference` | `null` | DocuPass reference created by your backend. |
| `partyId` | `null` | Optional party id for multi-party signing. |
| `sessionId` | `null` | Optional existing DocuPass session id. Normally discovered from the API response. |
| `authorization` | `null` | Optional full `Authorization` header value. If set, it overrides generated DocuPass auth. |
| `geolocation` | `null` | Optional `"lat,lng,accuracy"` value sent as the `Geolocation` header. |
| `disableSslValidation` | `false` | Advanced testing option for custom endpoints. Keep `false` for production. |
| `connectTimeoutMs` | `20000` | HTTP connect timeout in milliseconds. |
| `readTimeoutMs` | `20000` | HTTP read timeout in milliseconds. |

Authorization is generated automatically when `authorization` is not set:

```text
DOCUPASS <reference>
DOCUPASS <reference> <partyId>
DOCUPASS_SESSION <sessionId>
```

Reference strings with a slash are parsed automatically:

```dart
final config = DocupassApiConfig.fromReference(
  'DOCUPASS_REFERENCE/PARTY_ID',
);

// Authorization becomes:
// DOCUPASS DOCUPASS_REFERENCE PARTY_ID
```

### Controller Methods

| Method | Call when | Parameters |
| --- | --- | --- |
| `start()` | When the screen should begin loading the DocuPass task. | No parameters. Calls `get_action` when `enabled` is `true`. |
| `refresh()` | On `DocupassKycPartyPending`, or when you want to resync with the server. | No parameters. Calls `get_action`. |
| `back()` | When the user taps your back button and `state.canGoBack && !state.isBusy`. | No parameters. Does nothing on first step, busy state, or terminal screens. |
| `clearError()` | After your UI dismisses `state.error`. | No parameters. |
| `restart()` | When you intentionally want to reset local SDK state and start again. | No parameters. |
| `sendPhoneCode(number, type)` | On `DocupassKycPhoneVerification`, before the OTP is entered. | `number`: `String?`; `type`: `"sms"` or `"call"`. |
| `verifyPhoneCode(number, code)` | On `DocupassKycPhoneVerification`, after the user enters the OTP. | `number`: same number used for sending, or `null` for a preset server phone; `code`: OTP string. |
| `saveCustomForm(answers)` | On `DocupassKycCustomForm`, after all required fields are filled. | `answers`: `Map<String, String>` keyed by `field.fieldId` or fallback label. |
| `selectDocumentCountry(country)` | On `DocupassKycDocumentCountrySelection`, when the user chooses a country. | `country`: `DocupassCountry`, normally from `fetchDocupassCountries(event.filterCodes)`. |
| `selectDocumentType(documentTypeCode)` | On `DocupassKycDocumentSelection`, when the user chooses a document type. | `documentTypeCode`: from `event.documentTypes[].apiTypeCode`. |
| `uploadDocument(frontBase64, backBase64)` | On `DocupassKycDocumentCapture`, after your UI captures the required side(s). | Raw JPEG base64 without a `data:image/...` prefix. `backBase64` can be `null` for front-only documents. |
| `uploadFace(faceBase64List)` | On `DocupassKycFaceVerification`, after your liveness UI captures face frames. | Non-empty list of raw JPEG base64 strings without a `data:image/...` prefix. |
| `submitContract(signatures)` | On `DocupassKycContract`, after the user signs every required field. | `Map<signatureField.uid, image>`. Signature images should be `data:image/png;base64,...`. |
| `dispose()` | When the UI owner is destroyed. | No parameters. Closes HTTP resources and stops notifying listeners. |

Do not call step-specific methods before the matching event is emitted. If
`state.isBusy` is `true`, keep your UI controls disabled until a new state is
emitted.

### State Model

Every listener update exposes `DocupassKycUiState`.

| Field | Meaning |
| --- | --- |
| `event` | Current flow step as a `DocupassKycEvent` subclass. |
| `result` | Local SDK flow result collected so far. This is not the authoritative verification decision. |
| `isBusy` | `true` while the SDK is making an API call or processing a submitted action. |
| `canGoBack` | `true` when a custom UI can call `controller.back()`. |
| `error` | User-displayable error payload. It is independent from `event`. |

`DocupassKycErrorEvent` fields:

| Field | Meaning |
| --- | --- |
| `message` | User-displayable error message. |
| `normalized` | Structured error details when the SDK can classify the DocuPass error. |

Events and payloads:

| Event | Payload | What your UI should do |
| --- | --- | --- |
| `DocupassKycLoading` | None | Show loading UI. |
| `DocupassKycPhoneVerification` | `state`, `codeSent`, `currentNumber` | Show phone entry/OTP UI. Use `sendPhoneCode` and `verifyPhoneCode`. |
| `DocupassKycCustomForm` | `fields` | Render fields and submit with `saveCustomForm`. |
| `DocupassKycDocumentCountrySelection` | `filterCodes`, `selectedCountry` | Render countries and call `selectDocumentCountry`. |
| `DocupassKycDocumentSelection` | `country`, `documentTypes`, `selectedDocumentType` | Render document types and call `selectDocumentType`. |
| `DocupassKycDocumentCapture` | `country`, `documentType`, `documentSide`, `allowFileUpload` | Capture document image(s) and call `uploadDocument`. |
| `DocupassKycFaceVerification` | `actions` | Run liveness using `actions` and call `uploadFace`. |
| `DocupassKycContract` | `state`, `html`, `signatureFields` | Render HTML, collect signatures, and call `submitContract`. |
| `DocupassKycPartyPending` | None | Show pending UI and call `refresh()` when the user retries/checks status. |
| `DocupassKycCompleted` | `result` | Show final success UI. |
| `DocupassKycFailed` | `result`, `error` | Show final failure UI. |

## Parameter Reference

### Document Country

`controller.selectDocumentCountry(country)` accepts a `DocupassCountry`.

For custom UI, load the same remote country list used by the Quick UI:

```dart
final event = controller.state.event;

if (event is DocupassKycDocumentCountrySelection) {
  final countries = await fetchDocupassCountries(event.filterCodes);
  controller.selectDocumentCountry(countries.first);
}
```

`fetchDocupassCountries` loads:

```text
https://v.idanalyzer.com/asset/country.json
```

It uses the `iso` and `name_en` fields, filters by server-accepted country
codes when `filterCodes` is present, removes duplicates, and sorts by display
name.

For offline demos or fallback UI, use `countriesForFilter(event.filterCodes)`.
Unknown server country codes are preserved as `DocupassCountry(code: code,
name: code)`.

The built-in fallback country list currently contains:

| Code | Name |
| --- | --- |
| `AU` | Australia |
| `CA` | Canada |
| `DE` | Germany |
| `FR` | France |
| `GB` | United Kingdom |
| `HK` | Hong Kong |
| `JP` | Japan |
| `KR` | South Korea |
| `SG` | Singapore |
| `TH` | Thailand |
| `TW` | Taiwan |
| `US` | United States |

### Document Type

`controller.selectDocumentType(documentTypeCode)` accepts one of the document
type codes emitted by `event.documentTypes`. Use that payload instead of
hardcoding the full list, because the server can restrict available document
types.

| Constant | `apiTypeCode` | Label | Default back side requirement |
| --- | --- | --- | --- |
| `passportDocumentType` | `P` | `Passport` | No |
| `driverLicenseDocumentType` | `D` | `Driver License` | Yes |
| `identityCardDocumentType` | `I` | `Identity Card` | Yes |

Server `documentSide` overrides the local default:

| `documentSide` | Meaning |
| --- | --- |
| `1` | Front only. |
| `2` | Front and back may be required. Passport remains front-only in the Quick UI. |
| `0` or `null` | Use the local document type default. |

For custom UI, check both `event.documentSide` and
`event.documentType?.requiresBackSide` before deciding whether to ask for a back
image.

### Document Images

`controller.uploadDocument(frontBase64, backBase64)` expects:

| Parameter | Value |
| --- | --- |
| `frontBase64` | Required raw JPEG base64 for the front image. Do not include a `data:image/...` prefix. |
| `backBase64` | Raw JPEG base64 for the back image, or `null` when the document is front-only. |

The Quick UI captures with the device camera and converts the image before
uploading. Custom UI can use any camera or image picker implementation as long
as it submits raw JPEG base64.

### Face Verification

`event.actions` tells your custom UI which liveness actions to perform. The SDK
randomizes face actions and requires at least two actions when candidates are
available.

| Enum | Instruction |
| --- | --- |
| `KYCAction.turnLeft` | `TURN HEAD LEFT` |
| `KYCAction.turnRight` | `TURN HEAD RIGHT` |
| `KYCAction.turnUp` | `TURN HEAD UP` |
| `KYCAction.mouthOpen` | `OPEN MOUTH O-SHAPE` |

`controller.uploadFace(faceBase64List)` expects a non-empty list of raw JPEG
base64 strings without a `data:image/...` prefix.

The Quick UI uses the front camera and on-device face detection to verify head
movement and O-shaped mouth opening. Custom UI is responsible for its own
liveness detection and frame capture before calling `uploadFace`.

### Phone Verification

`DocupassKycPhoneVerification` contains:

| Field | Meaning |
| --- | --- |
| `state` | Full `DocupassSessionState`, including preset phone and country code options. |
| `codeSent` | `true` after `sendPhoneCode` succeeds. |
| `currentNumber` | The number used by the last send request, if provided by your UI. |

`controller.sendPhoneCode(number, type)` parameters:

| Parameter | Value |
| --- | --- |
| `number` | `null` if the server already has `state.userPhone`; otherwise send the phone number your UI collected, preferably in international format such as `+15551234567`. |
| `type` | `"sms"` or `"call"`. |

`controller.verifyPhoneCode(number, code)` parameters:

| Parameter | Value |
| --- | --- |
| `number` | Same number used for `sendPhoneCode`, or `null` for a preset server phone. |
| `code` | OTP code entered by the user. |

Available phone country codes are exposed as `event.state.phoneCountryCodes`:

| Field | Example | Meaning |
| --- | --- | --- |
| `name` | `United States` | Country display name. |
| `dialCode` | `+1` | Dialing prefix. |
| `code` | `US` | ISO-2 country code. |

### Custom Form

`DocupassKycCustomForm.fields` contains `DocupassCustomField` values:

| Field | Meaning |
| --- | --- |
| `fieldId` | Preferred key for `saveCustomForm`. |
| `fieldLabel` | User-visible label. Use as a fallback key only if `fieldId` is blank. |
| `fieldDescription` | Optional helper text from the DocuPass profile. |
| `fieldType` | `0` text, `1` multi-line text, `2` dropdown/options. |
| `fieldData` | Raw option data for dropdown fields. Preserve the selected server value when submitting. |

Submit answers with:

```dart
final key = field.fieldId.trim().isNotEmpty
    ? field.fieldId
    : field.fieldLabel;

await controller.saveCustomForm(<String, String>{
  key: answer,
});
```

For dropdown fields, the Quick UI accepts one option per line and supports
`label;value`, `label<TAB>value`, or `label|value`. If no separator is present,
the same text is used for label and value.

### Contract

`DocupassKycContract` contains:

| Field | Meaning |
| --- | --- |
| `html` | Contract HTML. Custom UI can render it in a WebView. |
| `signatureFields` | Signature placeholders extracted from `data-signature` elements. |
| `state` | Full `DocupassSessionState`. |

`DocupassContractSignatureField`:

| Field | Meaning |
| --- | --- |
| `uid` | Required key for `submitContract(signatures)`. |
| `label` | User-visible signature label. |
| `party` | Optional party identifier from the contract template. |

Submit signatures as PNG data URLs:

```dart
final signatures = <String, String>{
  for (final field in event.signatureFields)
    field.uid: 'data:image/png;base64,...',
};

await controller.submitContract(signatures);
```

Signature values should include the `data:image/png;base64,` prefix.

The Quick UI injects the drawn signature preview into matching contract
placeholders before submitting. Custom UI should do the same if it wants the
signed preview to appear inside its WebView.

## Back Navigation

`DocuPassView` handles Flutter system back and the SDK back button.
Non-terminal steps go back to the previous SDK step when possible. If the user
is already on the first step, `onBackAtFirstStep` is called so your app can
close the screen.

Final success and failure screens are terminal. Back presses do not leave those
screens; the user must tap `FINISH`.

For custom UI:

```dart
final state = controller.state;

if (state.canGoBack && !state.isBusy) {
  controller.back();
} else {
  Navigator.of(context).maybePop();
}
```

## Error Handling

API and local validation errors are exposed through `state.error`. Showing an
error does not necessarily change `state.event`, so your UI should render the
current event and show the error message separately.

```dart
final error = controller.state.error;

if (error != null) {
  final message = error.normalized?.toDisplayMessage() ?? error.message;
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('DocuPass error'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () {
            controller.clearError();
            Navigator.of(context).pop();
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
```

`DocupassNormalizedError` contains:

| Field | Meaning |
| --- | --- |
| `code` | Normalized top-level error code when available. |
| `subCode` | Normalized secondary code when available. |
| `title` | Short user-facing title. |
| `detail` | User-facing explanation. |
| `suggestion` | Recommended UI action. |
| `action` | SDK hint such as retry, retake document, retake face, fix signature, show completed, or show failed. |
| `warningCodes` | Optional warning codes returned by DocuPass. |
| `httpStatus` | HTTP status when available. |
| `rawMessage` | Raw server message when available. |
| `rawBody` | Raw server body when available. |

## Results

`DocuPassResult` is returned from `DocuPassView.onResult` after the final
`FINISH` tap.

| Field | Meaning |
| --- | --- |
| `status` | `completed`, `failed`, `cancelled`, or `unknown`. |
| `sessionId` | DocuPass session id when known. |
| `reference` | DocuPass reference when known. |
| `serverTask` | Last server task handled by the SDK. |
| `country` | Selected `DocupassCountry`. |
| `documentType` | Selected `DocupassDocumentType`. |
| `isFaceVerified` | Local SDK flag set after face upload succeeds locally. |
| `sessionState` | Latest server state as a map. |
| `error` | Terminal normalized error for failed flows. |
| `raw` | Local raw values collected by the SDK, including uploaded base64 values. |

`KYCResult` is the controller-level local result used by the event API. It
contains selected country/type, uploaded image base64 values, the current
session state, and terminal error information.

Both result models are useful for app UI decisions, but they are not the
authoritative identity verification result. Use your backend webhook or
server-side DocuPass result lookup to decide whether the user is accepted,
rejected, or under review.

## Example App

```sh
cd example
flutter pub get
flutter run
```

The example app starts on the input screen. Enter your own backend-created
reference, or set `_defaultReference` locally while debugging. Do not commit a
real DocuPass reference.

Local camera demo mode uses `enabled: false` and does not call DocuPass APIs.

Useful checks:

```sh
flutter analyze

cd example
flutter analyze
flutter build apk --debug
```

Install a debug APK on a connected Android device:

```sh
adb devices
adb -s <device-serial> install -r build/app/outputs/flutter-apk/app-debug.apk
```

## License

[MIT](LICENSE) (c) [ID Analyzer](https://www.idanalyzer.com)

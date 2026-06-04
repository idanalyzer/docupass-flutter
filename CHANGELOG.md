## 0.1.1

- **Customization props** on `DocuPassView` — `brandColor`, `logoUrl`, and
  `labels` (override any user-facing label, in any language), forwarded to the
  native cores' `DocuPassTheme` / `DocuPassStrings`.
- Picks up the native cores' 0.1.1 audit fixes (e-signature `data-signature`
  field detection, phone country-code picker).

## 0.1.0

Initial DocuPass Flutter plugin over the native Android + iOS cores.

- `DocuPassView` widget (AndroidView / UiKitView platform view) with props
  `reference`, `partyId`, `baseUrl` and an `onResult` callback.
- `DocuPassResult` / `DocuPassStatus` Dart types.
- Android: `DocupassFlutterPlugin` + `DocuPassPlatformView` hosting the native
  Compose `DocuPassView` (supplies its own ViewTree lifecycle/viewmodel/saved-state
  owners); result over a per-view MethodChannel.
- iOS: `DocupassFlutterPlugin` + `DocuPassPlatformView` hosting the SwiftUI
  `DocuPassView` via `UIHostingController`.

Wraps the native SDKs (no logic reimplemented).

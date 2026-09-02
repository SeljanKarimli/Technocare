# iOS App Store release

Technocare's iOS application uses bundle identifier
`com.technocare.technocare` and is built by the
`technocare-ios-app-store` Codemagic workflow.

## Apple and Codemagic setup

1. The Apple Developer account must have an active Apple Developer Program
   membership.
2. Register or confirm the explicit App ID `com.technocare.technocare` and
   enable Push Notifications.
3. Create the Technocare app record in App Store Connect before the first
   upload.
4. Create an App Store Connect API key with App Manager access. Store it in
   the Codemagic team integrations under the reference
   `technocare_app_store`; never commit its `.p8` file.
5. Codemagic fetches or creates the Apple Distribution certificate and App
   Store provisioning profile through this integration.

## Build and upload

Run the `Technocare iOS App Store` workflow manually in Codemagic. It:

- analyzes and tests the Flutter app;
- installs CocoaPods dependencies;
- applies the App Store provisioning profile;
- creates a signed IPA; and
- uploads the IPA to App Store Connect.

The first destination is App Store Connect/TestFlight. Wait for Apple's build
processing and compliance checks before assigning testers or submitting a
version for App Review.

The build consumes non-secret Firebase client identifiers from Codemagic
environment variables. If they are absent, the app still starts normally, but
push notifications stay disabled. APNs must also be configured in Firebase for
iOS notification delivery.

## Required Codemagic variables

- `FIREBASE_API_KEY`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_IOS_APP_ID`
- `FIREBASE_STORAGE_BUCKET` (optional)

`API_BASE_URL` is defined in `codemagic.yaml`. Signing certificates,
provisioning profiles, App Store Connect keys, and Firebase service credentials
must remain in Codemagic/Apple/Firebase secret storage and are excluded by the
repository `.gitignore`.

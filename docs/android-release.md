# Android release and Google Play publishing

The Android application ID is `com.technocare.technocare`.

## Signing model

- Google Play App Signing holds the app signing key used for distribution.
- Codemagic signs every uploaded Android App Bundle with the Technocare upload key.
- The upload key and its passwords must never be committed to Git.
- Keep an encrypted, independent backup of the upload keystore and its credentials. Codemagic does not provide a way to download the keystore after upload.

The Codemagic Android keystore reference must be named `technocare_upload_key`. The Gradle configuration reads the secure `CM_KEYSTORE_PATH`, `CM_KEYSTORE_PASSWORD`, `CM_KEY_ALIAS`, and `CM_KEY_PASSWORD` variables exposed by Codemagic.

For local signed builds, create `t_app/android/key.properties` with:

```properties
storePassword=REPLACE_WITH_SECRET
keyPassword=REPLACE_WITH_SECRET
keyAlias=REPLACE_WITH_ALIAS
storeFile=REPLACE_WITH_ABSOLUTE_KEYSTORE_PATH
```

`key.properties`, `*.jks`, and `*.keystore` are ignored by Git.

## Google Play publishing

1. Upload the keystore in Codemagic under **Teams > Personal Account > Integrations > Code signing identities > Android keystores** using the reference `technocare_upload_key`.
2. Build once and verify that the `Verify Android App Bundle signature` step passes.
3. For the first release, upload the signed bundle manually to the Google Play **Internal testing** track if Google Play has not yet accepted a version of the application.
4. Create a dedicated Google Cloud service account for Codemagic, grant it only the required release permissions for this application in Play Console, and store its JSON key in a Codemagic secret variable.
5. Add Codemagic `publishing.google_play` configuration only after the service-account secret exists. Use the `internal` track first; promote a verified build to production from Play Console.

Never use the unsigned bundle produced by GitHub Actions for Play Console. GitHub Actions only compiles it as a release-build check; Codemagic produces the signed publishing artifact.

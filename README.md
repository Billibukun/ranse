# Ranse

**Your mail, delivered.** Android email client for cPanel-hosted mailboxes —
a Data Druid Tech Services product.

Customers on cPanel hosting sign in with just their email address and
password; Ranse discovers the server settings, shows the inbox, sends mail
directly through the customer's own mail server, and notifies on new mail.

## Repository layout

| Path | What it is |
|---|---|
| `app/` | Flutter Android app (package `com.datadruid.ranse`) |
| `docs/` | Design notes |
| `changelog/` | Session changelogs |
| `.github/workflows/` | CI: tag → build signed APK → GitHub Release |

## How releases and auto-update work

1. Bump `version:` in `app/pubspec.yaml` (e.g. `0.2.0+2`).
2. Commit, then tag and push: `git tag v0.2.0 && git push origin v0.2.0`.
3. GitHub Actions builds the **signed** APK and attaches it to a GitHub
   Release for that tag.
4. Installed apps check the latest release on launch (and from Settings →
   Check for updates), download the APK, and hand it to the Android
   installer. Because every release uses the same signing key, it installs
   as a seamless update.

The public download page for customers is this repo's
[Releases](https://github.com/Billibukun/ranse/releases) — link the latest
APK from any site.

## Signing

`app/android/keystore/ranse-release.jks` + `app/android/key.properties`
exist **only locally and as GitHub secrets** (`ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`). They are gitignored.
**Back the keystore up — losing it permanently breaks the update chain**
(a new key means customers must uninstall/reinstall).

## Development

```
cd app
flutter pub get
flutter run          # debug on a connected device
flutter analyze && flutter test
flutter build apk --release
```

## Roadmap

- Push bridge on the Hetzner VPS (IMAP IDLE → FCM data ping) to replace
  15-minute polling with instant notifications.
- Folder tree, drafts, server-side search, per-customer branding.

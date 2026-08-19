# Canto Mobile

Flutter client for Canto's listening-first Cantonese course.

## Local development

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

## Railway web deployment

Create a Railway service from this repository and set the build variable
`API_BASE_URL` to the public HTTPS URL of the Canto backend, including
`https://` (for example `https://languagebackend-production.up.railway.app`).
If you omit the scheme, the app will assume HTTPS automatically. The included
Dockerfile builds the Flutter web/PWA release and serves it with nginx on
Railway's assigned port.

The same Flutter source supports native iOS and Android builds; public native
distribution requires separate App Store and Play Store releases.

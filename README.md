# Canto Mobile

Flutter client for Canto's listening-first Cantonese course.

## Local development

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

## Railway web deployment

Create a Railway service from this repository.

Set these variables on the **frontend** service:

| Variable | When | Example |
| --- | --- | --- |
| `BACKEND_URL` | runtime | `https://languagebackend-production.up.railway.app` |

You do **not** need `API_BASE_URL` on Railway. The web build always calls
same-origin `/api/...` and nginx proxies those requests to `BACKEND_URL`.

Optional: remove any existing `API_BASE_URL` variable from the frontend
service so it cannot override the Docker build default.

After deploy, hard refresh once (`Cmd+Shift+R`) to pick up the latest app
bundle.

The same Flutter source supports native iOS and Android builds; public native
distribution requires separate App Store and Play Store releases.

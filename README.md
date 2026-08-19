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
| `API_BASE_URL` | build (optional) | `/api` |

The Docker image builds Flutter web with `API_BASE_URL=/api` by default. The
app calls same-origin `/api/...` routes and nginx proxies them to
`BACKEND_URL`, so auth and curriculum requests always reach the backend even
if an old JS bundle is cached.

After deploy, hard refresh once (`Cmd+Shift+R`) to pick up the latest app
bundle.

The same Flutter source supports native iOS and Android builds; public native
distribution requires separate App Store and Play Store releases.

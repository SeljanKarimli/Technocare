# Technocare live mobile app

Technocare is a Flutter Android/iOS application backed by ASP.NET Core 8 and the live [technocare.az](https://technocare.az/) WordPress/WooCommerce site. WordPress remains the source of truth for homepage sections, services, education, projects, products, prices, stock, brands, and categories. Supported website changes reach the app through a five-minute conditional cache without a mobile release.

## Architecture

```mermaid
flowchart LR
    App[Flutter guest app] -->|HTTPS| API[ASP.NET Core gateway]
    API -->|Conditional JSON requests| WP[WordPress app API plugin]
    WP --> Woo[WooCommerce catalogue]
    API --> Mongo[(MongoDB users, applications, notifications)]
    API --> SMTP[SMTP verification, recovery, applications]
    WP -->|Signed update webhook| API
    API --> FCM[Firebase Cloud Messaging topic]
    FCM -->|Android/iOS system notification| App
    App -->|Prefilled guest order| WhatsApp[Technocare WhatsApp]
```

- Flutter never parses Elementor HTML and never trusts client-supplied prices.
- The WordPress plugin converts supported Elementor sections into ordered, typed JSON blocks.
- The backend isolates the app from WordPress response details, retries safe reads, caches for five minutes, and returns stale content during temporary website failures.
- The active cart is stored on the device and works without registration or login. It refreshes product snapshots from WooCommerce before preparing an order.
- The app resolves Technocare's WhatsApp contact from live homepage links, with a build-time fallback, and opens a complete prefilled order message. WhatsApp requires the customer to tap **Send**.
- Existing authentication and signed WooCommerce checkout/session code is retained for a possible future account/payment flow, but login, registration, profile, and server-side orders are not exposed by the active mobile UI.
- Published website/page/product changes create a broadcast notification through a signed WordPress webhook. Every app install subscribes to the `technocare-site-updates` Firebase topic; login is not required.
- Service and education applications are saved first, then queued for reliable SMTP delivery to `info@technocare.az`.
- Legacy MongoDB products, carts, orders, categories, and projects are retained behind admin-only `/api/internal/legacy/*` routes; the mobile app does not use them.

## Repository layout

| Path | Purpose |
| --- | --- |
| `wordpress/technocare-app-api/` | Versioned WordPress/WooCommerce integration plugin |
| `backendMAIN/` | ASP.NET Core gateway, identity, applications, notifications, cart coordination, admin UI |
| `backendMAIN.Tests/` | Backend contract, authorization, and sanitized-error tests |
| `t_app/` | Flutter Android/iOS client |
| `.github/workflows/ci.yml` | Backend, Flutter, and WordPress validation |
| `codemagic.yaml` | Android App Bundle validation and Codemagic artifact build |

## Public API

WordPress plugin:

| Method | Route |
| --- | --- |
| GET | `/wp-json/technocare-app/v1/home` |
| GET | `/wp-json/technocare-app/v1/products` |
| GET | `/wp-json/technocare-app/v1/products/{id}` |
| GET | `/wp-json/technocare-app/v1/suggestions?q=&limit=5` |
| GET | `/wp-json/technocare-app/v1/categories` |
| GET | `/wp-json/technocare-app/v1/brands` |
| GET | `/wp-json/technocare-app/v1/projects` |
| GET | `/wp-json/technocare-app/v1/services` |
| GET | `/wp-json/technocare-app/v1/education` |

The signed checkout and order endpoints are for the backend only.

Backend gateway:

| Access | Route |
| --- | --- |
| Public | `GET /api/v1/content/home` |
| Public | `GET /api/v1/content/projects`, `/services`, `/education` |
| Public | `GET /api/v1/shop/products`, `/products/{id}`, `/categories`, `/brands` |
| Public | `GET /api/v1/shop/suggestions?q=&limit=5` |
| Public media | `GET /api/v1/media?url=` (only Technocare upload images) |
| JWT, retained/inactive in the guest flow | `/api/v1/shop/cart`, `/checkout-session`, `/orders`, `/api/notifications/my-notifications` |
| Public | `GET /api/notifications/public` |
| Signed WordPress webhook | `POST /api/v1/site-events` |
| Public submission | `/api/serviceapplications`, `/api/educationapplications` |

Product search supports Azerbaijani text, exact/prefix SKU ranking, product name, brand/category, and description matching; category, brand, stock, and price filters; pagination; and relevance, popularity, latest, name, and price sorting.

## 1. Install the WordPress plugin

1. Copy `wordpress/technocare-app-api` to `wp-content/plugins/` on technocare.az.
2. Define a long random shared secret outside the repository in `wp-config.php`:

   ```php
   define('TECHNOCARE_APP_SHARED_SECRET', 'replace-with-at-least-32-random-characters');
   define('TECHNOCARE_APP_BACKEND_URL', 'https://api.technocare.az');
   ```

3. Activate **Technocare App API** in WordPress.
4. Open **Settings → Technocare App**, select the published homepage, and confirm supported section visibility/order.
5. Ensure WooCommerce checkout pages and pretty permalinks are configured.
6. Allow WP-Cron to finish the first product search-index build. Products are indexed in batches of 200; later product, stock, brand, and category edits update the index automatically.

The plugin reads rendered published content, WooCommerce records, and portfolio pages. Header/footer markup and unsupported sections are not sent. A genuinely new Elementor layout still needs a matching typed block and Flutter renderer.

## 2. Configure and run the backend

Prerequisites: .NET 8 SDK, MongoDB, SMTP credentials, and a valid HTTPS hostname such as `https://api.technocare.az`.

```powershell
Copy-Item backendMAIN/appsettings.example.json backendMAIN/appsettings.Development.json
dotnet restore backendMAIN/backend.csproj
dotnet run --project backendMAIN/backend.csproj --launch-profile https
```

Set secrets using environment variables in production:

```text
MongoDbSettings__ConnectionString
JwtSettings__Secret
TechnocareSite__SharedSecret
EmailSettings__SmtpPass
EmailSettings__ApplicationRecipient=info@technocare.az
Firebase__Enabled=true
Firebase__ProjectId
Firebase__ServiceAccountJson
AdminBootstrap__Email
```

`TechnocareSite__SharedSecret` must exactly match `TECHNOCARE_APP_SHARED_SECRET`. `Firebase__ServiceAccountJson` must be stored as a secret, never committed. Configure `Cors__AllowedOrigins__0` only for trusted browser origins. Native mobile requests do not require permissive CORS.

Deploy behind a reverse proxy that forwards `X-Forwarded-For` and `X-Forwarded-Proto`, binds a valid TLS certificate, and redirects HTTP to HTTPS. `/health/live` checks only the process; `/health/ready` checks WordPress and MongoDB dependencies. Verification and password-reset mail is delivered by a durable MongoDB outbox, so a temporary SMTP outage does not roll back registration.

There is no configuration-based admin password. To bootstrap the first administrator, set `AdminBootstrap__Email` to an existing verified BCrypt-backed user for one deployment, verify the role change, then remove the setting. Manage later roles through an authenticated Admin account.

## 3. Run the Flutter app

Prerequisites: Flutter stable with Dart 3.8 or later and Android Studio or Xcode.

Before the production API is deployed, the Web preview can use the local-only development API. It proxies catalogue reads to the live WooCommerce Store API and keeps demo account/application data only in memory; it never sends real email or push notifications:

```powershell
python scripts/dev-preview-api.py

Set-Location t_app
flutter run -d web-server `
  --web-port=8765 `
  --dart-define=API_BASE_URL=http://127.0.0.1:8787/api
```

```powershell
Set-Location t_app
flutter pub get
flutter run --dart-define=API_BASE_URL=https://api.technocare.az/api
```

System push notifications need the non-secret Firebase client identifiers at build time:

```powershell
flutter run `
  --dart-define=API_BASE_URL=https://api.technocare.az/api `
  --dart-define=FIREBASE_API_KEY=... `
  --dart-define=FIREBASE_PROJECT_ID=... `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... `
  --dart-define=FIREBASE_ANDROID_APP_ID=... `
  --dart-define=FIREBASE_IOS_APP_ID=...
```

Enable the **Push Notifications** and **Background Modes → Remote notifications** capabilities for the iOS App ID/profile, and upload the APNs authentication key in Firebase. Android 13+ and iOS ask the user for notification permission on first configured launch. If Firebase variables are absent, the app continues normally and the public in-app notification feed still works.

Use the same define for release builds:

```powershell
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.technocare.az/api
flutter build ipa --release --dart-define=API_BASE_URL=https://api.technocare.az/api
```

`WHATSAPP_PHONE=994102307097` can be supplied as an additional `--dart-define` fallback. Normally the app discovers the current WhatsApp link from the website homepage response within the same five-minute cache window. Android cleartext traffic and invalid-certificate overrides are disabled.

### Guest-only mobile flow

1. The mobile UI has no login, registration, profile, or account gate.
2. Browsing, search, cart, WhatsApp ordering, education/service applications, projects, and website-update notifications work as a guest.
3. The backend authentication implementation is retained but dormant so it can be reintroduced in a later release without affecting the guest journey.

## Validation

```powershell
dotnet test backendMAIN.Tests/backendMAIN.Tests.csproj

Set-Location t_app
flutter analyze --fatal-warnings
flutter test

php -l ..\wordpress\technocare-app-api\technocare-app-api.php
php ..\wordpress\technocare-app-api\tests\project-parser-smoke.php
php ..\wordpress\technocare-app-api\tests\search-normalization-smoke.php
```

CI runs backend tests, Flutter analysis/tests plus Android, iOS, and web builds, WordPress parser/search tests, and insecure-client checks on `main`, pull requests, and `codex/**` branches. A manual workflow run can enable the deployed production smoke test; it blocks on health, public routes, at least 8,995 products, exactly 26 projects, and all 26 primary images.

## Rollout order

1. Install and verify the WordPress plugin endpoints.
2. Deploy the backend to a valid HTTPS endpoint with production secrets.
3. Set DNS/TLS for `api.technocare.az` (or supply another HTTPS URL at build time).
4. Produce an internal Android/iOS build and verify guest cart persistence plus the prefilled WhatsApp order on real devices.
5. Release the mobile builds.

After deployment, verify that editing homepage text, changing product price/stock, reordering a supported section, and hiding a section appear in the app within five minutes.

## Security notes

- Do not commit `appsettings.*.json`, `.env` files, signing keys, certificates, SMTP passwords, JWT secrets, or the WordPress shared secret.
- Signed WordPress writes include a timestamp, single-use nonce, and HMAC signature.
- Swagger is development-only, errors are returned as sanitized Problem Details, and privileged routes require the Admin role.
- The guest cart stays only on the device and can be cleared from the cart screen.

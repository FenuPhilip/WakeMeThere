# WakeMeThere

WakeMeThere is an Android travel proximity alarm. Choose a destination, configure alert distances, and start a local Android foreground location service. It calculates approximate straight-line distance and can alert with sound, text-to-speech, and vibration.

## Current capabilities

- Select any destination by tapping the global online map, searching online places, or searching saved destinations on device.
- Render OpenStreetMap data with MapLibre Flutter and OpenFreeMap vector tiles. MapLibre displays the OpenFreeMap, OpenMapTiles, and OpenStreetMap attribution.
- Search and reverse geocode through configurable Photon by Komoot. Search waits 650 ms after typing, returns at most five matches, avoids GPS location bias, and caches recent results locally with expiry. Map taps stay selectable if Photon is offline.
- Save and delete destinations locally.
- Configure early, wake-up, and critical alert distances and alert modes per journey.
- Track using an Android foreground service, including while the app is in the background, when Android permissions and device conditions allow.
- Filter stale or inaccurate fixes, debounce proximity stages, and adapt polling as the destination gets closer.
- Store journey state and alert configuration in SQLite; store app preferences locally.
- Run GPS distance monitoring and proximity evaluation without internet after a journey starts.

## Not implemented yet

- Downloadable offline map packs. OpenFreeMap allows downloads up to 3,000 tiles or 50 MB per download, with at most four parallel requests and a unique identifying User-Agent. Larger downloads require contacting the provider. Offline pack download and lifecycle UI are not implemented yet.
- Route-aware distance or transit ETA. Displayed proximity is straight-line distance, not distance along a rail, road, or bus route.
- Automatic service restoration after device reboot, notification actions, battery exemption diagnostics, and a full device permission health dashboard.
- Physical-device reliability, battery, and offline acceptance testing. Background execution varies by Android version and device manufacturer.
- Production release signing. Release signing is disabled until a private keystore is configured.

## Requirements

- Flutter SDK 3.41 or newer
- Android SDK 36
- JDK 17

## Run locally

```powershell
flutter pub get
flutter analyze
flutter run
```

Build the Android debug app:

```powershell
cd android
./gradlew.bat assembleDebug
```

Background location needs precise location permission and enabled Location Services. Android notification permission is requested at journey start. Battery optimization and manufacturer-specific restrictions can still interrupt tracking. Force-stop, device shutdown, exhausted battery, unavailable GPS, or revoked permissions stop monitoring. Do not treat this app as a guaranteed safety device.

To sign a release build, supply these Gradle properties from a private user-level Gradle properties file or CI secrets: `RELEASE_STORE_FILE`, `RELEASE_STORE_PASSWORD`, `RELEASE_KEY_ALIAS`, and `RELEASE_KEY_PASSWORD`. Do not commit the keystore or passwords.

## Privacy and map data

There is no account, backend, analytics, or cloud location tracking. GPS fixes, saved destinations, journey history, and cached geocoder responses remain on device. Search terms are sent to Photon by Komoot; map-tap reverse geocoding sends the selected coordinates. Precise device GPS is not sent as a search bias. Photon’s public endpoint is a demo service with fair-use throttling, no availability guarantee, and possible service changes; see its [API and provider terms](https://github.com/komoot/photon#demo-server). Plan a move to a self-hosted or SLA-backed OSM geocoder if production traffic or uptime requirements exceed the public demo’s fair-use model.

Online map views load OpenFreeMap-hosted vector tiles based on OpenStreetMap data. OpenFreeMap’s public instance is free without API keys or request quotas, but it has no SLA and may be discontinued; see its [terms](https://openfreemap.org/tos/).

The product requirements and planned architecture are documented in [WakeMeThere_PRD_and_Technical_Architecture.md](WakeMeThere_PRD_and_Technical_Architecture.md).

# WakeMeThere --- Product Requirements & Technical Architecture

**Document type:** Product Requirements Document (PRD) + Technical
Architecture\
**Project:** WakeMeThere\
**Platform:** Android (Flutter)\
**Status:** Initial specification finalized; implementation-ready
baseline\
**Primary objective:** Help passengers avoid missing their bus, train,
or other travel stop by monitoring their location and issuing
configurable alerts before they reach their destination.

------------------------------------------------------------------------

## 1. Product Overview

WakeMeThere is an offline-first Android travel companion. A passenger
selects a destination, starts a journey, and can then lock their phone
or sleep while the app monitors their location. The app provides
progressively urgent alerts as the passenger approaches the selected
destination.

### Core promise

> Set your destination. Start tracking. Sleep with greater confidence.
> WakeMeThere alerts you before you arrive.

WakeMeThere is not a general-purpose replacement for Google Maps. Its
primary purpose is reliable destination-proximity monitoring and wake-up
alerts during travel.

### Target users and scenarios

-   Bus passengers who do not know the route or their drop-off stop
    well.
-   Train passengers who want an alert before their station.
-   Passengers in taxis, cars, or other vehicles.
-   Travellers who want to monitor an arbitrary map location, not only a
    named landmark.

### Product principles

1.  **Offline-first:** An active journey must not require an internet
    connection.
2.  **Local-first privacy:** No account, backend, cloud tracking, or
    mandatory data upload.
3.  **Reliability over visual complexity:** Background tracking and
    alerts are more important than decorative features.
4.  **Transparent limitations:** GPS, Android power management, device
    shutdown, force-stop, and hardware limitations mean the app must not
    promise a 100% guaranteed wake-up.
5.  **Modular implementation:** Separate UI, domain logic, data access,
    and native Android services.

------------------------------------------------------------------------

## 2. Finalized Product Decisions

  Area                                  Decision
  ------------------------------------- -------------------------------------------
  Platform                              Android first
  UI framework                          Flutter / Dart
  Native platform layer                 Kotlin
  Destination selection                 Both place search and map tap
  Maps                                  Online maps and downloadable offline maps
  Active journey internet requirement   None
  GPS                                   Device GPS; must work without mobile data
  Wake-up behavior                      Fully customizable
  Local persistence                     Yes
  User account                          Not required
  Backend/server                        Not required
  Advertising                           None planned
  Data model                            Store journey and preferences locally

### Important distinction: GPS vs maps vs place search

-   GPS positioning does not require internet, although signal quality
    and availability vary.
-   Online map tiles and online geocoding/search require internet.
-   Offline maps require map data to have been downloaded or installed
    in advance.
-   Offline place search requires a local searchable place dataset or
    another explicitly implemented offline search mechanism.
-   Do not claim the entire map/search experience works offline until
    offline map packages and local place search have actually been
    implemented and tested.

------------------------------------------------------------------------

## 3. Functional Requirements

### 3.1 Destination selection

The user must be able to:

1.  Search for a place by name when online.
2.  Select a search result as the destination.
3.  Tap any point on the map to set an arbitrary destination.
4.  View and adjust the selected destination marker.
5.  See the destination name, coordinates, and location on the map.
6.  Save frequently used destinations locally.
7.  Select a previously saved destination.
8.  Use an offline destination workflow for downloaded/local map data,
    once implemented.

Destination search and map selection are equally important entry points.

### 3.2 Journey setup

Before starting a journey, the user should be able to:

-   Review the destination.
-   Configure alert thresholds.
-   Configure sound, voice, and vibration.
-   Configure repeat behavior.
-   Start or cancel the journey.
-   See a clear indication that tracking is active.
-   Understand the permissions and battery settings required for
    background operation.

The app should prevent accidental journey activation and make the active
state obvious.

### 3.3 Active journey monitoring

During an active journey, WakeMeThere should:

-   Obtain location updates while the screen is locked.
-   Calculate distance from the current location to the destination.
-   Track GPS accuracy and timestamp/freshness.
-   Estimate whether the passenger is approaching or moving away.
-   Show current location, destination, remaining distance, and journey
    state in the UI when available.
-   Continue working without internet.
-   Display a persistent Android foreground-service notification while
    tracking.
-   Persist enough state to recover the journey after an eligible
    process restart.
-   Handle temporarily unavailable or inaccurate GPS without making
    unsafe assumptions.

### 3.4 Alerts and wake-up behavior

All alert behavior should be configurable.

Configuration options should include:

-   Early-warning distance.
-   Main wake-up distance.
-   Critical-proximity distance.
-   Sound selection.
-   Alarm volume behavior, subject to Android audio policies.
-   Voice announcements on/off.
-   Vibration on/off.
-   Repeat interval.
-   Repeat until acknowledged.
-   Announcement frequency or alert stages.
-   Optional quieter early warnings and stronger final alerts.

Example default profile (not a hard-coded requirement):

  Stage             Example distance Behavior
  --------------- ------------------ ------------------------------
  Early warning                 5 km Voice or notification
  Wake-up                       2 km Loud alarm, voice, vibration
  Critical                     500 m More urgent repeated alert

These are example defaults only. Users must be able to customize them.

The alarm should continue according to the configured repeat policy
until the user acknowledges it or the journey is ended. Acknowledge,
snooze (if implemented), cancel, and journey-complete actions must be
explicit.

The app must not rely on a Flutter timer or a scheduled arrival-time
alarm as its primary proximity trigger. The active location-monitoring
engine should evaluate GPS updates and trigger proximity alerts.

### 3.5 Journey completion

The app should support:

-   Manual completion.
-   Manual cancellation.
-   Destination reached state.
-   Clear indication that tracking and alerts have stopped.
-   A locally stored journey summary if journey history is enabled.

Do not automatically declare arrival solely because one noisy GPS point
falls inside the destination radius. Arrival confirmation needs
filtering and/or multiple valid readings.

### 3.6 Offline functionality

The target offline experience includes:

-   GPS location tracking.
-   Active journey monitoring.
-   Distance calculations.
-   Alert evaluation and delivery.
-   Locally saved destinations.
-   Locally saved settings.
-   Previously downloaded offline map regions.
-   Local destination selection on downloaded map data.
-   Offline place search, if a local place database is provided.

Offline map downloading may require internet before travel. The app must
communicate which regions are available offline.

### 3.7 Local privacy and storage

-   No account or sign-in.
-   No mandatory backend.
-   No cloud tracking.
-   No analytics or telemetry unless separately proposed and explicitly
    approved.
-   Store settings, saved destinations, and journey state locally.
-   Do not transmit precise location to a third party as part of normal
    operation.
-   Clearly document any external map tile, geocoding, or search
    provider usage and its privacy implications.
-   Provide a way to clear saved destinations and local journey history.

------------------------------------------------------------------------

## 4. Non-Functional Requirements

### Reliability

-   Background tracking must not depend on the Flutter UI remaining
    open.
-   The native Android service is responsible for active background
    location updates.
-   GPS errors and stale readings must be handled conservatively.
-   Alert thresholds must not repeatedly fire because of GPS jitter.
-   The app must clearly show when location is unavailable or
    unreliable.
-   The system should recover from process recreation where Android
    permits it.
-   The app must not claim guaranteed operation after force-stop, device
    shutdown, battery exhaustion, or revoked permissions.

### Performance and battery

-   Use an appropriate location update interval and accuracy/battery
    trade-off.
-   Avoid unnecessary high-frequency UI rebuilds.
-   Avoid excessive database writes.
-   Use foreground-service notification and Android-approved background
    location behavior.
-   Measure real battery use during long journeys and tune update
    frequency.

### Usability

-   Starting a journey should require few steps.
-   Active tracking state must be immediately understandable.
-   Remaining distance and alert configuration must be readable.
-   Critical controls must be accessible without navigating through many
    screens.
-   Provide clear permission explanations and recovery guidance.

### Testability

-   Geographic calculations must be unit tested.
-   Alert rules must be unit tested.
-   Journey state transitions must be unit tested.
-   Native service behavior must be tested on physical Android devices.
-   Offline behavior must be tested with network disabled.

------------------------------------------------------------------------

## 5. Proposed Technology Stack

  ------------------------------------------------------------------------
  Layer                   Technology               Responsibility
  ----------------------- ------------------------ -----------------------
  UI                      Flutter / Dart           Screens, map UI,
                                                   settings, journey
                                                   status

  State management        Riverpod                 Application state and
                          (`flutter_riverpod`)     dependency management

  Map rendering           `flutter_map`            Interactive map display

  Coordinates             `latlong2`               Geographic coordinate
                                                   types and calculations

  Foreground location /   `geolocator` where       Flutter-side location
  permissions             appropriate              and permission
                                                   integration

  Local database          SQLite via `sqflite`     Saved destinations,
                                                   journey state, history

  Preferences             `shared_preferences`     Simple user settings

  Permission helper       `permission_handler`     Permission workflow
                          where appropriate

  Native Android          Kotlin                   Foreground location
                                                   service, notifications,
                                                   alarm/audio/vibration

  Map data                OpenStreetMap-derived    Online/offline map
                          data or another properly content
                          licensed source

  Offline map storage     MBTiles candidate        Locally stored map
                                                   tiles

  Testing                 Flutter test + Android   Logic and device
                          instrumentation/manual   verification
                          tests
  ------------------------------------------------------------------------

### Dependency policy

Do not blindly add packages just because they appear in this document.
Before choosing a package:

1.  Verify current maintenance and compatibility.
2.  Verify its Android version support.
3.  Check its license.
4.  Check whether it actually supports the required offline/background
    behavior.
5.  Prefer a small number of well-maintained dependencies.
6.  Record the selected version constraints in `pubspec.yaml`.

`offline_tiles` may be evaluated as an MBTiles/offline-map candidate,
but it is not a mandatory dependency until compatibility and maintenance
have been verified.

### Map data and licensing

OpenStreetMap data is available under the ODbL, but the public
OpenStreetMap standard tile servers must not be treated as an
unrestricted bulk-download or offline tile service.

Select a provider whose terms explicitly permit the intended tile usage
and offline downloads, or generate/obtain MBTiles through a compliant
workflow. Include required attribution and comply with provider rate
limits, caching, and licensing terms.

Do not scrape public tile servers or silently download large geographic
areas from services that prohibit it.

------------------------------------------------------------------------

## 6. System Architecture

Use a layered architecture with clear boundaries.

### 6.1 Presentation layer --- Flutter

Responsibilities:

-   Home/dashboard.
-   Map display.
-   Destination search.
-   Destination selection and confirmation.
-   Journey setup.
-   Active journey screen.
-   Alert settings.
-   Saved destinations.
-   Permission onboarding.
-   Error and GPS status display.

### 6.2 Application/domain layer --- Dart

Responsibilities:

-   Journey orchestration.
-   Destination model and validation.
-   Geographic distance calculation.
-   GPS sample validation.
-   Proximity and alert rules.
-   Journey state machine.
-   Configuration validation.
-   Testable business rules independent of Flutter widgets.

Suggested domain services:

-   `JourneyManager`
-   `DestinationManager`
-   `DistanceEngine`
-   `LocationFilter`
-   `AlertRulesEngine`
-   `JourneyStateMachine`

### 6.3 Infrastructure/data layer

Responsibilities:

-   GPS repository/adapters.
-   Map repository.
-   Place-search repository.
-   Offline map repository.
-   SQLite repositories.
-   Preferences repository.
-   Flutter-to-native platform bridge.
-   Serialization and persistence.

### 6.4 Native Android layer --- Kotlin

Responsibilities:

-   Foreground location service.
-   Location update registration and handling.
-   Persistent tracking notification.
-   Native alarm/audio behavior.
-   Text-to-speech announcements.
-   Vibration.
-   Notification actions.
-   Native-to-Flutter event communication.
-   Restoration of eligible persisted journey state.
-   Android lifecycle and permission handling.

### 6.5 Key architectural rule

Flutter owns the application experience and domain configuration. Kotlin
owns the Android execution mechanisms required to keep active tracking
and alerts running when the UI is not visible.

Do not implement the critical background journey monitor as a Dart timer
that assumes the Flutter process remains active.

------------------------------------------------------------------------

## 7. Proposed Architecture Diagram

``` text
                 WakeMeThere ANDROID APP
                          |
             +------------+------------+
             |                         |
       Flutter UI                 Riverpod State
             |                         |
             +------------+------------+
                          |
                 Application / Domain
                          |
       +------------------+------------------+
       |                  |                  |
 Journey Manager   Distance Engine    Alert Rules Engine
       |                  |                  |
       +------------------+------------------+
                          |
                  Data / Infrastructure
                          |
       +------------------+------------------+
       |                  |                  |
  GPS Adapter       Local Database      Map Repository
       |                  |                  |
       +------------------+------------------+
                          |
                   Platform Channel
                          |
                  Native Android Kotlin
                          |
       +------------------+------------------+
       |                  |                  |
 LocationService     Alarm / Audio      Notification
       |                  |                  |
       +------------------+------------------+
                          |
                      Android OS
```

------------------------------------------------------------------------

## 8. Flutter Project Structure

Use feature-oriented organization. Do not put the entire application in
`main.dart`.

``` text
WakeMeThere/
|
|-- android/
|   `-- app/src/main/kotlin/<package-path>/
|       `-- WakeMeThere/
|           |-- MainActivity.kt
|           |-- tracking/
|           |   |-- LocationService.kt
|           |   |-- TrackingNotification.kt
|           |   `-- TrackingReceiver.kt
|           |-- alarms/
|           |   |-- AlarmManager.kt
|           |   |-- AlarmReceiver.kt
|           |   `-- AlarmAudio.kt
|           `-- bridge/
|               `-- WakeMeThereChannel.kt
|
|-- lib/
|   |-- main.dart
|   |
|   |-- app/
|   |   |-- app.dart
|   |   |-- router.dart
|   |   `-- theme.dart
|   |
|   |-- core/
|   |   |-- constants/
|   |   |-- errors/
|   |   |-- utils/
|   |   `-- services/
|   |
|   |-- features/
|   |   |-- home/
|   |   |   |-- presentation/
|   |   |   `-- providers/
|   |   |
|   |   |-- map/
|   |   |   |-- presentation/
|   |   |   |-- domain/
|   |   |   `-- data/
|   |   |
|   |   |-- destination/
|   |   |   |-- presentation/
|   |   |   |-- domain/
|   |   |   `-- data/
|   |   |
|   |   |-- journey/
|   |   |   |-- presentation/
|   |   |   |-- domain/
|   |   |   |-- data/
|   |   |   `-- providers/
|   |   |
|   |   |-- alerts/
|   |   |   |-- domain/
|   |   |   `-- presentation/
|   |   |
|   |   `-- settings/
|   |       |-- presentation/
|   |       `-- data/
|   |
|   `-- platform/
|       |-- tracking_channel.dart
|       `-- alarm_channel.dart
|
|-- test/
|   |-- distance_engine_test.dart
|   |-- alert_rules_test.dart
|   `-- journey_manager_test.dart
|
`-- pubspec.yaml
```

This is a proposed structure. The agent may add files as implementation
requires, but should preserve separation of concerns and avoid
unnecessary abstraction.

------------------------------------------------------------------------

## 9. Journey State Machine

Use explicit states rather than unrelated boolean flags.

Proposed states:

1.  `idle` --- no active journey.
2.  `preparing` --- permissions/configuration being checked.
3.  `tracking` --- valid journey monitoring is active.
4.  `approaching` --- an early-warning threshold has been crossed.
5.  `wakeUpAlert` --- the configured wake-up threshold has been crossed.
6.  `criticalAlert` --- critical proximity threshold has been crossed.
7.  `gpsUnavailable` --- location is temporarily unavailable or too
    inaccurate.
8.  `destinationReached` --- arrival has been confirmed.
9.  `completed` --- journey has ended.
10. `cancelled` --- user cancelled the journey.

The implementation may represent temporary GPS degradation as a
status/substate if that produces a cleaner state model.

### State transition expectations

-   `idle` -\> `preparing` when the user starts a journey.
-   `preparing` -\> `tracking` after required permissions and service
    startup succeed.
-   `tracking` -\> `approaching` after a validated early-warning
    threshold crossing.
-   `approaching` -\> `wakeUpAlert` after a validated wake-up threshold
    crossing.
-   `wakeUpAlert` -\> `criticalAlert` after a validated critical
    threshold crossing.
-   Active states -\> `gpsUnavailable` or a GPS-degraded substate when
    readings become stale/unreliable.
-   GPS recovery returns to the appropriate active state without
    resetting already-fired alert stages.
-   Active states -\> `destinationReached` only after a defensible
    arrival confirmation.
-   Active states -\> `completed` or `cancelled` through explicit user
    action as appropriate.

Do not reset alert stages simply because GPS distance fluctuates above
and below a threshold.

------------------------------------------------------------------------

## 10. Geographic Distance and GPS Reliability

### 10.1 Haversine calculation

Use Haversine distance for the initial straight-line distance between
the current GPS coordinate and destination coordinate.

``` text
a = sin²(Δφ / 2)
    + cos(φ1) * cos(φ2) * sin²(Δλ / 2)

d = 2 * R * atan2(√a, √(1-a))
```

Where:

-   `R` is approximately 6,371,000 metres.
-   `φ1`, `φ2` are latitudes in radians.
-   `λ1`, `λ2` are longitudes in radians.
-   `d` is distance in metres.

Use a tested implementation and unit tests. Do not duplicate geographic
math in UI widgets.

### 10.2 GPS sample validation

Each sample should consider:

-   Latitude and longitude validity.
-   Horizontal accuracy.
-   Timestamp and sample age.
-   Speed, if available and valid.
-   Whether the sample is plausible relative to previous samples.
-   Whether the location provider reports an error.

Reject or mark unreliable stale and unacceptable samples. Thresholds for
acceptable accuracy and freshness should be configurable constants and
tuned through testing, not scattered magic numbers.

### 10.3 Proximity evaluation

The initial algorithm should:

1.  Receive a location sample.
2.  Validate sample freshness and accuracy.
3.  Reject invalid or implausible samples.
4.  Calculate straight-line distance to destination.
5.  Maintain a short rolling history of valid readings.
6.  Evaluate whether the passenger is approaching, stationary, or moving
    away.
7.  Confirm threshold crossings using multiple valid readings or another
    defensible filter.
8.  Trigger each configured alert stage once per journey.
9.  Continue tracking until completion or cancellation.

Implement hysteresis/debouncing so GPS jitter does not repeatedly
trigger alerts.

### 10.4 Arrival detection

Do not declare arrival from one GPS point alone.

Use a configurable arrival radius and multiple valid readings, with
accuracy-aware logic. Provide manual completion as a fallback.

### 10.5 Route-aware distance --- later enhancement

Straight-line distance is not road distance. A destination may be
geographically close but separated by a river, highway, or inaccessible
road layout.

The MVP can use filtered GPS proximity, but the UI and documentation
must describe it as approximate straight-line proximity. A later phase
may add route-aware distance based on locally available road data or a
suitable routing engine.

------------------------------------------------------------------------

## 11. Android Background Execution and Permissions

This is a critical subsystem and must be implemented carefully for
modern Android.

### 11.1 Foreground location service

Implement a native Kotlin foreground service for active journey
tracking.

Expected behavior:

-   Start it from a user-visible action while the app is open.
-   Show an ongoing notification indicating that WakeMeThere is tracking a
    journey.
-   Register location updates using Android location APIs.
-   Evaluate proximity even while the Flutter screen is locked or not
    visible.
-   Stop updates and remove the ongoing notification when the journey
    ends.
-   Communicate status and events to Flutter when Flutter is available.
-   Keep the service independent of Flutter widget lifecycle.

### 11.2 Permissions

Implement progressive permission requests and explain each permission to
the user.

Review and correctly handle, based on the target SDK and Android
version:

-   Fine location.
-   Coarse location.
-   Background location, only if genuinely required by the chosen
    execution design and requested in the correct sequence.
-   Foreground service permission.
-   Foreground service location permission/type.
-   Notifications.
-   Any exact-alarm permission only if a genuine exact time-based alarm
    feature needs it.

Do not request permissions that are not needed.

The Android manifest and runtime permission flow must comply with the
app's target SDK and Android version requirements. In particular, check
Android 14+ foreground-service type and permission requirements.

### 11.3 Process death and force-stop

Persist the active journey configuration and last known state locally.

Implement recovery where Android permits, and explain limitations
accurately.

Important distinctions:

-   Process recreation is not the same as force-stop.
-   Android may prevent automatic restart after force-stop.
-   A device that is powered off cannot track GPS or sound an alarm.
-   Battery exhaustion, revoked permissions, severe OEM battery
    restrictions, and unavailable GPS can interrupt operation.

Never claim that tracking is guaranteed under all these conditions.

### 11.4 Alarm behavior

Proximity alarms should be driven by the active location service.

Use Android alarm scheduling only for genuine time-based functions, not
as a substitute for GPS proximity monitoring.

Implement audio, text-to-speech, vibration, notification actions, and
repeat behavior with Android policy and device restrictions in mind. Do
not assume an app can bypass Do Not Disturb, user volume settings, or
full-screen notification restrictions.

------------------------------------------------------------------------

## 12. Platform Channel Contract

Define a versioned and documented interface between Flutter and Kotlin.

Suggested operations (names are proposals; implement consistently):

### Flutter -\> Kotlin

-   `startJourney(configuration)`
-   `updateAlertConfiguration(configuration)`
-   `stopJourney()`
-   `acknowledgeAlert()`
-   `getTrackingStatus()`
-   `requestRequiredPermissions()` or a clearly separated permission
    workflow.

### Kotlin -\> Flutter events

-   `trackingStarted`
-   `trackingStopped`
-   `locationUpdated`
-   `distanceUpdated`
-   `approaching`
-   `wakeUpAlert`
-   `criticalAlert`
-   `gpsUnavailable`
-   `gpsRecovered`
-   `destinationReached`
-   `trackingError`

### Data contract

Use structured, versioned payloads. At minimum, a location update should
carry:

-   Latitude.
-   Longitude.
-   Accuracy in metres.
-   Timestamp.
-   Speed when available.
-   Distance to destination when calculated.
-   Tracking state.

A journey configuration should carry:

-   Journey ID.
-   Destination name.
-   Destination latitude and longitude.
-   Alert thresholds in metres.
-   Sound/voice/vibration preferences.
-   Repeat interval.
-   Repeat-until-acknowledged setting.
-   Arrival radius and relevant filtering settings.

Validate all data on both sides. Do not trust malformed platform-channel
payloads.

------------------------------------------------------------------------

## 13. Local Data Models

Suggested initial models:

### Destination

``` text
Destination
- id
- name
- latitude
- longitude
- source (search, map_tap, saved)
- createdAt
```

### AlertConfiguration

``` text
AlertConfiguration
- earlyWarningDistanceMeters
- wakeUpDistanceMeters
- criticalDistanceMeters
- arrivalRadiusMeters
- soundEnabled
- soundId
- voiceEnabled
- vibrationEnabled
- repeatEnabled
- repeatIntervalSeconds
- repeatUntilAcknowledged
```

### Journey

``` text
Journey
- id
- destinationId
- state
- startedAt
- completedAt
- lastLatitude
- lastLongitude
- lastLocationTimestamp
- lastKnownDistanceMeters
- firedAlertStages
- alertConfigurationSnapshot
```

Store a snapshot of the alert configuration with the journey so changing
global settings does not unexpectedly alter an active journey.

Use SQLite for structured records and preferences storage for simple
application settings. Choose a migration strategy before the database
schema becomes complex.

------------------------------------------------------------------------

## 14. UI Screens

The initial application should include these screens:

### 14.1 Home

-   WakeMeThere branding.
-   Destination search entry point.
-   Select-on-map entry point.
-   Saved destinations.
-   Start journey workflow.
-   Current active journey card, if one exists.

### 14.2 Map / destination selection

-   Map.
-   Current location marker.
-   Destination marker.
-   Search field and results when online.
-   Tap-to-select destination.
-   Confirm destination action.
-   Offline map availability indicator.

### 14.3 Journey setup

-   Destination summary.
-   Alert distance configuration.
-   Sound, voice, vibration controls.
-   Repeat interval.
-   Start journey action.
-   Permission/battery readiness information.

### 14.4 Active journey

-   Clear active-tracking indicator.
-   Destination name.
-   Remaining approximate distance.
-   Current GPS status and accuracy.
-   Current alert stage.
-   Map/route context when available.
-   Acknowledge alarm action.
-   End/cancel journey action.

### 14.5 Settings

-   Default alert configuration.
-   Sound selection.
-   Voice settings.
-   Vibration settings.
-   Map/offline map management.
-   Saved destinations.
-   Privacy and local-data controls.
-   Permissions and battery troubleshooting.

### UI design direction

Use a clean, modern navigation interface. Prioritize legibility, simple
controls, clear status indicators, and strong contrast. Avoid clutter
and unnecessary animations. The active journey screen must remain
understandable at a glance.

------------------------------------------------------------------------

## 15. Development Roadmap

Build incrementally. Each phase must produce a runnable, testable result
before moving forward.

### Phase 1 --- Project foundation

-   Create Flutter Android project.
-   Verify Flutter/Android toolchain.
-   Set up folder structure.
-   Add Riverpod.
-   Establish theme and routing.
-   Create basic home and settings screens.
-   Confirm app runs on a physical Android device or emulator.

**Deliverable:** Clean runnable Flutter application.

### Phase 2 --- Map and destination selection

-   Render an online map using a permitted tile source.
-   Show current location with permission.
-   Tap map to select destination.
-   Add destination marker and confirmation.
-   Add online place search through a selected provider.
-   Save destinations locally.

**Deliverable:** User can search for or tap a destination and save it.

### Phase 3 --- Geographic engine

-   Implement coordinate/destination models.
-   Implement Haversine distance.
-   Implement GPS sample validation.
-   Implement distance history/filtering.
-   Implement approach/moving-away evaluation.
-   Implement threshold-crossing and hysteresis logic.
-   Add unit tests.

**Deliverable:** Reliable, independently testable proximity engine using
simulated location samples.

### Phase 4 --- Native Android tracking

-   Implement Kotlin foreground location service.
-   Add ongoing notification.
-   Implement Flutter/Kotlin platform channel.
-   Start and stop service from user actions.
-   Receive location updates while screen is locked.
-   Persist journey configuration.
-   Handle permission denial and GPS unavailable cases.

**Deliverable:** Active tracking continues with screen locked on
supported devices.

### Phase 5 --- Alert engine

-   Implement configurable alert stages.
-   Implement native alarm audio.
-   Implement text-to-speech.
-   Implement vibration.
-   Implement repeat interval and acknowledgement.
-   Implement critical proximity alert.
-   Prevent duplicate alerts.

**Deliverable:** End-to-end proximity-triggered wake-up alert.

### Phase 6 --- Local persistence and recovery

-   Complete SQLite schema.
-   Save settings and destinations.
-   Save active journey state.
-   Implement eligible service/process recovery.
-   Implement journey completion and history.
-   Add clear-data functionality.

**Deliverable:** Journey configuration survives ordinary app restarts
where supported.

### Phase 7 --- Offline maps and offline search

-   Choose compliant offline map data source.
-   Implement MBTiles or another suitable local tile format.
-   Implement region download/import and storage management.
-   Display downloaded maps without internet.
-   Implement local place search using a suitable offline dataset.
-   Show which regions and search data are available offline.
-   Verify licensing and attribution.

**Deliverable:** Map viewing and destination selection in downloaded
regions without internet.

### Phase 8 --- Reliability and release testing

Test:

-   Screen locked for extended periods.
-   App moved to background.
-   Flutter activity recreated.
-   Process killed by Android where testable.
-   Force-stop limitation messaging.
-   GPS disabled.
-   GPS temporarily unavailable.
-   Poor GPS accuracy.
-   Internet disabled before and during journey.
-   Vehicle stationary for several minutes.
-   Vehicle moving away from destination.
-   GPS jitter around alert thresholds.
-   Alarm acknowledgement.
-   Notification permission denied.
-   Location permission denied/revoked.
-   Battery saver and OEM-specific battery restrictions.
-   Device reboot.
-   Long-duration battery consumption.
-   Different Android versions and manufacturers.

**Deliverable:** Tested release candidate with documented limitations.

------------------------------------------------------------------------

## 16. Testing Requirements

### Unit tests

At minimum:

-   Haversine known-coordinate cases.
-   Invalid coordinates.
-   Zero-distance case.
-   GPS accuracy rejection.
-   Stale sample rejection.
-   Distance trend evaluation.
-   Threshold crossing.
-   Hysteresis/debounce.
-   Duplicate alert prevention.
-   Alert-stage ordering.
-   Journey state transitions.
-   Arrival confirmation.

### Integration tests

-   Flutter-to-Kotlin start/stop.
-   Native service location event delivery.
-   Persisted journey configuration.
-   Alarm acknowledgement.
-   Notification actions.
-   Database migrations.

### Physical-device tests

Background location and alarm reliability must be tested on actual
Android hardware. Emulator tests alone are insufficient.

Use simulated GPS routes for repeatable logic tests, then validate real
travel behavior on physical devices.

------------------------------------------------------------------------

## 17. MVP Acceptance Criteria

The first complete MVP is acceptable when all of the following work:

1.  User can open WakeMeThere.
2.  User can select a destination by map tap.
3.  User can select a destination through search when online.
4.  User can configure at least early-warning and wake-up distances.
5.  User can start a journey.
6.  The app starts a native Android foreground location service.
7.  Tracking continues with the screen locked on a supported device.
8.  Distance is calculated and displayed.
9.  GPS noise does not repeatedly trigger the same alert.
10. The wake-up alert triggers at the configured proximity threshold.
11. Sound, vibration, and voice can be configured.
12. Alarm can be acknowledged.
13. Active tracking works without internet, provided GPS and required
    permissions are available.
14. User can end the journey.
15. Journey settings and destination are stored locally.
16. App clearly communicates GPS/permission/service failures.
17. No backend or account is required for core functionality.

Offline map downloads and offline place search are important product
requirements, but may be delivered in the later offline-maps phase
rather than blocking the first functional MVP.

------------------------------------------------------------------------

## 18. Instructions to the AI Coding Agent

You are implementing WakeMeThere, an Android-first Flutter application
based on this specification.

### Required working style

1.  Read this entire document before coding.
2.  Inspect the existing repository and development environment before
    modifying files.
3.  Do not assume that a file, package, permission, or feature already
    exists.
4.  Work in small, verifiable milestones.
5.  Before each milestone, state the files to be created or modified and
    the reason.
6.  Provide complete file contents when creating or replacing files.
7.  Do not leave placeholder methods for functionality claimed to be
    complete.
8.  Do not silently omit error handling.
9.  Do not put all code into `main.dart`.
10. Keep Flutter UI, domain logic, data access, and Kotlin platform code
    separated.
11. Write unit tests for geographic calculations, alert rules, and
    journey state transitions.
12. Run formatting, static analysis, and relevant tests after each
    milestone.
13. Fix build errors before proceeding.
14. Document commands required to run and test the application.
15. Do not introduce a backend, cloud service, authentication, or
    analytics without explicit approval.
16. Do not use an online-only map/search implementation and call it
    fully offline.
17. Verify current package documentation and Android platform
    requirements instead of relying on outdated assumptions.
18. Preserve required map-data licensing and attribution.
19. Never claim background reliability or offline functionality until it
    has been tested.
20. Ask for clarification only when a genuinely necessary product
    decision is missing. Otherwise, choose a sensible implementation,
    document the assumption, and proceed.

### Implementation order

Follow the roadmap in this document. Start with **Phase 1 --- Project
Foundation**.

At the end of every phase, report:

-   What was implemented.
-   Files created or changed.
-   Dependencies added and why.
-   Commands executed.
-   Build/test results.
-   Known limitations.
-   Exact next milestone.

### Do not do these things

-   Do not build a fake demo that only works while the screen is open.
-   Do not use a Dart timer as the core background tracking mechanism.
-   Do not trigger wake-up solely from estimated arrival time.
-   Do not trust a single inaccurate GPS reading.
-   Do not repeatedly trigger alerts due to GPS fluctuations.
-   Do not claim the app can overcome Android force-stop or a
    powered-off device.
-   Do not scrape public map tile servers.
-   Do not store or transmit precise location unnecessarily.
-   Do not generate a huge amount of code before verifying the
    foundation.

------------------------------------------------------------------------

## 19. Initial Setup Commands

On Windows PowerShell:

``` powershell
flutter --version
flutter doctor -v
```

Create the project:

``` powershell
cd D:\
flutter create --platforms=android --org com.WakeMeThere WakeMeThere
cd WakeMeThere
```

Add the initial candidate dependencies:

``` powershell
flutter pub add flutter_riverpod
flutter pub add flutter_map
flutter pub add latlong2
flutter pub add geolocator
flutter pub add sqflite
flutter pub add shared_preferences
flutter pub add permission_handler
```

Verify devices:

``` powershell
flutter devices
```

Run:

``` powershell
flutter run
```

These commands are the initial setup baseline. Verify package
compatibility and Android configuration before implementing production
functionality.

------------------------------------------------------------------------

## 20. Immediate First Task for the Agent

Begin with Phase 1 only.

1.  Inspect the machine/repository state available to you.
2.  Verify Flutter and Android tooling.
3.  Create or validate the `WakeMeThere` Flutter project.
4.  Establish the proposed feature-oriented folder structure.
5.  Configure Riverpod.
6.  Create a clean app theme and basic navigation.
7.  Create a minimal home screen and settings screen.
8.  Ensure the app builds and runs.
9.  Add a short `README.md` with setup and run instructions.
10. Report all changes and test results.

Do not implement GPS tracking, native alarms, or offline maps during
this first task. Those belong to later milestones and should be built on
the verified foundation.

------------------------------------------------------------------------
• run flutter analyze right after generating the Dart layer, and ./gradlew assembleDebug right after generating the Kotlin layer, so it catches errors while the context is still fresh.



**End of WakeMeThere specification.**

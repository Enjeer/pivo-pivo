# Pivo-Pivo

Flutter MVP for finding places and planning an evening.

## Run locally

Requires Flutter 3.47.8 or a compatible version with Dart 3.13.7 or newer.

```shell
flutter pub get
flutter run -d chrome
```

The app currently uses a clearly labelled synthetic demo catalogue around Minsk.
It has map browsing, name/category filtering, place details, an ordered evening
plan, manually entered expense estimates, favorites, and private notes stored
on the device.

Map tiles are loaded from OpenStreetMap and require an internet connection.
Attribution is shown in the app. The demo places are not real businesses; prices
and travel costs are not supplied by an external service. There is no live
catalogue, geolocation, route calculation, account, menu-photo upload, OCR,
contribution points, or rewards shop yet.

## Checks

```shell
flutter analyze
flutter test
flutter build web
```

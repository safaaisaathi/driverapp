# driverapp

Driver app for the Citizen-Centric Garbage Collection and Sanitation Monitoring System (PS000051, DDO Panchmahal Godhra).

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Demo data (emulator and explicit live seed)

The app has no project default in its seed tools. A bare seed run exits, so it
cannot reach production by accident.

```sh
npm --prefix scripts install
npm --prefix scripts run seed:emulator   # local Firestore emulator on :8080

# Explicit live seed. The project id is required.
FIREBASE_PROJECT=<project-id> npm --prefix scripts run seed
```

`emulator/seed-data.json` holds the reference data: wards, routes, vans,
drivers, staff and notices. Writes are idempotent (`merge: true`). The tools
refuse a project id that contains `prod`.


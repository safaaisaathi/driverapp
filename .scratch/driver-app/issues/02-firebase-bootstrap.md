# 02: Firebase bootstrap & anonymous session

**What to build:** The app boots with Firebase initialized and immediately signs in anonymously (grilled decision), so any pre-PIN screen can read public data (`vans` id/plateNo, `wards`, `routes`). FCM initialized; the app subscribes to topic `all` at first launch per 0.6.6. Emulator configuration so all local development runs against the Firebase Emulator Suite (0.10), with a clean switch to the shared project for integration checkpoints. Secret files (`google-services.json`) gitignored and documented as privately shared (0.10).

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] App launches and holds an anonymous session; a read of `vans` fields (`id`, `plateNo`, `routeId`, `status`, `lastLocation`) succeeds via repository against the emulator's seeded data
- [ ] Subscribes to FCM topic `all` on first launch (idempotent across restarts)
- [ ] Emulator init switchable by configuration; no shared-project keys in code or repo
- [ ] Permission-independent: no feature requires this ticket beyond boot; `flutter analyze` clean

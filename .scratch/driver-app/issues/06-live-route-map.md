# 06: D2 Live Route — map shell

**What to build:** The driver's home screen after shift start: full-screen map with the van marker (own `vans` doc stream) and the route's ward markers in `routes.wardIds` order with done wards ticked, plus the ordered ward list beneath/overlaid with the first undone ward highlighted ("next"). State management via Riverpod; listeners only while visible, cancelled on dispose (0.11). App-bar slot for Notices (badge placeholder, wired by the Notices ticket) and the small End-of-trip card placeholder. Every state covered: loading, empty (route empty), error, offline.

**Blocked by:** 05 (tracking engine — a live van position demands a running shift).

**Status:** ready-for-agent

- [ ] Open shift shows the van marker at the latest `lastLocation`; stale fix (older than `staleLocationSec`) renders per contract semantics
- [ ] Ward markers ordered; done wards visually ticked from `trips.wardsDone`; next ward highlighted
- [ ] App is usable one-handed; ≥56 dp targets; all strings through l10n
- [ ] Widget tests via fake repositories (seam 1): marker from van stream, tick states, next-ward highlight, loading/empty/error/offline

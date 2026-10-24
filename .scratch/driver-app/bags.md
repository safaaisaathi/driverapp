# Bags + long-haul plan

Deferred work parking lot. Nothing here blocks shipping; each item gets swept during a wave boundary or post-launch. Owner tags: me (agent), Backend Owner, or user.

## Performance Bag
| Item | Owner | Notes |
|---|---|---|
| `maxTrailBufferPoints` (5000) cap is a guess | me→14 | measure real append latency/batch size on device; tune |
| `gpsTrail` arrayUnion grows one doc unbounded over long shifts | Backend Owner | contract change (shard/rotation) — flagged, not built |
| D2 has 4+ concurrent listeners (van, trip, route, wards) | me→14 | cold-start snapshot cost on emulator + real phone |
| Map package choice (`flutter_map`, zero-key) | me→14 | swap to google_maps if PRD forces it; vec-tiles perf later |

## Bug Bag
| Item | Owner | Notes |
|---|---|---|
| Test-timer collision relies on event-loop FIFO ordering | me | could flake on slow CI; fix = flush-interval offsets if seen |
| fakeAsync unsuitable for chained-async writes | me | documented; never reintroduce (test #5 tracking) |

## Improvement Bag
| Item | Owner | Notes |
|---|---|---|
| Locale flip `en` → `gu` before demo | me | grilled decision; one-line change + arb review |
| `whereIn` >30-ward chunking in ward fan-out | me | documented exception ruling 12; build if demo routes exceed |
| Delete `dev_tracking.dart` + dev entrypoints at integration | me | ticket 14 |
| Index seeds list for Backend Owner (`firestore.indexes.json`) | Backend Owner | rulings 10/11/16 |
| Real Firebase keys swap point | user | one function: `sharedProjectFirebaseOptions()`; `--dart-define=DRIVERAPP_USE_EMULATOR=false` |

## Feature Bag
| Item | Owner | Notes |
|---|---|---|
| Staff push on mock-location detection | Backend Owner | no contract function exists (ruling 7) |
| Notices → push notification parity | Backend Owner | inbox read-model only for now |

## Loop protocol (standing)
1. Agents report → I gate: `flutter analyze` + `flutter test` in the worktree → merge branch → full-suite gate on main → append rulings to contract-notes → fold glossary candidates + ADRs.
2. Launch next frontier wave immediately (dependency table in README.md).
3. TDD: every ticket after 12 leads with its failing tests (existing suites are the regression seatbelt).
4. Ticket 14 (serial, last): integration rehearsal, real-phone stabilization, delete dev entrypoints.
5. **Pentest pass** after 14: auth (anonymous → PIN token), Firestore rules red-team (others' vans/trips/complaints, `currentTripId`/`mockLocationDetected` writes), callable abuse (verifyDriverPin rate-limit, token replay), input validation (PIN, malformed args), mock-location adversary, permission-abuse surface. Deliverable: findings → Bug Bag triage on `feat/` branch.
6. Post-completion changes: **branches only** — `feat/*`, `fix/*`, then merge after gates. No direct pushes to main beyond the ongoing wave merges.

# Driver App — local issue tracker

Spec: `spec.md` (source: `docs/PRD-2-driver-app.md`, grilled decisions recorded there).
Tickets are tracer-bullet vertical slices; work the **frontier** = ticket whose blockers are all done.

Blockers (dep order) — waves that can run in parallel:

| # | Ticket | Blocked by |
|---|--------|-----------|
| 01 | Models & repositories spine | — |
| 02 | Firebase bootstrap & anonymous session | — |
| 03 | Pure domain services (Write Policy, distance, ward order, Today) | — |
| 04 | F-D1 Shift Start (D1) | 01, 02 |
| 05 | F-D2 Tracking engine + F-D8 low-battery | 01, 02, 03 |
| 06 | D2 Live Route map shell | 05 |
| 07 | F-D3 Mark Ward Done | 05, 06 |
| 08 | F-D5 End Shift (D5) | 05, 06, 07 |
| 09 | F-D4 Notices inbox (D3) | 04, 06 |
| 10 | F-D6 Pending Reports (D4) | 01, 04 |
| 11 | F-D9 Mock-location detection | 01, 05 |
| 12 | F-D7 Offline GPS buffer & sync | 01, 05 |
| 13 | F-D10 Language toggle | 04 |
| 14 | Integration rehearsal & real-phone stabilization | 07, 08, 09, 10, 11, 12, 13 |

Parallelization notes for subagents:
- Wave A (unblocked): 01, 02, 03 — three independent agents.
- Wave B: 04 and 05 can start simultaneously once their blockers land (05 does **not** wait for 04).
- Wave C: 09 and 10 start right after 04+06/01; 11, 12 independent of each other; 13 trivial last-mile.
- 14 is the only serial gate. Branch per ticket: `feat/driver-<slug>` (0.10).
- Migration to GitHub Issues pending remote setup (`docs/agents/issue-tracker.md`).

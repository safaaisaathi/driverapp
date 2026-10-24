# 12: F-D7 Offline GPS buffer & sync

**What to build:** A dead zone must not lose a shift. Unsent points (both `lastLocation` writes and trail points) queue in local storage while offline and flush **in order** on reconnect; only the latest `lastLocation` matters for the live map (contract 0.13 note), so the queue drains against the van doc without spamming. Trail flushes keep their batching discipline even for catch-up data. Firestore write failures leave nothing silently dropped; the app surfaces an un-synced points volume subtly (no alarm spam). Screen locked / battery saver / swipe-away covered.

**Blocked by:** 05 (engine producing points), 01 (repositories).

**Status:** ready-for-agent

- [ ] 2-minute network cut mid-shift loses zero points; all queued points land in order after reconnect (acceptance criterion 4)
- [ ] Only the latest position write goes to `vans.lastLocation`; the queue never re-overwrites newer positions with stale ones
- [ ] Trail catch-up batches respect the 30-second batch shape (contract append pattern)
- [ ] Queue is durable across app kill/restart while offline
- [ ] Unit tests (seam 2) on the queue/flush ordering; integration basis for the rehearsal ticket

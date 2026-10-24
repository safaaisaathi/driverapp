# 09: F-D4 Notices inbox (D3)

**What to build:** Notices screen streaming `notices` where `targetType == all`, or `targetType == van` with `targetId == vanId`, or `targetType == ward` with `targetId` in the route's `wardIds` (contract 0.7 sendNotice shapes). Push via FCM topic `van_{vanId}` (subscribed at 04's shift start; topic `all` at 02's first launch) opened as a full message or in-app banner foreground; unread badge on D2's app-bar slot (06's placeholder). Unread state per notice; listeners only while visible, cancelled on dispose. Every state covered.

**Blocked by:** 04 (vanId context after sign-in), 06 (badge slot on D2).

**Status:** ready-for-agent

- [ ] Stream shows only the three matching target shapes; seed data confirms filtering (no whole-collection subscribe)
- [ ] FCM push arrives while foregrounded/bushed via the van topic; badge reflects unread on D2
- [ ] Opening a notice marks it read; badge clears accordingly
- [ ] Wrong/untargeted notices do not leak to this app; loading/empty/error/offline states on the screen
- [ ] Widget tests via fake repositories (seam 1): filter logic, read/badge state, push entry points

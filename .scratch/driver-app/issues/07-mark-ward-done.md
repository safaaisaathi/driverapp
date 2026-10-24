# 07: F-D3 Mark Ward Done

**What to build:** On D2: the large "Mark Ward Done" button for the **next** ward, plus a smaller per-ward control so any undone ward can be marked (grilled decision — real routes rarely follow list order). Both paths check the driver's live position against the ward `centre`/`radiusM` through the domain distance helper: inside → clean append; outside → still allowed, entry appended with `flagged = true` for admin review. Appends `{wardId, doneAt, flagged}` to `trips.wardsDone` (exact contract shape) and re-highlights the next undone ward. Screen keeps loading/error/offline states.

**Blocked by:** 05 (tracking engine — hot position required), 06 (D2 host screen).

**Status:** ready-for-agent

- [ ] Next ward's big button; other undone wards markable via the smaller control; out-of-order allowed per grilled decision
- [ ] Mark from outside `radiusM` sets `flagged = true` on that `wardsDone` entry only; inside-reach mark stays unflagged
- [ ] `wardsDone` entries exactly `{wardId, doneAt, flagged}`; next ward highlight advances on each mark
- [ ] Works offline (0.3 behaviour: local write, sync in order) within the write path
- [ ] Widget tests (seam 1) + domain unit tests (seam 2): flag decision, order handling, state after marking

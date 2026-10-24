# 01: Models & repositories spine (contract 0.11)

**What to build:** Plain model classes with `fromMap`/`toMap` mirroring section 0.2 exactly for `wards`, `vans`, `routes`, `trips`, `notices`, `complaints` (the collections the driver app reads/writes), and one repository per collection in `core/repositories`. Widgets must never touch Firebase directly after this lands. Firestore offline persistence enabled. Provider wiring so a fake repository can override a real one in tests (spec seam 1).

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] All six models round-trip `fromMap`/`toMap` against sample documents matching 0.2 shapes exactly (field names, enum `snake_case` values, `{lat,lng}` location shape)
- [ ] Enum values for `van.status`, `complaint.category`, `complaint.status`, `notice.targetType`, `ward.type` exist with contract strings only
- [ ] One repository per collection; operators used by driver features exist (vans list read, trips create/update, complaints update status, notices stream filtered by target, routes/wards reads)
- [ ] Firestore persistence on; no hardcoded values outside the shared constants file (0.4 names only)
- [ ] `flutter analyze` clean; model round-trip and repository unit tests green on the seams without live Firebase

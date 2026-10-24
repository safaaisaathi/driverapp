# 10: F-D6 Pending Reports (D4)

**What to build:** Today's `missed_collection` complaints for this route's wards — query: `category == missed_collection`, `createdAt` within **Today** (IST rule), `status in [received, assigned]`. Each report row offers exactly two buttons: **"Will Revisit"** → complaint `status = assigned`; **"Done"** → `status = resolved` + `resolvedAt` (contract shape; `resolvedPhotoUrl` stays unset — no contract field requires the driver to add one). Driver writes allowed per 0.8 only for `missed_collection` complaints within its route's wards. Minimal text, one-handed.

**Blocked by:** 01 (models/repos), 04 (driver route context).

**Status:** ready-for-agent

- [ ] List = exactly today's missed_collection reports for this route's wards, statuses received/assigned (Today IST deterministic)
- [ ] Will Revisit → `status = assigned`; Done → `status = resolved`, `resolvedAt` set; other fields untouched
- [ ] Complaints outside this route's wards / other categories / other statuses never appear; writes only ever touch the tapped complaint
- [ ] loading/empty ("nothing pending")/error/offline states localized; rows use big tap targets
- [ ] Widget tests via fake repositories (seam 1): query shape, both button outcomes, out-of-scope complaint rejection

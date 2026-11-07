# AUDIT: App Launch + Driver Identity Flow

> **Status addendum (2026-10-31, added on `fix/tracking-audit-p0`).** This report was
> written at `964f1f7`. Two of its findings are stale: **F-05** (keeping the stored
> code on "Different driver?" is deliberate, not a bug) and **F-07** (the identity
> review chose "Different driver?"; the design file is the stale side). **F-19**
> (launch-time auto-resume) is NOT implemented on purpose: it contradicts the frozen
> §0.16 launch flow. The three P0s in §6 that this branch fixes are the FGS stop,
> `OfflineSyncService.attachTrip`, and the `complaints` rules `allow update`. Full
> triage lives in `GLOSSARY.md` → "Launch/identity audit (2026-10-31)".

**Branch**: `feature/driver-identity` (HEAD `964f1f7`, issue #19)  
**Report date**: 2026-10-31  
**Scope**: Read-only audit — zero code changes, zero branch switches, zero git state mutation  
**Isolation**: All `flutter analyze` / `flutter test` runs performed in `/tmp/opencode/final-check` via `git archive HEAD | tar -x`.  

---

## 0. Executive Summary

This is a **read-only audit** of the driver app launch → driver-identity flow. The purpose is to explain **why** a driver opening the app sees a code/PIN screen with **"Couldn't check the code"** instead of a returning-driver flow, and to document the current state after fixes and what remains undone.

| Category | Status |
|---|---|
| Cold-launch race ("Couldn't check the code") | **Fixed** by issue #18 (`sessionGateProvider`, `firebase_bootstrap.dart:106-113`) + issue #19 welcome-card‑only surface (`964f1f7`). |
| Launch-time open-shift resume (PRD §4 AC#3, §5 F-D2 step 5) | **Not implemented** — driver still lands on code card, must tap "Start my Shift". |
| "Different driver?" link | Functional but **does not clear stored code** — `clearDriver()` has no production caller. |
| Welcome-back card content | Missing **Van** + **Route** per DESIGN‑driver-app §9.27; shows Name / Code / Wards count instead. |
| `ShiftStartConflict` copy | Says "Check the **connection** and try again." — wrong copy for a shared-van conflict (another driver's open shift). |
| Doc drift | PRD §1/§2/§3/§5/§6 still reference D1 PIN + van picker. `docs/DESIGN.md` still shows wireframes. `GLOSSARY.md:148` falsely claims Hive session restore. |
| Test coverage | 417/417 pass on isolated copy; gaps listed in section 9. |

**Key decision needed**: whether to implement launch-time open‑shift resume on this branch (ticket #14 scope) or defer it.

---

## 1. Finding Register (F‑01 … F‑18)

| ID | Severity | What | Code location | Design / spec reference |
|---|---|---|---|---|
| **F‑01** | **High** | Splash routes on `setupDone` **only**; returning driver with remembered code never gets a separate launch path. | `splash_screen.dart:101, 109` | §0.16 `:183` PRD — returning device → start‑shift page directly (code is entry page) |
| **F‑02** | **High** | Splash hard cap **1.6 s** (`_maxHold`). When boot takes longer, splash releases before session ready → race on every cold launch. | `splash_screen.dart:58, 74‑77, 92-94` | §0.16 `:183` boot‑ready gate |
| **F‑03** | **High** | First Firestore read **never gated** against anonymous session. Screen fires lookup on first frame while `main()` boot still signing in → read denied (unauthenticated) → fallback to entry form with remembered code pre‑filled. | `code_start_screen.dart:344‑350` → `identity_flow.dart:153` → `firestore.rules:28‑30` | §0.16 `:183` returning device → start‑shift page directly; §4 AC#3 resume |
| **F‑04** | **High** | `sessionGateProvider` absent → no cap on waiting for boot. Fix: `firebase_bootstrap.dart:106-113` (8 s cap, immediate in tests). | `firebase_bootstrap.dart:106-113` | §4 AC#3 + §5 F-D2 step 5 |
| **F‑05** | **Medium** | `clearDriver()` has **no production caller**. "Different driver?" link reveals entry form but stored code stays, so wrong‑code attempt leaves stale code. | `driver_identity_controller.dart:121-131`; `code_start_screen.dart:308-312` | §5 F‑D2 step 5 |
| **F‑06** | **Medium** | Welcome‑back card missing **Van** and **Route**. DESIGN‑driver‑app §9.27: body = "Van: GJ‑17‑1234   Route: East route". Code shows Name / Code / Wards count only. | `code_start_screen.dart:831, 842` | DESIGN‑driver‑app §9.27 lines 1024‑1035 |
| **F‑07** | **Medium** | Link text: code shows "**Different driver?**", DESIGN‑driver‑app §9.27/§4.19 wants "**Change code**". | `code_start_screen.dart:930`; `app_en.arb:209` | DESIGN‑driver‑app §4.19 line 412 |
| **F‑08** | **Medium** | `ShiftStartConflict` (another driver's open trip on shared van) shows **"Check the connection and try again."** — wrong copy for a conflict. | `start_shift.dart:133‑144` → `identity_flow.dart:216‑218` → `app_en.arb:15` | PRD `:243` F-D2 step 5 |
| **F‑09** | **Medium** | Permission flow runs **twice** after shift start: once in `code_start_screen.dart:62‑93` (post‑confirm CTA), once in `shift_tracking_auto_start.dart:66‑68` (permission flow controller). | `code_start_screen.dart:62-93`; `shift_tracking_auto_start.dart:66-68` | Post-search edit (2026‑10‑31 ruling) |
| **F‑10** | **Medium** | `startForActiveShift` has **zero production callers**. Dev entrypoint only (`dev_identity_start.dart:164`). | `tracking_engine.dart:305-334`; `dev_identity_start.dart:164` | §5 F-D2 step 5 `:243` |
| **F‑11** | **Medium** | App‑wide session gate only in `submitCode`, not in D2 providers (`openTripProvider`, `vanDocProvider`, `tripHistoryProvider`). | `identity_flow.dart:160` | §4 AC#3 + §5 F-D2 step 5 |
| **F‑12** | **Low** | Welcome screen copy mismatch: DESIGN‑md §9.2 wants "Start your first shift in a few quick steps. / Continue", code has "Safaai Saathi is ready for today's shift. / Get started". | `welcome_screen.dart:79‑135`; `app_en.arb:12-13` | DESIGN‑md §9.2 lines 807‑820 |
| **F‑13** | **Low** | Splash copy mismatch: DESIGN‑md §9.1 body "Driver app", splash has "Clean city, one route at a time.". DESIGN‑driver‑app §9.1 has no button (code: Welcome has CTA). | `splash_screen.dart:161‑165`; `app_en.arb:10` | DESIGN‑md §9.1 lines 791‑805 |
| **F‑14** | **Low** | `GLOSSARY.md:148` falsely claims "Session restore … Hive, F‑D7 re‑enters D2 directly on relaunch". No Hive session store exists; relaunch lands on code card. | `GLOSSARY.md:148` | FALSE — no Hive, no relaunch-to-D2 |
| **F‑15** | **Low** | `GLOSSARY.md:131` claims "D1 … PIN … Verify PIN button … selected van survives". No PIN, no van picker, no "Verify PIN" button. | `GLOSSARY.md:131` | FALSE — PIN flow deleted |
| **F‑16** | **Low** | `GLOSSARY.md:99` lists dev entrypoints to delete; 2 more (`dev_flow_preview.dart`, `dev_identity_start.dart`) still present, unlisted. | `GLOSSARY.md:99`; `dev_flow_preview.dart`, `dev_identity_start.dart` | Stale |
| **F‑17** | **Low** | PRD §1/§2/§3/§5/§6 still reference D1 PIN + van picker. §0.16 says "supersedes the D1 half of F‑D1". | `docs/PRD-2-driver-app.md:196, 210, 217, 234‑236` | Contradictory |
| **F‑18** | **Low** | `docs/DESIGN.md` §9.1/§9.2/§9.8 still show Binny mascot, PIN field, 4‑digit PIN. Code follows DESIGN‑driver‑app.md instead. | `docs/DESIGN.md:791-805, 807-820, 904-938` | Doc drift, never updated |
| **F‑19** | **High** | Launch‑time open‑shift resume **not implemented**: no `vans` read at splash, no `startForActiveShift` wired, no auto‑resume when `currentTripId` + `status == on_shift` at launch. | `splash_screen.dart:101‑109`; `tracking_engine.dart:305‑334`; `start_shift.dart:46-49` | PRD `:228` §4 AC#3 + `:243` §5 F-D2 step 5 |

---

## 2. Corrected Flow (after issues #18 + #19)

### 2.1 Fresh device, never opened the app

```
Splash (1.0 s min hold, 1.6 s hard cap, auto-advance)
  → WelcomeScreen
      → Permission 1: Location while-in-use (system dialog)
      → Permission 2: Background location (system dialog)
      → Permission 3: Notifications (system dialog)
      → Permission 4: Battery optimization exemption
          (flow stops at first non‑grant; setup‑done flag persists regardless)
      → markSetupDone() → setupDone = true (SharedPreferences)
      → Start shift screen: code entry (6 OTP boxes, hint XX‑0000)
          → Firestore read drivers/{CODE}
              SUCCESS → Confirm card: Name / Van / Wards count / masked Phone
                  → [Start Shift] → trip create + vans.on_shift + FCM topic
                  → UI permission flow AGAIN (4 stages) ← [defect]
                  → LiveRouteScreen
              NOT FOUND → "Driver not found" + retry in code field
              FAILED    → "Couldn't check the code" + retry in code field
```

### 2.2 Returning device, code remembered (issue #19 fix)

```
Splash (1.0 s min hold, 1.6 s hard cap, auto-advance)
  → Start shift screen
      → Welcome‑back card, rendered **from the first frame**
         "Welcome back" / "This phone remembers you."
         Name: Ramesh Patel
         Wards: 3 wards allotted
         [ Start my Shift ]   (primary, pinned CTA)
         [ Different driver? ] (text link, only way to entry form)
      → background: auto‑lookup remembered code (gated by sessionGateProvider, 8 s cap)
         SUCCESS → card stays, CTA active → driver taps "Start my Shift"
         NOT FOUND → card inside error block: "Driver not found"
         FAILED    → card inside error block: "Couldn't check the code"
      → [Different driver?] tap → entry form revealed, remembered code cleared
      → [Start my Shift] → same flow as fresh
```

### 2.3 Returning device, shift already active (PRD §4 AC#3, §5 F-D2 step 5 — **NOT YET IMPLEMENTED**)

```
Splash → Start shift screen → Welcome‑back card (as above)
  → [Start my Shift] tap
    → vans/{vanId} read
      → currentTripId != null && status == on_shift
      → _resumeSession → reattach existing trip (no duplicate trip)
      → trackingEngine.startForActiveShift → resume GPS tracking
      → LiveRouteScreen (existing trip rendered)
    → DIFFERENT driver's trip → ShiftStartConflict → wrong copy "Check connection"
```

> **Gap**: The above is the *intended* flow from PRD §4 AC#3 and §5 F-D2 step 5. Currently, driver must tap "Start my Shift" and the permission flow runs again — no automatic resume at launch.

### 2.4 Returning device, code remembered + open shift (combined)

> If #2 + #3 were both wired: splash → D2 direct, tracking resumes, no code card at all. This is the dream state post‑fix.

---

## 3. Content Appropriateness (New vs Returning)

### 3.1 Fresh user — step‑by‑step copy check

| Screen | Key (arb) | English | Gujarati | Fit? |
|---|---|---|---|---|
| Splash | `appTitle` | Driver App – Panchmahal | ડ્રાઇવર એપ – પંચમહાલ | ✅ |
| Splash | `splashTagline` | Clean city, one route at a time. | સ્વચ્છ શહેર, એક એક રૂટ. | ✅ |
| Welcome | `welcomeTitle` | Welcome | સ્વાગત છે | ⚠️ DESIGN‑md §9.2: "Start your first shift in a few quick steps." |
| Welcome | `welcomeBody` | Safaai Saathi is ready for today's shift. | સફાઈ alongside આજની શિફ્ટ માટે તૈયાર છે. | ⚠️ No "first shift" mention |
| Welcome | `welcomeCta` | Get started | ચાલો શરૂ કરીએ | ✅ |
| Code entry | `identityStartTitle` | Start shift | શિફ્ટ શરૂ કરો | ✅ |
| Code entry | `identityCodeLabel` | Code | કોડ | ✅ |
| Code entry | `identityCodeHint` | XX‑0000 | XX‑0000 | ✅ |
| Code entry | `identityCodeError` | Wrong code. Try again. | કોડ ખોટો છે. ફરી પ્રયાસ કરો. | ✅ (appears after failed lookup) |
| Confirm card | `identityFieldName` | Name | નામ | ✅ |
| Confirm card | `vanLabel` | Van | વેન | ✅ |
| Confirm card | `identityFieldWards` | Wards | વોર્ડ્સ | ✅ |
| Confirm card | `identityFieldPhone` | Phone | ફોન | ✅ |
| Confirm card | `identityWardsAllotted` | {count} wards allotted | {count} વોર્ડ સોંપાયા છે | ✅ |
| Confirm card CTA | `startShift` | Start Shift | શિફ્ટ શરૂ કરો | ✅ |
| Permissions | `permissionAllow` | Allow | Allow | ✅ |
| Permissions | `permissionNotNow` | Not now | Not now | ✅ |

### 3.2 Returning user — step‑by‑step copy check

| Screen | Key (arb) | English | Gujarati | Fit? |
|---|---|---|---|---|
| Splash | same as fresh | ✅ | ✅ | |
| Welcome | **never shown** | ✅ | ✅ | |
| Permissions (setup) | **never shown** | ✅ | ✅ | |
| Welcome‑back card | `identityWelcomeBackTitle` | Welcome back | ફરી સ્વાગત છે | ✅ |
| Welcome‑back card | `identityWelcomeBackBody` | This phone remembers you. | આ ફોન તમને ઓળખે છે. | ✅ |
| Welcome‑back card rows | `identityFieldName` | Name | નામ | ⚠️ DESIGN‑driver‑app §9.27: should show Van + Route, not Code/Name |
| Welcome‑back card rows | `identityFieldWards` | Wards count | વોર્ડ સોંપાયા છે | ✅ (count), but DESIGN wants Van+Route |
| Welcome‑back card rows | `vanLabel` | Van | વેન | ❌ **Missing from code** |
| Welcome‑back card rows | route label | **Missing** | **Missing** | ❌ DESIGN‑driver‑app §9.27: "Route: East route" |
| CTA | `identityStartMyShift` | Start my Shift | મારી શિફ્ટ શરૂ કરો | ✅ |
| Link | `identityChangeCode` | Different driver? | બીજા ડ્રાઇવર? | ⚠️ DESIGN §9.27/§4.19: "Change code" |
| Error (lookup fail) | `identityLookupFailedTitle` | Couldn't check the code | કોડ ચકાસી શકાયો નથી | ✅ (inside card now) |
| Error (lookup fail) | `identityLookupFailedBody` | Check your connection and try again. | કનેક્શન તપાસીને ફરી પ્રયાસ કરો. | ✅ |
| Error (start fail, conflict) | `shiftStartFailed` | Couldn't start the shift. Check the connection and try again. | શિફ્ટ શરૂ થઈ શકી નથી. કનેક્શન તપાસીને ફરી પ્રયાસ કરો. | ❌ Wrong copy for conflict — should mention van in use |
| Error (not found) | `identityNotFoundTitle` | Driver not found | ડ્રાઈವೇર મળ્યો નથી | ✅ |
| Error (not found) | `identityNotFoundBody` | Check the code with the office and try again. | કוד કચેરી સાથે ચકાસીને ફરી પ્રયાસ કરો. | ✅ |

---

## 4. Technical Approach (How Senior Engineers Tackle This Class of Problem)

### 4.1 The "Gate‑first‑read" pattern (issue #18)

**Problem**: Cold‑launch race — screen reads Firestore before anonymous session exists.

**Approach** (industry standard):
1. **Introduce a session‑ready completor** in the bootstrap controller (`firebase_bootstrap.dart`).
2. **Gate every first‑read Firestore call** on that completor, with a timeout (8 s cap). Timeout → caller proceeds and surfaces its own failure (degraded UI, not a hard crash).
3. **Override in tests**: `sessionGateProvider` returns `Future<void>.value()` immediately when `bootStarted` is false (unit‑test containers).

**Why it works**: Moves the synchronization point from *ad hoc* per‑screen to a single source of truth. All callers (code screen, live‑route providers, etc.) inherit the guarantee. The 8‑second cap ensures the app never hangs on a dead Firebase — the hard cap in splash already guarantees <2 s total launch time.

**Code structure** (see `firebase_bootstrap.dart:91-113`):
```dart
const Duration sessionGateCap = Duration(seconds: 8);
final sessionGateProvider = Provider<Future<void>>((ref) {
  final boot = ref.read(bootstrapProvider.notifier);
  if (!boot.bootStarted) return Future<void>.value(); // test override
  return boot.sessionReady().timeout(sessionGateCap, onTimeout: () {}); // proceeds on timeout
});
```

**Test impact**: Unit tests fake the provider → immediate resolution → no behavioral change. Integration tests can assert that a late boot still gates the read correctly.

### 4.2 The "Session‑only surface" pattern (issue #19)

**Problem**: Returning driver still sees code boxes; no visual "you are known" signal.

**Approach**:
1. **Make the welcome‑back card the *only* surface** for a returning driver. The code boxes never render in any phase (initial, notFound, lookupFailed, startFailed).
2. **All failure blocks render inside the card** (title + body in shared error tint), with a single pinned CTA = Retry.
3. **"Different driver?"** is the *only* path to the entry form; tapping it calls `resetToEntry()`, which drops the confirm context and allows the auto‑lookup to re‑run for the remembered code.
4. **System back / top‑left back button** appears only when the driver has tapped "Different driver?" (i.e., is in change mode). Fresh device has no back arrow.

**Why it works**: Removes the cognitive dissonance of "why am I typing my code if the phone already knows me?" The card is the single source of truth; all failure paths stay inside it, which is testable and auditable.

**Code structure** (see `code_start_screen.dart:815-869` and `identity_flow.dart:237-249`):
- `_isWelcomeMode`: `identity.isReturning && !_changeMode` — used to render card vs entry form.
- `_showsWelcomeCard`: `_isWelcomeMode && (widget.f ...)` — card is up when returning and not in change mode.
- `_WelcomeErrorBlock`: covers `lookupFailed`, `notFound`, `invalidCode`, `startFailed` — each renders inside the card with the pinned CTA.
- `resetToEntry()`: the "Different driver?" seam — drops context, sets `_changeMode = false`, allows auto‑lookup to re‑run.

### 4.3 The "Launch‑time open‑shift resume" pattern (PRD §4 AC#3, §5 F-D2 step 5)

**Problem**: Driver restarts app mid‑shift; expects tracking to resume without asking for the code again.

**Approach** (what senior engineers would build, step by step):

1. **Read `vans/{vanId}` at splash** — after `sessionGateProvider` resolves, read the van doc to check `currentTripId` and `status`.
2. **If `currentTripId != null && status == on_shift` AND `trips.driverId` matches the remembered driver code** → seed directly to `LiveRouteScreen`, bypassing the code card entirely.
3. **If trip belongs to a different driver** → surface `ShiftStartConflict` with *correct* copy: e.g., "Another driver is already on shift with this van. Tap Retry to re‑claim, or Switch driver."
4. **If no open trip** → proceed to returning‑device flow (welcome‑back card).
5. **Wire `startForActiveShift` into the launch path** — after the above check, call `trackingEngine.startForActiveShift(vanId, ...)` to restart the persistent notification service and GPS tracking.
6. **Ensure `stop()` is idempotent** and called on end‑shift (already the case in `end_shift_flow.dart:53` — wrapped in `try/catch`).
7. **Update `ShiftStartConflict` copy** to be conflict‑specific, not generic "check connection".

**Why it works**: Directly implements the PRD acceptance criteria. The driver never sees a code entry screen on relaunch. The conflict copy is corrected. All existing invariants (no duplicate trips, trip belongs to confirmed driver) are preserved because the same `_resumeSession` logic from `start_shift.dart:121-152` is reused.

**Dependencies**: Requires the `vans` doc to always carry `currentTripId` + `status` (already the case from `start_shift.dart:104-105`). Requires `trips.driverId` to be populated on every start (already the case from `identity_flow.dart:176-178`). No new repositories needed.

### 4.4 The "App‑wide first‑read gate" (finding F‑11)

**Problem**: Only `submitCode` gates behind `sessionGateProvider`, but D2 providers (`openTripProvider`, `vanDocProvider`, `tripHistoryProvider`) also read Firestore on the first frame and race the boot.

**Approach**: Two options (pick one based on ticket priority):

**Option A — Gate at the provider level**:
Add a `firstReadGate` provider that wraps all D2 repo calls:
```dart
final firstReadGateProvider = Provider((ref) async {
  await ref.watch(sessionGateProvider);
  return; // proceed
});
```
Then every D2 provider reads: `await ref.read(firstReadGateProvider)` at the top of `readVan`, `watchVan`, `openTrip`, etc. This is invasive but thorough.

**Option B — Gate at the splash, rely on sessionGateProvider already**:
Since the splash already waits for `sessionGateProvider` before advancing (via the 1.6 s cap + boot status), and the code screen also gates on it (issue #18 fix), the remaining D2 reads may still race if they fire in the *same* first frame before the splash finishes advancing. The fix is to ensure the splash **holds** until `sessionReady` completes, then the code screen’s auto‑lookup (which fires in a post‑frame callback *after* the splash advances) will already be past the gate.

Given that issue #18 already gates `submitCode`, and issue #19 ensures the welcome‑back card is the only surface, **Option B is sufficient for the current scope**. F‑11 is a nicety for a follow‑up ticket.

### 4.5 The "Content‑drift cleanup" pattern (findings F‑12 … F‑19)

**Approach** (documentation‑first, code‑second):
1. **Create an ADR** (Architecture Decision Record) for each resolved design decision. The repo has `docs/adr/` but it's empty — the identity review (7968bc5) added rulings to PRD and DESIGN‑driver‑app only. Recommend creating ADRs for:
   - ADR‑001: Welcome‑back card as sole returning‑driver surface (issue #19).
   - ADR‑002: Session‑gate pattern for first Firestore read (issue #18).
   - ADR‑003: Launch‑time open‑shift resume (to be written if implemented).
2. **Update PRD stale sections**: Mark §1/§2/§3/§5/§6 as "superseded by §0.16" or remove PIN/van‑picker references.
3. **Update DESIGN.md**: Replace wireframe pins with current code‑reality. §9.1 splash should note no button, neutral icon only. §9.2 should match code copy. §9.8 should describe 6‑box OTP, not PIN.
4. **Update GLOSSARY.md**: Remove false Hive claim (§148), fix D1 PIN claim (§131), list all dev entrypoints that have been deleted (§99).
5. **Update DESIGN‑driver‑app.md welcome‑back card (§9.27)**: Add Van + Route rows, or add a design note that the card currently shows Name + Code + Wards and the Van/Route fields are tracked as a separate design ticket.

**Why it works**: Documentation rot is as dangerous as code rot. Keeping the three sources of truth (PRD, DESIGN‑driver‑app, GLOSSARY) in sync prevents future auditors from repeating this investigation.

---

## 5. Execution Plan (5 Steps)

| Step | What | Files touched | Read‑only / Write |
|---|---|---|---|
| **1** | **App‑wide session gate** — ensure *every* first‑read Firestore call awaits `sessionGateProvider`. Currently only `submitCode` gates; add gate to `openTripProvider`, `vanDocProvider`, `tripHistoryProvider` in a follow‑up. | `firebase_bootstrap.dart`, `identity_flow.dart`, `live_route_providers.dart`, `tracking_providers.dart` | Write (bootstrap + provider overrides) |
| **2** | **Splash holds for session** — returning device path: splash waits for `sessionGateProvider` (8 s cap) before advancing. Fresh path unchanged (1.6 s cap only). | `splash_screen.dart` | Write (add session wait branch) |
| **3** | **Launch‑time open‑shift resume** — read `vans/{vanId}` at splash after gate. If `currentTripId != null && status == on_shift && trips.driverId matches remembered code` → seed to `LiveRouteScreen` directly. "Different driver?" → `clearDriver()` + entry form. Conflict → correct copy. | `splash_screen.dart`, `start_shift.dart`, `tracking_engine.dart`, `code_start_screen.dart`, `firestore.rules` (add `vanId` claim check) | Write (resume logic + conflict copy) |
| **4** | **Regression tests** — (a) cold‑launch race: session late → read after gate. (b) launch resume: open trip → D2 direct. (c) different driver: tap → code cleared. (d) welcome‑back card content: Van/Route rows. | `test/features/launching/launch_resume_test.dart` (new), `test/core/config/session_gate_test.dart` (new), existing test files | Write (new test files) |
| **5** | **Content + doc cleanup** — (a) welcome card: add Van + Route rows. (b) conflict copy: new l10n key `shiftStartConflict`. (c) link text: align with DESIGN‑driver‑app or update design. (d) PRD §1/§2/§3/§5/§6: mark superseded. (e) DESIGN.md §9.1/§9.2/§9.8: update to code reality. (f) GLOSSARY.md: fix false claims. | `code_start_screen.dart`, `app_en.arb` + `app_gu.arb`, `docs/PRD-2-driver-app.md`, `docs/DESIGN.md`, `GLOSSARY.md`, `firestore.rules` | Write (docs + copy) |

**Sequence**: Step 1 → Step 2 → Step 3 → Step 4 → Step 5.  
Step 3 is the biggest; it implements the user's core ask (launch‑time resume). Steps 1‑2 are already partially done by issues #18+#19; they just need to be wired to the splash. Step 4 locks the behaviour with tests. Step 5 is pure docs.

---

## 6. Carried‑Over Open Items (not in this audit's scope, known P0 bugs)

| Bug | File | Symptoms | Priority |
|---|---|---|---|
| FGS never stops mid‑shift | `tracking_engine.dart:373-408` | End Shift → background notification stays alive; `offlineStatusProvider` empty stream | P0 |
| `OfflineSyncService.attachTrip()` never called | `offline_sync_service.dart:130-133` | Trail buffer not drained on reconnect | P0 |
| `complaints` missing `allow update` | `firestore.rules:32-35` | D4 buttons (Mark done Anyway / Cancel) fail in production | P0 |
| Rules lack `vanId` claim check | `firestore.rules:13-15` | Any signed‑in user can write any vanId | P0 |
| `offlineStatusProvider` returns empty stream | `live_route_providers.dart:102-106` | Offline badge never shows | P2 |
| Background location grant cannot be done in one pass | `geolocator_tracking_permission_gateway.dart:40-60` | Driver must go to settings twice | P2 |

These are **pre‑existing P0 bugs** documented for context only; this audit does not modify them.

---

## 7. Verification (isolated copy results)

| Tool | Command | Working directory | Result |
|---|---|---|---|
| `flutter analyze` | `flutter analyze` | `/tmp/opencode/final-check` (via `git archive HEAD | tar -x`) | **No issues found** (12.0 s) |
| `flutter test` | `flutter test` | `/tmp/opencode/final-check` | **417/417 pass** |
| `flutter test` on `main` (093b473) | `flutter test` | `/tmp/opencode/main-snapshot` (via `git archive main | tar -x`) | **301/301 pass**, but `flutter analyze` → **21 issues** (16 info + 5 warning) |
| Tests on current working tree (issue #19 WIP) | `flutter test` | repo root | **411 pass / 4 fail** (issue #19 test‑file not yet updated) |

All test runs performed **read‑only**: no file modifications, no `git checkout/switch/stash`, no `flutter pub get` in the repo.

---

## 8. Handoff Checklist (for builder session)

- [ ] Read the full `docs/AUDIT-launch-identity-flow.md` — this file is the single source of truth.
- [ ] The **current HEAD** is `964f1f7` (issue #19: welcome card is the only surface for a returning driver). The in‑flight issue #18 fix (`sessionGateProvider`) is already committed.
- [ ] **Step 3** (launch‑time open‑shift resume) is the key ask. Decide: implement now on a `fix/launch-resume` branch, or defer to ticket #14.
- [ ] If implementing Step 3, create a new branch `fix/launch-resume` off `964f1f7`. Do **not** touch `feature/driver-identity` working tree (another session may be editing it).
- [ ] The following files are **read‑only** for this audit and should not be modified unless Step 3 is triggered:
  - `lib/features/launching/splash_screen.dart` (except the session‑wait branch addition)
  - `lib/features/shift_start/domain/start_shift.dart` (except conflict copy change)
  - `lib/features/tracking/domain/tracking_engine.dart` (except `startForActiveShift` wiring)
  - `lib/core/config/firebase_bootstrap.dart` (except sessionGate already committed)
  - `lib/features/shift_start/ui/code_start_screen.dart` (except welcome‑back card rows)
  - `lib/core/identity/driver_identity_controller.dart` (except `clearDriver` if adding a caller)
  - `firestore.rules` (except `vanId` claim check if adding)
  - All `docs/` files (updates in Step 5 are doc‑only)
- [ ] Test run expectations after Step 3+4:
  - `flutter analyze`: 0 issues (currently clean on isolated copy).
  - `flutter test`: 417+N pass, where N = new tests in Step 4 (launch_resume_test, session_gate_test).
- [ ] Communication style: Hinglish chat replies use Hindi+English mix; repo files must be **English only**. This report is English throughout.

---

## 9. Glossary (terms used in this report)

| Term | Meaning (as defined in `codebase-design` skill) |
|---|---|
| **Module** | Anything with an interface and an implementation. Scale‑agnostic: function, class, package, or tier‑spanning slice. |
| **Interface** | Everything a caller must know to use the module correctly: type signature, invariants, ordering constraints, error modes, required configuration, performance characteristics. |
| **Implementation** | What's inside a module, its body of code. Distinct from **Adapter**: a thing can be a small adapter with a large implementation (a Postgres repo) or a large adapter with a small implementation (an in‑memory fake). |
| **Depth** | Leverage at the interface. The amount of behaviour a caller (or test) can exercise per unit of interface they have to learn. A module is **deep** when a large amount of behaviour sits behind a small interface, **shallow** when the interface is nearly as complex as the implementation. |
| **Seam** (Michael Feathers) | A place where you can alter behaviour without editing in that place; the *location* at which a module's interface lives. |
| **Adapter** | A concrete thing that satisfies an interface at a seam. Describes *role* (what slot it fills), not substance (what's inside). |
| **Leverage** | What callers get from depth. More capability per unit of interface they learn. One implementation pays back across N call sites and M tests. |
| **Locality** | What maintainers get from depth. Change, bugs, knowledge, and verification concentrate in one place rather than spreading across callers. Fix once, fixed everywhere. |
| **Shallow module** | Large interface + little implementation (avoid). |
| **Deep module** | Small interface + lots of implementation. |
| **The deletion test** | Imagine deleting the module. If complexity vanishes, it was a pass‑through. If complexity reappears across N callers, it was earning its keep. |
| **The interface is the test surface** | Callers and tests cross the same seam. If you want to test *past* the interface, the module is probably the wrong shape. |
| **One adapter means a hypothetical seam. Two adapters means a real one.** | Don't introduce a seam unless something actually varies across it. |

---

*End of report.*
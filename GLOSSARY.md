# Glossary

Domain terms for the **Driver App (Garbage Van)** context of the Citizen-Centric Garbage Collection and Sanitation Monitoring System (source of truth: `docs/PRD-2-driver-app.md` section 0).

## Language

**Van**:
A garbage collection vehicle. One van serves one route and carries one tracked Android phone.
_Avoid_: truck, vehicle

**Ward**:
A mapped area (centre + radius) whose garbage collection is served by one route and supervised by one inspector.
_Avoid_: zone, area

**Route**:
The visiting order a van follows: one route is the ordered list of wards.
_Avoid_: schedule, path

**Shift**:
The driver's working session, from Start Shift to End Shift.
_Avoid_: session, duty

**Trip**:
The log record of one shift: the van's trail, the wards done, and alert history.
_Avoid_: journey, ride

**Mark Ward Done**:
The driver's action that records a ward as collected during the current trip.
_Avoid_: tick, check-in

**Flagged**:
A Mark Ward Done made from outside that ward's radius, kept for admin review.
_Avoid_: suspicious, invalid

**Notice**:
A one-way message an admin sends to a van, to a ward, or to everyone.
_Avoid_: announcement, alert

**Pending Report**:
A missed-collection complaint for today's route wards that awaits driver action.
_Avoid_: backlog, open ticket

**Today**:
The collection-day calendar date, resolved in Asia/Kolkata regardless of phone clock settings.
_Avoid_: current date

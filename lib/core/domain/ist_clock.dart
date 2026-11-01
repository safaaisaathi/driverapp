/// **Today** — the collection-day calendar date, resolved in Asia/Kolkata
/// (+05:30, no DST — PRD-2 0.2 `trips.date` and all "created today" queries)
/// regardless of the phone clock or timezone settings. Implemented with
/// fixed-offset arithmetic; no tz database is used.
library;

/// A calendar date in the IST zone.
typedef IstDate = ({int year, int month, int day});

const Duration _istOffset = Duration(hours: 5, minutes: 30);

/// The IST calendar date of instant [now]. Works for any input timezone
/// because the instant is first normalised to UTC, then shifted +05:30.
IstDate todayIST(DateTime now) {
  final ist = now.toUtc().add(_istOffset);
  return (year: ist.year, month: ist.month, day: ist.day);
}

/// The IST date of [now] as an ISO `yyyy-MM-dd` string, zero-padded, in the
/// shape used for `trips.date`.
String todayIsoIST(DateTime now) {
  final d = todayIST(now);
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

/// Whether two instants fall on the same IST calendar day. Handles the
/// IST-midnight edge: e.g. 18:29:59 UTC and 18:30:01 UTC on the same UTC day
/// are different IST days.
bool isSameDayIST(DateTime a, DateTime b) => todayIST(a) == todayIST(b);

/// Whether [createdAt] was made **today** (same IST day as [now]) — the
/// predicate behind Pending Reports and the missed-collection queries.
bool wasCreatedTodayIST(DateTime createdAt, DateTime now) =>
    isSameDayIST(createdAt, now);

/// Whole minutes [past] is before [now], floored and clamped to ≥ 0.
/// Timezone-free (an instant difference), but named for the IST-clock family
/// used by "Last seen X min ago" style helpers.
int minutesAgoIST(DateTime past, DateTime now) {
  final minutes = now.difference(past).inMinutes;
  return minutes < 0 ? 0 : minutes;
}

/// The UTC instant of 00:00 IST on the IST day containing [now] — the lower
/// bound for range queries over a collection day (`createdAt >= this`).
DateTime utcStartOfIstDay(DateTime now) {
  final d = todayIST(now);
  final istMidnight = DateTime.utc(d.year, d.month, d.day);
  return istMidnight.subtract(_istOffset);
}

/// The half-open UTC window `[start, endExclusive)` that brackets the IST
/// calendar day containing [instant] — the READ counterpart of the
/// `trips.date` WRITE frame ([utcStartOfIstDay]).
///
/// Building the window from the instant's LOCAL calendar fields (the pre-bag
/// behaviour, issue #15) only works when the phone sits in IST: on any other
/// zone the local date of "now" is a different day than the IST date, so
/// today's trip fell outside its own query. IST has no DST, so the IST day is
/// exactly 24 h and [endExclusive] is a fixed offset.
({DateTime start, DateTime endExclusive}) istDayWindow(DateTime instant) {
  final start = utcStartOfIstDay(instant);
  return (start: start, endExclusive: start.add(const Duration(days: 1)));
}

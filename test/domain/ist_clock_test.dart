import 'package:driverapp/core/domain/ist_clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('todayIST', () {
    test('UTC midnight boundary: 18:30 UTC is already the next IST day', () {
      // 2026-06-15 18:30 UTC == 2026-06-16 00:00 IST.
      final d = todayIST(DateTime.utc(2026, 6, 15, 18, 30, 0));
      expect(d.year, 2026);
      expect(d.month, 6);
      expect(d.day, 16);
    });

    test('one second before IST midnight stays on the previous day', () {
      final d = todayIST(DateTime.utc(2026, 6, 15, 18, 29, 59));
      expect(d.year, 2026);
      expect(d.month, 6);
      expect(d.day, 15);
    });

    test('mid IST afternoon maps trivially', () {
      // 2026-06-15 06:30 UTC == 12:00 IST, same day.
      expect(todayIST(DateTime.utc(2026, 6, 15, 6, 30, 0)).day, 15);
    });

    test('month and year roll over across IST midnight', () {
      // 2026-06-30 18:30 UTC == 2026-07-01 00:00 IST.
      expect(todayIST(DateTime.utc(2026, 6, 30, 18, 30, 0)),
          (year: 2026, month: 7, day: 1));
    });

    test('year roll over across IST midnight', () {
      // 2026-12-31 18:30 UTC == 2027-01-01 00:00 IST.
      expect(todayIST(DateTime.utc(2026, 12, 31, 18, 30, 0)),
          (year: 2027, month: 1, day: 1));
    });

    test('leap day: IST date of 29 Feb exists as expected', () {
      // 2028-02-28 18:30 UTC == 2028-02-29 00:00 IST (2028 is a leap year).
      expect(todayIST(DateTime.utc(2028, 2, 28, 18, 30, 0)),
          (year: 2028, month: 2, day: 29));
    });

    test('DST is irrelevant: IST is a fixed +05:30 offset year-round', () {
      // During the US DST shift (March 2026) IST still moves +05:30.
      expect(todayIST(DateTime.utc(2026, 3, 8, 9, 30, 0)), // 15:00 IST
          (year: 2026, month: 3, day: 8));
      expect(todayIST(DateTime.utc(2026, 11, 1, 9, 30, 0)), // 15:00 IST
          (year: 2026, month: 11, day: 1));
    });

    test('non-IST device times: fixed-offset DateTime input is normalised',
        () {
      // A device in UTC-5 reporting 23:45 local == 04:45 UTC == 10:15 IST,
      // still same IST day 2026-06-16.
      final deviceTime = DateTime.parse('2026-06-15T23:45:00-05:00');
      expect(todayIST(deviceTime), (year: 2026, month: 6, day: 16));

      // A device far ahead (UTC+14) reporting 03:00 on the 16th local ==
      // 13:00 UTC on the 15th == 18:30 IST on the 15th.
      final aheadDevice = DateTime.parse('2026-06-16T03:00:00+14:00');
      expect(todayIST(aheadDevice), (year: 2026, month: 6, day: 15));
    });
  });

  group('todayIsoIST', () {
    test('formats yyyy-MM-dd, zero padded', () {
      expect(todayIsoIST(DateTime.utc(2026, 6, 16, 4, 0, 0)), '2026-06-16');
      expect(todayIsoIST(DateTime.utc(2026, 1, 5, 4, 0, 0)), '2026-01-05');
    });

    test('same instant as UTC-midnight boundary test', () {
      expect(todayIsoIST(DateTime.utc(2026, 6, 15, 18, 30, 0)), '2026-06-16');
    });
  });

  group('isSameDayIST', () {
    test('instants across IST midnight on the same UTC day differ', () {
      final before = DateTime.utc(2026, 6, 15, 18, 29, 59);
      final after = DateTime.utc(2026, 6, 15, 18, 30, 1);
      expect(isSameDayIST(before, after), isFalse);
    });

    test('two afternoon instants on the same IST day match', () {
      expect(isSameDayIST(DateTime.utc(2026, 6, 15, 4, 0, 0),
          DateTime.utc(2026, 6, 15, 12, 0, 0)), isTrue);
    });

    test('23 hours apart but different IST days → false', () {
      expect(isSameDayIST(DateTime.utc(2026, 6, 15, 18, 30, 0),
          DateTime.utc(2026, 6, 15, 10, 30, 0)), isFalse);
    });

    test('next calendar day same clock time → false', () {
      expect(isSameDayIST(DateTime.utc(2026, 6, 15, 6, 0, 0),
          DateTime.utc(2026, 6, 16, 6, 0, 0)), isFalse);
    });
  });

  group('wasCreatedTodayIST', () {
    test('complaint created this morning counts as today', () {
      final now = DateTime.utc(2026, 6, 15, 8, 0, 0); // 13:30 IST
      final createdAt = DateTime.utc(2026, 6, 15, 3, 30, 0); // 09:00 IST
      expect(wasCreatedTodayIST(createdAt, now), isTrue);
    });

    test('complaint created yesterday IST (last evening UTC) does not', () {
      final now = DateTime.utc(2026, 6, 15, 3, 30, 0); // 09:00 IST on the 15th
      final createdAt = DateTime.utc(2026, 6, 14, 14, 0, 0); // 19:30 IST on the 14th
      expect(wasCreatedTodayIST(createdAt, now), isFalse);
    });

    test('created seconds before IST midnight is "yesterday" by now', () {
      final createdAt = DateTime.utc(2026, 6, 15, 18, 29, 59);
      final now = DateTime.utc(2026, 6, 15, 18, 30, 0); // 00:00 IST on the 16th
      expect(wasCreatedTodayIST(createdAt, now), isFalse);
    });
  });

  group('minutesAgoIST', () {
    test('whole minutes floored', () {
      final now = DateTime.utc(2026, 6, 15, 8, 0, 0);
      expect(minutesAgoIST(now.subtract(const Duration(seconds: 90)), now), 1);
      expect(minutesAgoIST(now.subtract(const Duration(minutes: 17)), now), 17);
    });

    test('future instant clamps to zero', () {
      final now = DateTime.utc(2026, 6, 15, 8, 0, 0);
      expect(
          minutesAgoIST(now.add(const Duration(minutes: 5)), now), 0);
    });

    test('same instant is zero', () {
      final now = DateTime.utc(2026, 6, 15, 8, 0, 0);
      expect(minutesAgoIST(now, now), 0);
    });
  });

  group('utcStartOfIstDay', () {
    test('is exactly 18:30 UTC of the previous UTC day', () {
      final now = DateTime.utc(2026, 6, 15, 8, 0, 0); // 13:30 IST on the 15th
      final start = utcStartOfIstDay(now);
      expect(start, DateTime.utc(2026, 6, 14, 18, 30, 0));
    });

    test('just after IST midnight: start is 30 min before now', () {
      final now = DateTime.utc(2026, 6, 15, 18, 30, 30);
      expect(utcStartOfIstDay(now), DateTime.utc(2026, 6, 15, 18, 30, 0));
    });

    test('createdAt exactly at start counts as today', () {
      final now = DateTime.utc(2026, 6, 15, 8, 0, 0);
      final start = utcStartOfIstDay(now);
      expect(wasCreatedTodayIST(start, now), isTrue);
    });
  });
}

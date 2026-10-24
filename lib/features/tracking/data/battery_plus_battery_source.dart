/// Real battery_plus-backed battery source (F-D8: read battery every check,
/// feed it into the Write Policy).
library;

import 'package:battery_plus/battery_plus.dart';

import '../domain/battery_source.dart';

class BatteryPlusBatterySource implements BatterySource {
  final Battery _battery = Battery();

  @override
  Future<int?> readBatteryPct() async {
    final level = await _battery.batteryLevel;
    // BatteryPlus reports -1 when unavailable.
    if (level < 0) return null;
    return level;
  }
}

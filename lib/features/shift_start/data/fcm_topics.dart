/// FCM topic naming + the messaging seam for the shift feature (PRD-2
/// 0.6.6: the driver app subscribes to `van_{vanId}` after shift start).
///
/// Moved here from `verify_driver_pin.dart` (ticket 7, old-D1 deletion) so
/// neither `fcmTopicVanOf` nor `driverMessagingGatewayProvider` lives in the
/// deleted PIN-verification file. `fcmTopicAll` stays in
/// `firebase_bootstrap.dart`.
library;

import 'package:driverapp/core/config/firebase_bootstrap.dart'
    show FirebaseMessagingGateway, MessagingGateway;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// FCM topic for one van (PRD-2 0.6.6).
String fcmTopicVanOf(String vanId) => 'van_$vanId';

/// Messaging seam reuse (topic `van_{vanId}` subscription after start).
final Provider<MessagingGateway> driverMessagingGatewayProvider =
    Provider<MessagingGateway>((ref) => const FirebaseMessagingGateway());

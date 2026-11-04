/// Riverpod wiring for the callable seam (02-contracts/callables.json).
///
/// Feature tests never touch this file: they override both providers with
/// scripted fakes (test/repositories/fake_repositories.dart), exactly like the
/// repository spine.
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_callables.dart';
import 'shift_gateway.dart';

/// The driver's bind + custom-token sign-in.
final driverSessionGatewayProvider = Provider<DriverSessionGateway>(
  (ref) => FirebaseDriverSessionGateway(
    FirebaseFunctions.instance,
    FirebaseAuth.instance,
  ),
);

/// `startShift`, `endShift`, `markWardDone`.
final shiftGatewayProvider = Provider<ShiftGateway>(
  (ref) => FirebaseShiftGateway(FirebaseFunctions.instance),
);

/// connectivity_plus-backed [ConnectivitySource]: the real platform adapter
/// for the offline sync service (F-D7). Android only per the contract (0.6);
/// `none`/`unknown` count as offline, every other interface as online.
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../connectivity_source.dart';

class ConnectivityPlusSource implements ConnectivitySource {
  ConnectivityPlusSource([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Stream<bool> get status {
    late StreamController<bool> controller;
    StreamSubscription<List<ConnectivityResult>>? subscription;
    controller = StreamController<bool>(
      onListen: () {
        // Current state first (source contract), then changes.
        _connectivity.checkConnectivity().then(
          (results) => controller.add(_online(results)),
        );
        subscription ??= _connectivity.onConnectivityChanged.listen(
          (results) => controller.add(_online(results)),
        );
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  bool _online(List<ConnectivityResult> results) =>
      results.isNotEmpty &&
      results.any(
        (result) =>
            result != ConnectivityResult.none &&
            result != ConnectivityResult.other,
      );
}

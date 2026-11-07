/// FCM tap routing (B-21).
///
/// A tap can land in two states:
/// 1. The app is running and the user taps the tray notification
///    (`onMessageOpenedApp`).
/// 2. The app is terminated and the tap launches it (`getInitialMessage`).
///
/// In both cases the destination is the notices inbox, opened at the pushed
/// notice id. The app may not have a shift session yet on a cold launch, so a
/// tap is held until the session exists instead of being dropped.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/notices/ui/notices_screen.dart';
import '../../features/shift_start/domain/shift_session.dart';
import '../navigation/app_navigator.dart';
import 'push_notifications.dart';

final Provider<PushTapRouter> pushTapRouterProvider =
    Provider<PushTapRouter>(PushTapRouter.new);

final class PushTapRouter {
  PushTapRouter(this._ref);

  final Ref _ref;

  StreamSubscription<PushMessage>? _tapSub;

  /// A tapped notice id waiting for a navigator and a running shift.
  String? _pendingNoticeId;

  /// Wires the tap streams once. Safe to call again after a retry.
  void start() {
    if (_tapSub != null) return;
    final gateway = _ref.read(pushGatewayProvider);
    _tapSub = gateway.onOpened.listen(_onTap);
    unawaited(
      gateway.initialMessage().then((message) {
        if (message != null) _onTap(message);
      }),
    );
    _ref.listen<ShiftSession?>(
      shiftControllerProvider,
      (previous, next) {
        if (next != null) _flush();
      },
      fireImmediately: true,
    );
  }

  void _onTap(PushMessage message) {
    _pendingNoticeId = message.noticeId;
    _flush();
  }

  void _flush() {
    final noticeId = _pendingNoticeId;
    if (noticeId == null) return;
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      // A cold-launch tap can beat the first frame. Retry on the next frame
      // instead of dropping it.
      WidgetsBinding.instance.addPostFrameCallback((_) => _flush());
      return;
    }
    if (_ref.read(shiftControllerProvider) == null) return;
    _pendingNoticeId = null;
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => NoticesScreen(initialNoticeId: noticeId),
        ),
      ),
    );
  }
}

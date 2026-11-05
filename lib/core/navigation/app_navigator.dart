/// The app's single navigator key.
///
/// Push taps arrive OUTSIDE the widget tree (`onMessageOpenedApp` and
/// `getInitialMessage`), so the router needs a navigator handle without a
/// BuildContext. `main()` hands this key to `MaterialApp`.
library;

import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> appNavigatorKey =
    GlobalKey<NavigatorState>();

import 'package:arrowtapout/router/routes.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Navigation utilities ensuring safe back-stack unwinding across ArrowZ.
abstract final class NavUtils {
  /// Pops if there is a previous route in the stack; otherwise transitions safely
  /// to [fallbackRoute] (defaulting to [Routes.home]).
  static void safeBack(BuildContext context, {String fallbackRoute = Routes.home}) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(fallbackRoute);
    }
  }
}

/// Extension on [BuildContext] for ergonomic SafeBack invocation.
extension SafeBackExtension on BuildContext {
  void safeBack({String fallbackRoute = Routes.home}) {
    NavUtils.safeBack(this, fallbackRoute: fallbackRoute);
  }
}

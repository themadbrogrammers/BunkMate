import 'package:flutter/widgets.dart';

class AppVisibilityService extends RouteAware with WidgetsBindingObserver {
  static final AppVisibilityService instance = AppVisibilityService._internal();
  bool _observerAttached = false;
  VoidCallback? onRouteVisible;

  AppVisibilityService._internal() {
    if (!_observerAttached) {
      WidgetsBinding.instance.addObserver(this);
      _observerAttached = true;
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  bool _routeVisible = true;
  bool _appForeground = true;

  bool get isRouteVisible => _routeVisible && _appForeground;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appForeground = state == AppLifecycleState.resumed;
  }

  void subscribe(
    RouteObserver<PageRoute<dynamic>> observer,
    PageRoute<dynamic> route,
  ) {
    observer.subscribe(this, route);
  }

  void unsubscribe(RouteObserver<PageRoute<dynamic>> observer) {
    observer.unsubscribe(this);
  }

  @override
  void didPopNext() {
    _routeVisible = true;
    onRouteVisible?.call();
  }

  @override
  void didPush() {
    _routeVisible = true;
    onRouteVisible?.call();
  }

  @override
  void didPushNext() => _routeVisible = false;

  @override
  void didPop() => _routeVisible = false;
}

import 'package:flutter/widgets.dart';
import 'package:bunkmate/services/ad_service.dart';
import 'package:bunkmate/providers/ad_provider.dart';
import 'package:provider/provider.dart';

class AdLifecycleObserver with WidgetsBindingObserver {
  final BuildContext context;
  bool _backgrounded = false;

  AdLifecycleObserver(this.context) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _backgrounded = true;
      return;
    }

    if (state == AppLifecycleState.resumed && _backgrounded) {
      _backgrounded = false;

      context.read<AdProvider>().resetSession();
      AdService.instance.onAppResumed(context);
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}

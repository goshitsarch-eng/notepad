import 'package:flutter/foundation.dart';

import 'result.dart';

/// Runs one async action that takes an argument and exposes whether it is running
/// and what it last returned. View models call [execute] instead of talking to
/// repositories directly, as the Flutter architecture guide recommends for UI events.
class Command1<T, A> extends ChangeNotifier {
  Command1(this._action);

  final Future<Result<T>> Function(A argument) _action;
  bool _running = false;
  Result<T>? _last;

  bool get running => _running;
  Result<T>? get last => _last;

  /// Runs the action. Returns null without starting if a run is already in progress.
  Future<Result<T>?> execute(A argument) async {
    if (_running) return null;
    _running = true;
    notifyListeners();
    try {
      final result = await _action(argument);
      _last = result;
      return result;
    } finally {
      _running = false;
      notifyListeners();
    }
  }
}

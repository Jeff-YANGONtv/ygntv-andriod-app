import 'package:flutter/foundation.dart';

import 'auth_service.dart';

class AuthController extends ChangeNotifier {
  AuthController(this.service);

  final AuthService service;
  AuthSession? session;
  bool busy = false;
  bool ready = false;

  Future<void> restore() async {
    try {
      session = await service.restoreSession();
    } catch (_) {
      session = null;
    }
    ready = true;
    notifyListeners();
  }

  Future<String?> signIn(String email, String password) =>
      _run(() => service.signIn(email, password));

  Future<String?> signUp(String name, String email, String password) =>
      _run(() => service.signUp(name, email, password));

  Future<String?> signInWithGoogle() => _run(service.signInWithGoogle);

  Future<String?> signInWithTelegram() => _run(service.signInWithTelegram);

  Future<String?> _run(Future<AuthSession> Function() action) async {
    if (busy) return 'Please wait for the current request to finish.';
    busy = true;
    notifyListeners();
    try {
      session = await action();
      return null;
    } catch (error) {
      return error.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await service.logout();
    } catch (_) {
      // Clear the local secure session even if the server cannot be reached.
    }
    await service.clearSession();
    session = null;
    notifyListeners();
  }
}

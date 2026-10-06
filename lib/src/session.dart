import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api.dart';
import 'config.dart';

class Session extends ChangeNotifier {
  Session(this.api);
  final ApiClient api;
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'intention_mobile_token';

  bool booting = true;
  bool busy = false;
  Map<String, dynamic>? profile;

  bool get signedIn => profile != null;
  Map<String, dynamic> get user => Map<String, dynamic>.from(profile?['user'] as Map? ?? const {});
  String get role => '${user['role'] ?? ''}';

  bool get roleAllowed => AppConfig.requiredRole.isEmpty || role == AppConfig.requiredRole;

  Future<void> _clearLocalSession() async {
    api.token = null;
    profile = null;
    await _storage.delete(key: _tokenKey);
  }

  Future<void> bootstrap() async {
    try {
      final saved = await _storage.read(key: _tokenKey);
      if (saved != null && saved.isNotEmpty) {
        api.token = saved;
        try {
          profile = Map<String, dynamic>.from(await api.get('me') as Map);
          if (!roleAllowed) await _clearLocalSession();
        } on ApiException catch (e) {
          if (e.statusCode == 401) await _clearLocalSession();
        }
      }
    } finally {
      booting = false;
      notifyListeners();
    }
  }

  Future<void> login(String login, String password, String deviceName) async {
    busy = true;
    notifyListeners();
    try {
      final data = Map<String, dynamic>.from(await api.post('auth/login', body: {
        'login': login,
        'password': password,
        'device_name': deviceName,
      }) as Map);
      final token = '${data['token'] ?? ''}';
      if (token.isEmpty) throw ApiException('Token олинмади.');
      api.token = token;
      await _storage.write(key: _tokenKey, value: token);
      profile = Map<String, dynamic>.from(await api.get('me') as Map);
      if (!roleAllowed) {
        final actualRole = role;
        try { await api.post('auth/logout'); } catch (_) {}
        await _clearLocalSession();
        throw ApiException('Бу илова фақат ${AppConfig.requiredRole} роли учун. Киритилган аккаунт роли: $actualRole.');
      }
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> refreshProfile() async {
    if (api.token == null) return;
    profile = Map<String, dynamic>.from(await api.get('me') as Map);
    if (!roleAllowed) await _clearLocalSession();
    notifyListeners();
  }

  Future<void> logout() async {
    busy = true;
    notifyListeners();
    try {
      try { if (api.token != null) await api.post('auth/logout'); } catch (_) {}
      await _clearLocalSession();
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}

class SessionScope extends InheritedNotifier<Session> {
  const SessionScope({super.key, required Session session, required super.child}) : super(notifier: session);
  static Session of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SessionScope>()!.notifier!;
}

import 'package:shared_preferences/shared_preferences.dart';
import 'package:vision_app/core/services/keycloack_auth_service.dart';

class LocalStorageService {
  static const _accessKey = 'kc_access_token';
  static const _refreshKey = 'kc_refresh_token';
  static const _idKey = 'kc_id_token';
  static const _expKey = 'kc_expires_at';

  Future<void> saveTokens(AuthToken t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, t.accessToken);
    await prefs.setString(_refreshKey, t.refreshToken);
    await prefs.setString(_idKey, t.idToken);
    await prefs.setInt(_expKey, t.expiresAt.millisecondsSinceEpoch);
  }
  Future<AuthToken?> loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    final access = prefs.getString(_accessKey);
    final refresh = prefs.getString(_refreshKey);
    final id = prefs.getString(_idKey) ?? '';
    final expMs = prefs.getInt(_expKey);

    if (access == null || refresh == null || expMs == null) return null;

    return AuthToken(
      accessToken: access,
      refreshToken: refresh,
      idToken: id,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expMs),
    );
  }

  Future<void> clear() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_accessKey);
      await prefs.remove(_refreshKey);
      await prefs.remove(_idKey);
      await prefs.remove(_expKey);
  }

}
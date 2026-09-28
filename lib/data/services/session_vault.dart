import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Platform vault for the opaque session secret (Keychain / Keystore /
/// libsecret / DPAPI via flutter_secure_storage). Never log key values.
abstract class SessionVault {
  Future<String?> readSessionToken();
  Future<void> writeSessionToken(String token);
  Future<DateTime?> readExpiresAt();
  Future<void> writeExpiresAt(DateTime expiresAt);
  Future<String> deviceId();
  Future<void> clearSession();

  /// Optional manager backup for future act-as return (not used in baseline UI).
  Future<String?> readManagerBackupToken();
  Future<void> writeManagerBackupToken(String token);
  Future<void> clearManagerBackupToken();
}

const _kSessionToken = 'stitch_session_token';
const _kExpiresAt = 'stitch_session_expires_at';
const _kDeviceId = 'stitch_device_id';
const _kMgrBackup = 'stitch_mgr_session_token';

class SecureSessionVault implements SessionVault {
  SecureSessionVault({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readSessionToken() => _storage.read(key: _kSessionToken);

  @override
  Future<void> writeSessionToken(String token) =>
      _storage.write(key: _kSessionToken, value: token);

  @override
  Future<DateTime?> readExpiresAt() async {
    final raw = await _storage.read(key: _kExpiresAt);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  @override
  Future<void> writeExpiresAt(DateTime expiresAt) =>
      _storage.write(key: _kExpiresAt, value: expiresAt.toUtc().toIso8601String());

  @override
  Future<String> deviceId() async {
    final existing = await _storage.read(key: _kDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = const Uuid().v4();
    await _storage.write(key: _kDeviceId, value: id);
    return id;
  }

  @override
  Future<void> clearSession() async {
    await _storage.delete(key: _kSessionToken);
    await _storage.delete(key: _kExpiresAt);
  }

  @override
  Future<String?> readManagerBackupToken() => _storage.read(key: _kMgrBackup);

  @override
  Future<void> writeManagerBackupToken(String token) =>
      _storage.write(key: _kMgrBackup, value: token);

  @override
  Future<void> clearManagerBackupToken() => _storage.delete(key: _kMgrBackup);
}

/// In-memory vault for unit tests.
class InMemorySessionVault implements SessionVault {
  String? sessionToken;
  DateTime? expiresAt;
  String? managerBackup;
  final String _deviceId = 'test-device-id';

  @override
  Future<String?> readSessionToken() async => sessionToken;

  @override
  Future<void> writeSessionToken(String token) async => sessionToken = token;

  @override
  Future<DateTime?> readExpiresAt() async => expiresAt;

  @override
  Future<void> writeExpiresAt(DateTime value) async => expiresAt = value;

  @override
  Future<String> deviceId() async => _deviceId;

  @override
  Future<void> clearSession() async {
    sessionToken = null;
    expiresAt = null;
  }

  @override
  Future<String?> readManagerBackupToken() async => managerBackup;

  @override
  Future<void> writeManagerBackupToken(String token) async => managerBackup = token;

  @override
  Future<void> clearManagerBackupToken() async => managerBackup = null;
}

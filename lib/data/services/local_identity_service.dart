import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/auth_state.dart';
import '../repositories/auth_repository.dart';

/// Resolves "who am I" independent of cloud auth state — the identity axis
/// is orthogonal to the session axis. A local-only user still has a stable
/// id: generated once on first launch and persisted to a plain file (no
/// schema/migration needed for a single scalar), never requiring network
/// access.
///
/// When cloud auth is active (`authenticatedOnline`), [currentUserId] prefers
/// the live cloud subject uid so message stamping / "is this me" checks align
/// with the backend principal.
///
/// After the first successful cloud login, the subject uid is written to disk
/// and kept when the session ends (logout, 401, expired token). Offline or
/// unauthenticated chat then still treats that uid as "me" so promoted messages
/// stay labeled "You" and new sends stay on the canonical cloud author id.
class LocalIdentityService {
  static const _localFileName = 'local_identity_id.txt';
  static const _cloudFileName = 'cloud_user_id.txt';

  String? _localUserId;
  String? _persistedCloudUserId;
  Directory? _supportDirectory;
  AuthRepository? _auth;

  /// Wire cloud session so [currentUserId] / [authenticatedOnline] stay in sync.
  /// Safe to call once after constructing [AuthRepository]; replaces any prior bind.
  void bindAuthRepository(AuthRepository auth) {
    _auth?.removeListener(_onAuthChanged);
    _auth = auth;
    auth.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    final auth = _auth;
    if (auth == null) return;
    if (auth.state.status != AuthStatus.authenticated) return;
    final cloud = auth.state.cloudUserId;
    if (cloud == null || cloud.isEmpty) return;
    _rememberCloudUserId(cloud);
  }

  void _rememberCloudUserId(String cloudUserId) {
    if (_persistedCloudUserId == cloudUserId) return;
    _persistedCloudUserId = cloudUserId;
    final dir = _supportDirectory;
    if (dir == null) return;
    final file = File(p.join(dir.path, _cloudFileName));
    file.writeAsString(cloudUserId).ignore();
  }

  bool get authenticatedOnline =>
      _auth?.state.status == AuthStatus.authenticated &&
      (_auth?.state.cloudUserId?.isNotEmpty ?? false);

  /// Stable local-only id (never the cloud uid). Useful for migrations / debug.
  String get localUserId {
    final id = _localUserId;
    if (id == null) {
      throw StateError('LocalIdentityService.initialize() must complete before localUserId is read');
    }
    return id;
  }

  /// Effective author id for stamping and "You" labels: live cloud subject when
  /// signed in, else last known cloud uid after a prior login, else local.
  String get currentUserId {
    if (authenticatedOnline) {
      return _auth!.state.cloudUserId!;
    }
    final persisted = _persistedCloudUserId;
    if (persisted != null && persisted.isNotEmpty) {
      return persisted;
    }
    return localUserId;
  }

  Future<void> initialize({Directory? supportDirectory}) async {
    final supportDir = supportDirectory ?? await getApplicationSupportDirectory();
    _supportDirectory = supportDir;
    final cloudFile = File(p.join(supportDir.path, _cloudFileName));
    if (await cloudFile.exists()) {
      final id = (await cloudFile.readAsString()).trim();
      if (id.isNotEmpty) _persistedCloudUserId = id;
    }
    final file = File(p.join(supportDir.path, _localFileName));
    if (await file.exists()) {
      _localUserId = (await file.readAsString()).trim();
      return;
    }
    final id = const Uuid().v4();
    await file.create(recursive: true);
    await file.writeAsString(id);
    _localUserId = id;
  }

  void dispose() {
    _auth?.removeListener(_onAuthChanged);
    _auth = null;
  }
}

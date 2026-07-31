import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Resolves "who am I" independent of cloud auth state — the identity axis
/// is orthogonal to the session axis (`docs/plans/cloud-sync.md`'s
/// `CloudSessionState`). A local-only user still has a stable id: generated
/// once on first launch and persisted to a plain file (no schema/migration
/// needed for a single scalar), never requiring network access.
///
/// When cloud auth lands, this becomes the seam where `currentUserId`
/// resolves to the cloud-assigned user id instead once `authenticatedOnline`
/// — same interface, callers (message stamping, "is this me" checks in the
/// UI) don't change.
class LocalIdentityService {
  static const _fileName = 'local_identity_id.txt';

  String? _userId;

  String get currentUserId {
    final id = _userId;
    if (id == null) {
      throw StateError('LocalIdentityService.initialize() must complete before currentUserId is read');
    }
    return id;
  }

  Future<void> initialize() async {
    final supportDir = await getApplicationSupportDirectory();
    final file = File(p.join(supportDir.path, _fileName));
    if (await file.exists()) {
      _userId = (await file.readAsString()).trim();
      return;
    }
    final id = const Uuid().v4();
    await file.create(recursive: true);
    await file.writeAsString(id);
    _userId = id;
  }
}

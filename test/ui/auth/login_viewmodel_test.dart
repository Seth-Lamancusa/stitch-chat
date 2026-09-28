import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_chat/core/notifications/notification_service.dart';
import 'package:stitch_chat/data/repositories/fake_auth_repository.dart';
import 'package:stitch_chat/data/services/local_identity_service.dart';
import 'package:stitch_chat/ui/auth/login_viewmodel.dart';

void main() {
  group('LocalIdentityService cloud seam', () {
    test('currentUserId stays local until authenticatedOnline', () async {
      final identity = LocalIdentityService();
      final auth = FakeAuthRepository();
      identity.bindAuthRepository(auth);

      final dir = await Directory.systemTemp.createTemp('stitch_identity_');
      addTearDown(() => dir.delete(recursive: true));
      await identity.initialize(supportDirectory: dir);

      final local = identity.localUserId;
      expect(identity.authenticatedOnline, isFalse);
      expect(identity.currentUserId, local);

      await auth.login(identifier: 'alice', password: 'x');
      expect(identity.authenticatedOnline, isTrue);
      expect(identity.currentUserId, 'actor-1');
      expect(identity.localUserId, local);

      await auth.logout();
      expect(identity.authenticatedOnline, isFalse);
      expect(identity.currentUserId, 'actor-1');

      await auth.handleUnauthorized();
      expect(identity.currentUserId, 'actor-1');
      expect(identity.localUserId, local);
    });

    test('persisted cloud id reloads on next launch without session', () async {
      final dir = await Directory.systemTemp.createTemp('stitch_identity_');
      addTearDown(() => dir.delete(recursive: true));

      final auth = FakeAuthRepository();
      final identity = LocalIdentityService();
      await identity.initialize(supportDirectory: dir);
      identity.bindAuthRepository(auth);
      await auth.login(identifier: 'alice', password: 'x');
      expect(identity.currentUserId, 'actor-1');

      final relaunch = LocalIdentityService();
      await relaunch.initialize(supportDirectory: dir);
      relaunch.bindAuthRepository(FakeAuthRepository());
      expect(relaunch.authenticatedOnline, isFalse);
      expect(relaunch.currentUserId, 'actor-1');
    });
  });

  group('LoginViewModel', () {
    test('login success and failure surface via notifications', () async {
      final auth = FakeAuthRepository();
      final notifications = NotificationService();
      final vm = LoginViewModel(authRepository: auth, notifications: notifications);

      await vm.init();
      expect(vm.authReady, isTrue);

      final ok = await vm.login(identifier: 'alice', password: 'x');
      expect(ok, isTrue);
      expect(vm.isAuthenticated, isTrue);
      expect(notifications.toasts, isNotEmpty);

      auth.loginShouldFail = true;
      final fail = await vm.login(identifier: 'alice', password: 'bad');
      expect(fail, isFalse);
      expect(vm.formError, isNotNull);

      vm.dispose();
    });

    test('onAuthenticated runs after successful login', () async {
      final auth = FakeAuthRepository();
      final notifications = NotificationService();
      var calls = 0;
      final vm = LoginViewModel(
        authRepository: auth,
        notifications: notifications,
        onAuthenticated: () async {
          calls++;
        },
      );

      await vm.init();
      expect(calls, 0);

      await vm.login(identifier: 'alice', password: 'x');
      expect(calls, 1);
      vm.dispose();
    });

    test('onAuthenticated runs after init when session already authenticated', () async {
      final auth = FakeAuthRepository();
      await auth.login(identifier: 'alice', password: 'x');
      var calls = 0;
      final vm = LoginViewModel(
        authRepository: auth,
        notifications: NotificationService(),
        onAuthenticated: () async {
          calls++;
        },
      );

      await vm.init();
      // FakeAuthRepository.init leaves authenticated state as-is.
      expect(calls, 1);
      vm.dispose();
    });

    test('forced unauthorized notifies error toast', () async {
      final auth = FakeAuthRepository();
      final notifications = NotificationService();
      final vm = LoginViewModel(authRepository: auth, notifications: notifications);
      await vm.login(identifier: 'alice', password: 'x');
      notifications.dismiss(notifications.toasts.first.id);

      await auth.handleUnauthorized();
      expect(vm.isAuthenticated, isFalse);
      expect(
        notifications.toasts.any((n) => n.message.contains('expired')),
        isTrue,
      );
      vm.dispose();
    });
  });
}

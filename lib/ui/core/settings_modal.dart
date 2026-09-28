import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/settings/theme_service.dart';
import '../../data/models/auth_state.dart';
import '../auth/login_screen.dart';
import '../auth/login_viewmodel.dart';

/// Sizing/structure ported from file-tile's settings modal: a centered
/// [Dialog] capped at a third of the window width and 80% of its height,
/// rounded, with a fixed header/footer around a scrollable body — so future
/// settings sections drop into the same scaffold instead of resizing the
/// dialog per-section.
void showSettingsModal(BuildContext context) {
  final rootContext = context;
  showDialog(
    context: context,
    builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      return Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.33,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Material(
              color: colorScheme.surface,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Settings',
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Account', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                            const SizedBox(height: 12),
                            Consumer<LoginViewModel>(
                              builder: (context, loginVm, _) {
                                final auth = loginVm.state;
                                if (auth.status == AuthStatus.bootstrapping) {
                                  return const ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text('Checking cloud session…'),
                                    dense: true,
                                  );
                                }
                                if (auth.isAuthenticated) {
                                  final label = auth.profile?.userTag ??
                                      auth.subject?.userTag ??
                                      auth.cloudUserId ??
                                      'Signed in';
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text('@$label', style: TextStyle(color: colorScheme.onSurface)),
                                    subtitle: Text(
                                      auth.delegated ? 'Delegated cloud session' : 'Cloud session',
                                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                                    ),
                                    trailing: TextButton(
                                      onPressed: loginVm.busy
                                          ? null
                                          : () async {
                                              await loginVm.logout();
                                            },
                                      child: const Text('Sign out'),
                                    ),
                                  );
                                }
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('Not signed in', style: TextStyle(color: colorScheme.onSurface)),
                                  subtitle: Text(
                                    'Local chat works offline. Sign in for cloud sync.',
                                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                                  ),
                                  trailing: TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      showLoginModal(rootContext);
                                    },
                                    child: const Text('Sign in'),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                            Text('Appearance', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                            const SizedBox(height: 12),
                            Consumer<ThemeService>(
                              builder: (context, themeService, _) => SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('Dark Mode', style: TextStyle(color: colorScheme.onSurface)),
                                value: themeService.isDarkMode,
                                onChanged: themeService.setDarkMode,
                                activeThumbColor: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

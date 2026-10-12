import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stitch_chat/core/settings/message_font_service.dart';
import 'package:stitch_chat/data/services/cloud_user_directory.dart';
import 'package:stitch_chat/data/services/session_vault.dart';
import 'package:stitch_chat/data/services/stitch_http_client.dart';
import 'package:stitch_chat/ui/columns/column_view.dart';
import 'package:stitch_chat/ui/columns/columns_viewmodel.dart';

import 'message_font_test_helper.dart';

/// Providers required by [ColumnView] / composer / message list in widget tests.
class ColumnViewTestProviders extends StatelessWidget {
  const ColumnViewTestProviders({
    super.key,
    required this.vm,
    required this.messageFontService,
    required this.child,
  });

  final ColumnsViewModel vm;
  final MessageFontService messageFontService;
  final Widget child;

  static Future<ColumnViewTestProviders> wrap({
    required ColumnsViewModel vm,
    required Widget child,
  }) async {
    ColumnView.debugSuppressComposerAutoFocus = true;
    final fonts = await createTestMessageFontService();
    return ColumnViewTestProviders(
      vm: vm,
      messageFontService: fonts,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final http = StitchHttpClient(
      baseUrl: 'http://127.0.0.1:1',
      vault: InMemorySessionVault(),
    );
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ColumnsViewModel>.value(value: vm),
        ChangeNotifierProvider<MessageFontService>.value(value: messageFontService),
        Provider<CloudUserDirectory>.value(value: CloudUserDirectory(http)),
      ],
      child: child,
    );
  }
}

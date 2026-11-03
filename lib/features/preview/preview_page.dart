import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../render/render_page.dart';

/// Minimal no-shell host for SDUI pages (dev/preview builds with [kDevNoAuth]).
/// Outside UuimsShell so a missing auth profile does not spin forever.
class PreviewPage extends StatelessWidget {
  const PreviewPage({super.key, required this.page, this.params = const {}});

  final String page;
  final Map<String, String> params;

  @override
  Widget build(BuildContext context) {
    final t = ShadTheme.of(context);
    return Scaffold(
      backgroundColor: t.colorScheme.background,
      appBar: AppBar(
        title: Text(page, style: t.textTheme.large),
        backgroundColor: t.colorScheme.background,
        foregroundColor: t.colorScheme.foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: RenderPage(page: page, params: params),
      ),
    );
  }
}

import 'package:flutter/material.dart';

typedef LibraryLoader = Future<void> Function();

/// Loads a deferred library once, then builds [builder].
/// Share one [loader] future across routes so ShellRoute + child do not double-fetch.
class DeferredPage extends StatefulWidget {
  const DeferredPage({
    super.key,
    required this.loader,
    required this.builder,
    this.placeholder,
  });

  final LibraryLoader loader;
  final WidgetBuilder builder;
  final Widget? placeholder;

  @override
  State<DeferredPage> createState() => _DeferredPageState();
}

class _DeferredPageState extends State<DeferredPage> {
  late final Future<void> _future = widget.loader();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SelectableText('Failed to load page:\n${snapshot.error}'),
              ),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return widget.placeholder ??
              const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return widget.builder(context);
      },
    );
  }
}

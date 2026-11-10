/// Post-auth / non-login pages for web deferred splitting.
///
/// Imported from [router.dart] with `deferred as` so login/splash/callback stay in the
/// main JS chunk; shell + render (charts/tables/forms) load on first authenticated route.
library;

export '../features/health/health_page.dart';
export '../features/preview/preview_page.dart';
export '../features/shell/admin_shell.dart';
export '../render/menu_route_page.dart';
export '../render/render_page.dart';
export '../widgets/common.dart' show ForbiddenPage, NotFoundPage;

import '../features/system/role_permission_editor.dart';

bool _ready = false;

/// Idempotent bootstrap after [loadLibrary] (registers RENDER.md custom pages).
void ensurePostAuthReady() {
  if (_ready) return;
  registerSystemCustomPages();
  _ready = true;
}

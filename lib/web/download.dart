/// Cross-platform entry point for triggering a browser file download.
///
/// The real implementation ([download_web.dart]) uses `dart:js_interop` /
/// `package:web` and is selected only when those libraries exist (i.e. a web
/// build). On the Dart VM (unit/widget tests) the stub is used instead, so a
/// page that offers a download stays testable without pulling in web-only code.
library;

export 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart';

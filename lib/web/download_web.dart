import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Trigger a browser download of [content] as a file named [filename].
///
/// Web-only: this file is imported solely from the web viewer entrypoint
/// (`lib/main_web.dart`), so its `dart:js_interop` / `package:web` use never
/// reaches the mobile app build.
void downloadText(
  String filename,
  String content, {
  String mime = 'text/plain;charset=utf-8',
}) {
  final bytes = Uint8List.fromList(utf8.encode(content));
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mime),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  anchor.click();
  web.URL.revokeObjectURL(url);
}

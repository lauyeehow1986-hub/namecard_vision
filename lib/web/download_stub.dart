/// Non-web fallback for [downloadText]. The web viewer only ever runs in a
/// browser, so this exists solely to let VM unit/widget tests compile a page
/// that references the download; it is never expected to be called.
void downloadText(
  String filename,
  String content, {
  String mime = 'text/plain;charset=utf-8',
}) {
  throw UnsupportedError('downloadText is only available on the web.');
}

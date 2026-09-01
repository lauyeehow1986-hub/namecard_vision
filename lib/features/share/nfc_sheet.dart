import 'package:flutter/material.dart';

import '../../model/card.dart';
import '../../share/nfc_share.dart';

/// Present the "hold your phone near the other device" sheet to send [card]
/// over NFC. Returns when the user dismisses it; the session is always stopped.
Future<void> showNfcSend(BuildContext context, NameCard card) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: true,
    showDragHandle: true,
    builder: (_) => _NfcRunner(mode: _NfcMode.send, card: card),
  );
}

/// Present the NFC receive sheet. Resolves to the decoded card once a tag is
/// tapped, or null if the user dismisses first.
Future<NameCard?> showNfcReceive(BuildContext context) {
  return showModalBottomSheet<NameCard?>(
    context: context,
    isDismissible: true,
    showDragHandle: true,
    builder: (_) => const _NfcRunner(mode: _NfcMode.receive),
  );
}

enum _NfcMode { send, receive }

enum _NfcState { waiting, working, done, error }

class _NfcRunner extends StatefulWidget {
  final _NfcMode mode;
  final NameCard? card;

  const _NfcRunner({required this.mode, this.card});

  @override
  State<_NfcRunner> createState() => _NfcRunnerState();
}

class _NfcRunnerState extends State<_NfcRunner> {
  _NfcState _state = _NfcState.waiting;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    NfcShare.stop();
    super.dispose();
  }

  Future<void> _start() async {
    if (widget.mode == _NfcMode.send) {
      await NfcShare.hostCard(
        widget.card!,
        onWritten: () => _finish(_NfcState.done, 'Shared. Tap done.'),
        onError: (m) => _finish(_NfcState.error, m),
      );
    } else {
      await NfcShare.readCard(
        onRead: (card) {
          if (mounted) Navigator.of(context).pop(card);
        },
        onForeign: () =>
            _finish(_NfcState.error, 'That tag has no Namecard Vision card.'),
        onError: (m) => _finish(_NfcState.error, m),
      );
    }
  }

  void _finish(_NfcState state, String message) {
    if (!mounted) return;
    setState(() {
      _state = state;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSend = widget.mode == _NfcMode.send;

    final Widget icon;
    final String title;
    switch (_state) {
      case _NfcState.waiting:
      case _NfcState.working:
        icon = const _PulsingNfcIcon();
        title = isSend
            ? 'Hold the phones back-to-back to share'
            : 'Hold near the other phone to receive';
      case _NfcState.done:
        icon = Icon(Icons.check_circle,
            size: 56, color: theme.colorScheme.primary);
        title = 'Done';
      case _NfcState.error:
        icon = Icon(Icons.error_outline,
            size: 56, color: theme.colorScheme.error);
        title = 'NFC problem';
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 16),
            Text(title,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center),
            if (_message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(_state == _NfcState.done ? 'Done' : 'Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A gently pulsing NFC glyph while a session waits for a tap.
class _PulsingNfcIcon extends StatefulWidget {
  const _PulsingNfcIcon();

  @override
  State<_PulsingNfcIcon> createState() => _PulsingNfcIconState();
}

class _PulsingNfcIconState extends State<_PulsingNfcIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_c),
      child: Icon(Icons.contactless,
          size: 56, color: Theme.of(context).colorScheme.primary),
    );
  }
}

import 'package:flutter/material.dart';

import '../../model/card.dart';
import '../../share/ble_share.dart';

/// Present the "sharing over Bluetooth" sheet to stream [card] to a nearby phone
/// that opens its own Bluetooth receive sheet. Always stops advertising on close.
Future<void> showBleSend(BuildContext context, NameCard card) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: true,
    showDragHandle: true,
    isScrollControlled: false,
    builder: (_) => _BleRunner(mode: _BleMode.send, card: card),
  );
}

/// Present the Bluetooth receive sheet. Resolves to the decoded card once a
/// nearby sender's transfer completes, or null if dismissed first.
Future<NameCard?> showBleReceive(BuildContext context) {
  return showModalBottomSheet<NameCard?>(
    context: context,
    isDismissible: true,
    showDragHandle: true,
    builder: (_) => const _BleRunner(mode: _BleMode.receive),
  );
}

enum _BleMode { send, receive }

enum _BleState { starting, waiting, working, done, error }

class _BleRunner extends StatefulWidget {
  final _BleMode mode;
  final NameCard? card;

  const _BleRunner({required this.mode, this.card});

  @override
  State<_BleRunner> createState() => _BleRunnerState();
}

class _BleRunnerState extends State<_BleRunner> {
  BleSender? _sender;
  BleReceiver? _receiver;

  _BleState _state = _BleState.starting;
  String _message = '';
  int _received = 0;
  int? _total;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _sender?.stop();
    _receiver?.stop();
    super.dispose();
  }

  Future<void> _start() async {
    if (widget.mode == _BleMode.send) {
      final sender = _sender = BleSender();
      await sender.start(
        widget.card!,
        onWaiting: () => _set(_BleState.waiting, 'Looking for a nearby phone…'),
        onSending: () => _set(_BleState.working, 'Sending the card…'),
        onSent: () => _set(_BleState.done, 'Shared. Tap done.'),
        onError: (m) => _set(_BleState.error, m),
      );
    } else {
      final receiver = _receiver = BleReceiver();
      await receiver.start(
        onScanning: () => _set(_BleState.waiting, 'Looking for a nearby phone…'),
        onConnecting: () => _set(_BleState.working, 'Connecting…'),
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _state = _BleState.working;
            _received = received;
            _total = total;
            _message = 'Receiving the card…';
          });
        },
        onReceived: (card) {
          if (mounted) Navigator.of(context).pop(card);
        },
        onError: (m) => _set(_BleState.error, m),
      );
    }
  }

  void _set(_BleState state, String message) {
    if (!mounted) return;
    setState(() {
      _state = state;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSend = widget.mode == _BleMode.send;

    final Widget icon;
    final String title;
    switch (_state) {
      case _BleState.starting:
      case _BleState.waiting:
      case _BleState.working:
        icon = const _PulsingBluetoothIcon();
        title = isSend
            ? 'Sharing over Bluetooth'
            : 'Receiving over Bluetooth';
      case _BleState.done:
        icon = Icon(Icons.check_circle,
            size: 56, color: theme.colorScheme.primary);
        title = 'Done';
      case _BleState.error:
        icon = Icon(Icons.error_outline,
            size: 56, color: theme.colorScheme.error);
        title = 'Bluetooth problem';
    }

    final showProgress = _state == _BleState.working &&
        !isSend &&
        _total != null &&
        _total! > 0;

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
            if (showProgress) ...[
              const SizedBox(height: 14),
              LinearProgressIndicator(value: _received / _total!),
            ],
            if (_state == _BleState.starting ||
                _state == _BleState.waiting) ...[
              const SizedBox(height: 12),
              Text(
                isSend
                    ? 'Ask the other person to choose “Receive over Bluetooth”.'
                    : 'Ask the other person to choose “Share → Bluetooth”.',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(_state == _BleState.done ? 'Done' : 'Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A gently pulsing Bluetooth glyph while a session runs.
class _PulsingBluetoothIcon extends StatefulWidget {
  const _PulsingBluetoothIcon();

  @override
  State<_PulsingBluetoothIcon> createState() => _PulsingBluetoothIconState();
}

class _PulsingBluetoothIconState extends State<_PulsingBluetoothIcon>
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
      child: Icon(Icons.bluetooth_searching,
          size: 56, color: Theme.of(context).colorScheme.primary),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../model/card.dart';
import '../../share/envelope.dart';
import '../../share/nfc_share.dart';
import '../share/nfc_sheet.dart';

/// Camera QR scanner for receiving a card. Decodes the NCV envelope and, on a
/// valid card, pops with the decoded [NameCard] for the caller to verify+save.
/// A manual paste path is offered so cards can be received without a camera
/// (desktop/web, or a code shared as text).
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;
      final card = _tryDecode(raw);
      if (card != null) {
        _handled = true;
        Navigator.of(context).pop(card);
        return;
      }
    }
  }

  NameCard? _tryDecode(String raw) {
    try {
      return ShareEnvelope.decode(raw);
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan a card'),
        actions: [
          if (NfcShare.platformSupported)
            IconButton(
              tooltip: 'Receive via NFC',
              icon: const Icon(Icons.contactless),
              onPressed: _receiveNfc,
            ),
          IconButton(
            tooltip: 'Enter code',
            icon: const Icon(Icons.keyboard),
            onPressed: _enterManually,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) => _CameraUnavailable(
                    onEnterCode: _enterManually,
                  ),
                ),
                const _ReticleOverlay(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _error ??
                  'Point the camera at a Namecard Vision QR code, or enter a '
                      'shared code by hand.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _error != null
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _receiveNfc() async {
    final card = await showNfcReceive(context);
    if (card == null || !mounted) return;
    Navigator.of(context).pop(card);
  }

  Future<void> _enterManually() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter share code'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Paste the share code…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty) return;
    final card = _tryDecode(code.trim());
    if (!mounted) return;
    if (card == null) {
      setState(() => _error = 'That code is not a valid Namecard Vision card.');
      return;
    }
    Navigator.of(context).pop(card);
  }
}

class _ReticleOverlay extends StatelessWidget {
  const _ReticleOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white70, width: 3),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _CameraUnavailable extends StatelessWidget {
  final VoidCallback onEnterCode;
  const _CameraUnavailable({required this.onEnterCode});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined,
                color: Colors.white70, size: 48),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Camera unavailable on this device.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onEnterCode,
              icon: const Icon(Icons.keyboard),
              label: const Text('Enter code instead'),
            ),
          ],
        ),
      ),
    );
  }
}

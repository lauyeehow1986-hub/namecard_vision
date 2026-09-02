import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../model/card.dart';
import '../../ocr/ocr_scanner.dart';

/// Drive the "scan a physical card" flow: let the user pick camera or gallery,
/// run OCR with a progress dialog, and return the parsed [NameCard] for the
/// caller to open in the editor for review. Returns null if cancelled, and
/// shows a snackbar on failure.
Future<NameCard?> scanPhysicalCard(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final source = await _pickSource(context);
  if (source == null || !context.mounted) return null;

  // Progress dialog while ML Kit works.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ScanningDialog(),
  );

  NameCard? card;
  String? error;
  try {
    card = await OcrScanner.scan(source: source);
  } on OcrException catch (e) {
    error = e.message;
  } catch (_) {
    error = 'Something went wrong while scanning.';
  }

  if (!context.mounted) return null;
  Navigator.of(context).pop(); // dismiss progress dialog

  if (error != null) {
    messenger.showSnackBar(SnackBar(content: Text(error)));
    return null;
  }
  if (card == null) return null; // user cancelled the picker

  final anyField = card.name.isNotEmpty ||
      card.org.isNotEmpty ||
      card.emails.isNotEmpty ||
      card.phones.isNotEmpty;
  if (!anyField) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No text found — try a clearer photo.')),
    );
  } else {
    messenger.showSnackBar(
      const SnackBar(content: Text('Review the scanned details before saving.')),
    );
  }
  return card;
}

Future<ImageSource?> _pickSource(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
}

class _ScanningDialog extends StatelessWidget {
  const _ScanningDialog();

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      content: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(width: 20),
          Expanded(child: Text('Reading the card…')),
        ],
      ),
    );
  }
}

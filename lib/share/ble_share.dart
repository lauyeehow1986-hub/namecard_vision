import 'dart:async';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/foundation.dart';

import '../model/card.dart';
import 'ble_transfer.dart';

/// Device-only Bluetooth Low Energy exchange. The sender acts as a BLE
/// **peripheral** advertising the Namecard Vision service and streaming the
/// framed `NCV1` envelope over a notify characteristic; the receiver acts as a
/// **central** that scans for that service, connects, subscribes, and
/// reassembles the bytes with [BleReassembler]. The payload is the same
/// verifiable envelope as QR and NFC, so a received card recomputes the
/// sender's fingerprint + safety code. The art itself is never sent.
///
/// Nothing here runs on web/desktop or in host tests — the pure framing lives
/// in [BleTransfer]/[BleFramer]/[BleReassembler], which is what the unit tests
/// cover. On-device exchange needs two physical phones to smoke-test.
class BleShare {
  const BleShare._();

  /// BLE peer exchange is a mobile-only feature here (peripheral advertising is
  /// unreliable on desktop). The UI gates on this before offering it.
  static bool get platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static final UUID _serviceUuid = UUID.fromString(BleTransfer.serviceUuid);
  static final UUID _charUuid = UUID.fromString(BleTransfer.characteristicUuid);

  static bool _sameUuid(UUID a, UUID b) =>
      a.toString().toLowerCase() == b.toString().toLowerCase();
}

/// Peripheral side: advertise and stream [card] to the first central that
/// subscribes.
class BleSender {
  final PeripheralManager _pm = PeripheralManager();
  final List<StreamSubscription<dynamic>> _subs = [];
  bool _delivering = false;
  bool _stopped = false;

  /// Begin advertising [card]. [onWaiting] fires once advertising is live,
  /// [onSending] when a peer starts pulling bytes, [onSent] on success, and
  /// [onError] with a user-facing message on any failure.
  Future<void> start(
    NameCard card, {
    required void Function() onWaiting,
    required void Function() onSending,
    required void Function() onSent,
    required void Function(String message) onError,
  }) async {
    if (!BleShare.platformSupported) {
      onError('This device does not support Bluetooth sharing.');
      return;
    }
    try {
      final authorized = await _pm.authorize();
      if (!authorized) {
        onError('Bluetooth permission is needed to share.');
        return;
      }
      if (_pm.state != BluetoothLowEnergyState.poweredOn) {
        onError('Turn on Bluetooth and try again.');
        return;
      }

      final payload = BleTransfer.payloadFor(card);
      final characteristic = GATTCharacteristic.mutable(
        uuid: BleShare._charUuid,
        properties: [
          GATTCharacteristicProperty.read,
          GATTCharacteristicProperty.notify,
        ],
        permissions: [GATTCharacteristicPermission.read],
        descriptors: [],
      );
      final service = GATTService(
        uuid: BleShare._serviceUuid,
        isPrimary: true,
        includedServices: [],
        characteristics: [characteristic],
      );

      await _pm.removeAllServices();
      await _pm.addService(service);

      // A central that reads the whole characteristic (instead of subscribing)
      // gets the requested slice of the payload back.
      _subs.add(_pm.characteristicReadRequested.listen((e) async {
        if (!BleShare._sameUuid(e.characteristic.uuid, BleShare._charUuid)) {
          return;
        }
        final off = e.request.offset.clamp(0, payload.length);
        try {
          await _pm.respondReadRequestWithValue(
            e.request,
            value: payload.sublist(off),
          );
        } catch (_) {/* central went away */}
      }));

      // The main path: when a central subscribes to notifications, stream the
      // framed envelope to it.
      _subs.add(_pm.characteristicNotifyStateChanged.listen((e) async {
        if (!e.state) return;
        if (!BleShare._sameUuid(e.characteristic.uuid, BleShare._charUuid)) {
          return;
        }
        if (_delivering) return;
        _delivering = true;
        onSending();
        try {
          await _stream(e.central, characteristic, payload);
          if (!_stopped) onSent();
        } catch (_) {
          if (!_stopped) onError('The transfer was interrupted. Try again.');
        }
      }));

      await _pm.startAdvertising(
        Advertisement(
          name: BleTransfer.advertisedName,
          serviceUUIDs: [BleShare._serviceUuid],
        ),
      );
      onWaiting();
    } catch (e) {
      onError('Could not start Bluetooth sharing. Try again.');
      await stop();
    }
  }

  Future<void> _stream(
    Central central,
    GATTCharacteristic characteristic,
    Uint8List payload,
  ) async {
    var maxFrame = 20;
    try {
      maxFrame = await _pm.getMaximumNotifyLength(central);
    } catch (_) {/* keep the conservative default */}
    final frames = BleFramer.frames(payload, maxFrame);
    for (final frame in frames) {
      if (_stopped) return;
      await _pm.notifyCharacteristic(central, characteristic, value: frame);
      // A brief gap keeps the platform notify queue from overflowing.
      await Future<void>.delayed(const Duration(milliseconds: 8));
    }
  }

  /// Stop advertising and release the GATT service.
  Future<void> stop() async {
    _stopped = true;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    try {
      await _pm.stopAdvertising();
    } catch (_) {}
    try {
      await _pm.removeAllServices();
    } catch (_) {}
  }
}

/// Central side: scan for a sending peer, connect, and reassemble the card.
class BleReceiver {
  final CentralManager _cm = CentralManager();
  final List<StreamSubscription<dynamic>> _subs = [];
  final BleReassembler _reassembler = BleReassembler();
  Peripheral? _peripheral;
  bool _done = false;
  bool _stopped = false;

  /// Begin scanning. [onScanning] fires once discovery is live, [onConnecting]
  /// when a peer is found, [onProgress] as bytes arrive (received/total, total
  /// may be null until the header lands), [onReceived] with the decoded card,
  /// and [onError] with a user-facing message.
  Future<void> start({
    required void Function() onScanning,
    required void Function() onConnecting,
    required void Function(int received, int? total) onProgress,
    required void Function(NameCard card) onReceived,
    required void Function(String message) onError,
  }) async {
    if (!BleShare.platformSupported) {
      onError('This device does not support Bluetooth sharing.');
      return;
    }
    try {
      final authorized = await _cm.authorize();
      if (!authorized) {
        onError('Bluetooth permission is needed to receive.');
        return;
      }
      if (_cm.state != BluetoothLowEnergyState.poweredOn) {
        onError('Turn on Bluetooth and try again.');
        return;
      }

      _subs.add(_cm.discovered.listen((e) async {
        if (_peripheral != null || _stopped) return;
        _peripheral = e.peripheral;
        onConnecting();
        try {
          await _cm.stopDiscovery();
          await _cm.connect(e.peripheral);
        } catch (_) {
          if (!_stopped) onError('Could not connect. Move closer and retry.');
        }
      }));

      _subs.add(_cm.connectionStateChanged.listen((e) async {
        if (_stopped) return;
        if (e.state == ConnectionState.connected) {
          await _onConnected(e.peripheral, onError);
        }
      }));

      _subs.add(_cm.characteristicNotified.listen((e) {
        if (_done || _stopped) return;
        if (!BleShare._sameUuid(e.characteristic.uuid, BleShare._charUuid)) {
          return;
        }
        _onFrame(e.value, onProgress, onReceived, onError);
      }));

      await _cm.startDiscovery(serviceUUIDs: [BleShare._serviceUuid]);
      onScanning();
    } catch (e) {
      onError('Could not start Bluetooth. Try again.');
      await stop();
    }
  }

  Future<void> _onConnected(
    Peripheral peripheral,
    void Function(String) onError,
  ) async {
    try {
      final services = await _cm.discoverGATT(peripheral);
      GATTCharacteristic? target;
      for (final s in services) {
        if (!BleShare._sameUuid(s.uuid, BleShare._serviceUuid)) continue;
        for (final c in s.characteristics) {
          if (BleShare._sameUuid(c.uuid, BleShare._charUuid)) {
            target = c;
            break;
          }
        }
      }
      if (target == null) {
        onError('That phone is not sharing a card.');
        await stop();
        return;
      }
      await _cm.setCharacteristicNotifyState(peripheral, target, state: true);
    } catch (_) {
      if (!_stopped) onError('Could not read the card. Try again.');
      await stop();
    }
  }

  void _onFrame(
    Uint8List frame,
    void Function(int, int?) onProgress,
    void Function(NameCard) onReceived,
    void Function(String) onError,
  ) {
    try {
      final payload = _reassembler.add(frame);
      onProgress(_reassembler.received, _reassembler.total);
      if (payload != null) {
        _done = true;
        final card = BleTransfer.cardFrom(payload);
        onReceived(card);
        stop();
      }
    } on BleTransferException {
      onError('The card data was garbled. Try again.');
      stop();
    } on FormatException {
      onError('Received data was not a valid card.');
      stop();
    }
  }

  /// Stop scanning and disconnect.
  Future<void> stop() async {
    _stopped = true;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    try {
      await _cm.stopDiscovery();
    } catch (_) {}
    final p = _peripheral;
    if (p != null) {
      try {
        await _cm.disconnect(p);
      } catch (_) {}
    }
  }
}

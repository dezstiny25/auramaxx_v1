import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleController {
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? controlCharacteristic;
  BluetoothCharacteristic? notifyCharacteristic;

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  Stream<bool> get connectionStream => _connectionController.stream;

  static const String deviceName = "AuraMaxx";

  static final Guid serviceUuid = Guid("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
  static final Guid characteristicUuid =
      Guid("6E400002-B5A3-F393-E0A9-E50E24DCCA9E");
    static final Guid notifyUuid =
      Guid("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<int>>? _notifySub;

  final StreamController<String> _notifyController =
      StreamController<String>.broadcast();

  Stream<String> get notificationStream => _notifyController.stream;

  /// Scan for AuraMaxx device and connect
  Future<void> connect() async {
    await FlutterBluePlus.turnOn();

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    _scanSub = FlutterBluePlus.scanResults.listen((results) async {
      for (final r in results) {
        if (r.device.name == deviceName) {
          await FlutterBluePlus.stopScan();
          await _scanSub?.cancel();

          await r.device.connect(autoConnect: false);
          connectedDevice = r.device;

          // Discover services and setup characteristics
          await _setupDevice(r.device);

          _connectionController.add(true);

          // Listen for disconnect
          r.device.connectionState.listen((state) {
            if (state == BluetoothConnectionState.disconnected) {
              _connectionController.add(false);
              connectedDevice = null;
              controlCharacteristic = null;
            }
          });

          return;
        }
      }
    });
  }

  Future<void> disconnect() async {
    if (connectedDevice != null) {
      // disable notifications
      try {
        if (_notifySub != null) {
          await notifyCharacteristic?.setNotifyValue(false);
          await _notifySub?.cancel();
        }
      } catch (_) {}

      await connectedDevice!.disconnect();
      connectedDevice = null;
      controlCharacteristic = null;
      notifyCharacteristic = null;
      _notifyController.add('');
      _connectionController.add(false);
    }
  }

  Future<void> send(String message) async {
    if (controlCharacteristic == null) return;

    final bytes = utf8.encode(message);
    await controlCharacteristic!.write(bytes, withoutResponse: false);
  }

  void notifyConnected(bool state) {
    _connectionController.add(state);
  }

  Future<void> _setupDevice(BluetoothDevice device) async {
    connectedDevice = device;
    controlCharacteristic = null;
    notifyCharacteristic = null;

    final services = await device.discoverServices();
    for (final service in services) {
      if (service.uuid == serviceUuid) {
        for (final c in service.characteristics) {
          if (c.uuid == characteristicUuid) {
            controlCharacteristic = c;
          }
          if (c.uuid == notifyUuid) {
            notifyCharacteristic = c;
          }
        }
      }
    }

    // Activate notifications if available
    if (notifyCharacteristic != null) {
      try {
        await notifyCharacteristic!.setNotifyValue(true);
        _notifySub = notifyCharacteristic!.value.listen((data) {
          try {
            final s = utf8.decode(data);
            _notifyController.add(s);
          } catch (_) {}
        });
      } catch (_) {}
    }
  }

  // Public wrapper
  Future<void> setupDevice(BluetoothDevice device) async {
    return _setupDevice(device);
  }
}

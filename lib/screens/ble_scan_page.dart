import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../ble/ble_controller.dart';

class BleScanPage extends StatefulWidget {
  final BleController ble;
  const BleScanPage({super.key, required this.ble});

  @override
  State<BleScanPage> createState() => _BleScanPageState();
}

class _BleScanPageState extends State<BleScanPage> {
  List<ScanResult> scanResults = [];
  StreamSubscription<List<ScanResult>>? _scanSub;
  bool isScanning = false;

  Future<bool> _requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  Future<void> startScan() async {
    final granted = await _requestPermissions();
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('BLE permissions not granted')),
      );
      return;
    }

    scanResults.clear();
    setState(() => isScanning = true);

    await FlutterBluePlus.turnOn();
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 6));

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        scanResults = results;
      });
    });

    await Future.delayed(const Duration(seconds: 6));
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();

    setState(() => isScanning = false);
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await widget.ble.disconnect();
      await device.connect(autoConnect: false);
      await widget.ble.setupDevice(device);
      widget.ble.notifyConnected(true);
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to ${device.name}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Connection failed: $e')));
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BLE Scan')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: isScanning ? null : startScan,
            child: Text(isScanning ? 'Scanning...' : 'Scan'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: scanResults.length,
              itemBuilder: (context, index) {
                final r = scanResults[index];
                final device = r.device;

                return ListTile(
                  title: Text(
                    device.name.isNotEmpty ? device.name : 'Unknown Device',
                  ),
                  subtitle: Text(device.remoteId.toString()),
                  trailing: ElevatedButton(
                    child: const Text('Connect'),
                    onPressed: () => connectToDevice(device),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

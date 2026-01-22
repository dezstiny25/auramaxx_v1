import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'manual_controller_page.dart';
import '../ble/ble_controller.dart';
import '../screens/ble_scan_page.dart';

enum LightZone {
  frontLeft,
  frontRight,
  rearLeft,
  rearRight,
}

class ControlPage extends StatefulWidget {
  final BleController ble;

  const ControlPage({super.key, required this.ble});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  bool isConnected = false;

  final Set<LightZone> selectedZones = {};
  String selectedMode = 'Strobe';
  double speed = 120;

  List<Map<String, dynamic>> presets = [];

  static const String _presetsKey = 'auramaxx_presets_v1';

  @override
  void initState() {
    super.initState();

    widget.ble.connectionStream.listen((state) {
      if (!mounted) return;
      setState(() {
        isConnected = state;
      });
    });

    _loadPresets();
  }

  Future<void> _loadPresets() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_presetsKey);
    if (raw == null) return;
    try {
      final List decoded = jsonDecode(raw);
      presets = decoded.cast<Map<String, dynamic>>();
      setState(() {});
    } catch (_) {}
  }

  Future<void> _savePresetsToStorage() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_presetsKey, jsonEncode(presets));
  }

  void _toggleZone(LightZone zone) {
    setState(() {
      if (selectedZones.contains(zone)) {
        selectedZones.remove(zone);
      } else {
        selectedZones.add(zone);
      }
    });
    _sendUpdate();
  }

  void _sendUpdate() {
    if (!isConnected) return;

    final data = {
      "zones": selectedZones.map(zoneName).toList(),
      "mode": selectedMode,
      "speed": speed.toInt(),
    };

    widget.ble.send(jsonEncode(data));
  }

  void _openBleScanPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BleScanPage(ble: widget.ble),
      ),
    );
  }

  Future<void> _promptSavePreset() async {
    final controller = TextEditingController();
    final name = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Preset'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Preset name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    final preset = {
      'name': name,
      'zones': selectedZones.map(zoneName).toList(),
      'mode': selectedMode,
      'speed': speed.toInt(),
    };

    setState(() {
      presets.add(preset);
    });
    await _savePresetsToStorage();
  }

  Future<void> _applyPreset(Map<String, dynamic> preset) async {
    final List zones = preset['zones'] ?? [];
    selectedZones.clear();
    for (final z in zones) {
      switch (z) {
        case 'front_left':
          selectedZones.add(LightZone.frontLeft);
          break;
        case 'front_right':
          selectedZones.add(LightZone.frontRight);
          break;
        case 'rear_left':
          selectedZones.add(LightZone.rearLeft);
          break;
        case 'rear_right':
          selectedZones.add(LightZone.rearRight);
          break;
      }
    }
    setState(() {
      selectedMode = preset['mode'] ?? selectedMode;
      speed = (preset['speed'] ?? speed).toDouble();
    });
    _sendUpdate();
  }

  Future<void> _deletePreset(int index) async {
    setState(() {
      presets.removeAt(index);
    });
    await _savePresetsToStorage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/auramaxx_logo.png',
          height: 36,
        ),
        actions: [
          IconButton(
            tooltip: 'Manual Controller',
            icon: const Icon(Icons.gamepad),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ManualControllerPage(ble: widget.ble),
                ),
              );
            },
          ),
          GestureDetector(
            onTap: _openBleScanPage,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    isConnected ? 'Connected' : 'Disconnected',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isConnected ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/bground.png',
              fit: BoxFit.cover,
            ),
          ),
          Column(
            children: [
              /// TOP 2/3 — CAR + ZONES
              Expanded(
                flex: 2,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 180,
                      height: 320,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/Car.png',
                          width: 1000,
                          color: Colors.white70,
                          colorBlendMode: BlendMode.modulate,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: zoneIndicator('Front Left', LightZone.frontLeft),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: zoneIndicator('Front Right', LightZone.frontRight),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: zoneIndicator('Rear Left', LightZone.rearLeft),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: zoneIndicator('Rear Right', LightZone.rearRight),
                    ),
                  ],
                ),
              ),

              /// BOTTOM 1/3 — MODES + PRESETS
              Expanded(
                flex: 1,
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Mode',
                                        style:
                                            TextStyle(color: Colors.white60)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white10,
                                        borderRadius: BorderRadius.circular(12),
                                        border:
                                            Border.all(color: Colors.white12),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: selectedMode,
                                          isExpanded: true,
                                          dropdownColor:
                                              const Color(0xFF1B1B1B),
                                          items: const [
                                            DropdownMenuItem(
                                                value: 'Solid',
                                                child: Text('Solid')),
                                            DropdownMenuItem(
                                                value: 'Strobe',
                                                child: Text('Strobe')),
                                            DropdownMenuItem(
                                                value: 'Alternate',
                                                child: Text('Alternate')),
                                            DropdownMenuItem(
                                                value: 'Chase',
                                                child: Text('Chase')),
                                          ],
                                          onChanged: (value) {
                                            setState(() {
                                              selectedMode = value!;
                                            });
                                            _sendUpdate();
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Speed',
                                        style:
                                            TextStyle(color: Colors.white60)),
                                    Slider(
                                      min: 50,
                                      max: 500,
                                      value: speed,
                                      label: speed.toInt().toString(),
                                      onChanged: (value) {
                                        setState(() {
                                          speed = value;
                                        });
                                        _sendUpdate();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _promptSavePreset,
                                icon: const Icon(Icons.save),
                                label: const Text('Save Preset'),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: presets.isEmpty
                                    ? const Text('No presets',
                                        style: TextStyle(color: Colors.white60))
                                    : DropdownButton<int>(
                                        isExpanded: true,
                                        hint: const Text('Choose preset',
                                            style: TextStyle(
                                                color: Colors.white60)),
                                        dropdownColor: const Color(0xFF1B1B1B),
                                        items: List.generate(
                                          presets.length,
                                          (i) => DropdownMenuItem(
                                            value: i,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(presets[i]['name'] ??
                                                    'Preset'),
                                                IconButton(
                                                  icon: const Icon(Icons.delete,
                                                      size: 18),
                                                  onPressed: () async {
                                                    await _deletePreset(i);
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        onChanged: (idx) {
                                          if (idx == null) return;
                                          _applyPreset(presets[idx]);
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ZONE INDICATOR
  Widget zoneIndicator(String label, LightZone zone) {
    final bool isSelected = selectedZones.contains(zone);

    return GestureDetector(
      onTap: () => _toggleZone(zone),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isSelected ? 22 : 16,
            height: isSelected ? 22 : 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? Colors.redAccent : Colors.white38,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.redAccent.withOpacity(0.7),
                        blurRadius: 10,
                      )
                    ]
                  : [],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? Colors.redAccent : Colors.white54,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  String zoneName(LightZone zone) {
    switch (zone) {
      case LightZone.frontLeft:
        return 'front_left';
      case LightZone.frontRight:
        return 'front_right';
      case LightZone.rearLeft:
        return 'rear_left';
      case LightZone.rearRight:
        return 'rear_right';
    }
  }
}

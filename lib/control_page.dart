import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ble/ble_controller.dart';
import '../screens/ble_scan_page.dart';
import 'manual_controller_page.dart';

enum LightZone { frontLeft, frontRight, rearLeft, rearRight }

enum ActiveOverlay { none, mode, speed, presets }

class ControlPage extends StatefulWidget {
  final BleController ble;
  const ControlPage({super.key, required this.ble});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage>
    with SingleTickerProviderStateMixin {
  bool isConnected = false;

  final Set<LightZone> selectedZones = {};
  String selectedMode = 'Solid';
  double speed = 50;

  ActiveOverlay activeOverlay = ActiveOverlay.none;

  final List<String> modes = [
    'Solid',
    'Strobe',
    'Chase',
    'Loop',
    'Alternate',
    'Random'
  ];

  List<Map<String, dynamic>> presets = [];
  static const String _presetsKey = 'auramaxx_presets_v1';
  int selectedPresetIndex = 0;
  int selectedModeIndex = 0;

  late AnimationController overlayAnim;
  late Animation<double> overlayScale;
  late Animation<double> overlayFade;

  Timer? _speedDebounce;

  // =========================
  // INIT
  // =========================
  @override
  void initState() {
    super.initState();

    overlayAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    overlayScale =
        CurvedAnimation(parent: overlayAnim, curve: Curves.easeOutBack);
    overlayFade = CurvedAnimation(parent: overlayAnim, curve: Curves.easeOut);

    widget.ble.connectionStream.listen((state) {
      if (!mounted) return;
      setState(() => isConnected = state);
    });

    widget.ble.notificationStream.listen((payload) {
      if (!mounted) return;
      try {
        if (payload.isEmpty) return;
        final map = jsonDecode(payload) as Map<String, dynamic>;

        final zones = <String>[];
        if (map.containsKey('zones')) {
          final z = map['zones'];
          if (z is List) zones.addAll(z.cast<String>());
        }

        selectedZones.clear();
        for (final s in zones) {
          if (s == 'front_left') selectedZones.add(LightZone.frontLeft);
          if (s == 'front_right') selectedZones.add(LightZone.frontRight);
          if (s == 'rear_left') selectedZones.add(LightZone.rearLeft);
          if (s == 'rear_right') selectedZones.add(LightZone.rearRight);
        }

        if (map.containsKey('mode')) {
          selectedMode = map['mode'] as String? ?? selectedMode;
        }

        setState(() {});
      } catch (_) {}
    });

    _loadPresets();
    selectedModeIndex = modes.indexOf(selectedMode).clamp(0, modes.length - 1);
  }

  // =========================
  // OVERLAY TOGGLE (FIXED)
  // =========================
  void _toggleOverlay(ActiveOverlay overlay) {
    HapticFeedback.lightImpact();

    setState(() {
      if (activeOverlay == overlay) {
        activeOverlay = ActiveOverlay.none;
        overlayAnim.reverse();
      } else {
        activeOverlay = overlay;
        overlayAnim.forward(from: 0);
      }
    });
  }

  // =========================
  // PRESETS
  // =========================
  Future<void> _loadPresets() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_presetsKey);
    if (raw == null) return;

    try {
      presets = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      setState(() {});
    } catch (_) {}
  }

  Future<void> _savePresets() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_presetsKey, jsonEncode(presets));
  }

  Future<void> _applyPreset(Map<String, dynamic> preset) async {
    // briefly turn everything off before applying
    widget.ble.send(jsonEncode({
      "zones": [],
      "mode": "Off",
      "speed": 0,
    }));

    await Future.delayed(const Duration(milliseconds: 50));

    selectedZones.clear();
    for (final z in preset['zones']) {
      if (z == 'front_left') selectedZones.add(LightZone.frontLeft);
      if (z == 'front_right') selectedZones.add(LightZone.frontRight);
      if (z == 'rear_left') selectedZones.add(LightZone.rearLeft);
      if (z == 'rear_right') selectedZones.add(LightZone.rearRight);
    }

    setState(() {
      selectedMode = preset['mode'];
      speed = (preset['speed']).toDouble();
    });

    _sendUpdate();
  }

  // =========================
  // ZONES
  // =========================
  void _toggleZone(LightZone zone) {
    HapticFeedback.selectionClick();
    setState(() {
      selectedZones.contains(zone)
          ? selectedZones.remove(zone)
          : selectedZones.add(zone);
    });
    _sendUpdate();
  }

  // =========================
  // POWER OFF
  // =========================
  void _turnOffAll() {
    HapticFeedback.heavyImpact();

    selectedZones.clear();
    selectedMode = 'Off';
    speed = 0;

    setState(() {});

    if (!isConnected) return;

    widget.ble.send(jsonEncode({
      "zones": [],
      "mode": "Off",
      "speed": 0,
    }));
  }

  // =========================
  // SEND TO ESP32
  // =========================
  void _sendUpdate() {
    if (!isConnected || selectedMode == 'Off') return;

    // Speed controls OFF delay (blink-only ON)
    final int offDelayMs = (1000 - (speed * 9)).clamp(80, 1000).toInt();

    widget.ble.send(jsonEncode({
      "zones": selectedZones.map(zoneName).toList(),
      "mode": selectedMode,
      "speed": offDelayMs,
    }));
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/auramaxx_logo.png', height: 36),
        actions: [
          IconButton(
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
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => BleScanPage(ble: widget.ble)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(isConnected ? 'Connected' : 'Disconnected'),
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
            child: Image.asset('assets/bground.png', fit: BoxFit.cover),
          ),

          // POWER BUTTON
          Positioned(
            top: 12,
            left: 12,
            child: IconButton(
              iconSize: 32,
              color: Colors.redAccent,
              icon: const Icon(Icons.power_settings_new),
              onPressed: _turnOffAll,
            ),
          ),

          Column(
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset('assets/Car.png', width: 380),
                    Positioned(
                        top: 60,
                        left: 90,
                        child:
                            zoneIndicator('Front Left', LightZone.frontLeft)),
                    Positioned(
                        top: 60,
                        right: 90,
                        child:
                            zoneIndicator('Front Right', LightZone.frontRight)),
                    Positioned(
                        bottom: 60,
                        left: 90,
                        child: zoneIndicator('Rear Left', LightZone.rearLeft)),
                    Positioned(
                        bottom: 60,
                        right: 90,
                        child:
                            zoneIndicator('Rear Right', LightZone.rearRight)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 64),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: controlButton(
                            icon: Icons.auto_awesome,
                            label: 'MODE',
                            value: selectedMode,
                            onTap: () => _toggleOverlay(ActiveOverlay.mode),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: controlButton(
                            icon: Icons.speed,
                            label: 'SPEED',
                            value: '${speed.toInt()}%',
                            onTap: () => _toggleOverlay(ActiveOverlay.speed),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // FULL WIDTH PRESET BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: controlButton(
                        icon: Icons.bookmark,
                        label: 'PRESETS',
                        value: '${presets.length} Saved',
                        onTap: () => _toggleOverlay(ActiveOverlay.presets),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (activeOverlay != ActiveOverlay.none)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() => activeOverlay = ActiveOverlay.none);
                  overlayAnim.reverse();
                },
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    color: Colors.black45,
                    child: Center(
                      child: ScaleTransition(
                        scale: overlayScale,
                        child: FadeTransition(
                          opacity: overlayFade,
                          child: overlayCard(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // =========================
  // OVERLAYS
  // =========================
  Widget overlayCard() {
    Widget child;
    double height;

    switch (activeOverlay) {
      case ActiveOverlay.mode:
        child = modeOverlay();
        height = 260;
        break;
      case ActiveOverlay.presets:
        child = presetsOverlay();
        height = 320;
        break;
      case ActiveOverlay.speed:
        child = speedOverlay();
        height = 180;
        break;
      default:
        child = const SizedBox();
        height = 0;
    }

    // reserve some safe space for status/nav bars and avoid doubling padding
    final screenHeight = MediaQuery.of(context).size.height;
    final safePadding = MediaQuery.of(context).padding.top +
        MediaQuery.of(context).padding.bottom +
        40.0;
    final maxAllowed = (screenHeight - safePadding) * 0.85;
    final containerHeight = (height.clamp(0.0, maxAllowed) as double);

    return Container(
      width: 320,
      height: containerHeight,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }

  Widget modeOverlay() {
    final initial = selectedModeIndex.clamp(0, modes.length - 1);
    return CupertinoPicker(
      scrollController: FixedExtentScrollController(initialItem: initial),
      itemExtent: 40,
      useMagnifier: true,
      magnification: 1.15,
      onSelectedItemChanged: (i) {
        setState(() {
          selectedModeIndex = i;
          selectedMode = modes[i];
        });
        _sendUpdate();
      },
      children: modes.asMap().entries.map((e) {
        final idx = e.key;
        final m = e.value;
        final selected = idx == selectedModeIndex;
        return Center(
          child: Text(
            m,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white54,
              fontSize: selected ? 20 : 16,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget presetsOverlay() {
    if (presets.isEmpty) {
      return Column(
        children: [
          const Expanded(
            child: Center(
                child: Text('No saved presets',
                    style: TextStyle(color: Colors.white))),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () async {
                final controller = TextEditingController();
                final name = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: Colors.black87,
                    title: const Text('Preset name',
                        style: TextStyle(color: Colors.white)),
                    content: TextField(
                      controller: controller,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Name',
                        hintStyle: TextStyle(color: Colors.white38),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(null),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.of(ctx).pop(controller.text.trim()),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                );
                if (name == null) return;
                setState(() {
                  presets.add({
                    'name':
                        name.isEmpty ? 'Preset ${presets.length + 1}' : name,
                    'zones': selectedZones.map(zoneName).toList(),
                    'mode': selectedMode,
                    'speed': speed.toInt(),
                  });
                  _savePresets();
                  selectedPresetIndex = presets.length - 1;
                });
              },
              child:
                  const Text('Save New', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      );
    }

    final initial = selectedPresetIndex.clamp(0, presets.length - 1);
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: CupertinoPicker(
            scrollController: FixedExtentScrollController(initialItem: initial),
            itemExtent: 40,
            onSelectedItemChanged: (i) {
              setState(() => selectedPresetIndex = i);
              if (i >= 0 && i < presets.length) {
                _applyPreset(presets[i]);
                // keep overlay open (do not close)
              }
            },
            children: presets.asMap().entries.map((e) {
              final idx = e.key;
              final p = e.value;
              final label = p['name'] ?? p['mode'] ?? 'Preset ${idx + 1}';
              final selected = idx == selectedPresetIndex;
              return Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white54,
                    fontSize: selected ? 18 : 15,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 1),
        Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: presets.isEmpty
                    ? null
                    : () {
                        setState(() {
                          presets.removeAt(selectedPresetIndex);
                          if (presets.isEmpty) {
                            selectedPresetIndex = 0;
                          } else if (selectedPresetIndex >= presets.length) {
                            selectedPresetIndex = presets.length - 1;
                          }
                          _savePresets();
                        });
                      },
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24)),
                child:
                    const Text('Delete', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 1),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: () async {
                  final controller = TextEditingController();
                  final name = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: Colors.black87,
                      title: const Text('Preset name',
                          style: TextStyle(color: Colors.white)),
                      content: TextField(
                        controller: controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Name',
                          hintStyle: TextStyle(color: Colors.white38),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(null),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.of(ctx).pop(controller.text.trim()),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  );
                  if (name == null) return;
                  setState(() {
                    presets.add({
                      'name':
                          name.isEmpty ? 'Preset ${presets.length + 1}' : name,
                      'zones': selectedZones.map(zoneName).toList(),
                      'mode': selectedMode,
                      'speed': speed.toInt(),
                    });
                    _savePresets();
                    selectedPresetIndex = presets.length - 1;
                  });
                },
                child: const Text('Save New',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget speedOverlay() {
    return Column(
      children: [
        Slider(
          min: 0,
          max: 100,
          value: speed,
          onChanged: (v) {
            setState(() => speed = v);
            _speedDebounce?.cancel();
            _speedDebounce =
                Timer(const Duration(milliseconds: 120), _sendUpdate);
          },
        ),
        Text('${speed.toInt()}%',
            style: const TextStyle(color: Colors.white, fontSize: 22)),
      ],
    );
  }

  // =========================
  // COMPONENTS
  // =========================
  Widget controlButton({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          color: const Color(0xFF2B2B2B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 34, color: Colors.white),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: Colors.white)),
            Text(value,
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget zoneIndicator(String label, LightZone zone) {
    final active = selectedZones.contains(zone);
    return GestureDetector(
      onTap: () => _toggleZone(zone),
      child: Column(
        children: [
          Container(
            width: active ? 22 : 16,
            height: active ? 22 : 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? Colors.redAccent : Colors.white38,
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                fontSize: 10,
                color: active ? Colors.redAccent : Colors.white54,
              )),
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

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
  String selectedMode = 'Strobe';
  double speed = 50;

  ActiveOverlay activeOverlay = ActiveOverlay.none;
  final List<String> modes = ['Solid', 'Strobe', 'Chase'];

  List<Map<String, dynamic>> presets = [];
  static const String _presetsKey = 'auramaxx_presets_v1';
  int selectedPresetIndex = 0;

  late AnimationController overlayAnim;
  late Animation<double> overlayScale;
  late Animation<double> overlayFade;

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

  void _toggleZone(LightZone zone) {
    HapticFeedback.selectionClick();
    setState(() {
      selectedZones.contains(zone)
          ? selectedZones.remove(zone)
          : selectedZones.add(zone);
    });
    _sendUpdate();
  }

  void _turnOffAll() {
    HapticFeedback.heavyImpact();

    setState(() {
      selectedZones.clear();
      selectedMode = 'Off';
      speed = 0;
    });

    if (!isConnected) return;

    widget.ble.send(jsonEncode({
      "zones": [],
      "mode": "Off",
      "speed": 0,
    }));
  }

  void _sendUpdate() {
    if (!isConnected || selectedMode == 'Off') return;

    // Convert speed to milliseconds for ESP32 firmware
    final int delayMs = (1000 - (speed * 9)).clamp(100, 1000).toInt();

    widget.ble.send(jsonEncode({
      "zones": selectedZones.map(zoneName).toList(),
      "mode": selectedMode,
      "speed": delayMs,
    }));
  }

  void _openBleScanPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BleScanPage(ble: widget.ble)),
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
      selectedPresetIndex = presets.length - 1;
    });
    await _savePresetsToStorage();
  }

  Future<void> _deletePresetWithConfirmation() async {
    if (presets.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Preset'),
        content: Text(
            'Are you sure you want to delete preset "${presets[selectedPresetIndex]['name']}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        presets.removeAt(selectedPresetIndex);
        if (selectedPresetIndex >= presets.length) selectedPresetIndex = 0;
      });
      await _savePresetsToStorage();
    }
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
            child: Image.asset('assets/bground.png', fit: BoxFit.cover),
          ),

          // 🔥 OFF button at top-left below status bar
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
                flex: 2,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset(
                      'assets/Car.png',
                      width: 400,
                      color: Colors.white70,
                      colorBlendMode: BlendMode.modulate,
                    ),
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
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
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
                                onTap: () =>
                                    _toggleOverlay(ActiveOverlay.speed),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: controlButton(
                                icon: Icons.bookmark,
                                label: 'PRESETS',
                                value: '${presets.length} Saved',
                                onTap: () =>
                                    _toggleOverlay(ActiveOverlay.presets),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (activeOverlay != ActiveOverlay.none)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => activeOverlay = ActiveOverlay.none),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    color: Colors.black45,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {}, // absorb taps
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
            ),
        ],
      ),
    );
  }

  Widget overlayCard() {
    Widget child;
    double height = 200;

    switch (activeOverlay) {
      case ActiveOverlay.mode:
        child = modeOverlay();
        height = 260;
        break;
      case ActiveOverlay.speed:
        child = speedOverlay();
        height = 200;
        break;
      case ActiveOverlay.presets:
        child = presetsOverlay();
        height = 320;
        break;
      default:
        child = const SizedBox();
    }

    return Container(
      width: 320,
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withOpacity(0.6),
            blurRadius: 22,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget modeOverlay() {
    final controller =
        FixedExtentScrollController(initialItem: modes.indexOf(selectedMode));
    return CupertinoPicker(
      scrollController: controller,
      itemExtent: 40,
      magnification: 1.15,
      useMagnifier: true,
      onSelectedItemChanged: (index) {
        setState(() => selectedMode = modes[index]);
        _sendUpdate();
      },
      children: modes.map((m) {
        final isSelected = m == selectedMode;
        return Center(
          child: Text(
            m.toUpperCase(),
            style: TextStyle(
              fontSize: isSelected ? 24 : 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: isSelected
                  ? [const Shadow(color: Colors.redAccent, blurRadius: 22)]
                  : [],
            ),
          ),
        );
      }).toList(),
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
            _sendUpdate();
          },
        ),
        const SizedBox(height: 12),
        Text(
          '${speed.toInt()}%',
          style: const TextStyle(
            fontSize: 22,
            color: Colors.white,
            shadows: [
              Shadow(color: Colors.redAccent, blurRadius: 14),
            ],
          ),
        ),
      ],
    );
  }

  Widget presetsOverlay() {
    final controller =
        FixedExtentScrollController(initialItem: selectedPresetIndex);

    return Column(
      children: [
        Expanded(
          child: CupertinoPicker(
            scrollController: controller,
            itemExtent: 40,
            magnification: 1.15,
            useMagnifier: true,
            onSelectedItemChanged: (index) {
              setState(() => selectedPresetIndex = index);
              _applyPreset(presets[index]);
            },
            children: presets.isEmpty
                ? [
                    const Center(
                        child: Text(
                      'No presets',
                      style: TextStyle(color: Colors.white60),
                    ))
                  ]
                : presets.map((p) {
                    final isSelected =
                        presets.indexOf(p) == selectedPresetIndex;
                    return Center(
                      child: Text(
                        p['name'] ?? 'Preset',
                        style: TextStyle(
                          fontSize: isSelected ? 22 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: isSelected
                              ? [
                                  const Shadow(
                                      color: Colors.redAccent, blurRadius: 18)
                                ]
                              : [],
                        ),
                      ),
                    );
                  }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            minimumSize: const Size.fromHeight(40),
          ),
          icon: const Icon(Icons.save),
          label: const Text('Save Current'),
          onPressed: _promptSavePreset,
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent.shade700,
            minimumSize: const Size.fromHeight(40),
          ),
          icon: const Icon(Icons.delete),
          label: const Text('Delete Selected'),
          onPressed: _deletePresetWithConfirmation,
        ),
      ],
    );
  }

  Widget controlButton({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 96,
          decoration: BoxDecoration(
            color: const Color(0xFF2B2B2B),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.45),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 34, color: Colors.white),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              Text(value,
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget zoneIndicator(String label, LightZone zone) {
    final bool isSelected = selectedZones.contains(zone);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => _toggleZone(zone),
      child: Padding(
        padding: const EdgeInsets.all(18),
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

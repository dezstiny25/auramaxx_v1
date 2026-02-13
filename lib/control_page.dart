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
import '../widgets/control_button.dart';
import '../widgets/zone_indicator.dart';
import '../widgets/overlay_card.dart';
import '../widgets/mode_picker.dart';
import '../widgets/speed_slider.dart';
import '../widgets/preset_picker.dart';

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

    // Listen to BLE connection
    widget.ble.connectionStream.listen((state) {
      if (!mounted) return;
      setState(() => isConnected = state);
    });

    // Listen to BLE notifications
    widget.ble.notificationStream.listen((payload) {
      if (!mounted) return;
      try {
        if (payload.isEmpty) return;
        final map = jsonDecode(payload) as Map<String, dynamic>;
        final zones = <String>[];
        if (map.containsKey('zones'))
          zones.addAll((map['zones'] as List).cast<String>());

        selectedZones.clear();
        for (final s in zones) {
          if (s == 'front_left') selectedZones.add(LightZone.frontLeft);
          if (s == 'front_right') selectedZones.add(LightZone.frontRight);
          if (s == 'rear_left') selectedZones.add(LightZone.rearLeft);
          if (s == 'rear_right') selectedZones.add(LightZone.rearRight);
        }

        if (map.containsKey('mode'))
          selectedMode = map['mode'] as String? ?? selectedMode;

        setState(() {});
      } catch (_) {}
    });

    _loadPresets();
    selectedModeIndex = modes.indexOf(selectedMode).clamp(0, modes.length - 1);
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
    widget.ble.send(jsonEncode({"zones": [], "mode": "Off", "speed": 0}));
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
  // OVERLAY TOGGLE
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
    widget.ble.send(jsonEncode({"zones": [], "mode": "Off", "speed": 0}));
  }

  // =========================
  // SEND TO ESP32
  // =========================
  void _sendUpdate() {
    if (!isConnected || selectedMode == 'Off') return;
    final int offDelayMs = (1000 - (speed * 9)).clamp(80, 1000).toInt();
    widget.ble.send(jsonEncode({
      "zones": selectedZones.map(zoneName).toList(),
      "mode": selectedMode,
      "speed": offDelayMs,
    }));
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

  // =========================
  // BUILD
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/auramaxx_logo.png', height: 36),
        actions: [
          IconButton(
            icon: const Icon(Icons.gamepad),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ManualControllerPage(ble: widget.ble)),
            ),
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
              child: Image.asset('assets/bground.png', fit: BoxFit.cover)),
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
                        child: ZoneIndicator(
                          label: 'Front Left',
                          active: selectedZones.contains(LightZone.frontLeft),
                          onTap: () => _toggleZone(LightZone.frontLeft),
                        )),
                    Positioned(
                        top: 60,
                        right: 90,
                        child: ZoneIndicator(
                          label: 'Front Right',
                          active: selectedZones.contains(LightZone.frontRight),
                          onTap: () => _toggleZone(LightZone.frontRight),
                        )),
                    Positioned(
                        bottom: 60,
                        left: 90,
                        child: ZoneIndicator(
                          label: 'Rear Left',
                          active: selectedZones.contains(LightZone.rearLeft),
                          onTap: () => _toggleZone(LightZone.rearLeft),
                        )),
                    Positioned(
                        bottom: 60,
                        right: 90,
                        child: ZoneIndicator(
                          label: 'Rear Right',
                          active: selectedZones.contains(LightZone.rearRight),
                          onTap: () => _toggleZone(LightZone.rearRight),
                        )),
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
                          child: ControlButton(
                            icon: Icons.auto_awesome,
                            label: 'MODE',
                            value: selectedMode,
                            onTap: () => _toggleOverlay(ActiveOverlay.mode),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ControlButton(
                            icon: Icons.speed,
                            label: 'SPEED',
                            value: '${speed.toInt()}%',
                            onTap: () => _toggleOverlay(ActiveOverlay.speed),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ControlButton(
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

          // =========================
          // OVERLAY
          // =========================
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
                      child: OverlayCard(
                        overlayScale: overlayScale,
                        overlayFade: overlayFade,
                        activeOverlay: activeOverlay,
                        modeOverlay: ModePicker(
                          modes: modes,
                          selectedModeIndex: selectedModeIndex,
                          onChanged: (i, mode) {
                            setState(() {
                              selectedModeIndex = i;
                              selectedMode = mode;
                            });
                            _sendUpdate();
                          },
                        ),
                        speedOverlay: SpeedSlider(
                          speed: speed,
                          onChanged: (v) {
                            setState(() => speed = v);
                            _speedDebounce?.cancel();
                            _speedDebounce = Timer(
                                const Duration(milliseconds: 120), _sendUpdate);
                          },
                        ),
                        presetOverlay: PresetPicker(
                          presets: presets,
                          selectedPresetIndex: selectedPresetIndex,
                          onApply: _applyPreset,
                          onUpdate: (newIndex) =>
                              setState(() => selectedPresetIndex = newIndex),
                          onSave: _savePresets,
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
}

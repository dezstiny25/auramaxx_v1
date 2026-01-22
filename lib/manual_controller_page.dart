import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'ble/ble_controller.dart';

import 'control_page.dart';

class ManualControllerPage extends StatelessWidget {
  final BleController ble;

  const ManualControllerPage({super.key, required this.ble});

  void _sendManual(LightZone zone, bool on) {
    final Map<String, dynamic> data = {
      'zones': [
        (() {
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
        })(),
      ],
      'mode': 'Solid',
      'state': on ? 'on' : 'off',
    };

    ble.send(jsonEncode(data));
  }

  Widget _buildButton(BuildContext context, String label, LightZone zone) {
    return Listener(
      onPointerDown: (_) => _sendManual(zone, true),
      onPointerUp: (_) => _sendManual(zone, false),
      onPointerCancel: (_) => _sendManual(zone, false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 6)
              ],
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manual Controller')),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/bground.png', fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child:
                              _buildButton(context, 'FL', LightZone.frontLeft),
                        ),
                      ),
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child:
                              _buildButton(context, 'FR', LightZone.frontRight),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child:
                              _buildButton(context, 'RL', LightZone.rearLeft),
                        ),
                      ),
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child:
                              _buildButton(context, 'RR', LightZone.rearRight),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PresetPicker extends StatelessWidget {
  final List<Map<String, dynamic>> presets;
  final int selectedPresetIndex;
  final void Function(Map<String, dynamic>) onApply;
  final void Function(int) onUpdate;
  final Future<void> Function() onSave;

  const PresetPicker({
    Key? key,
    required this.presets,
    required this.selectedPresetIndex,
    required this.onApply,
    required this.onUpdate,
    required this.onSave,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
              onPressed: onSave,
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
              onUpdate(i);
              if (i >= 0 && i < presets.length) onApply(presets[i]);
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
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: presets.isEmpty
                    ? null
                    : () {
                        presets.removeAt(selectedPresetIndex);
                        onUpdate(selectedPresetIndex >= presets.length
                            ? presets.length - 1
                            : selectedPresetIndex);
                        onSave();
                      },
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24)),
                child:
                    const Text('Delete', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: onSave,
                child: const Text('Save New',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

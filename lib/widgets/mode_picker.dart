import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ModePicker extends StatelessWidget {
  final List<String> modes;
  final int selectedModeIndex;
  final void Function(int, String) onChanged;

  const ModePicker({
    Key? key,
    required this.modes,
    required this.selectedModeIndex,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final initial = selectedModeIndex.clamp(0, modes.length - 1);
    return CupertinoPicker(
      scrollController: FixedExtentScrollController(initialItem: initial),
      itemExtent: 40,
      useMagnifier: true,
      magnification: 1.15,
      onSelectedItemChanged: (i) => onChanged(i, modes[i]),
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
}

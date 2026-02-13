import 'package:flutter/material.dart';

class ZoneIndicator extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const ZoneIndicator({
    Key? key,
    required this.label,
    required this.active,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
}

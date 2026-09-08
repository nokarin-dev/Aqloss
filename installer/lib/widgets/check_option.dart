import 'package:flutter/material.dart';

class CheckOption extends StatelessWidget {
  const CheckOption({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: value ? const Color(0xFF4F8EF7) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: value
                    ? const Color(0xFF4F8EF7)
                    : const Color(0xFF3A3A48),
                width: 1.5,
              ),
            ),
            child: value
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF9A9AAA), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

class FloatingNavItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;

  const FloatingNavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
  });
}

class FloatingPillNavBar extends StatelessWidget {
  final int currentIndex;
  final List<FloatingNavItem> items;
  final ValueChanged<int> onTap;
  final Color activeColor;
  final Color inactiveColor;

  const FloatingPillNavBar({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
    this.activeColor = const Color(0xFF6366F1), // Modern Indigo/Purple
    this.inactiveColor = const Color(0xFF6B7280),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(
          // ignore: deprecated_member_use
          color: activeColor.withOpacity(0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: activeColor.withOpacity(0.18),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = index == currentIndex;

              return Expanded(
                child: InkWell(
                  onTap: () => onTap(index),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          // ignore: deprecated_member_use
                          ? activeColor.withOpacity(0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected
                              ? (item.activeIcon ?? item.icon)
                              : item.icon,
                          color: isSelected ? activeColor : inactiveColor,
                          size: 22,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected ? activeColor : inactiveColor,
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          // iOS style subtle home bar line at bottom inside the pill widget
          Center(
            child: Container(
              width: 90,
              height: 3.5,
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: activeColor.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentIndex});

  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kSurfaceLowest,
        boxShadow: const [
          BoxShadow(
            color: Color(0x100D3732),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.explore_outlined,
                label: 'Home',
                isSelected: currentIndex == 0,
                onTap: () {
                  if (currentIndex != 0) context.go('/');
                },
                activeColor: kPrimary,
                inactiveColor: kSecondary,
              ),
              _NavItem(
                icon: Icons.map_outlined,
                label: 'Offline Maps',
                isSelected: currentIndex == 1,
                onTap: () {
                  if (currentIndex != 1) context.go('/offline-maps');
                },
                activeColor: kPrimary,
                inactiveColor: kSecondary,
              ),
              _NavItem(
                icon: Icons.tune,
                label: 'Settings',
                isSelected: currentIndex == 2,
                onTap: () {
                  if (currentIndex != 2) context.go('/settings');
                },
                activeColor: kPrimary,
                inactiveColor: kSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.activeColor,
    required this.inactiveColor,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? activeColor : inactiveColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: color),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: color,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

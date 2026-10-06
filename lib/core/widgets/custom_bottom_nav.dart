import 'package:flutter/material.dart';
import '../../features/auth/home_screen.dart';
import '../../features/food/favorites_screen.dart';
import '../../features/profile/profile_screen.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final bool isDarkMode;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    this.isDarkMode = true, 
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode ? const Color(0xFF101817) : Colors.white;
    final selectedColor = isDarkMode ? Colors.white : const Color(0xFF127B6D);
    final unselectedColor = isDarkMode ? const Color(0xFFA1AFA9) : const Color(0xFF6B7280);

    return BottomAppBar(
      color: bgColor,
      surfaceTintColor: Colors.transparent,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            context: context,
            icon: Icons.book,
            label: 'Diario',
            index: 0,
            selectedColor: selectedColor,
            unselectedColor: unselectedColor,
            targetScreen: const HomeScreen(),
          ),
          _buildNavItem(
            context: context,
            icon: Icons.restaurant,
            label: 'Alimenti',
            index: 1,
            selectedColor: selectedColor,
            unselectedColor: unselectedColor,
            targetScreen: const FavoritesScreen(),
          ),
          const SizedBox(width: 40),
          _buildNavItem(
            context: context,
            icon: Icons.person_outline,
            label: 'Profilo',
            index: 2,
            selectedColor: selectedColor,
            unselectedColor: unselectedColor,
            targetScreen: const ProfileScreen(),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int index,
    required Color selectedColor,
    required Color unselectedColor,
    Widget? targetScreen,
  }) {
    final isSelected = currentIndex == index;
    final color = isSelected ? selectedColor : unselectedColor;

    return InkWell(
      onTap: () {
        if (!isSelected && targetScreen != null) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation1, animation2) => targetScreen,
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
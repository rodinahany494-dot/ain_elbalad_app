import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class TechNavBar extends StatelessWidget {
  final int currentIndex;

  const TechNavBar({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF2A6BA9),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _navItem(context, 0, 'assets/icons/completed_tasks.svg',
                Icons.check_circle_outline),

            _navItem(context, 1, 'assets/icons/in_progress.svg',
                Icons.trending_up),

            /// 🔶 HOME (center)
            GestureDetector(
              onTap: () {
                if (currentIndex == 2) return;
                Navigator.pushReplacementNamed(context, '/home');
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFA500),
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(
                  'assets/home_new.png', // لو png سيبيه، لو svg غيره
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                      Colors.white, BlendMode.srcIn),
                ),
              ),
            ),

            _navItem(context, 3, 'assets/icons/my_tasks.svg',
                Icons.list_alt),

            _navItem(context, 4, 'assets/icons/update_tasks.svg',
                Icons.update),
          ],
        ),
      ),
    );
  }

  Widget _navItem(
      BuildContext context, int index, String path, IconData fallback) {
    final isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () {
        if (index == currentIndex) return;

        switch (index) {
          case 0:
            Navigator.pushReplacementNamed(context, '/completed');
            break;
          case 1:
            Navigator.pushReplacementNamed(context, '/in_progress');
            break;
          case 3:
            Navigator.pushReplacementNamed(context, '/tasks');
            break;
          case 4:
            Navigator.pushReplacementNamed(context, '/update');
            break;
        }
      },
      child: SvgPicture.asset(
        path,
        width: 24,
        height: 24,
        colorFilter: ColorFilter.mode(
          isSelected ? const Color(0xFFFFA500) : Colors.white,
          BlendMode.srcIn,
        ),
        placeholderBuilder: (c) =>
            Icon(fallback, color: Colors.white, size: 24),
      ),
    );
  }
}
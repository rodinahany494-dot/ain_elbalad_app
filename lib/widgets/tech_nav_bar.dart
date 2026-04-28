import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ain_elbalad/technician/technician_screens.dart';

class TechNavBar extends StatelessWidget {
  final int currentIndex;

  const TechNavBar({super.key, required this.currentIndex});

  static const Color _bluePrimary = Color(0xFF2A6BA9);
  static const Color _activeYellow = Color(0xFFFFA500);

  Widget _navItem(
    BuildContext context,
    int index,
    Widget page,
    String path,
    IconData fallback,
  ) {
    final isActive = currentIndex == index;

    return GestureDetector(
      onTap: () {
        if (isActive) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => page),
        );
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isActive ? _activeYellow : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: SvgPicture.asset(
            path,
            width: 24,
            height: 24,
            colorFilter: const ColorFilter.mode(
              Colors.white,
              BlendMode.srcIn,
            ),
            placeholderBuilder: (BuildContext context) => Icon(
              fallback,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _homeItem(BuildContext context) {
    final isActive = currentIndex == 2;

    return GestureDetector(
      onTap: () {
        if (isActive) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const TechnicianHomeScreen(),
          ),
        );
      },
      child: Container(
        width: 40,
        height: 40,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? _activeYellow : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Image.asset(
          'assets/home_new.png',
          width: 24,
          height: 24,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _bluePrimary,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _navItem(
              context,
              0,
              const CompletedTasksScreen(),
              'assets/icons/completed_tasks.svg',
              Icons.check_circle_outline,
            ),
            _navItem(
              context,
              1,
              const InProgressTasksScreen(),
              'assets/icons/in_progress.svg',
              Icons.trending_up,
            ),
            _homeItem(context),
            _navItem(
              context,
              3,
              const TasksScreen(),
              'assets/icons/my_tasks.svg',
              Icons.list_alt,
            ),
            _navItem(
              context,
              4,
              const UpdateTaskScreen(taskId: '', status: 'In Progress'),
              'assets/icons/update_tasks.svg',
              Icons.update,
            ),
          ],
        ),
      ),
    );
  }
}
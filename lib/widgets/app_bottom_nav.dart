import 'package:flutter/material.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onLocationTap,
    required this.onHomeTap,
    required this.onTrackTap,
    required this.onCreateTap,
    this.locationLoading = false,
  });

  final int currentIndex;
  final VoidCallback onLocationTap;
  final VoidCallback onHomeTap;
  final VoidCallback onTrackTap;
  final VoidCallback onCreateTap;
  final bool locationLoading;

  static const Color _blue = Color(0xFF004E98);
  static const Color _activeYellow = Color(0xFFFFB200);

  Widget _iconItem(IconData icon, int index, VoidCallback onTap) {
    final isActive = currentIndex == index;
    if (isActive) {
      return Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: _activeYellow,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      );
    }
    return IconButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      icon: Icon(icon, color: Colors.white, size: 24),
    );
  }

  Widget _locationItem() {
    final isActive = currentIndex == 0;
    if (isActive) {
      return Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: _activeYellow,
          shape: BoxShape.circle,
        ),
        child: locationLoading
            ? const Padding(
                padding: EdgeInsets.all(7),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(
                Icons.location_on_outlined,
                color: Colors.white,
                size: 24,
              ),
      );
    }
    return IconButton(
      onPressed: onLocationTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      icon: const Icon(
        Icons.location_on_outlined,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 343,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _blue,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _locationItem(),
          _iconItem(Icons.home_outlined, 1, onHomeTap),
          _iconItem(Icons.local_shipping_outlined, 2, onTrackTap),
          _iconItem(Icons.note_add_outlined, 3, onCreateTap),
        ],
      ),
    );
  }
}

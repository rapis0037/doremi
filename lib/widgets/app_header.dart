import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.onLeading,
    required this.trailing,
    required this.onTrailing,
  });
  final String title;
  final String subtitle;
  final IconData leading;
  final VoidCallback onLeading;
  final IconData trailing;
  final VoidCallback onTrailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: Row(
        children: [
          IconButton(tooltip: '뒤로', onPressed: onLeading, icon: Icon(leading, size: 28)),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Color(0xff687582), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: trailing == Icons.settings_outlined ? '설정' : '음정 소리',
            onPressed: onTrailing,
            icon: Icon(trailing, size: 28),
          ),
        ],
      ),
    );
  }
}

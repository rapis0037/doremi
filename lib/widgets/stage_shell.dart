import 'package:flutter/material.dart';

import 'app_background.dart';
import 'app_header.dart';
import 'dialogs/sound_settings_dialog.dart';
import 'responsive_viewport.dart';

class StageShell extends StatelessWidget {
  const StageShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.soundOn,
    required this.onSoundChanged,
    required this.onBack,
    required this.child,
  });
  final String title;
  final String subtitle;
  final bool soundOn;
  final ValueChanged<bool> onSoundChanged;
  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: ResponsiveViewport(
            child: Column(
              children: [
                AppHeader(
                  title: title,
                  subtitle: subtitle,
                  leading: Icons.arrow_back_rounded,
                  onLeading: onBack,
                  trailing: Icons.music_note_rounded,
                  onTrailing: () => showSoundSettings(context, value: soundOn, onChanged: onSoundChanged),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

Future<void> showSoundSettings(
  BuildContext context, {
  required bool value,
  required ValueChanged<bool> onChanged,
  bool? sparklesOn,
  ValueChanged<bool>? onSparklesChanged,
}) {
  if (sparklesOn != null && onSparklesChanged != null) {
    return _showLearningSettings(
      context,
      voiceOn: value,
      sparklesOn: sparklesOn,
      onVoiceChanged: onChanged,
      onSparklesChanged: onSparklesChanged,
    );
  }
  return _showVoiceSettings(context, value: value, onChanged: onChanged);
}

Future<void> _showLearningSettings(
  BuildContext context, {
  required bool voiceOn,
  required bool sparklesOn,
  required ValueChanged<bool> onVoiceChanged,
  required ValueChanged<bool> onSparklesChanged,
}) async {
  var currentVoice = voiceOn;
  var currentSparkles = sparklesOn;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setLocal) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 50),
                    const Expanded(
                      child: Text(
                        '학습 설정',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('완료'),
                    ),
                  ],
                ),
                const Divider(),
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: const Text(
                    '계이름 목소리',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  value: currentVoice,
                  onChanged: (next) {
                    currentVoice = next;
                    onVoiceChanged(next);
                    setLocal(() {});
                  },
                ),
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: const Text(
                    '스파클 효과',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  value: currentSparkles,
                  onChanged: (next) {
                    currentSparkles = next;
                    onSparklesChanged(next);
                    setLocal(() {});
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _showVoiceSettings(
  BuildContext context, {
  required bool value,
  required ValueChanged<bool> onChanged,
}) async {
  var current = value;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setLocal) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 62),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 50),
                    const Expanded(
                      child: Text(
                        '음정 소리',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('완료'),
                    ),
                  ],
                ),
                const Divider(),
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: const Text(
                    '계이름 음성',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  value: current,
                  onChanged: (next) {
                    current = next;
                    onChanged(next);
                    setLocal(() {});
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

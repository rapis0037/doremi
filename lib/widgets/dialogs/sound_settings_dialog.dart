import 'package:flutter/material.dart';

Future<void> showSoundSettings(
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
                      child: Text('음정 소리', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    ),
                    TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('완료')),
                  ],
                ),
                const Divider(),
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: const Text('피아노 음정', style: TextStyle(fontWeight: FontWeight.w700)),
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

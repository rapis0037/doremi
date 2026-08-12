import 'package:audioplayers/audioplayers.dart';

import '../core/constants.dart';
import '../core/models.dart';

/// 건반 음원(피아노)과 계이름 음성을 재생한다.
///
/// 두 소리는 겹쳐 들려야 한다 — 건반을 누르면 피아노 음이 울리는 채로 음표가
/// 날아가고, 오선지에 안착한 뒤 그 위로 "도!" 하고 음성이 얹힌다. 한 플레이어로
/// 둘 다 재생하면 음성이 피아노 음을 끊어 버리므로 채널을 나눠 둔다.
class TonePlayer {
  final AudioPlayer _note = AudioPlayer();
  final AudioPlayer _voice = AudioPlayer();

  /// 첫 탭이 지연되지 않도록 음원을 미리 디코딩해 둔다.
  Future<void> preload() async {
    try {
      await AudioCache.instance.loadAll({
        for (final note in notes) ...[note.noteAsset, note.voiceAsset],
      }.toList());
    } catch (_) {
      // 미리 불러오지 못해도 재생 시점에 다시 읽으므로 무시한다.
    }
  }

  Future<void> playNote(NoteSpec note) => _play(_note, note.noteAsset);

  Future<void> playVoice(NoteSpec note) => _play(_voice, note.voiceAsset, volume: .5);

  /// 같은 채널의 이전 소리는 끊는다. 건반을 연달아 누르면 앞 음이 물리지 않는다.
  Future<void> _play(AudioPlayer player, String asset, {double volume = 1}) async {
    await player.stop();
    await player.setVolume(volume);
    await player.play(AssetSource(asset));
  }

  Future<void> dispose() async {
    await _note.dispose();
    await _voice.dispose();
  }
}

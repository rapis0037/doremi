import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

class TonePlayer {
  final AudioPlayer _player = AudioPlayer();
  final Map<String, Uint8List> _cache = {};

  Future<void> playNote(double frequency, {required double durationSeconds}) async {
    final key = '${frequency.toStringAsFixed(2)}-$durationSeconds';
    final bytes = _cache.putIfAbsent(key, () => _createWav(frequency, durationSeconds));
    await _player.stop();
    await _player.play(BytesSource(bytes));
  }

  Future<void> dispose() => _player.dispose();

  Uint8List _createWav(double frequency, double seconds) {
    const sampleRate = 22050;
    final sampleCount = (sampleRate * seconds).round();
    final dataSize = sampleCount * 2;
    final bytes = ByteData(44 + dataSize);

    void text(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        bytes.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    text(0, 'RIFF');
    bytes.setUint32(4, 36 + dataSize, Endian.little);
    text(8, 'WAVE');
    text(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    text(36, 'data');
    bytes.setUint32(40, dataSize, Endian.little);

    for (var i = 0; i < sampleCount; i++) {
      final t = i / sampleRate;
      final attack = math.min(1.0, t / .035);
      final release = math.min(1.0, (seconds - t) / .18).clamp(0.0, 1.0).toDouble();
      final envelope = attack * release * math.exp(-.38 * t);
      final sample = (
            math.sin(2 * math.pi * frequency * t) * .68 +
            math.sin(2 * math.pi * frequency * 2 * t) * .19 +
            math.sin(2 * math.pi * frequency * 3 * t) * .08
          ) *
          envelope;
      bytes.setInt16(
        44 + i * 2,
        (sample * 27000).round().clamp(-32768, 32767).toInt(),
        Endian.little,
      );
    }
    return bytes.buffer.asUint8List();
  }
}

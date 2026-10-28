import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/services/offline_voice_service.dart';

void main() {
  test('PCM meter reports silence and scales with actual audio energy', () {
    Uint8List pcm(int amplitude) {
      final data = ByteData(320);
      for (var i = 0; i < 160; i++) {
        data.setInt16(i * 2, i.isEven ? amplitude : -amplitude, Endian.little);
      }
      return data.buffer.asUint8List();
    }

    expect(pcmRecordingLevel(Uint8List(0)), 0);
    expect(pcmRecordingLevel(Uint8List(1)), 0);
    expect(pcmRecordingLevel(pcm(0)), 0);
    expect(pcmRecordingLevel(pcm(1)), 0);
    final quiet = pcmRecordingLevel(pcm(100));
    final speech = pcmRecordingLevel(pcm(4000));
    expect(quiet, greaterThan(0));
    expect(speech, greaterThan(quiet));
    expect(pcmRecordingLevel(pcm(32767)), closeTo(1, 0.001));
  });
}

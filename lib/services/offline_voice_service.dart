import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

abstract class VoiceCapture {
  /// Current microphone loudness, from silence (0) to full scale (1).
  ValueListenable<double> get level;
  Future<void> start();
  Future<String> stopAndTranscribe({String language = ''});
  Future<void> cancel();
  Future<void> dispose();
}

/// Microphone PCM and inference stay on this device. No network fallback.
class OfflineVoiceService implements VoiceCapture {
  final _level = ValueNotifier<double>(0);
  @override
  ValueListenable<double> get level => _level;

  final AudioRecorder _recorder = AudioRecorder();
  final BytesBuilder _audio = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? _subscription;
  String? _modelPath;
  bool _disposed = false;
  bool _recording = false;
  int _generation = 0;
  Object? _captureError;
  static const sampleRate = 16000;
  static const maxSeconds = 30;

  Future<String> _prepareModel() async {
    if (_modelPath != null) return _modelPath!;
    Map<String, dynamic> manifest;
    try {
      manifest = jsonDecode(
              await rootBundle.loadString('assets/offline_voice/manifest.json'))
          as Map<String, dynamic>;
    } catch (_) {
      throw StateError(
          'This build does not include the offline speech model. Install a build with the model bundled, or type your command.');
    }
    final support = await getApplicationSupportDirectory();
    final version = (manifest['archive_sha256'] as String).substring(0, 12);
    final directory = Directory('${support.path}/offline_voice/base-$version');
    await directory.create(recursive: true);
    final files = (manifest['files'] as Map).cast<String, dynamic>();
    for (final name in [
      'encoder.int8.onnx',
      'decoder.int8.onnx',
      'tokens.txt'
    ]) {
      final file = File('${directory.path}/$name');
      final size = (files[name] as Map)['bytes'] as int;
      if (await file.exists() && await file.length() == size) continue;
      final data = await rootBundle.load('assets/offline_voice/$name');
      if (data.lengthInBytes != size) {
        throw StateError(
            'The offline model is incomplete. Reinstall an app build that includes the model, or type your command.');
      }
      final temporary = File('${file.path}.partial');
      await temporary.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true);
      await temporary.rename(file.path);
    }
    return _modelPath = directory.path;
  }

  @override
  Future<void> start() async {
    final generation = ++_generation;
    if (_disposed) throw StateError('Voice input has been closed.');
    if (!Platform.isAndroid && !Platform.isWindows) {
      throw UnsupportedError(
          'Offline voice input is available on Android and Windows.');
    }
    if (_recording) return;
    if (!await _recorder.hasPermission()) {
      throw StateError(
          'Microphone permission is needed. Enable it in device settings, or type your command.');
    }
    if (_disposed || generation != _generation) return;
    await _prepareModel();
    if (_disposed || generation != _generation) return;
    _audio.clear();
    _level.value = 0;
    _captureError = null;
    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: sampleRate,
      numChannels: 1,
    ));
    if (_disposed || generation != _generation) {
      await _recorder.stop();
      return;
    }
    _recording = true;
    _subscription = stream.listen((chunk) {
      _level.value = pcmRecordingLevel(chunk);
      final remaining = maxSeconds * sampleRate * 2 - _audio.length;
      if (remaining > 0) {
        _audio.add(chunk.length <= remaining
            ? chunk
            : Uint8List.sublistView(chunk, 0, remaining));
      }
    }, onError: (Object error) {
      _level.value = 0;
      _captureError = error;
    }, onDone: () {
      _level.value = 0;
    });
  }

  @override
  Future<String> stopAndTranscribe({String language = ''}) async {
    if (!_recording) return '';
    _recording = false;
    try {
      await _recorder.stop();
    } finally {
      await _subscription?.cancel();
      _subscription = null;
      _level.value = 0;
    }
    if (_captureError != null) {
      _audio.clear();
      throw StateError('The microphone was interrupted. Please record again.');
    }
    final pcm = _audio.takeBytes();
    if (_disposed || pcm.isEmpty) return '';
    return compute(transcribeOfflinePcm, <String, Object>{
      'path': _modelPath!,
      'pcm': pcm,
      'language': language,
    });
  }

  @override
  Future<void> cancel() async {
    _generation++;
    try {
      if (_recording) {
        _recording = false;
        await _recorder.stop();
      }
    } finally {
      await _subscription?.cancel();
      _subscription = null;
      _audio.clear();
      _level.value = 0;
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    try {
      await cancel();
    } finally {
      try {
        await _recorder.dispose();
      } finally {
        _level.dispose();
      }
    }
  }
}

/// RMS loudness from the same PCM16 audio used for local transcription.
/// Map -60..0 dBFS to 0..1 so ordinary speech remains visible.
double pcmRecordingLevel(Uint8List pcm) {
  final count = pcm.length ~/ 2;
  if (count == 0) return 0;
  final view = ByteData.sublistView(pcm);
  var sum = 0.0;
  for (var i = 0; i < count; i++) {
    final sample = view.getInt16(i * 2, Endian.little) / 32768.0;
    sum += sample * sample;
  }
  if (sum == 0) return 0;
  final decibels = 20 * math.log(math.sqrt(sum / count)) / math.ln10;
  return ((decibels + 60) / 60).clamp(0.0, 1.0);
}

/// Top-level entry point also used by the native offline smoke check.
String transcribeOfflinePcm(Map<String, Object> input) {
  final pcm = input['pcm'] as Uint8List;
  final view = ByteData.sublistView(pcm);
  final samples = Float32List(pcm.length ~/ 2);
  var audibleSamples = 0;
  for (var i = 0; i < samples.length; i++) {
    samples[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
    if (samples[i].abs() > 0.01) audibleSamples++;
  }
  // Avoid decoding empty/silent buffers; this is not an emotion classifier.
  if (audibleSamples < 1280) return '';
  final path = input['path'] as String;
  sherpa.initBindings();
  final recognizer = sherpa.OfflineRecognizer(sherpa.OfflineRecognizerConfig(
    model: sherpa.OfflineModelConfig(
      whisper: sherpa.OfflineWhisperModelConfig(
        encoder: '$path/encoder.int8.onnx',
        decoder: '$path/decoder.int8.onnx',
        language: input['language'] as String? ?? '',
        task: 'transcribe',
      ),
      tokens: '$path/tokens.txt',
      modelType: 'whisper',
      numThreads: 2,
      debug: false,
      provider: 'cpu',
    ),
  ));
  try {
    final stream = recognizer.createStream();
    try {
      stream.acceptWaveform(
          samples: samples, sampleRate: OfflineVoiceService.sampleRate);
      recognizer.decode(stream);
      return recognizer.getResult(stream).text.trim();
    } finally {
      stream.free();
    }
  } finally {
    recognizer.free();
  }
}

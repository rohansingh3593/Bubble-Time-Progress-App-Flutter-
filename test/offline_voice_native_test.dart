import 'dart:io';
import 'dart:convert';
import 'dart:ffi';

import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/services/offline_voice_service.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

void main() {
  test('bundled native model decodes a local sample without a speech API',
      () async {
    // Flutter's test runner does not copy plugin DLLs beside flutter_tester.
    // Resolve the installed package for this opt-in test; installed apps bundle it.
    if (Platform.isWindows) {
      final configFile = File('.dart_tool/package_config.json').absolute;
      final config = jsonDecode(await configFile.readAsString()) as Map;
      final package = (config['packages'] as List)
          .cast<Map>()
          .singleWhere((p) => p['name'] == 'sherpa_onnx_windows');
      final root =
          configFile.uri.resolve(package['rootUri'] as String).toFilePath();
      final arch = Platform.version.contains('arm64') ? 'arm64' : 'x64';
      final libraries = '$root/windows/$arch';
      DynamicLibrary.open('$libraries/onnxruntime.dll');
      sherpa.initBindings(libraries);
    }
    final text = transcribeOfflinePcm({
      'path': Directory('assets/offline_voice').absolute.path,
      'pcm': await File('.dart_tool/voice_model/sample.pcm').readAsBytes(),
      'language': 'en',
    });
    expect(text.trim().split(RegExp(r'\s+')).length, greaterThan(3));
  },
      skip: !const bool.fromEnvironment('RUN_NATIVE_VOICE_TEST'),
      timeout: const Timeout(Duration(minutes: 2)));
}

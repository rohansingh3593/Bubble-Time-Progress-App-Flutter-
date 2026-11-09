# Bundled offline speech model

Run `python tool/prepare_voice_model.py` before building the application.
This downloads the multilingual Whisper base ONNX model from the sherpa-onnx
project, extracts the INT8 encoder/decoder and token list, and verifies them
against manifest.json. Only this development step uses the network.

The application reads the bundled files locally. It has no model downloader,
speech API key, hosted recognition endpoint, or cloud fallback. Missing assets
produce an actionable error; text entry remains available.

The multilingual model supports Hindi and English. Mixed speech accuracy and
latency depend on pronunciation, noise and hardware and require device trials.
It transcribes speech; task extraction is implemented separately in Dart.

Model source: https://github.com/k2-fsa/sherpa-onnx/releases/tag/asr-models
Model license: MIT (Whisper; see WHISPER_LICENSE.txt).
Runtime license: Apache-2.0 (sherpa-onnx package).

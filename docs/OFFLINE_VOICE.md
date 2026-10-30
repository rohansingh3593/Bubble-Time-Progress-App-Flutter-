# Offline voice tasks

Current direction, 2026-10-28: the user requires Android and Windows support,
fully offline Hindi, English and mixed speech. This supersedes the earlier
provider/API-first AI proposal. No Goblin Tools integration is used.

## User flow

Choose **Add by voice** from the navigation menu or Master Tasks, or tap the
microphone in Day. Tap **Record a command**, speak your task, then **Stop recording**.
While recording, a heartbeat-style waveform follows the actual microphone volume,
with a listening label and elapsed time. Silence produces a flat trace. This is a
sound-level display; recognized words appear after Stop, not as live captions.
The waveform uses the same local audio as transcription and stops on recording
completion/cancellation. Feedback checks: four tests passed across
`voice_tasks_widget_test.dart` and `voice_recording_level_test.dart`; targeted Dart
analysis found no issues. Real-device microphone trials are still required.
For one task creation, the filled-in task form opens automatically. Review it and
press **Save task** to add the task. Recording and parsing alone never save it.
For multiple tasks or edit/completion commands, review the draft cards. You can also
correct/type a transcript and press **Analyse command**. Duplicate
task names require choosing a specific task; selection is stored by immutable ID.

Examples:

- `Add study Python tomorrow at 6 pm for ten minutes`
- `Please remind me to finish the report tomorrow at six thirty pm for half an hour`
- `मुझे कल शाम छह बजे दूध खरीदना है`
- `mujhe kal shaam chhe baje Python padhna hai`
- `Remind me to call Mum on Friday at five pm`
- `Add renew passport on November 5`
- `Remind me to call Mum in ten minutes for five minutes`
- `कल शाम छह बजे Python पढ़ना दस मिनट के लिए जोड़ो`
- `Rename study Python to practise Python`
- `Edit practise Python for twenty five minutes`
- `Reschedule practise Python tomorrow at 6 pm`
- `Complete practise Python` / `Python पढ़ना पूरा कर दो`
- `Add launch project with steps plan, build, test`

Separate multiple commands with newlines or semicolons in the editable transcript.
The parser supports explicit commands and common conversational task phrases,
not unrestricted conversational reasoning.
Speech can be Hindi, English, or mixed; name matching is exact after case/spacing
normalization. It does not translate stored names to guess a target.

Dates support today, tomorrow, day after tomorrow, आज, कल, परसों and YYYY-MM-DD.
The offline [chrono_dart](https://pub.dev/packages/chrono_dart) library also handles
selected calendar phrases: English weekdays, full month names with numeric days,
`in three days`, and `next week`. Hindi/Hinglish weekday names and relative days
are normalized locally before date extraction. Chrono itself supports English;
this does not claim general Hindi language understanding.

Bare weekdays mean the upcoming occurrence (including today); `next Friday`
follows the library's following-week convention. `next week` means seven days
from today. The interpreted calendar date is shown in the review form. Chrono
returns UTC dates, which are converted to local time. The integration normalizes
bare weekdays through `this weekday` and `next week` through `in 7 days` to avoid
incorrect results found in the package's forward-weekday/casual-week paths.
Calendar phrases are extracted before calling the library so names such as May
and task numbers such as chapter 6 are preserved.

`In ten minutes` schedules the task ten minutes from now; `for ten minutes` sets
its duration. Spoken `six thirty pm`, `six in the evening`, compound hour/minute
durations, `half an hour`, `one and a half hours` and `आधा घंटा` are supported.
Conflicting recognized dates/times/durations require transcript correction.
Bare English `at six` requires AM/PM. Arbitrary phrasing, recurring schedules,
and unsupported fractions still need the task editor; this is a bounded parser.
Use one unit for a relative start delay (`in 90 minutes`); compound task durations
(`for one hour and thirty minutes`) are supported. Parser/review verification:
28 tests passed across voice_natural_language_test.dart, voice_tasks_test.dart,
voice_tasks_widget_test.dart and task_form_test.dart. Targeted Dart analysis found
no issues. These are transcript-to-task tests, not acoustic accuracy benchmarks.

कल is interpreted as tomorrow and explicitly flagged for review. English AM/PM,
24-hour HH:MM and Hindi morning/evening times are supported. Durations use whole
minutes/hours, including supported English/Hindi number words and Devanagari
digits. Unspecified durations use the existing task editor default of 15 minutes.
Spoken step names create flat steps. A stated total duration is distributed
across those steps without losing minutes (25 across three steps becomes 9/8/8);
otherwise each starts at 15 minutes. Both defaults are explained before review. This is transcription of supplied steps, not generated task breakdown.
Existing project duration comes from its individual steps; a voice command that
only replaces that total is rejected with guidance to edit the individual times.

Completion of a project previews completion of its steps using existing duration
accounting. The user can inspect/correct this before confirming. Routine completion
targets today's occurrence; routine date/time commands are rejected with guidance
to use recurrence settings. Routine rename/duration commands are supported. Daily Journal is excluded from command targets. Deletion, negative commands,
automatic background actions and emotional-tone analysis are outside this release.

## Implementation

```text
Microphone → local PCM16 → bundled multilingual model → editable transcript
           → Dart command parser → task preview → explicit save → existing Hive
```

| File | Role |
| --- | --- |
| lib/services/offline_voice_service.dart | Native microphone capture, bundled model staging and local CPU inference in an isolate; no HTTP client or speech service. |
| lib/services/voice_task_parser.dart | Bounded Hindi/English command and duration rules plus offline Chrono date extraction; produces drafts only. |
| lib/models/voice_task_draft.dart | Typed, immutable proposal with an ID. |
| lib/services/voice_task_service.dart | ID-based target selection, preview, stale-source checks and confirmed local writes. |
| lib/screens/voice_tasks_screen.dart | Record/stop/correct/analyse/review workflow; typed fallback after microphone/model errors. |
| lib/widgets/voice_listening_indicator.dart | Live microphone-level trace and recording timer; removed when recording ends. |
| lib/widgets/quick_add_task_dialog.dart | Existing editor, including exact durations and preserved scheduled hour/minute. |
| lib/services/hive_service.dart | Existing task persistence plus a replayable date-move intent. |
| tool/prepare_voice_model.py | Development-time download, safe extraction, pinned hash verification and smoke-test fixture preparation. |

Task rescheduling persists `__pending_task_move__` as source key, destination key,
and the updated Task before changing buckets. It upserts the same ID at the target,
removes it from the source, recalculates snapshots and removes the intent. Startup
replays interrupted moves. Move operations are serialized; this is not a general
transaction or multi-device conflict solution for all existing app writes.

## Runtime, model and privacy boundary

The speech runtime is [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx), using its
multilingual Whisper base INT8 encoder and decoder. Its Flutter support includes
Android and Windows. Model `.en` variants are English-only and must not replace
the multilingual assets. See the project's [model documentation](https://k2-fsa.github.io/sherpa/onnx/pretrained_models/whisper/export-onnx.html).
Microphone capture uses [record](https://pub.dev/packages/record); path_provider
locates private local model storage. Versions are locked in pubspec.lock.
`chrono_dart` 2.0.2 and its `day` dependency run in Dart on the device. They need
no model, API key, backend or network connection. The speech model is unchanged.

The bundled model files total approximately 153.2 MiB. The initial development
download is about 208 MB. First voice use copies assets into application support
storage, so additional local disk space is required. Model copies are reused.
Recognition uses CPU and latency varies by device. Mixed-language accuracy is a
target requiring real microphone trials, not a guaranteed language benchmark.

The voice path has no API key, HTTP call, runtime model download or cloud fallback.
Recording begins only after a user tap and microphone permission. Audio is held
in a bounded memory buffer, not saved to disk. Backgrounding/cancelling stops
capture; dismissing releases the recorder. Decoding already in progress can finish
in its isolate, but a dismissed screen discards the result. The transcript is held
in screen state; saved task text is stored locally. Existing optional task sync is
a separate feature, disabled by default; it is not needed for voice input.

The speech model's MIT license is bundled in assets/offline_voice/WHISPER_LICENSE.txt.
The runtime is Apache-2.0. Runtime staging checks sizes; development preparation
verifies the archive and individual files against the committed SHA-256 manifest.

## Prepare, build and verify

Run from the repository root:

```powershell
flutter pub get
python tool/prepare_voice_model.py
flutter test --no-pub
flutter test --no-pub test/offline_voice_native_test.dart --dart-define=RUN_NATIVE_VOICE_TEST=true
flutter build windows --debug --no-pub
flutter build apk --debug --flavor safe --no-pub
```

Native/model packages and the model are downloaded during development, then
bundled in the binaries. A fresh checkout must run preparation before packaging;
large ONNX/token files are deliberately excluded from Git. The opt-in native
test uses the public English WAV fixture distributed with the model, not a
recording of the user. Normal tests skip that heavier test.

Automated coverage includes Hindi/mixed text parsing, duration/date validation,
duplicate names, preview-only behavior, repeated Apply, stale-source rejection,
step completion, date-move recovery and the microphone-error typed fallback.

Release acceptance still requires real Android and Windows microphone sessions:
grant/deny permission, background during capture, short/silent/noisy input, Hindi,
English and mixed speech, duplicate task names, and first-launch recording with
network access disabled. Measure latency and memory on the actual target phone.
Debug builds and an English native fixture do not establish these device results.


## Executed verification (2026-10-28)

- Full regression suite with the native model enabled: **31 tests passed**.
- Static analysis of the new voice models/services/screen/tests: **no issues found**.
- Windows debug build: passed; executable at
  `build/windows/x64/runner/Debug/momentum.exe` (keep its adjacent files).
- Android safe debug build: passed; APK at
  `build/app/outputs/flutter-apk/app-safe-debug.apk`.
- Cached model preparation repeated successfully, including archive/file hash checks
  and extraction of the reproducible native smoke-test sample.
- Project documentation links resolve; README.md is the only root Markdown file.
- `git diff --check`: passed.

The native recognition check decoded a public English speech sample. Parser tests
cover Hindi and mixed transcripts. Widget tests use a fake microphone and isolated
store; separate service tests exercise actual temporary Hive storage. These results
must not be represented as real microphone or Hindi/Hinglish acoustic accuracy tests.

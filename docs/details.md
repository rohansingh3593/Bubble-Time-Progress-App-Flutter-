# Momentum repository analysis and implementation reference

Current direction (2026-10-28): fully offline voice-to-task creation and edit/completion commands on Android and Windows, with Hindi, English and mixed speech. No external inference API dependency. The earlier hosted-provider AI plan is superseded by this constraint. See [offline voice implementation and validation](OFFLINE_VOICE.md).

Implementation update (2026-10-28): immutable task/step IDs, Hive schema-v3 step migration, and exact positive-minute handling are now implemented. The AI tools and focus-session feature remain planned. See [verified foundation changes](details.md#j-implemented-foundations).

Assessment date: 2026-10-28. Evidence is the current working tree, including existing
uncommitted changes. This is a source review with limited executed checks, not a
claim that all features/platforms work. The original placeholder idea has now been
replaced by the user's seven AI/focus feature requirements. Earlier source findings describe the pre-foundation baseline except where
updated below; section J records the implemented changes; the new planning findings appear in section I. No hosted-provider AI implementation has been added. Offline speech inference is
now implemented; the current status and checks are in OFFLINE_VOICE.md.

Evidence labels used here:

- **Confirmed**: directly present in inspected source/configuration or observed in
  an executed check. Source presence does not establish runtime correctness.
- **Inferred**: likely consequence of a code path; needs a reproducing test.
- **Unverified**: environment, behavior or external decision not established here.
- **Proposed**: future implementation, never a statement of current capability.

Product scope is in [PRD.md](PRD.md), boundaries in [architecture.md](architecture.md),
implementation contracts in [design.md](design.md), execution order in
[phases.md](phases.md), and coding guidance in [.cursorrules](../.cursorrules).

## A. Inventory and review scope

```text
lib/
  main.dart
  constants/       colors.dart, dashboard_themes.dart
  models/          task_model.dart + generated adapter; other local domain models
  services/        hive_service.dart, api_client.dart, sync_service.dart,
                   log_reward_policy.dart
  screens/         15 screen files, including period/task/productivity/domain views
  widgets/         bubbles, forms, routine dialog, profile/rank and period summaries
  utils/           grid_utils.dart, task_time_utils.dart, text_formatters.dart
backend/
  main.py, database.py, models.py, websocket_manager.py, requirements.txt
test/
  widget_test.dart
android/ ios/ windows/ linux/ macos/ web/   Flutter platform scaffolds
pubspec.yaml, pubspec.lock, analysis_options.yaml
README.md, QUICK_START.md, COMPLETE_TASK_MANAGEMENT_GUIDE.md
PRODUCTION_ARCHITECTURE.md, IMPLEMENTATION_SUMMARY.md,
IMPLEMENTATION_COMPLETE.md, REQUIREMENTS_VERIFICATION.md
run.ps1, server_run.ps1, mobile_api_run.ps1, mobile_lan_check.ps1,
web_run.ps1, api_test.ps1, activate.ps1, clean_up.ps1, commit_id.ps1
```

Directory inventory and targeted source tracing covered app startup, persistence,
task CRUD/recurrence/scheduling, local domain models, UI integrations, REST/WS,
configuration, tests, scripts and platform release settings. This was not a
line-by-line audit of every large presentation widget or generated native file.

Generated/dependency content was excluded: build/, .dart_tool/, .venv_backend/,
test1/, platform ephemeral output and unrelated images. test1 is a Python virtual
environment (Include/Lib/Scripts/pyvenv.cfg), not an application test suite.
The generated TaskAdapter was inspected because compatibility depends on it.
No actual .env contents, credentials, private keys or personal database records
were read or copied into these documents. No repository AGENTS.md was found in
the searched workspace or ancestor paths. All six requested root documents were
absent before this task, so no existing content in them needed merging.

Confirmed no relevant CI workflow, Dockerfile/Compose, Kubernetes manifest, cloud
IaC, backend migration directory, backend test suite, .env.example or root LICENSE
was found. Native RunnerTests scaffolds exist in ios/ and macos/; they are not
evidence of application-domain coverage. No deployed infrastructure was verified.

### Working-tree preservation

Pre-existing modified tracked files: PRODUCTION_ARCHITECTURE.md, README.md,
activate.ps1, backend/main.py, backend/models.py, backend/websocket_manager.py,
lib/services/hive_service.dart, lib/services/sync_service.dart, pubspec.lock,
pubspec.yaml. Pre-existing untracked code/scripts include api_test.ps1,
lib/services/api_client.dart, mobile_api_run.ps1, mobile_lan_check.ps1,
server_run.ps1 and web_run.ps1, plus the two local Python environments.
These were reviewed as current evidence and preserved. The only authored changes
for this request are the six root planning documents.

### Components and important files

| Existing path | Confirmed responsibility / observations |
| --- | --- |
| lib/main.dart | main, MyApp and MainScreen; Hive init and adapter registration; themes/fonts; sidebar/bottom navigation; Month selected initially; motto Timer and lifecycle checks. Progress and Reports instantiate the same ProductivityTimelineView class. |
| lib/services/hive_service.dart | Singleton, roughly 2,500 lines; storage, migrations, recurrence, journal synthesis, profiles/settings, instructions, rewards, snapshots, automatic journey entries and cloud hooks. |
| lib/models/task_model.dart | Task with 19 Hive fields; immutable ID at 16, immutable typed-step list at 17, legacy remote alias at 18; existing properties and copyWith retained. |
| lib/models/task_model.g.dart | typeId 0, fields 0-18; compatible legacy defaults; missing ID generated and persisted by migration. TaskStep uses typeId 1, fields 0-8. |
| lib/services/api_client.dart | HTTP client injection, task payload conversion, slug-based cloud identity and REST convenience methods. |
| lib/services/sync_service.dart | WebSocket callback connection and REST convenience forwarding; exposes a second stream getter, no error/reconnect loop. |
| lib/services/log_reward_policy.dart | LogRewardPolicy milestones: 3/7/14/30 qualifying days map to 100/250/600/1500 coins. Reuse without changing policy. |
| lib/screens/year_view.dart, lib/screens/month_view.dart, lib/screens/week_view.dart, lib/screens/day_view.dart | Period visualization and task/routine interaction. Day view includes DragTarget/Draggable scheduling, duration editing and description markers. This is already implemented locally. |
| lib/screens/task_screen.dart | Dated/all-task flows; routine dialogs; reference/index CRUD through HiveService. |
| lib/screens/dashboard_view.dart, lib/screens/streak_view.dart | Local summaries, progress and activity presentation. |
| lib/screens/journal_view.dart, lib/screens/journey_timeline_view.dart | Daily reflection/mood and journey presentation linked to local persistence. |
| lib/screens/instruction_dashboard_view.dart | Instruction rules, options/levels and history UI. |
| lib/screens/goal_dashboard_view.dart, lib/screens/reward_money_history_view.dart | Local reward goals and ledger/history; not a payment integration. |
| lib/screens/productivity_timeline_view.dart, lib/screens/log_earn_view.dart | Reports, profile/reward presentation and log milestones; productivity view also runs a foreground reminder timer. |
| lib/widgets/quick_add_task_dialog.dart | showQuickAddTaskDialog / showTaskFormDialog; substantial form with phases, recurrence and linked instruction workflows. It is not the small text-only form in older docs. |
| lib/widgets/routine_occurrence_dialog.dart | Existing occurrence completion/instruction interaction; reuse rather than build another completion dialog. |
| lib/widgets/bubble_widget.dart, lib/widgets/period_progress_bubble_map.dart | Shared bubble/grid display. |
| lib/widgets/productivity_period_summary.dart, lib/widgets/rank_profile_card.dart, lib/widgets/profile_avatar.dart, lib/widgets/app_text.dart | Reusable summaries, ranking, avatars and text presentation. Avatar uses File/Image.file paths. |
| lib/utils/task_time_utils.dart | TaskPhaseInfo, parseTaskPhases, serializeTaskPhase, duration normalization and planned/recorded-minute calculations. |
| lib/utils/text_formatters.dart, lib/utils/grid_utils.dart | Title/metadata formatting and grid sizing utilities. |
| lib/constants/dashboard_themes.dart, lib/constants/colors.dart | Theme/palette/font/layout style definitions and colors. |
| backend/main.py | FastAPI app, CORS, startup unique index, owner seam, CRUD and socket endpoint. |
| backend/models.py | TaskPayload, TaskUpdatePayload, WebSocketEvent, BroadcastEvent. |
| backend/database.py | dotenv load, Motor client, database/tasks collection. |
| backend/websocket_manager.py | Dict of user IDs to socket lists; sequential sends, removal on exceptions. |

### Dependencies and environment observed

| Manifest/evidence | Declared or observed versions |
| --- | --- |
| pubspec.yaml | Dart >=3.0.0 <4.0.0; Flutter; hive ^2.2.3, hive_flutter ^1.1.0, image_picker ^1.1.2, google_fonts ^6.2.1, http ^1.2.2, web_socket_channel ^3.0.1 |
| Development dependencies | flutter_test, flutter_lints ^5.0.0, hive_generator ^2.0.1, build_runner ^2.4.6 |
| pubspec.lock SDK constraints | Dart >=3.10.3 <4.0.0 and Flutter >=3.38.4; materially stricter than pubspec.yaml's Dart lower bound |
| Installed SDK cache metadata | Flutter 3.41.6, Dart 3.11.4; read from local SDK metadata, not a fresh version-manager installation |
| backend/requirements.txt | Unpinned fastapi, uvicorn, motor, pydantic, python-dotenv |
| Existing .venv_backend metadata | fastapi 0.141.1; uvicorn 0.52.4; motor 3.7.1; pydantic 2.13.4; python-dotenv 1.2.3; transitive pymongo 4.17.0 |

Installed-version metadata is not proof of runtime compatibility or a recommended
lockfile. Python source uses union types requiring Python 3.10+ and Pydantic v2 APIs;
dependency-specific Python minima must be checked when pinning a clean environment.
The source contains no backend packaging/lock strategy. api_test.ps1 separately
installs websockets, whereas backend/requirements.txt does not explicitly request
WebSocket runtime support. Verify that in any clean backend install.

## B. Existing implementation and flows

### Startup and local operations

Confirmed startup: initialize Flutter -> Hive.initFlutter -> register TaskAdapter
if needed -> HiveService.init -> open tasksBox -> schema migration -> normalize
task names -> dedupe recurring records -> rebuild snapshots -> optional sync ->
runApp. With cloud enabled, the initial task pull is awaited before first rendering.

HiveService.addTask normalizes the title, writes a date list, recalculates the day's
snapshot and launches optional cloud upsert. updateTask and updateTaskByReference
can change dueDate without moving the list key. Deletion filters the date list and
recalculates; completion changes done/status and may generate the next recurrence.
All task storage updates use existing Hive listeners for UI refresh.

getTasksForDate adds a synthetic Daily Journal task; _storedTasksForDate removes
that synthetic task from stored-list access. getAllTasksByDate scans date keys,
adds today's synthetic journal task, and includes journal dates. Do not interpret
the journal task as evidence of an extra stored task when counting records.

Recurring routines support Daily/Weekly/Monthly/Yearly, separate enable state,
occurrence completion and terminal states. Monthly/yearly next dates use Dart
DateTime construction, which can roll overflow into the next month; desired
month-end semantics need tests/clarification, not an accidental behavior change.
Some recurring update paths use DateTime.now instead of a selected historical day.

### Local persistence model

| Keys/model | Storage and relationships |
| --- | --- |
| YYYY-MM-DD | List<Task> under tasksBox; Task fields include title, done, description, dueDate, priority/status/category, delegate, recurrence, flags, minutes/hour/color and enable state. |
| __meta_schema_version__ | One-element list, currently version 3 (IDs and typed steps). |
| __meta_categories__, __meta_delegates__, __meta_user_profile__, other __meta_* | Category/delegate choices and profile/theme/font/settings lists. No account authentication. |
| __journal__ + date | JournalEntry list: mood, reflection, date, task counts and productivity score. |
| __journey__ + id | JourneyEntry list; auto_journey_ records derive from daily state; optional task-name and image reference. |
| __productivity_snapshot__ + date | ProductivitySnapshot and point-event serialization; derived summaries. |
| __instruction__ + id | InstructionRule lists with history, levels/options; links by task/phase name. |
| __reward_ledger__ + id, __reward_goal__ + id | RewardLedgerEntry / RewardGoal positional lists, local goal references/history. rewardPointsPerRupee is 10. |
| __motivation_mottos__, __motivation_motto_settings__ | MotivationMotto and reminder maps stored inside lists. |

Related model files: lib/models/instruction.dart, journal_entry.dart,
journey_entry.dart, productivity_snapshot.dart, reward_money.dart,
motivation_motto.dart, user_profile.dart and rank_profile.dart (the latter computes
rank from activity). These are local Dart domain types, not backend schemas.
No SQL tables, foreign keys or database joins exist. Positional-list layout and
name-based links require careful compatibility tests.

### Actual REST and WebSocket contract

All implemented routes below are in backend/main.py. Default success status is 200,
including POST and DELETE; no explicit response model is declared.

| Endpoint | Current request/response and behavior |
| --- | --- |
| GET / | `{status: "Backend running"}`; no per-request DB ping. Startup still requires creating the MongoDB index. |
| GET /tasks | X-User-Id header or DEV_USER_ID fallback; list of owner-filtered records, with `_id` stringified; no pagination. |
| POST /tasks | Required nonempty task_id; optional title/start_time/end_time/status/done/updated_at, extra fields allowed. Owner and updated_at overwritten by server; upsert `$set` by owner/task_id. Returns `{message: "Task saved", task: supplied_fields_plus_server_fields}`. |
| PUT /tasks/{task_id} | All declared fields optional, extras allowed; `exclude_none=True`; owner/path ID/server time override payload; `$set` only supplied non-null fields. 404 if absent. Returns supplied fields, not a fresh full read. |
| DELETE /tasks/{task_id} | Hard delete by owner and ID; 404 if absent; returns message/task_id and broadcasts a delete event. No tombstone. |
| WS /ws?user_id=... | Accepts caller-chosen user or DEV_USER_ID; incoming event is ping or subscribe with data map; ping replies pong; no mutation messages. Malformed input/other exceptions disconnect manager state. |

BroadcastEvent is `{event, user_id, data}`. Supported task events: task_created,
task_updated, task_completed, task_deleted, schedule_changed. Completed state takes
precedence in event selection; a supplied schedule field selects schedule_changed.
On create POST, an inserted record emits task_created. subscribe is accepted by the
schema but has no special handler. WebSocketManager does not share state across
workers and has no explicit send timeout/heartbeat lifecycle policy.

Only HH:MM field format is validated by validate_schedule. It does not enforce end
after start, due_date validity, allowed status values, or a done/status invariant.
exclude_none prevents explicit nullable-field clearing. Payloads allow arbitrary
extra data and lack application-specific length limits. These are confirmed gaps,
not evidence of an exploited attack.

### Sync path and concrete failure modes

ApiClient.taskCloudId derives `date-category-slugged_title`; it ignores due time.
Non-ASCII titles may collapse to the same `task` slug. taskFromPayload does not
retain the cloud ID; absent/invalid due_date becomes now, missing title becomes
Synced Task, and missing fields get defaults. This loses remote identity and makes
partial-event application unsafe.

HiveService subscribes and pulls on startup. Regular local upserts call POST, not
PUT, despite the older roadmap's examples. Incoming create/update/complete/schedule
events are applied directly; failed event application schedules a debounced pull.
Delete events scan date lists and remove matching recomputed IDs. Pull only upserts
returned records; it does not remove remotely deleted tasks missed while offline.

_syncCloudUpsert/_syncCloudDelete are unawaited with an 8-second timeout and log
failures. They do not persist a queue, retry after restart, reconcile versions, or
upload all pre-existing local data at initial enablement. _applyingCloudTasks is a
shared boolean, not serialization; concurrent event/pull/local actions can overlap.
SyncService.connect lacks onError/onDone/reconnect handling, and its events getter
would add another subscription to the same channel if used alongside connect.

### Reuse, duplication and complexity

Reuse existing forms, HiveService accessors, task_time_utils, LogRewardPolicy and
widgets. Avoid copying the large task form or rebuilding recurrence from scratch.
Targeted opportunities found: different title-case functions in HiveService and
text_formatters; schedule marker parsing in day_view, quick_add_task_dialog and
HiveService; repeated edit/complete flows in period/task screens; repeated reward
goal UI in goal_dashboard_view and productivity_timeline_view. Similarity is not
proof that one extraction preserves all semantics. Refactor only when a tested
change needs it. HiveService's breadth and large UI files are maintenance costs,
not justification for a repository-wide architecture rewrite.

## C. Gap analysis

| Category | Finding |
| --- | --- |
| Already exists | Time views, task CRUD/forms, local schedules/dragging, recurring routines, journaling, instructions, goals/reward ledger, profile/themes, reports/streaks, local migration, REST/WS task starter. |
| P0 modifications | Stable task/occurrence identity, date-key correctness, serialized writes/recoverable moves, startup/save error behavior, meaningful tests and honest release scripts/docs. |
| P0 new files | Focused tests and synthetic legacy fixture; no new runtime service/database required. |
| Preserve | Existing Hive field numbers, metadata shapes, descriptions, journal synthesis, recurrence policy, reward formulas, themes, domain screens and unrelated user edits. |
| Later S1/S2 | Durable queue, canonical payloads, conflict versions, tombstones, identity mapping, verified authentication/account isolation, lifecycle/driver maintenance, deployment checks. |
| Do not build now | Duplicate Python frontend, microservices, broad cloud domain collections, payments, Kafka/Redis/Kubernetes, another UI state framework, generic repository layer. |

Old documentation has useful user-workflow descriptions but stale implementation
claims. README labels themes/cloud features as future despite current code;
IMPLEMENTATION_COMPLETE and REQUIREMENTS_VERIFICATION describe a much smaller app
and unqualified production readiness. PRODUCTION_ARCHITECTURE lists hypothetical
collections/services, and one section still suggests socket writes. Current source
uses REST writes. The six new documents distinguish this without overwriting the
user's existing documents. Correcting old docs is a Phase 4 implementation task.

## D. Implementation mapping and dependencies

The complete exact file/status/responsibility/test table is maintained once in
[design.md, Implementation file map](design.md#implementation-file-map). This
dependency-oriented index explains why each change is needed:

| Change / priority | Existing file anchors | Proposed new files | Dependencies and verification |
| --- | --- | --- | --- |
| F1/F3 IDs and schema-v2 | lib/models/task_model.dart, lib/models/task_model.g.dart, lib/services/hive_service.dart | test/task_identity_test.dart, test/task_migration_test.dart, test/fixtures/task_v1.bin | Old binary fixture; append field 16; copyWith/occurrence audit; repeated migration test. |
| F1/F3 safe date moves | lib/services/hive_service.dart | test/hive_service_test.dart | IDs, serialized writes, pending move replay; interrupt every step and restart. |
| F1/F2/F5 UI/error behavior | lib/main.dart, lib/screens/task_screen.dart, lib/widgets/quick_add_task_dialog.dart and four period screens | test/task_flow_test.dart, test/period_views_test.dart | Existing save APIs and Hive listeners; failure/draft/date/layout tests. |
| F4 domain preservation | lib/services/hive_service.dart, lib/utils/task_time_utils.dart, lib/services/log_reward_policy.dart | test/domain_regression_test.dart | Fixed clock/fixtures; journal/routine/points/ledger/profile round trip. |
| F5 reproducibility/release | run.ps1, .gitignore, README.md, QUICK_START.md; pubspec.yaml only for versioning | None required | Direct test exit result, native offline smoke, restore rehearsal. |
| S1 transport and queue | lib/services/api_client.dart, lib/services/sync_service.dart, lib/services/hive_service.dart, lib/main.dart | lib/services/task_sync_store.dart; test/api_client_test.dart, test/sync_service_test.dart, test/task_sync_store_test.dart | Stable IDs; canonical API; persistent queue/conflict/restart tests. |
| S1/S2 backend | backend/main.py, backend/models.py, backend/database.py, backend/websocket_manager.py, backend/requirements.txt | backend/tests/test_tasks.py, backend/tests/test_websocket.py, backend/requirements-dev.txt, backend/.env.example | Test DB; schema-v2 and provider contracts; null/conflict/retry/owner checks. |
| S1 native network | android/app/src/main/AndroidManifest.xml, api_test.ps1 | None required | Explicit release networking; isolated smoke DB; installed-device test. |

No proposed file is presented as already created. S2 provider-specific auth/storage
files and E1 export/platform work need their own decision record before coding.

## E. Environment and configuration

No backend environment variable is mandatory for local-only Flutter. The backend
needs reachable MongoDB when it starts because its startup hook creates an index.
No credentials are needed for an isolated unsecured local MongoDB test instance;
an authenticated hosted instance requires separately supplied credentials.

| Setting | Current default / safe example | Use and requirement |
| --- | --- | --- |
| MONGO_URL | `mongodb://localhost:27017` | backend/database.py; required operationally for backend, default supplied. Never paste a credential-bearing URI into docs/logs. |
| MONGO_DATABASE | `momentum_task_app`; test example `momentum_docs_test` | Backend database name; isolate smoke tests from personal data. |
| DEV_USER_ID | `dev-user` | REST fallback and WS fallback; development identity only. |
| CORS_ALLOWED_ORIGINS | `*`; safer local example `http://localhost:8080` | Comma-separated backend origins. Explicit actual origins required for any hosted browser client. |
| MOMENTUM_CLOUD_SYNC_ENABLED | `false` | Dart bool.fromEnvironment compile-time flag; retain false for P0. |
| MOMENTUM_API_BASE_URL | Source default `https://api.momentum.com`; safe test `http://127.0.0.1:8000` | Dart String.fromEnvironment. Domain ownership/deployment unverified; use explicitly configured test host. Phone localhost is the phone, not laptop. |
| MOMENTUM_WS_URL | Source default `wss://api.momentum.com/ws`; test `ws://127.0.0.1:8000/ws` | Dart compile-time socket URL; configure alongside REST host. |
| MOMENTUM_USER_ID | `dev-user` | Dart compile-time development owner; not a token. |
| PYTHONPATH | Backend path set by scripts | Script import convenience because backend uses sibling imports. Running Uvicorn from backend/ matches current layout. |

Backend calls load_dotenv; no template was found. Dart --dart-define is not a secret
store. The server_run script currently prints MongoUrl, which could expose credentials
if a real URI is supplied; replace that output with a redacted status before hosted
use. .gitignore does not currently exclude .env, .venv_backend or test1.

## F. Development and execution reference

Commands marked **repository-backed** appear in current docs/scripts or match their
declared parameters. This label means source evidence, not that they were run here.
Commands marked **proposed/unverified** are future workflow suggestions. Do not run
destructive setup scripts to perform documentation checks.

### Local Flutter (repository-backed)

From project root, with Flutter on PATH and native toolchains available:

```powershell
flutter pub get
flutter run -d windows
flutter test
flutter analyze
flutter build apk
flutter build web
```

Evidence: README.md, QUICK_START.md, activate.ps1, run.ps1, analysis_options.yaml,
web_run.ps1. `flutter build ios` also appears in QUICK_START.md but needs macOS/Xcode
and signing; it was not run from this Windows workspace. Proposed/unverified:
`flutter build windows` for the pilot artifact, and
`dart run build_runner build --delete-conflicting-outputs` only after an authorized
model change; the latter can overwrite generated output and needs diff review.
No dependency install or production build was performed in this task.

### Backend development (repository-backed, not executed here)

The README documents these commands from backend/ in an activated Python environment:

```powershell
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

MongoDB must already be running; these commands do not install it. Use 0.0.0.0 only
for intentional development network access; the app has no real authentication.
For a controlled Windows test, existing script parameters support:

```powershell
.\server_run.ps1 -HostAddress 127.0.0.1 -MongoDatabase momentum_docs_test -SkipInstall
```

This assumes .venv_backend exists with dependencies. Without SkipInstall the script
may create/install its environment. It sets MONGO_URL/MONGO_DATABASE/PYTHONPATH and
runs Uvicorn with reload. Backend credentials/production defaults are not verified.

For mobile experimentation, mobile_api_run.ps1 supports DeviceId, ApiHost, Port,
UserId and SkipPubGet. Example with documentation-only placeholder values:

```powershell
.\mobile_api_run.ps1 -DeviceId '<device-id>' -ApiHost '<laptop-LAN-IP>' -SkipPubGet
```

Replace placeholders before running. This explicitly enables the unsafe starter
sync, so use synthetic data and the same isolated backend. It is excluded from P0.
Network/firewall/Android cleartext policy and phone/laptop reachability were not
verified. mobile_lan_check.ps1 is a diagnostic helper, not proof of connectivity.

### Existing verification scripts

```powershell
.\run.ps1 -SkipDependencyInstall
.\api_test.ps1 -MongoDatabase momentum_docs_test -HostAddress 127.0.0.1 -NoKeepAlive
```

Both are repository-backed but were not run wholesale. run.ps1 compiles Python,
checks diff whitespace and invokes flutter test; Flutter failures are WarningOnly,
so a zero exit does not mean tests passed. api_test.ps1 creates/uses test1 by default,
installs requirements plus websockets unless skipped, starts a hidden server, tests
HTTP CRUD/socket handshake, and may probe LAN addresses. It defaults to the normal
application database unless overridden; CRUD is not read-only. Its no-database-test
flag does not bypass the backend startup index requirement. Always use isolated data.

web_run.ps1 can enable Flutter web, install packages, start a web-server or build
and serve build/web using Python. It has options that open a browser or stop a port
owner; inspect them before use. activate.ps1 stops processes, clears caches and runs
flutter create .; clean_up.ps1 also deletes artifacts. Neither is a harmless test.

Proposed/unverified future Python test command after files/dependencies exist:
`python -m unittest discover -s backend/tests`. Backend integration tests require
an isolated MongoDB instance and the future HTTP test dependency. There is no
existing pytest/unittest backend test collection to report as passed today.

## G. Risks and unknowns

Likelihood reflects source paths and anticipated use over the next 3-6 months,
not measured incident rates. Severity describes potential impact.

| Risk | Evidence/status | Severity / likelihood | Realistic mitigation and priority |
| --- | --- | --- | --- |
| R1: Mutable/colliding cloud identity | Confirmed slug construction in api_client.dart; inferred duplicate/overwrite on rename or same-title/date/category | High / high when sync enabled | Keep sync off in P0; stable local IDs F1; explicit old-ID mapping/collision review S1. |
| R2: Partial remote events erase fields | Confirmed PUT broadcasts supplied fields; taskFromPayload defaults missing fields, applied as complete Task | High / high when partial PUT used | S1 canonical records/invalidation pulls; regression test for completion-only/time-only updates. |
| R3: Lost uploads and missed remote deletions | Confirmed unawaited/log-only writes, no queue/reconnect/tombstones, pull only upserts | High / high offline | S1 persistent queue, retries, tombstones and foreground/reconnect reconciliation. |
| R4: Account impersonation and subscription leakage | Confirmed caller-selected X-User-Id/query identity | Critical / high if exposed | No public API release; verified token subject for REST/WS and account cache isolation before S2. |
| R5: Local date-key inconsistency and duplicate matching | Confirmed edit methods write old key; content-based matching lacks stable IDs; observed by source, runtime reproduction pending | High / medium | F1/F3 IDs, serialized operations and crash-recoverable date moves. |
| R6: Migration/data recovery failure | Current adapter/list schemas and no general backup facility found | High / medium | Synthetic legacy fixtures, append-only fields, idempotent version marker, backup/restore gate. |
| R7: Local/cloud concurrency | Confirmed whole-list writes and shared boolean guard; lost-update consequence inferred | High / medium | Serialize task mutations and remote apply; queue journals and failure-injection tests. |
| R8: Inconsistent scheduling/recurrence/time zones | Description markers plus dueDate/duration; end clipped to 23:59; month rollover and now-based occurrence paths | Medium / high near boundaries | Preserve P0 policy with fixed tests; explicitly decide midnight/month-end/time-zone semantics before S1 converter. |
| R9: Motor support horizon and unpinned runtime | requirements.txt and upstream maintenance notice | Medium / high over backend maintenance | Pin tested runtime, migrate to PyMongo Async before hosted rollout; no database replacement. [Upstream notice](https://github.com/mongodb/motor) |
| R10: Platform release gaps | Android main INTERNET absent, debug signing in app/build.gradle.kts; macOS outgoing entitlement absent; dart:io images | High / high for untested targets | Native local pilot first; test actual artifacts; fix release networking only with S1; web/macOS/iOS certification later. |
| R11: Weak verification gates | One widget test; run.ps1 suppresses test failure exit; no CI found | High / high | Focused regression tests and direct failure gate; optional CI after reliable commands exist. |
| R12: Performance and startup delay | Full-store scans/rebuilds, sequential WS fan-out, unbounded GET, initial awaited 8-second pull | Medium / medium | Measure 1,000-task pilot; avoid remote startup dependency; paginate/bound requests in S1; cache only demonstrated hotspots. |
| R13: Secret/privacy leakage | server_run prints Mongo URL; .env/venv ignore gaps; local profile/journal/photos stored without explicit box encryption | High / medium | Ignore secrets/envs, redact logs, OS access protection, keep private data local; encryption needs key/recovery design if threat model requires it. |
| R14: API resilience/input gaps | Extra fields allowed, nulls dropped, no DB shutdown/readiness/send timeout | Medium / high under malformed data/outage | S1 explicit schema/limits/null semantics; S2 lifecycle, timeouts, sanitized diagnostics. |
| R15: Process-local socket fan-out | websocket_manager.py connection dictionary | Medium / high with multiple workers | Single backend process for pilot; add shared broadcast only when multi-worker deployment is justified. |
| R16: Maintainability and name links | Large HiveService/UI files; duplicated parsers; instruction/task associations by names | Medium / high as features grow | Targeted tested extraction only; explicit later link migration; avoid adding more domains now. |
| R17: Hosting/business uncertainty | No provider, budget, users or commercial requirement supplied | Medium / high if cloud is assumed | Local pilot costs no hosting; decide S2 budget/identity and measure demand first. |

Unverified: MongoDB availability/version/data integrity; ownership or availability
of api.momentum.com; actual LAN sync; fresh installation compatibility; all release
artifacts; native performance/accessibility; real-user value; backup access; license
ownership; provider/API terms. No evidence supports “production ready.”

The feature direction is now explicit: seven AI/focus tools. Primary release target,
provider, budget and deployment audience remain open. Windows/Android is a planning
default. The 56-96-hour local foundation estimate does not include the AI extension
or cross-device sync; phases.md separates those estimates.

## H. Verification and evidence ledger

Executed in this documentation task:

| Check | Actual result / limit |
| --- | --- |
| Backend syntax | Existing .venv_backend Python parsed all four backend .py files with ast.parse successfully; no imports, DB connection or endpoint execution implied. |
| Installed package metadata | Read six backend package versions with importlib.metadata; versions recorded above. |
| Flutter test | `flutter test --no-pub` passed: one test, “renders the app shell.” Initial sandbox run produced no output and was interrupted; retry outside sandbox passed. |
| Existing diff whitespace | `git diff --check` passed before document writing; final scoped checks recorded after creation. |
| Documentation | Six files created; automated local-link, balanced-fence, whitespace and F1-F5 coverage checks passed. File mappings, scope, estimates and recovery contracts also reviewed for consistency. Mermaid source is included; visual rendering was not independently tested. |

Not executed: flutter analyze, dependency upgrades/installations, backend CRUD or
WebSocket runtime checks, MongoDB access, native builds, device smoke tests, migration
tests (not created yet), or performance measurements. Earlier docs' verification
claims were not treated as execution evidence. One diagnostic attempt to inspect
Windows process command lines was denied; no source file needed for this assessment
was inaccessible. External Todoist/TickTick terms URLs could not be opened; pricing
and feature pages were accessible, with links in PRD.md.

Key evidence anchors for follow-up:

- [Startup and navigation](../lib/main.dart): main, MyApp, MainScreen.
- [Local data and sync hooks](../lib/services/hive_service.dart): init,
  _runMigrationsIfNeeded, addTask/updateTask/updateTaskByReference,
  _handleRecurringIfNeeded, pullCloudTasks, _applyCloudTaskEvent, _syncCloudUpsert.
- [Task identity/serialization](../lib/services/api_client.dart): taskCloudId,
  taskToPayload, taskFromPayload.
- [Persistent task fields](../lib/models/task_model.dart) and
  [legacy adapter](../lib/models/task_model.g.dart).
- [REST and WebSocket endpoints](../backend/main.py), [payloads](../backend/models.py),
  [database initialization](../backend/database.py), [fan-out](../backend/websocket_manager.py).
- [Current test coverage](../test/widget_test.dart), [check wrapper](../run.ps1),
  [API smoke script](../api_test.ps1).
- [Android release settings](../android/app/build.gradle.kts),
  [Android manifest](../android/app/src/main/AndroidManifest.xml),
  [macOS release entitlements](../macos/Runner/Release.entitlements).

Recommended first implementation task: add test/task_identity_test.dart and
test/hive_service_test.dart to reproduce same-name reference edits and cross-date
movement using synthetic Hive data. Inspect lib/services/hive_service.dart and
lib/models/task_model.dart, then implement D2/D3 only after the failing assertions
demonstrate the current behavior. This turns the highest-value local risks into
reviewable, bounded changes before cloud expansion.

## I. Seven-tool expansion findings and implementation reference

Subsequent user clarification: use only the feature ideas, with no Goblin Tools
API or implementation dependency. Historical research links in this section are
evidence of the brainstorming process only. They are not runtime dependencies or
implementation resources to copy. Build original Momentum UI, prompts and logic;
no scraping, embedding or reuse of Goblin Tools code, assets or branding.

The follow-up user request explicitly names task breakdown, rewriting, tone
analysis, guided task execution, explanation, decision support and estimation.
The plan covers A1 Breakdown, A2 Estimate, A3 Focus, A4 Rewrite, A5 Tone Check,
A6 Explain, A7 Decide, plus export/nesting AX, without changing
application source. This supersedes earlier statements that the product idea was
unknown. The original F1-F5 foundation remains relevant because generated steps
and focus sessions need reliable task identity and persistence.

### Confirmed reuse and important gaps

| Capability | Current evidence | Required extension |
| --- | --- | --- |
| Task breakdown | TaskPhaseInfo and parseTaskPhases/serializeTaskPhase in lib/utils/task_time_utils.dart; phase drafts/editor in lib/widgets/quick_add_task_dialog.dart | AI draft generation, typed hierarchical steps, review/apply and stable step IDs; existing text phase format is insufficient for arbitrary nested AI output. |
| Estimate | Task.estimatedMinutes plus phase minutes, taskPlannedMinutes and taskRecordedMinutesForDay | Typed estimate range/assumptions separate from accepted plan and measured time. normalizeTaskDuration now preserves every positive integer; provider estimate ranges and raw focus time remain future work. |
| Focus | Day view shows next unfinished phase in _taskSubtitle; completion flows already update storage/snapshots | No dedicated FocusSession/Stopwatch execution controller found. Add local checkpointing, pause/resume and idempotent completion. Existing schedule clock Timer only refreshes the view. |
| Four text tools | Flutter HTTP and FastAPI/Pydantic are present | New shared AI workspace, six typed backend operations, provider/access/limits and reviewed result UI. No model provider/AI routes were found in the inspected source. |
| Export | Existing task/phase data and completion state | New serializers plus target-format verification; no existing general Markdown/Notion/Todoist export implementation found. |
| Runtime separation | backend/main.py imports database and awaits create_index at startup | AI-only mode must skip DB initialization and disable insecure task routes; otherwise MongoDB remains an accidental AI dependency. |

The earlier registry had only Task typeId 0. TaskStep typeId 1 is now implemented; any future registry allocation
must still be checked again when implementing, since other work may add adapters.
TaskStep and its adapter exist. AI/focus/export implementation files in design D8 remain planned.

### Plan mapping and configuration

The exact existing/new file table and tests are maintained in
[design.md](design.md#d8-seven-tool-ai-extension-a1-a7ax). Execution order and hours
are in [phases.md](phases.md#ai-delivery-track-implement-the-specified-seven-tools).
Model SDK installation and live provider calls remain future work. The foundation
adapters and schema-v3 migration are implemented; further hierarchy migrations are future work. No API key is present in these plans.

New settings are proposed, not read by the application today:

| Setting | Proposed value/use |
| --- | --- |
| AI_ENABLED | false unless deliberately configured |
| AI_PROVIDER / AI_MODEL | Selected after six-operation quality/cost evaluation; no guessed identifier |
| AI_API_KEY | Server environment secret only; placeholder `<server-secret>` |
| AI_TIMEOUT_SECONDS / AI_MAX_OUTPUT_TOKENS | 30 seconds / 1800 output-token ceiling |
| AI_DAILY_REQUEST_LIMIT / AI_MAX_CONCURRENT_REQUESTS | 50 / 2 per verified user; tune after observed usage |
| TASK_SYNC_ENABLED | Keep true for compatibility with existing backend development; explicitly false in AI-only launch configuration |
| MOMENTUM_AI_ENABLED / MOMENTUM_AI_BASE_URL | false / explicit development or HTTPS service URL; independent of existing task-cloud-sync flag |

No new execution command is represented as working today. AI-only startup, paid
request authorization and provider wiring must first be implemented and tested.
Input contents stay out of logs; only selected text is transmitted after an AI
action. The provider's retention policy is an unresolved selection criterion.

### Additional risks and tests

| Risk | Severity / likelihood | Mitigation |
| --- | --- | --- |
| AI suggestions become destructive edits | High / medium | Explicit preview/apply, stable generated draft IDs, stale-source checks and idempotent writes. |
| Generated minutes silently become 15 | Fixed for positive integer durations in the shared helper; AI bounds still pending | Separate estimate schema and typed-step migration; numeric tests for 5, 10, 25 and 180 minutes; preserve legacy totals. |
| Nested work double counts time/rewards | High / medium | Aggregate leaves only; completion remains explicit and idempotent; parent/child/reopen fixtures. |
| Timer drift and phantom work | Medium / high after suspend/restart | Foreground monotonic timer, checkpoint every 15s, background pause, restore paused; no automatic completion. |
| Paid API abuse or leaked key | High / high if deployed with dev-user | Server-held key, verified access, HTTPS, limits and provider/application budget controls before exposure. |
| Tone/decision output overstates knowledge | Medium / medium | Multiple interpretations, missing-context questions, explicit assumptions and human-reviewed quality fixtures. |
| Rewriter changes meaning | High / medium | Compare original/result; preserve factual anchors and negation tests; user must review before applying. |
| Export promises exceed importer capability | Medium / medium | Format-specific docs/fixtures, honest lossy-export explanation; no implied live integration. |

Official reference pages reviewed: [Magic ToDo](https://goblin.tools/ToDo),
[Formalizer](https://goblin.tools/Formalizer), [Judge](https://goblin.tools/Judge),
[Taskmaster](https://goblin.tools/Taskmaster), [Professor](https://goblin.tools/Professor),
[Consultant](https://goblin.tools/Consultant), [Estimator](https://goblin.tools/Estimator),
plus About/Terms/Privacy. Their interfaces confirm the broad feature descriptions;
not every dynamic feature was interactively exercised. A supported developer API
was not verified, and no permission to call private endpoints is assumed.

Verification of this follow-up: source searches/read-only inspection, official-page
research and documentation consistency checks. Application tests from section H
belong to the earlier assessment; no AI tests or source implementation ran here.

## J. Implemented foundations

Implemented on 2026-10-28 at the user's explicit request, before any AI feature.
No new runtime dependency, provider request, or Goblin Tools integration was added.

1. Task.id and TaskStep.id are final opaque identifiers. New tasks/steps receive
   them once; ordinary copies, editor rename/reorder and Hive round trips retain
   them. Non-routine deduplication uses IDs rather than titles. Existing recurring
   occurrences keep their own IDs. Future focus sessions must reference taskId
   and stepId; no timer or focus-session persistence has been implemented yet.
2. Hive schema v3 adds Task fields 16-18 without renumbering fields 0-15, registers
   TaskStep typeId 1, and migrates legacy phase text into typed steps. Original
   descriptions and malformed rows remain available. Version writes happen after
   task-list writes/flush; retries retain IDs already written. The editor, day,
   dashboard, streak, task and instruction phase readers use shared taskSteps.
   Steps currently form a flat ordered list; hierarchical AI drafts remain planned.
3. Every positive integer duration survives normalization. Five and ten minutes
   are selectable; custom values such as 25 stay available when editing. Legacy
   unspecified null/zero still default to 15. TaskStep validates planned minutes
   as positive and actual minutes as nonnegative; zero actual time stays zero.
   Reward formulas were not changed. Existing unsupported values now contribute
   their actual stored duration, rather than the previous erroneous 15 minutes.
4. Cloud serialization carries entity_id and typed steps. Migrated tasks retain
   their previous cloud slug as a frozen alias, avoiding a remote-key change on
   rename. New tasks use immutable IDs as remote keys. This is codec compatibility,
   not completion of the broader S1 offline/conflict/authentication work.

Verification is in test/task_foundation_test.dart, test/task_form_test.dart and
existing test/widget_test.dart. It covers real old-format Hive bytes, preserved
metadata/description, restart, migration retry, duplicate task/step IDs, equal task
names, stale edit indexes, reorder/rename with completion state, cloud codec round
trips, zero actual time, non-preset durations and unchanged preset reward totals.
The widget tests exercise the actual form, not just helper functions.

Remaining scope: AI features, hierarchical steps, focus sessions, recoverable date
moves/write serialization, full sync conflict handling, name-linked instruction
migration, immutable recurring-series IDs and native installed-device validation.
These foundations do not imply that every F1-F5 or A1-A7 acceptance criterion passes.

Executed checks for these foundations: `flutter test --no-pub` passed all 16 tests;
`git diff --check` passed. Full `flutter analyze --no-pub` reported no errors but
remains nonzero because of repository warnings/deprecation/style notices. No native
installed-device build, live cloud round trip or provider call was validated.


## K. Offline voice and documentation organization

The active implementation and verified results are in [OFFLINE_VOICE.md](OFFLINE_VOICE.md).
Android and Windows debug builds succeed, the full suite including native offline
inference passes 31 tests, and the new voice code passes targeted static analysis.
No speech API, API key, runtime model downloader or cloud fallback is used.
The 153.2 MiB multilingual model is bundled at build time. Hindi/mixed text parsing
is tested; real microphone accuracy remains a device acceptance check.

Root Markdown documentation was moved into docs/ at the user's request. README.md
remains at the root. README links and .cursorrules now direct project analysis to
this folder. Existing historical reports were retained, not replaced or discarded.

Voice listening feedback now uses RMS from the captured PCM16 buffer, exposed by
`VoiceCapture.level`, and a bounded 48-point trace in
`lib/widgets/voice_listening_indicator.dart`. Silence gives a flat trace; the
listening card includes elapsed time and explains that words appear after Stop.
Coverage is in `test/voice_recording_level_test.dart` and
`test/voice_tasks_widget_test.dart` (audio energy, silence, cancellation and saving).

Task extraction adds chrono_dart 2.0.2 and its day dependency. The parser handles
common conversational prefixes, selected calendar phrases, start delays and
duration idioms while preserving the existing typed drafts and save boundary.
Regression tests cover all seven weekday names from each weekday, month/year
rollover, ordinary names/numbers, conflicting fields and Hindi/Hinglish titles.
Library UTC output and bare-weekday/casual-week edge cases are handled explicitly;
see OFFLINE_VOICE.md for supported phrases and interpretation conventions.

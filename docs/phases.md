# Momentum implementation roadmap

Task extraction follow-up: implemented conversational creation prefixes, selected
offline natural-date parsing with chrono_dart, duration idioms and start delays.
Review notes expose date assumptions and conflicting recognized fields require
correction. This extends the voice parser; it does not implement a general local
language model or the seven planned assistance tools.

Voice feedback follow-up: implemented a live microphone-volume trace and elapsed
timer during recording. Recognition remains after Stop. See OFFLINE_VOICE.md for
verification; real Android/Windows microphone trials remain an acceptance check.

Current direction (2026-10-28): fully offline voice-to-task creation and edit/completion commands on Android and Windows, with Hindi, English and mixed speech. No external inference API dependency. The earlier hosted-provider AI plan is superseded by this constraint. See [offline voice implementation and validation](OFFLINE_VOICE.md).

Implementation update (2026-10-28): immutable task/step IDs, Hive schema-v3 step migration, and exact positive-minute handling are now implemented. The AI tools and focus-session feature remain planned. See [verified foundation changes](details.md#j-implemented-foundations).

Status: plan, 2026-10-28. Foundation IDs/steps/durations and the offline voice implementation are present.
The remaining roadmap below is not fully implemented; see OFFLINE_VOICE.md for the active delivery scope.
Scope now includes the specified seven-tool expansion in [PRD.md](PRD.md), with
an AI delivery track below; the original phases remain the reliability foundation.
[design.md](design.md) supplies
the file map and behavior; [details.md](details.md) records observed verification.

## Effort and sequencing

Estimated local MVP effort: **56-96 hours, or 7-12 working days at 8 hours/day**,
including assessment. This is a planning range, not an elapsed-time report. Assumes
one developer able to work in Flutter/Dart, an operational SDK, available Windows
and Android devices, existing screens retained, and no major corrupt-data recovery.
For someone primarily experienced in Python, reserve another 16-32 hours of Flutter
learning/debugging. Add time if backup/device access or migration failures require
product changes. A 14-day user pilot is elapsed observation time beyond coding.

| Phase | Dependency | Estimate | Requirement coverage |
| --- | --- | --- | --- |
| 0: Assessment and scope | Repository access | 4-6 h | F1-F5 baseline; S1/S2 risks |
| 1: Reproducible baseline | Phase 0 | 6-10 h | F1-F5 test fixtures |
| 2: Local reliability | Phase 1 red/green baseline | 24-42 h | F1/F3/F4/F5 |
| 3: Behavior validation | Phase 2 | 14-24 h | F1-F5 acceptance |
| 4: Pilot release | Phase 3 passes | 8-14 h | F5 release gate |
| 5: Optional task sync | Validated need after pilot | Additional 96-168 h | S1 only; 12-21 working days |
| 6: Optional hosted service | S1 plus provider/budget decisions | Additional 40-80 h, low confidence | S2; 5-10 working days |

P0 excludes public hosting/accounts, general domain sync, new rewards, background
notifications, wallpaper, teams, external calendars, payments, iOS/macOS/web release
certification and Kubernetes. Existing local advanced features remain intact.

## Phase 0: Repository assessment

Objective: distinguish implemented behavior from historical documentation and
identify the smallest useful deliverable. Prerequisite: inspect the working tree,
including pre-existing modifications. No source edits are authorized by this phase.

Execution order:

1. Read entry points, local persistence, models, UI/service call paths and backend.
2. Inspect dependencies, scripts, tests, platform manifests and existing docs.
3. Record gaps, alternatives, assumptions, risks and source evidence.
4. Create the six root documents and check traceability.

Exact files changed: .cursorrules, architecture.md, design.md, phases.md, PRD.md,
details.md. Dependencies: repository and current product information; no API server.
Tests/checks: backend AST parse, existing Flutter shell test, link/path/consistency
checks and diff review. Deliverable: coherent assessment and implementation plan.
Done when facts are sourced and unknowns labeled. Status: assessment produced;
check details.md for actual verification, not older “production ready” claims.
Original scope blocker resolved: the user subsequently specified seven AI/focus
tools. Their incremental scope and delivery plan are in the AI track below.

## Phase 1: Establish the baseline (6-10 h)

Objective: make defects reproducible before changing data. Prerequisite: Phase 0
and an isolated copy of representative data, never a production data mutation.

1. Confirm SDK versions against pubspec.lock and run existing tests/analyzer.
2. Create synthetic old-adapter records, duplicate-title and date-move fixtures.
3. Add focused failing tests for identity/date membership; snapshot current domain
   outputs for recurrence, journaling, instructions and rewards.
4. Define test isolation/reset seams; record device and backup access constraints.

Exact files expected: new test/task_identity_test.dart, test/task_migration_test.dart,
test/hive_service_test.dart, test/domain_regression_test.dart,
test/fixtures/task_v1.bin; existing test/widget_test.dart only if isolation needs it;
update details.md and phases.md with measured baseline. No production fix yet.
Dependencies: flutter_test, Hive, a valid legacy adapter fixture. Required tests:
existing suite plus deliberately failing reproductions; document which failures
are expected. Deliverables: reproducible baseline and synthetic fixtures.
Done when each reported P0 defect has a deterministic reproduction and tests never
touch personal data. Risks: singleton lifecycle, current-date dependence, old
adapter generation defaults. Technical approach: design D1.

## Phase 2: Implement local reliability (24-42 h)

Objective: implement F1/F3 and preserve F4 with minimal changes. Prerequisite:
Phase 1 fixtures and known baseline.

1. Append Task.id and regenerate the adapter; implement idempotent schema-v3 IDs/steps (foundation completed; see details J).
2. Update ID-based lookup and occurrence creation paths; distinguish series from
   occurrence identity. Preserve synthetic journal and name-linked instructions.
3. Serialize task mutations; implement cross-day move intent, replay and summary
   recomputation. Exercise injected failures after every persisted step.
4. Propagate save errors through current task/dialog/startup flows, preserving drafts.
5. Keep cloud disabled and verify offline startup; add a font fallback only if the
   uncached offline case demonstrates it is required.

Exact files: lib/models/task_model.dart, lib/models/task_model.g.dart,
lib/services/hive_service.dart, lib/widgets/quick_add_task_dialog.dart,
lib/screens/task_screen.dart, lib/main.dart; lib/screens/year_view.dart,
lib/screens/month_view.dart, lib/screens/week_view.dart, lib/screens/day_view.dart
only for affected save/error call sites; Phase 1 tests; design.md/details.md.
Dependencies: D2/D3 migration contracts and D4 compatibility rules. Required tests:
legacy decode, repeated migration, duplicate titles, concurrent saves, interrupted
move/restart, domain snapshots, retained drafts. Deliverable: local hardening diff.
Done when F1/F3 acceptance cases pass without modifying reward/recurrence policy.
Risks: regenerated adapter loses defaults, copied IDs reused for new occurrences,
pending move survives but startup does not replay it, UI matching uses stale indices.

## Phase 3: Validate user behavior (14-24 h)

Objective: prove all P0 acceptance criteria, including actual device behavior.
Prerequisites: Phase 2 tests passing and devices available.

1. Add task-flow and date-view widget tests, including the two target layouts.
2. Verify synthetic journal completion/deletion, instruction history, unchanged
   reward totals, profile/themes and routine recurrence after restart.
3. Run cold offline tests with API/MongoDB absent and font cache unavailable.
4. Measure start/save targets with 1,000 synthetic tasks; fix demonstrated bottlenecks.
5. Record results and resolve all P0 failures; preserve unrelated analyzer findings
   as explicit backlog instead of doing a broad refactor.

Exact files: new test/task_flow_test.dart and test/period_views_test.dart;
test/domain_regression_test.dart, test/hive_service_test.dart, test/widget_test.dart;
only implicated Phase 2 production files if a test fails; details.md/phases.md.
Dependencies: F1-F5, temporary data, native test devices. Required tests: full Flutter
suite, analyzer review, Windows and Android manual end-to-end scenarios, performance
samples. Deliverable: acceptance report with device/build/version and measurements.
Done when every P0 row in PRD is evidenced, or release is explicitly blocked by a
failed row. Risks: static/widget tests miss native media/filesystem failures.

## Phase 4: Release the local pilot (8-14 h)

Objective: a reversible, trustworthy private release. Prerequisites: Phase 3,
distribution decision, and tested backup/restore on selected devices.

1. Make run.ps1 return failure when mandatory Flutter tests fail; test this with an
   isolated deliberately failing test, then remove that temporary failure.
2. Update .gitignore for local environments/secrets and correct setup/status docs.
3. Build and smoke test Windows/Android with task cloud sync disabled.
4. Rehearse close/backup/upgrade/restore on disposable data; record rollback steps.
5. Provide pilot instructions, collect 14-day feedback and decide whether S1 is useful.

Exact files: run.ps1, .gitignore, README.md, QUICK_START.md, pubspec.yaml only for an
intentional build-version change; details.md, phases.md, PRD.md. If Android public
distribution is chosen, android/app/build.gradle.kts signing requires a separate
configuration task; no keys belong in the repository. Dependencies: SDK/native
toolchains and workable backup access. Required tests: Flutter suite, failure exit
code, installed native smoke tests and restored data checks. Deliverables: pilot
artifacts and release/rollback record. Done when F5 passes and known limitations
are visible to pilot users. Blockers: inaccessible backup, unverified signing or
unresolved data-loss defects. Do not launch the API as part of this release.

## Phase 5: Conditional reliable task sync (96-168 h additional)

Objective: S1 on controlled test data after the pilot establishes a need. Prerequisites:
all P0, explicit sync scope, old-server backup and identity mapping review. This is
not the safe public-hosting milestone and the estimate assumes coordinated clients.

1. Characterize existing REST/event behavior and write backend/codec tests.
2. Finalize schema-v2 pagination, revisions, null handling and collision migration.
3. Implement canonical responses, conditional writes, idempotency and tombstones.
4. Implement persistent local queue, serialized drain, dirty/conflict protection,
   reconnect/resume/poll reconciliation and visible pending state.
5. Run two-device outage/restart/conflict/delete tests and release-network checks.

Exact files: lib/services/api_client.dart, lib/services/sync_service.dart,
lib/services/hive_service.dart, lib/models/task_model.dart and generated adapter if
sync metadata is added, lib/main.dart, new lib/services/task_sync_store.dart;
backend/main.py, backend/models.py, backend/database.py, backend/websocket_manager.py,
backend/requirements.txt; new backend/requirements-dev.txt and backend/.env.example;
new backend/tests/test_tasks.py, backend/tests/test_websocket.py,
test/api_client_test.dart, test/sync_service_test.dart, test/task_sync_store_test.dart;
android/app/src/main/AndroidManifest.xml; api_test.ps1 for isolated database/default
safety improvements; six planning documents as scope changes.
Dependencies: MongoDB test instance, WS runtime support, D6 contract decisions.
Tests: idempotency, conflicts, partial update regression, tombstones, invalid data,
100-edit offline convergence and latency targets. Deliverable: reliable controlled
task-sync prototype. Done when S1 acceptance passes and no data is silently lost.
Risks: unrecoverable historical slug collisions, incomplete queue journaling,
concurrent response handling and task/description schedule divergence.

## Phase 6: Conditional hosted identity and operations (40-80 h additional)

Objective: S2, not a blanket expansion to every local domain. Prerequisites: S1,
identity provider/platform choices, hosting budget and account-data migration plan.
Estimate excludes custom credential management and significant provider research.

1. Choose identity provider and specify native/browser socket authentication.
2. Verify access tokens and derive owner server-side; isolate local caches by owner.
3. Migrate driver to PyMongo Async, pin dependencies and add app lifespan/readiness.
4. Configure TLS, explicit origins, request limits, sanitized logs and backup restore.
5. Test cross-account REST/WS denial, logout/relogin and deployment rollback.

Known exact files: backend/main.py, backend/database.py, backend/models.py,
backend/websocket_manager.py, backend/requirements.txt, backend/.env.example,
lib/services/api_client.dart, lib/services/sync_service.dart,
lib/services/hive_service.dart, lib/main.dart and Phase 5 tests. New auth/hosting
files depend on the provider; write a concrete follow-on design before coding them.
Deliverable: authenticated pilot deployment and runbook. Done when S2 tests pass and
restore is demonstrated. Risks/blockers: provider choice, account migration,
credential storage, operation cost and multi-worker socket limitations.

## Traceability and progress checklist

No unchecked implementation task below was performed by the documentation task.

| Task | Implementation completed | Tests passed | Documentation updated |
| --- | --- | --- | --- |
| Phase 0 repository assessment and six-document plan | [x] | [x] scoped checks only; see details.md | [x] |
| F1 stable task identity and date-correct CRUD (D2/D3, Phases 1-3) | [ ] | [ ] | [ ] |
| F2 visual/date-view acceptance (D4, Phases 1/3) | [ ] | [ ] | [ ] |
| F3 legacy migration and restart recovery (D2/D3, Phases 1-3) | [ ] | [ ] | [ ] |
| F4 integrated-domain regression preservation (D4, Phases 1-3) | [ ] | [ ] | [ ] |
| F5 offline, error handling and release gates (D4/D5, Phases 2-4) | [ ] | [ ] | [ ] |
| S1 reliable task sync (D6, Phase 5) | [ ] | [ ] | [ ] |
| S2 hosted identity/operations (D7, Phase 6) | [ ] | [ ] | [ ] |

E1 export/extra platforms and E2 other advanced features require separate scoped
plans after validation. Do not convert the full-product wishlist into MVP tasks.

## AI delivery track: implement the specified seven tools

All stages implement Momentum-owned features. Goblin Tools API integration,
scraping, website embedding and reuse of its code/assets/branding are excluded by
explicit user instruction. Select a separate AI model provider or local model;
do not spend implementation effort investigating a Goblin Tools integration.

This track follows local foundation Phases 1-4 and can be prototyped with fake AI
responses alongside that work. Task-cloud-sync Phases 5/6 are not prerequisites.
The AI access/security gate is still necessary before a paid endpoint is exposed.
Original 56-96 hours estimates only the local foundation, not these new features.

| Stage | Ordered tasks and exact principal files | Effort | Exit gate / dependencies |
| --- | --- | --- | --- |
| AI-0: shared service | Choose one provider via synthetic evaluation; create backend/ai_models.py, backend/ai_service.py, backend/ai_routes.py; integrate backend/main.py conditional DB mode; update backend/requirements.txt, new backend/.env.example; add lib/services/ai_client.dart, lib/models/ai_result.dart | 24-40 h | Mocked schema/error/timeout tests pass; AI-only startup works without DB; loopback spike first; access/quotas/HTTPS before mobile exposure. |
| AI-1: Break Down + Estimate (A1/A2) | Reuse the implemented TaskStep model/adapters, schema-v3 migration, duration helpers and editor; add hierarchy as required; add ai_result_preview.dart and task/day contextual actions | 32-56 h | Stable Task IDs prerequisite; legacy fixtures round-trip; editable preview; duplicate/stale Apply protection; exact estimates distinct from recorded time; no lost existing phases. |
| AI-2: Focus (A3) | Add lib/models/focus_session.dart, lib/services/focus_service.dart, lib/screens/focus_view.dart; connect task/day actions and existing completion service | 24-40 h | One active local timer; pause/restart checkpoints; offline operation; no double rewards or completion on timeout; deterministic next-step suggestion. |
| AI-3: four shared tools (A4-A7) | Add lib/screens/ai_tools_view.dart; extend ai_result_preview.dart and lib/main.dart navigation; implement six-operation instruction/result handling in backend/ai_service.py and ai_models.py | 24-40 h | Rewrite comparison, cautious tone interpretation, explanation/example and criteria-based decision work; 20 reviewed synthetic examples per operation; access and limits shared. |
| AI-4: exports/nesting/release (AX) | Add lib/services/task_export_service.dart; finish nested step controls in quick_add_task_dialog.dart/ai_result_preview.dart; update android/app/src/main/AndroidManifest.xml for AI network access; update six documents and README.md | 16-24 h | Bounded nested editing/rebreak, Markdown and validated Todoist/Notion CSV imports, native offline/HTTPS smoke, privacy/cost review, full suite acceptance. |

Additional feature estimate: **120-200 hours (15-25 working days)**. Including the
56-96-hour foundation: **176-296 hours (22-37 working days; roughly 5-8 full-time
weeks)**. First useful AI release through AI-2 adds 80-136 hours to the foundation.
These are rough engineering ranges, assuming one experienced Flutter/Python
developer, one hosted provider, no cross-device sync, simple existing UI styling,
CSV rather than live OAuth connectors, and an off-the-shelf access mechanism.
Provider procurement, custom authentication, store review, cross-platform edge
cases or complex old-data repair can extend them. Do not add the previous S1/S2
estimates unless cloud task sync is separately selected. A demo can be much faster
because it omits migrations, reliable timers, acceptance testing and release work.

Tests/files by stage (all new unless already listed as foundation tests):

- AI-0: backend/tests/test_ai_models.py, backend/tests/test_ai_service.py,
  backend/tests/test_ai_routes.py, test/ai_client_test.dart; fake provider tests,
  disabled DB/access/quota/timeout assertions.
- AI-1: test/task_steps_test.dart, test/task_ai_flow_test.dart; migration, hierarchical
  IDs, reordering, stale responses, invalid output and repeated Apply.
- AI-2: test/focus_service_test.dart, test/focus_flow_test.dart plus existing
  test/domain_regression_test.dart; fake clock, pause/resume/restart, no double counting.
- AI-3: test/ai_tools_test.dart, test/ai_quality_cases.json; shared UI plus manual
  model-quality rubric. Unit tests alone do not certify AI correctness.
- AI-4: test/task_export_test.dart and full regression suite; disposable import
  projects, installed Android/Windows checks, documented token usage/cost.

Before AI-0 live calls, decide provider/model, data retention acceptability, private
versus hosted access, and a spending cap. Before AI-1 acceptance, review schema-v3
duration/reward compatibility. Before AI-4, recheck target CSV importer contracts.
These are concrete decision gates, not reasons to block mock-backed design work.

| Requirement | Approach | Stage | Implemented / verified |
| --- | --- | --- | --- |
| A1 Break Down | D8 structured preview, step schema, review/apply | AI-1; recursive controls AI-4 | [ ] / [ ] |
| A2 Estimate | D8 typed range and separate planned/actual values | AI-1 | [ ] / [ ] |
| A3 Focus | D8 local checkpoint/controller and existing completion | AI-2 | [ ] / [ ] |
| A4 Rewrite | D8 rewrite result variants and preservation rubric | AI-3 | [ ] / [ ] |
| A5 Tone Check | D8 possible readings/cues/context | AI-3 | [ ] / [ ] |
| A6 Explain | D8 explanation/example/key terms | AI-3 | [ ] / [ ] |
| A7 Decide | D8 criteria/options/conditional recommendation | AI-3 | [ ] / [ ] |
| AX export/nesting | D8 bounded tree and target-specific files | AI-4 | [ ] / [ ] |

Recommended first vertical slice: a synthetic task -> mocked Breakdown endpoint ->
editable preview -> cancel/apply tests. Then connect the real provider. The local
identity/phase migration must pass before applying generated steps to personal data.

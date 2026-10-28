# Momentum detailed technical design

Current direction (2026-10-28): fully offline voice-to-task creation and edit/completion commands on Android and Windows, with Hindi, English and mixed speech. No external inference API dependency. The earlier hosted-provider AI plan is superseded by this constraint. See [offline voice implementation and validation](OFFLINE_VOICE.md).

Implementation update (2026-10-28): immutable task/step IDs, Hive schema-v3 step migration, and exact positive-minute handling are now implemented. The AI tools and focus-session feature remain planned. See [verified foundation changes](details.md#j-implemented-foundations).

Status: foundation D2 implemented, 2026-10-28; the other sections remain proposals
unless the implementation update explicitly marks them complete. Scope and priorities are defined in [PRD.md](PRD.md); current behavior and
limitations are evidenced in [details.md](details.md).

## Design constraints

Retain Flutter, HiveService, tasksBox and the existing UI/service boundaries. Do not
rewrite the frontend or introduce a relational database. Implement P0 F1-F5 before
P1 S1/S2. Existing recurrence, journal, instruction, phase-description, reward and
theme semantics are compatibility constraints, even when they merit future cleanup.
Native Windows and Android are the pilot targets. Dates remain device-local wall
times for P0; do not silently UTC-convert existing tasks.

## D1: Baseline and test seams (F1-F5)

Expand beyond test/widget_test.dart before altering persistence. Use temporary Hive
directories, real TaskAdapter round trips, and seeded representative records. Reuse
HiveService.instance by closing/reinitializing its box between tests; add an explicit
close/reset lifecycle method only where tests expose stale handles/timers. A clock
parameter on recurrence operations is preferable to introducing a DI container.
Do not make production startup run with test paths or compile-time sync enabled.

First reproduce these cases: two identical non-recurring task titles; edit the
second by reference; move one across dates; restart; complete/reopen an occurrence;
save/delete a journal; restart with profile and instruction history. Tests must
assert stored records and calculated values, not just widget existence.

## D2: Stable local identity and migration (F1/F3)

Implemented contract:

- Task keeps Hive typeId 0 and fields 0-15. Field 16 is final String id,
  field 17 is an optional immutable List<TaskStep>, and field 18 is the frozen
  legacyCloudId. Constructors accept a missing ID for old bytes and generate
  16 random bytes as 32 hex characters; ordinary copyWith preserves it.
- TaskStep has Hive typeId 1: id, name, description, status, planned minutes,
  urgent, important, actual minutes and completion timestamp at fields 0-8.
  IDs and step fields are final. Reordering changes list order only. Null steps
  mean legacy data; an explicit empty list means no steps.
- Schema v3 follows v1 metadata setup. It scans date lists, assigns/persists IDs,
  repairs duplicate IDs, parses legacy phase rows once, writes each list and
  flushes before advancing the version marker. Retry preserves committed IDs.
  Descriptions are retained verbatim during migration; malformed rows remain
  recoverable text. Existing name normalization and recurring deduplication
  still run afterward. A dedicated startup recovery UI remains future work.
- Old adapters can omit appended fields; generated readers retain legacy defaults.
  test/task_foundation_test.dart writes actual old 16-field Hive records and
  verifies migration, metadata preservation, repeat startup and interrupted retry.
- Task edits resolve identity by ID. UI deletion callbacks retain the selected
  Task reference across dialogs. Index-compatible updateTask resolves the ID in
  its incoming task instead of trusting the old position. New callers should
  use reference-based methods; legacy index-only delete/toggle methods remain.
- Recurring occurrence IDs are distinct; existing IDs survive completion and
  series edits. Read-only projections use a deterministic source/date ID and
  retain it when saved. Series matching still uses name/category/frequency.
  Synthetic journal IDs are journal:YYYY-MM-DD. A durable recurring-series ID
  and migration of name-linked instruction rules are separate future work.
- The optional cloud codec sends entity_id and typed steps. New remote keys use
  the immutable ID; migrated records freeze the previous slug as legacyCloudId
  to avoid changing existing server keys on rename. This does not solve historic
  remote slug collisions or the wider S1 sync/recovery requirements.
- Positive durations, including 5, 10, 25 and 180, are exact. The shared helper
  defaults only legacy null/zero to 15 and rejects negatives. TaskStep rejects
  nonpositive planned minutes and negative actual minutes; actual zero is valid.
  Dropdowns include persisted custom values. AI request/estimate bounds and raw
  uncertainty ranges still belong to the future AI contract.

The current step schema is flat; parent/child hierarchy and focus-session models
are future additions, not part of this foundation migration. Tests also cover
form reorder/rename, custom durations and equivalent productivity reward totals.

## D3: Date moves, concurrency and recovery (F1/F3)

Update for offline voice: updateTaskByReference now persists and replays a date-move
intent, with ID-based destination upsert and source removal. The voice path uses it.
The legacy index-compatible updateTask still writes into its date argument's list.
Broader concurrency and recovery requirements below remain a plan. Route ordinary-task updates through one internal operation that knows both
the original key and new dueDate key. Serialize task read-modify-write operations
through a small Future chain owned by HiveService; ensure a rejected operation does
not poison later queued operations. Queue only outer mutations, not nested helpers,
to avoid self-deadlock. Do not rely on the current _applyingCloudTasks boolean as a
lock. The same queue must protect recovery and later remote application.

Same-day updates need one list write by ID. Cross-day moves need a recoverable
intent because two Hive keys are not one transaction. Proposed reserved key
`__meta_pending_task_move__` holds one list containing source key, destination key,
task id and the updated Task object. Only one move runs at a time:

```text
persist move intent; flush
upsert destination by id; flush
remove source by id; flush
recalculate both days' snapshots and auto journey entries
delete intent; flush
report success
```

On startup replay an outstanding intent before exposing task screens. Each step is
idempotent; target upsert preserves exactly one ID and source removal tolerates
absence. Keep the intent until recomputation succeeds. Readers must not treat the
intent key as task data. The brief intermediate duplication is not exposed as a
completed operation; UI disables the pending action until it finishes. This is
crash recovery, not a claim of protection from filesystem/device corruption.
If a move fails with its intent still present, retry recovery before accepting
another task mutation. Never overwrite an unresolved intent with a later move;
keep task editing paused with a retry option until recovery succeeds.

```mermaid
sequenceDiagram
  participant user as User
  participant ui as Existing task dialog
  participant service as HiveService
  participant box as tasksBox
  user->>ui: Save edited date
  ui->>service: Update selected task by stable ID
  service->>box: Persist and flush move intent
  service->>box: Upsert destination, remove source
  service->>box: Recompute summaries and clear intent
  service-->>ui: Save completed
  box-->>ui: Hive listeners refresh views
```

For interrupted same-day saves, Hive write success remains the acknowledgment
boundary; derived summaries are rebuildable on next startup. If a later snapshot
write fails after the task itself saved, report that distinction so retry does not
create another task. Preserve the draft and ID for retry. A failed initial write
must leave the dialog open and not claim success.

## D4: Preserve domain rules and useful UI (F2/F4/F5)

Keep the current visual hierarchy and reusable dialogs. Validate leap days, week
starts, task/date selection and listener refresh through behavior tests; change
individual period screens only where a reproduced regression requires it.

Journal save/delete continues to control the synthetic Daily Journal task. Do not
sync it as a user-created task. Keep LogRewardPolicy and rewardPointsPerRupee intact.
Test snapshots against fixed inputs to detect point/ledger drift. Local instructions
link by task/phase names, not IDs: preserve their existing matching policy for P0
and document rename behavior. Migrating those links is a separate future design;
stable task identity alone does not solve name-based instruction associations.

Descriptions remain compatible with `---PHASES---` and schedule markers. Reuse
task_time_utils.dart for phase operations rather than writing another parser.
Do not globally replace title casing: HiveService's private formatter and
text_formatters.dart currently differ on whitespace, URLs and identifiers.

Keep cloud disabled in pilot builds. Test a cold offline start with no cached fonts;
if google_fonts emits unhandled failures, use a system TextTheme as the offline
fallback in MyApp while retaining stored theme/font preferences. Do not add a font
download service. Preserve input on local errors and show a concise retry message.
Do not add telemetry, a sync indicator that implies backup, or a new settings system
just for the local pilot.

## D5: Validation, safety and release (F5)

P0 adds no API endpoints or Pydantic schemas. The existing backend remains an
experimental, opt-in path. Use a disposable data copy for migrations and a clean
install plus an upgrade install for pilot validation. Record app data location on
each tested device, close the app before a filesystem backup, and restore that
backup on a disposable installation. Verify IDs, task counts and representative
journal/ledger values. Do not overwrite personal data during the rehearsal.
Android backup access depends on the chosen build/device; if no restore procedure
works, block that pilot release or implement E1 before relying on it for real data.

Rollback uses the prior binary with the matching pre-migration backup, restored
while closed. An older binary may drop unknown fields on rewrite; do not assume
schema downgrade is safe. Keep app version/build identification in release notes.
Resolve ownership/signing decisions before public distribution; debug-signed APKs
are test artifacts. No backend host is required for P0.

## D6: Later task-sync design (S1, excluded from P0)

Do not turn cloud sync on merely after adding a socket retry loop. A bounded design
can extend current routes/services without CRDTs, message brokers or extra domains:

- Persist the immutable Task id as task_id instead of deriving a slug. Preserve
  the old cloud ID mapping for a migration; back up the server first. Existing slug
  collisions may already have overwritten data and cannot be recovered from code.
  Do not guess which legacy device copy owns a collision. Pause sync and resolve
  ambiguous mappings before a coordinated client/server cutover.
- Add revision, last_mutation_id and deleted_at metadata to server records; retain
  the compound owner/task index. Use one-document conditional updates so revision
  checks and writes are atomic. A delete creates a tombstone, not hard deletion.
  Retain tombstones throughout the pilot; later retention needs a resync contract.
- Store pending full-task mutations in a separate proposed Hive box `taskSyncBox`,
  keyed by task ID. Include operation ID, operation kind, base revision, payload,
  retry count and state. Journal intent before local changes, then apply locally;
  recover unfinished intent on startup. For edits while a request is in flight,
  keep the successor separately and never clear it when acknowledging its predecessor.
- Serialize drain and remote-apply operations. Initial opt-in queues eligible local
  tasks before reconciliation. Never replace a dirty local task with a remote
  snapshot. New server revisions against a dirty base become a conflict containing
  both versions. User selection produces a new operation against the current
  revision; no silent last-writer-wins policy.
- Keep the original operation ID across retries. The server checks matching
  last_mutation_id before revision mismatch and returns the prior/current accepted
  result without incrementing twice. Concurrent divergent writes receive 409.
- Treat socket events as invalidation hints; debounce and fetch canonical records.
  Reconcile on startup, reconnect, foreground resume and every 60 seconds while
  foregrounded. A paginated snapshot must include tombstones; absence alone must
  never delete unsent local records. Repeated reconciliation converges even when
  pages span concurrent edits. Cursor details must be finalized before S1 coding.
- Add onError/onDone handling, tracked StreamSubscription, bounded exponential
  retry with jitter (1, 2, 4, up to 30 seconds), and dispose cancellation. Keep a
  single socket stream consumer; remove or broadcast the unused second-listener
  API deliberately. Use an 8-second request timeout, pause on validation/auth/
  conflict errors, retry only transient failures, and show pending/error/conflict
  states rather than swallowing them.

### Proposed S1 API contract and validation

These are coordinated protocol changes, not current behavior. Keep REST paths but
version the payload contract explicitly (`schema_version: 2`); incompatible legacy
clients must remain sync-disabled during cutover. Responses contain full canonical
records, including task_id, revision, updated_at and deleted_at. Never broadcast a
patch as a complete task. updated_at is aware UTC with an explicit offset.

| Operation | Proposed contract |
| --- | --- |
| POST /tasks | Create with task_id, mutation_id, schema_version, full payload, base_revision=0; return full canonical task; duplicate acknowledged mutation is idempotent; existing divergent ID is 409. |
| PUT /tasks/{task_id} | Existing update fields plus base_revision and mutation_id; atomic conditional update; return full record; 404 unknown task, 409 stale revision. |
| DELETE /tasks/{task_id} | Require base_revision and mutation_id in explicitly documented request headers; persist tombstone; acknowledge matching repeated delete without resurrection. |
| GET /tasks | Add a bounded limit (default 100, maximum 500), opaque continuation cursor and include_deleted option; return `{items, next_cursor}`; owner comes from auth, not filters supplied in data. |
| WS /ws | Task change hints include task_id/revision; clients reconcile canonical REST state; ping/pong remains transport liveness, not proof of completed sync. |

Expand Pydantic models to explicitly enumerate the existing fields sent by
ApiClient.taskToPayload. Validate nonempty title (1-500 characters), description
up to 20,000 characters, valid due_date, priority/status from the actual UI plus
existing routine statuses, estimated_minutes 0-1440, hour_slot null or 0-23, boolean
flags and bounded string IDs. Proposed limits need a legacy-data scan before
enforcement. Allow explicit null clearing for nullable fields using exclude_unset,
not exclude_none. Reject unknown fields in schema v2 after compatibility testing;
never let payload fields choose owner, revision or server timestamps.

Use due_date plus duration as canonical schedule data; represent midnight explicitly
instead of clipping to 23:59. Read legacy description markers through one tested
converter. Remote malformed dates are rejected/quarantined, never replaced with
DateTime.now. Local wall time versus time-zone-aware scheduling is an open product
decision that must close before multi-zone sync. No SQL tables/relationships or
Alembic migration are needed; keep one MongoDB task document per owner/task.

## D7: Hosted identity and operations (S2, separate milestone)

Select a maintained identity provider after budget/platform requirements are known.
Verify issuer, audience, signature and expiry server-side; derive user_id from the
verified subject for every CRUD query and socket subscription. Never accept an
arbitrary header/query identity in hosted mode. Do not implement a custom password
store just to replace dev-user.

WebSocket authentication needs platform-specific treatment: native authorization
headers or a short-lived one-use ticket for browser clients. Do not put durable
bearer tokens in URLs/logs. Define provider-specific schemas after provider choice;
invented login endpoints are not implementation-ready until that choice is made.
Separate local data and pending queues per authenticated subject and server origin;
logout stops sync without uploading one account's records into another account.

Before hosting: migrate Motor to PyMongo Async in backend/database.py, explicitly
pin verified compatible dependencies, manage client creation/close through app
lifespan, add database timeouts/readiness, TLS, explicit CORS and sanitized logs.
One Uvicorn process is sufficient for a pilot; in-process sockets cannot fan out
across independent workers. Backups must be restored in a test database before
launch. Hosting, rate limits and session storage remain S2 decisions.

## Implementation file map

`Existing` refers to this working tree, including untracked user files. `New` files
below remain proposed unless covered by D2 or the foundation update. The original
file map is retained for the broader reliability work; current tests are
test/task_foundation_test.dart and test/task_form_test.dart.

| File/module | Status | Responsibility and changes | Priority / tests |
| --- | --- | --- | --- |
| lib/models/task_model.dart | Existing | Append ID; preserve copyWith and legacy fields | F1/F3; task_identity_test.dart, task_migration_test.dart |
| lib/models/task_model.g.dart | Existing generated | Regenerate compatible field 16 adapter | F3; binary fixture decode/round trip |
| lib/services/hive_service.dart | Existing | Schema-v3 IDs/steps and per-occurrence IDs (done); serialized writes, move intent/recovery, ID lookup, error/lifecycle seam | F1/F3/F4/F5; service/migration/domain tests |
| lib/widgets/quick_add_task_dialog.dart | Existing | Retain draft/ID on failure and report save state through existing form flow | F1/F5; task_flow_test.dart |
| lib/screens/task_screen.dart | Existing | Resolve task ID for edits; surface storage errors | F1/F5; task_flow_test.dart |
| lib/main.dart | Existing | Recover before rendering; startup error/retry, font fallback if reproduced | F5; widget_test.dart and offline smoke |
| lib/screens/year_view.dart, lib/screens/month_view.dart, lib/screens/week_view.dart, lib/screens/day_view.dart | Existing | Preserve visual behavior; adapt save call/error paths only as required by F1 | F2; period_views_test.dart |
| lib/utils/task_time_utils.dart, lib/services/log_reward_policy.dart | Existing reuse | Preserve parsing/reward policy; no speculative rewrite | F4; domain_regression_test.dart |
| test/task_identity_test.dart | New | Same-name tasks, rename, reference/index compatibility | F1 |
| test/task_migration_test.dart | New | Old binary fields, ID assignment, repeated/interrupted migration | F3 |
| test/hive_service_test.dart | New | Date movement, injected failures, recovery, concurrent saves, close/reopen | F1/F3 |
| test/domain_regression_test.dart | New | Recurrence, synthetic journal, instructions, snapshots/ledger/profile | F4 |
| test/task_flow_test.dart, test/period_views_test.dart | New | User behavior, date selection, errors and layouts | F1/F2/F5 |
| test/fixtures/task_v1.bin | New test fixture | Synthetic pre-ID Hive record, no user data | F3 |
| test/widget_test.dart | Existing | Retain shell test; test startup/retry as needed | F5 |
| run.ps1 | Existing | Make test failures fail validation; preserve explicit skip behavior | F5; deliberate failing-test exit-code check |
| README.md, QUICK_START.md | Existing | Correct setup/platform/sync claims and backup/rollback instructions | F5; review against observed runs |
| .gitignore | Existing | Ignore local envs/test1/.env while allowing a future .env.example | F5; verify secrets/venvs not staged |
| lib/services/api_client.dart, lib/services/sync_service.dart | Existing | S1 stable-ID codec, canonical responses, timeout/reconnect/dispose | S1; proposed test/api_client_test.dart, test/sync_service_test.dart |
| lib/services/task_sync_store.dart | New later | Durable queue/conflict state only; uses Hive, not a new database | S1; proposed test/task_sync_store_test.dart |
| backend/models.py, backend/main.py, backend/database.py, backend/websocket_manager.py | Existing | S1 validation/revisions/tombstones; S2 auth/lifespan/driver/readiness/send limits | S1/S2; proposed backend/tests/test_tasks.py, backend/tests/test_websocket.py |
| backend/requirements.txt, backend/requirements-dev.txt, backend/.env.example | Existing / New / New | Pin runtime, separate test dependencies, safe configuration template | S1/S2; isolated install/smoke |
| lib/main.dart, lib/services/hive_service.dart, lib/models/task_model.dart | Existing later extension | Connect S1 store, dirty/conflict UI state, remote revision metadata; S2 account scoping | S1/S2; end-to-end recovery scenarios |
| android/app/src/main/AndroidManifest.xml | Existing later | Release INTERNET permission when sync actually ships; no broad cleartext exception | S1; installed release-device network test |

S2 identity-provider-specific files are intentionally undecided until provider
selection; do not treat S2 as an authorized implementation ticket with a settled
protocol. macOS/web fixes and user export are E1, outside this concrete P0 file set.

## Test matrix and alternatives

| Layer | Required evidence |
| --- | --- |
| Unit/model | Legacy binary decoding; ID copy/creation; phase round trips; fixed reward fixtures; boundary dates. |
| Hive integration | Distinct duplicate titles, rapid serialized writes, move interruption after each persisted step, disk/write errors, migration rerun, close/reopen. |
| Widget | Add/edit/complete/delete via existing dialogs; retain failed draft; listener updates; phone/desktop sizes; correct selected date. |
| Native end-to-end | Real Windows/Android offline launches, persistence after restart, upgrade fixture, backup/restore and recorded performance targets. Manual checks are acceptable for this pilot. |
| Later backend | Owner separation, invalid/extra fields, null clear, stale revisions, duplicate retries, database failure, tombstones, no partial-record clobber, socket disconnect/slow send. |
| Later two-device | Offline queued edit/delete, crash during drain, missed delete event, simultaneous edits, reconnect convergence and account-switch isolation. |

Stable IDs plus a small move intent are smaller than replacing Hive, yet address
concrete corruption/identity risks. A simple local-only pilot is smaller than
promising reliable two-way sync. Full CRDTs, generic repositories, global DI and
server-side copies of all domains have no justified role at current scale.

## D8: Seven-tool AI extension (A1-A7/AX)

Implementation boundary: use the feature ideas only. Write Momentum's own prompts,
UI, schemas and task/focus logic. No Goblin Tools API, private endpoint, scraping,
website embedding, copied code, assets or branding is part of this design.
Provider selection is independent of Goblin Tools, even if it offers an API later.

This section implements the user's now-specified product direction. D1-D5 remain
the local reliability foundation; D6/D7 task sync is not a prerequisite for these
tools. All paths and contracts below are proposed, not implemented. Provider/model,
production identity mechanism and monthly budget still need selection before live
mobile/hosted service use; mock-backed development does not depend on those choices.

### Shared product flow and responsibilities

Add Break Down, Estimate and Focus actions to existing task/day flows. Add one
AI Tools entry for Rewrite, Tone Check, Explain and Decide using a shared input,
options, loading/error and result shell. Operation-specific result widgets should
remain small and typed rather than a universal JSON-driven form framework.

The AI service returns suggestions only. The client presents a draft, supports
editing/reordering, and calls HiveService only on Apply. Generation failure/cancel
does not mutate the task. Capture the source task ID and a digest of its fields at
request time; if it changes before Apply, retain the result and require re-review.
Generate local IDs for proposed steps once when constructing the preview. Applying
those IDs is idempotent: repeated Apply must not append a second copy. A regenerating
request replaces a draft, never accepted work. Do not silently replace completed
steps when re-breaking an unfinished leaf; show the exact replacement before apply.

### Typed step storage and duration migration

Reuse the implemented D2 foundation: Task.id at field 16, steps at field 17,
legacyCloudId at field 18, Hive schema v3, and TaskStep typeId 1. Do not renumber
its current fields 0-8 (id, name, description, status, minutes, urgent, important,
actualMinutes, completedAt). Register adapters before opening the box.

Future hierarchy work must append compatible fields for parentId, estimate bounds
and raw focus seconds with a new migration/version. List order is display order
among siblings; validate no dangling parent, cycle or duplicate ID. Depth limit is
3 and total nodes 50 per task in the pilot; generation produces at most 12 new
steps per request. The provider returns proposal indexes/structure, never trusted
database IDs. Bounds are product defaults, not model capabilities.

The implemented v3 migration retains original phase text, parses valid rows into
flat steps and preserves exact positive durations plus zero actual time. Typed
steps are authoritative, including an explicit empty list. Malformed rows remain
recoverable text; a dedicated migration-warning UI is not implemented. Existing
recurrence policies remain unchanged. Recurring substep redesign is outside the
first AI release.

For future AI structured steps, enforce the product limit of 1-1440 planned minutes
at the request/review boundary and provide a numeric editor. The foundation model
itself permits any positive integer. Estimate bounds remain separate values and
may describe larger activities that should be broken down (proposed provider cap
43,200 minutes). Validate missing, non-integer or nonpositive AI estimates explicitly;
never apply the legacy null/zero default of 15 to hide invalid output. Raw focus
seconds must remain separate from estimates and recorded minutes. Existing stored
5/10-minute values now contribute exactly those minutes, correcting the old helper.

Only leaves contribute duration; containers aggregate their children, preventing
parent/child double counting. Completed leaf work contributes recorded minutes
using existing reward rates: choose confirmed actual minutes when present, otherwise
the accepted planned minutes. Convert actual seconds to minutes once at explicit
completion (ceil(seconds/60), with 0 remaining 0); show that value before confirmation.
Raw focus time stays separate until confirmed. Never award rewards on generation,
timer expiration, pause, or repeated completion. Previously completed legacy tasks with valid preset durations
must yield identical totals after migration; unsupported durations and zero actual
time intentionally use their exact stored values after the correction. Tests must cover partial child
completion, reopening, cancelled leaves and repeat Apply/Complete.

### One typed AI endpoint

Proposed `POST /ai/assist` uses a Pydantic discriminated union keyed by operation,
following the [official union documentation](https://docs.pydantic.dev/latest/concepts/unions/#discriminated-unions).
Implement six concrete input/result pairs. The common envelope is:

```json
{
  "schema_version": 1,
  "request_id": "client-generated-unique-id",
  "operation": "breakdown",
  "input": {
    "task": "Build a FastAPI application",
    "context": "Small personal project; I know Python",
    "detail_level": 3,
    "max_steps": 8
  }
}
```

Response: request_id, operation, schema_version, result, warnings. Result shapes:

| Operation | Inputs beyond selected text | Required result shape |
| --- | --- | --- |
| breakdown (A1) | context, detail_level 1-5, max_steps 1-12 | steps with title/description and optional estimate, assumptions, clarification_question nullable |
| estimate (A2) | experience, difficulty 1-5, focus_difficulty 1-5, context | low_minutes, likely_minutes, high_minutes, assumptions, uncertainty_note |
| rewrite (A4) | tone enum, intensity 1-5; optional compare_tones with 1-3 distinct choices | variants each with tone/text; preservation warnings where context is ambiguous |
| tone (A5) | conversation/context; suggest_reply boolean | possible_readings, textual_cues, missing_context, optional suggested_reply |
| explain (A6) | topic, knowledge_level, simplicity 1-5 | explanation, example, key_terms, limitations |
| decide (A7) | question, options, criteria/constraints | options with pros/cons, assumptions, conditional_recommendation, missing_information |

Check input strings for reasonable bounds (main text up to 8,000 characters,
context 2,000), normalize empty input, enforce enum/range/node limits, and reject
invalid generated output before returning success. Estimate invariants include
1 <= low <= likely <= high <= 43,200. No synthetic confidence percentage is needed.
Task breakdown levels describe granularity, rewriting levels describe intensity,
and explanation levels describe simplicity; do not apply one shared multiplier.

Use the provider's schema-constrained output if available, then independently
validate with Pydantic. User text is data, not permission to change server rules.
No provider tool execution, filesystem access or arbitrary URL fetch is enabled.
Return typed errors: 422 invalid input; 401/403 access; 429 quota/concurrency;
502 invalid/provider failure; 504 timeout; 503 AI disabled. Error body contains
code, safe message, request_id and retryable. Never expose provider keys/raw errors.

Use a server 30-second deadline and client 35-second deadline. Start without
streaming so partial JSON is never applied. No automatic paid regeneration on a
parse failure; offer explicit retry and retain input. If transport retries are
introduced, reuse request_id and coalesce an in-flight repeat to avoid a second
provider call. An in-memory result cache is not durable billing idempotency across
restarts; do not promise exactly-once provider charging.

### Focus execution is local application logic (A3)

Proposed FocusSession: sessionId, taskId, stepId nullable, occurrenceDate when
applicable, state, accumulatedSeconds, lastCheckpointAt, targetMinutes, completedAt.
Store one active session checkpoint in a separate Hive box `focusBox`; no server
database or socket is needed. Use Stopwatch for foreground elapsed time and a UI
Timer only to repaint. Persist start/pause/resume/complete and checkpoint every
15 seconds. Pause on background for the first release. After process death restore
paused at the last checkpoint, stating that at most the uncheckpointed interval
is unrecorded; do not invent time worked while the app was closed.

Do not start two local active sessions. Session references follow immutable task/
step IDs so reordering/renaming cannot attach time to a different step. If its step
is deleted or changed, pause and ask the user to resolve the target. If work exceeds
the estimate, show overtime; completion stays manual. Focus Complete calls the
same idempotent task/step completion path as the normal UI and updates snapshots
once. Skip chooses another item without marking the skipped task complete.

Suggested-next initially uses local rules: incomplete/available leaves first,
then earliest due date, existing urgency/priority, fit to available time, and stable
list order for ties. Show the reason; allow manual selection. A model is unnecessary
for this feature. Cross-device active-session arbitration and background alarms
are separate future features, not hidden requirements of the timer.

### Exports and complete-suite behavior

AX adds recursive Markdown checklists from the same step tree, preserving sibling
order and completed states. Todoist/Notion exports are separate csv serializers
with an explicit target format; verify their current official import documentation
when implementing. Use proper quoting and protect spreadsheet-leading formulas.
Present format limitations before export and validate fixture imports in disposable
projects/databases. A file export does not create an account connection, preserve
all fields, or establish two-way sync. Add manual nested editing and depth-bounded
leaf breakdown here after the initial one-level workflow passes.

### Access, privacy, provider choice and operating cost

First test the endpoint through a fake provider and a loopback-only desktop spike.
Before real mobile/hosted use, select verified user access, HTTPS and server-held
secrets. Do not use the existing X-User-Id as protection against paid API abuse.
AI-only mode disables insecure task routes and MongoDB startup; existing sync mode
retains its current explicit configuration. The SDK is the only likely new backend
runtime dependency, selected after provider evaluation; no Flutter AI SDK is needed.

Proposed server settings: AI_ENABLED=false by default; AI_PROVIDER, AI_MODEL and
AI_API_KEY (server secret); AI_TIMEOUT_SECONDS=30; AI_MAX_OUTPUT_TOKENS=1800;
AI_DAILY_REQUEST_LIMIT=50; AI_MAX_CONCURRENT_REQUESTS=2 per verified user.
These limits are starting defaults, not a guarantee of affordable spend. Add a
provider-side hard budget where available and application admission limits. Use
provider-reported usage rather than prompt length as the billing measurement.
Do not claim a resettable in-process counter enforces a durable monthly budget.
If provider budget controls are insufficient, persist usage counters using the
already available backend storage for hosted mode before charging access is enabled.

Proposed client configuration: MOMENTUM_AI_ENABLED=false and
MOMENTUM_AI_BASE_URL explicitly set for the pilot; no embedded production key/URL.
Provider selection criteria: quality on the six-operation evaluation set, structured
output, latency, retention/residency terms, token prices and account limits. Pick
one hosted model after a small benchmark; avoid training/RAG/multiple providers.
No fixed provider rate or monthly invoice is asserted by this plan.

Monthly model estimate:
`requests * (mean_input_tokens * input_price_per_million + mean_output_tokens * output_price_per_million) / 1,000,000`.
Add retries, comparison variants, hosting and taxes. For example, 3,000 requests
averaging 800 input and 600 output tokens consume 2.4M input + 1.8M output tokens;
multiply by the chosen current rates. This is a workload example, not a quote.
Cache shared prompt instructions where the provider supports it; do not add a
global cache of users' sensitive text. Histories stay off unless explicitly saved.

### File-level implementation plan

| File | Existing/new | Required work and tests |
| --- | --- | --- |
| backend/main.py | Existing | Register AI router; lazy/conditional task DB startup; disabled task/WS mode; verified AI access dependency. Test AI-only startup with MongoDB unavailable. |
| backend/ai_routes.py | New | /ai/assist, request validation/access/limits and typed HTTP errors; backend/tests/test_ai_routes.py. |
| backend/ai_models.py | New | Six discriminated input/result schemas and validators; backend/tests/test_ai_models.py. |
| backend/ai_service.py | New | One provider call path and operation-specific instruction constants; output validation/timeouts; fake provider seam; backend/tests/test_ai_service.py. |
| backend/requirements.txt, backend/.env.example | Existing/new | Chosen SDK version and safe AI/sync configuration; no secrets. |
| lib/services/ai_client.dart, lib/models/ai_result.dart | New | Typed requests/results, timeouts and safe error conversion using installed http; test/ai_client_test.dart. |
| lib/screens/ai_tools_view.dart, lib/widgets/ai_result_preview.dart | New | Shared four-tool workspace and review/apply UI; test/ai_tools_test.dart. |
| lib/main.dart, lib/screens/task_screen.dart, lib/screens/day_view.dart | Existing | Workspace navigation and contextual Break Down/Estimate/Focus actions; test/task_ai_flow_test.dart. |
| lib/models/task_model.dart, lib/models/task_model.g.dart | Existing | Append field 17 after F1 ID; schema-v3 typed steps; test/task_steps_test.dart. |
| lib/models/task_step.dart, lib/models/task_step.g.dart | New/generated | TaskStep model/adapter and stable hierarchy; migration tests. |
| lib/services/hive_service.dart | Existing | Adapter registration, schema-v3 migration, atomic accepted-step application, shared completion; test/task_steps_test.dart and domain regressions. |
| lib/utils/task_time_utils.dart, lib/widgets/quick_add_task_dialog.dart | Existing | Shared structured-step access, legacy fallback and exact new-step duration; preserve phase completion behavior. |
| lib/screens/focus_view.dart, lib/services/focus_service.dart, lib/models/focus_session.dart | New | Local focus controller/checkpoint/view; test/focus_service_test.dart and test/focus_flow_test.dart. |
| lib/services/task_export_service.dart | New | Markdown/target-specific CSV from task steps; test/task_export_test.dart. |
| android/app/src/main/AndroidManifest.xml | Existing | Release INTERNET permission for AI even if task sync remains off; installed-device HTTPS check. |
| test/ai_quality_cases.json | New synthetic fixture | At least 20 cases per AI operation, expected properties/rubric; no real journal/message data. |

Mandatory tests: reject unknown operation/oversized input/invalid model JSON;
preserve old tasks during migration; preserve arbitrary Unicode/pipes/newlines in
new typed steps; no writes on Generate/Cancel; stale response protection; double
Apply/Complete idempotency; offline focus and checkpoint restore; unchanged historical
reward totals; no ancestor/leaf double counting; AI-only startup without MongoDB;
access/quota denial before provider call; synthetic CSV/Markdown round trips.
Runtime live-provider quality evaluation is separate from deterministic unit tests
and requires a deliberately configured key and budget. None ran during planning.


Voice creation UX update: **Add by voice** is available in the main navigation and
Master Tasks, with a microphone shortcut in Day. After a single spoken creation,
Stop opens the filled task editor automatically; only **Save task** persists it.
See [the voice guide](OFFLINE_VOICE.md) for commands and platform verification.

Recording feedback: `VoiceCapture.level` exposes normalized microphone loudness.
`OfflineVoiceService` calculates RMS from existing PCM16 chunks and resets it on
stop/cancel. `VoiceListeningIndicator` samples the value every 80 ms for a bounded
48-point heartbeat-style trace and timer. Its timer is disposed when the listening
UI is removed. This adds no dependency, audio persistence or transcription call.

Task extraction follow-up: VoiceTaskParser uses chrono_dart 2.0.2 for selected
calendar spans, with local Hindi/Hinglish normalization. UTC results are converted
to local time, and bare-weekday/next-week normalization avoids observed library
edge cases. Spoken duration and start-delay rules stay separate. Natural creation
prefixes are recognized before edit/completion intent, so "remind me to finish"
creates a task. showTaskFormDialog accepts optional reviewNotes, supplied by the
voice screen; other callers retain the existing form. Regression cases live in
test/voice_natural_language_test.dart and the voice widget tests.

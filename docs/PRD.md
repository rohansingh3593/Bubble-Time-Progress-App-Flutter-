# Momentum product requirements

Current direction (2026-10-28): fully offline voice-to-task creation and edit/completion commands on Android and Windows, with Hindi, English and mixed speech. No external inference API dependency. The earlier hosted-provider AI plan is superseded by this constraint. See [offline voice implementation and validation](OFFLINE_VOICE.md).

Implementation update (2026-10-28): immutable task/step IDs, Hive schema-v3 step migration, and exact positive-minute handling are now implemented. The AI tools and focus-session feature remain planned. See [verified foundation changes](details.md#j-implemented-foundations).

Assessment date: 2026-10-28. Status: proposed plan based on the current working tree.

The user has now specified the product expansion: seven capabilities inspired by
Goblin Tools: task breakdown, rewriting, tone analysis, focus execution, explanation,
decision support and time estimation. This replaces the original unfilled idea.
The local reliability requirements below remain the foundation (F1-F5); the added
AI feature contract is in the final section. Only the three foundation fixes are implemented so far; the remaining
requirements are a plan. AI assistance and cloud task synchronization are separate features.
See [repository evidence](details.md) and [technical design](design.md).

## Recommendation: BUILD incrementally on the existing app

Validate and harden the existing local app while adding a shared AI capability. The app already
combines visual time awareness, tasks, routines, journaling, instructions, rewards,
and reports. Rebuilding these features would add cost without testing demand.
The distinctive hypothesis is that bubble-based time views plus personal reflection
help someone act on their daily plan. That benefit has not been measured.

Target users are individuals planning their own work/study and habits, initially
the repository owner on Windows and Android. Teams, public accounts, and paid SaaS
customers are not established requirements. User pain points are forgetting planned
work, losing the link between activity and reflection, and not trusting saved state.
Practical value is a dependable personal tool and a test of the visual workflow;
there is no supported revenue forecast or market-size claim.

## Existing solutions and build versus buy

Research checked 2026-10-28; displayed US prices are reference prices, not Indian
checkout quotes. Tax, billing channel, and future price changes are not included.

| Choice | Verified capability and price | Fit and trade-off |
| --- | --- | --- |
| Todoist | Free Beginner includes five personal projects and reminders; Pro displays USD 60/year or USD 7/month, with calendar and duration features | Prefer using it if dependable ordinary task planning is the real goal. Custom bubble/reward behavior would still require separate development. [Official pricing](https://www.todoist.com/pricing) |
| TickTick | Free tier includes cross-platform sync; Premium displays USD 49.99/year and multiple calendar views | Strong comparison for a combined task/habit workflow; less control over the app's custom experience. [Official pricing](https://ticktick.com/upgrade) and [features](https://ticktick.com/features) |
| Retain Momentum | Existing local workflows and custom visualizations; no hosting needed for the local MVP | Highest flexibility and maintenance responsibility. Use existing code, then validate whether customization is worth that effort. |

The alternatives are hosted products with free/paid plans, not code dependencies to
copy into this project. Their detailed reuse/API licensing terms were not verified:
the attempted terms pages were inaccessible. No license or API integration right is
assumed. Repository-level LICENSE was not found. Review ownership and third-party
notices before public redistribution. This is an unresolved release input, not a
claim that private use is prohibited.

Recommendation is an inference from existing feature overlap and this codebase's
maintenance gaps: use an existing product if the custom visual workflow is not
valuable; otherwise harden Momentum. Integrating a second task system now would
create another synchronization problem without an established user need.

## MVP scope and measurable requirements

The foundation MVP (F1-F5) is a reliable local Windows/Android pilot of existing features. The work is
hardening, not expanding the product. Existing advanced screens remain available;
their redesign and new capabilities are excluded. Complexity is relative effort,
not a statement that a feature is currently missing.

| ID / priority | Feature and value | Existing baseline / required change | Complexity / dependencies | Acceptance criteria |
| --- | --- | --- | --- | --- |
| F1 / P0 | Reliable task CRUD and scheduling | CRUD exists; make identity stable and date moves consistent | Medium; F3 migration | Two same-title/category/date non-recurring tasks remain independently editable/deletable; renaming retains identity; a date move leaves exactly one record on the new date after restart; create, complete, reopen, delete persist correctly. |
| F2 / P0 | Trustworthy year/month/week/day views | Existing views, bubbles, task sheets and Hive listeners | Low-medium; F1 | Leap year, month boundary and week boundary fixtures select the correct date; CRUD changes appear without reopening the screen; no overflow on the chosen 360x800 logical-pixel phone and 1280x800 desktop test sizes. |
| F3 / P0 | Persistence and upgrade safety | Compatible Hive adapters and schema-v3 ID/step migration (implemented) | Medium; test fixtures first | Legacy 16-field tasks load with all values intact; assigned IDs survive two migrations/restarts; interrupted date move recovers without lost/duplicate records; successful save survives close/reopen; failed save is not reported as successful. |
| F4 / P0 | Preserve integrated productivity behavior | Routines, journal task, instructions, snapshots, reward ledger, profile/themes already exist | Medium regression work; F1/F3 | Same input fixtures give unchanged points and reward balances; completing/reopening a routine does not multiply the occurrence; saving/deleting a journal changes its synthetic task once; profile/theme and instruction history survive restart. |
| F5 / P0 | Usable offline pilot and honest release status | Cloud flag already defaults off; release/test gates incomplete | Low-medium; F1-F4 | With API/MongoDB absent, app opens and local tasks work; no task REST/WS traffic with flag off; no unhandled startup/font failure offline; visible storage errors preserve drafts; Windows and Android smoke runs and backup/restore rehearsal are recorded. |
| S1 / P1 | Reliable opt-in task sync | Partial REST/WS starter exists | High; all P0, identity migration, recovery protocol | In an isolated two-device trial, 100 queued edits converge after reconnect/restart, deletes stay deleted, partial events cannot erase fields, conflicts preserve local edits for review, and a healthy-network edit appears on the second device within 5 seconds. |
| S2 / P1 | Authenticated hosted sync | No real authentication exists | High; S1, provider/hosting decisions | Missing/invalid credentials fail closed on REST and WS; account A cannot read/write/subscribe to B; tokens and private content absent from logs; logout/account change cannot mix caches or pending writes. |
| E1 / P1 | User-facing backup/export and broader platform support | No general backup flow found; platform scaffolds exist | Medium; demand and portability tests | Restore a documented export on a clean device; validate web image handling and platform entitlements before claiming support. |
| E2 / P2 | Reminder delivery, broader domain sync, integrations | Foreground timers/local domains exist; background delivery and cloud domains do not | High; validated use and individual designs | Define a separate acceptance contract per requested domain before implementation. |

## User stories and journeys

- As a planner, I select a date bubble, add a task, complete it, and see that date's
  progress update. Restarting must preserve the task and completion state (F1-F3).
- As a user revising plans, I change a task's title/date without creating a second
  copy or editing a different same-name task (F1).
- As a user reflecting on my day, I save a journal entry and see the built-in Daily
  Journal task and productivity summary reflect that action (F4).
- As an offline user, I open the app without a server, work normally, and receive a
  useful error retaining my draft if local saving fails (F5).
- Later, as a two-device user, I explicitly enable sync, see pending/conflict state,
  and recover from an interrupted connection without assuming local data is backed
  up merely because the socket connected (S1/S2).

## Non-functional requirements

For the local pilot, target cold start under 3 seconds and task feedback within
300 ms for 1,000 stored tasks on the recorded test devices; these are proposed
targets, not measured performance. Record p95 across 20 task operations and five
cold starts. Do not block initial rendering on remote I/O. Keep Hive data readable
across the migration, use temporary data in tests, and never clear a damaged store
automatically. Recoverable local errors must retain input and identify retry options.
No cloud hosting, account, or credentials are required for the F1-F5 foundation.
The subsequent AI release needs a configured provider and protected backend access.

Preserve existing reward policy; displayed rupee amounts are personal tracking,
not payments, bank transfers, or a financial service. Private journals, photos and
task text must not enter diagnostic logs. Keyboard access, readable labels, and
the two target layouts are minimum UI checks; a comprehensive accessibility audit
is not claimed by this pilot.

## Validation and success metrics

Proposed validation: owner plus up to four willing users for 14 days. Success means
zero confirmed data-loss incidents, all P0 acceptance tests passing, at least three
of five users using the app on eight days, and at least three reporting that the
visual workflow helps planning. If only the owner participates, report a personal
utility result, not market validation. Collect a short diary/interview, not a new
analytics service. Sync investment depends on evidence that a second device is a
recurring need. These targets and the participant count remain product assumptions.

## Exclusions and decisions

No new backend for journals/rewards/goals, public launch, real-money payouts, autonomous
agent, wallpaper, Kafka/Redis, Kubernetes, team permissions, automatic external
calendar sync, or full CRDT conflict resolution in P0. Recurring behavior already
present must be preserved, not reclassified as an absent future feature.

Open decisions: AI provider/budget and privacy requirements; priority of cloud sync versus local use;
primary Android/Windows devices; whether dates should float across time zones;
desired behavior for same-name routine series; legal ownership/distribution terms;
acceptable storage/backup UX; hosting budget and identity provider if S2 is pursued.
The local plan can proceed using [design defaults](design.md); public sync cannot
be specified as production-ready until its identity and migration decisions close.

See [phases.md](phases.md) for estimates and requirement traceability and
[details.md](details.md) for severity/likelihood of repository risks.

## Specified expansion: seven integrated assistance tools

Decision: implement these capabilities within Momentum using one server-side AI
integration, shared result review, and the existing task storage/UI. No seven-model
system, training pipeline, vector database or multi-agent orchestration is needed.
The differentiated value is turning advice into the user's actual tasks and focus
sessions. For standalone rewriting/explanation alone, using the existing website
would be less work; app integration is justified by the connected task workflow.

Research on 2026-10-28 confirmed the referenced tools on their official pages.
Magic ToDo's detail control requests smaller steps; its Todoist/Notion exports are
CSV import workflows with different hierarchy/completion limitations, not two-way
connectors. [Magic ToDo](https://goblin.tools/ToDo). A supported public Goblin Tools
developer API was not verified in the reviewed pages/search; do not assume one is
available or use undocumented endpoints. The plan uses an independently configured
model provider. [About](https://goblin.tools/About).

User clarification: regardless of API availability, Goblin Tools must not be used
as an integration or implementation dependency. Its role is feature inspiration
only. Build Momentum's own UI, prompts, task logic and storage; do not call its
APIs, scrape or embed its website, or reuse its code, assets or branding. Any
citations above or below record prior research only, not a proposed dependency.

Use descriptive Momentum labels below; these are feature inspirations, not a claim
of affiliation or exact reproduction of another product's outputs.

| ID / delivery | Momentum feature | Behavior and measurable acceptance |
| --- | --- | --- |
| A1 / first AI release | Break Down | On an existing/draft task, choose detail 1-5 and receive editable steps. Preview, add/remove/reorder and explicitly apply. Accepted steps have stable IDs; duplicate Apply does not duplicate them; generating/cancelling cannot change stored tasks. Full suite supports manual nested steps and breaking a selected unfinished leaf further, bounded at depth 3 and 50 total nodes. |
| A2 / first AI release | Estimate | Return low/likely/high minutes, assumptions and uncertainty, with low <= likely <= high. User may override. No estimate silently becomes a due date or recorded work. Include difficulty, experience and focus context; these are inputs, not a universal multiplier. |
| A3 / first AI release | Focus | Show one chosen task/step, start/pause/resume, complete or skip, and choose next. Work offline after steps are saved; restart restores the last checkpoint paused; timer reaching zero never marks work complete or awards points. Breaking down further invokes A1 only on request. |
| A4 / second release | Rewrite | Tone and strength controls, original/result side by side, editable output, copy/apply. Explicit comparison supports at most three selected tones per request. Fixtures preserve names, dates, amounts, negation and commitments; never send a message automatically. [Reference](https://goblin.tools/Formalizer) |
| A5 / second release | Tone Check | Possible interpretations, quoted cues, missing context and optional draft reply. Ambiguous inputs must allow multiple readings; do not claim to know the writer's emotions or intentions. No invented accuracy percentage. [Reference](https://goblin.tools/Judge) |
| A6 / second release | Explain | Topic, existing knowledge and simplicity controls; return explanation, example and key terms. Unsupported current facts are not labeled verified; no invented citations. Keep concept content separate from saved tasks unless user explicitly adds it. [Reference](https://goblin.tools/Professor) |
| A7 / second release | Decide | Options plus user constraints; compare pros/cons, assumptions and conditional recommendation. Missing critical criteria produces a question instead of fabricated personal context. User remains decision maker. [Reference](https://goblin.tools/Consultant) |
| AX / suite completion | Export and deeper task controls | Markdown checklist export preserves order/depth/completion; Todoist and Notion CSV export tested against current import docs using synthetic fixtures. Explain each format's known losses; do not promise automatic synchronization. No OAuth connector in this scope. |

First release means F1-F5 plus A1/A2/A3 and the shared AI backend. A4-A7 and AX stay
in the requested full-suite scope and are scheduled explicitly, not abandoned.
The first A1 interface may show one level, but its persisted schema supports the
bounded nested structure so full-suite work does not require another storage rewrite.
No cross-device focus synchronization is promised; S1/S2 remain independent work.

The primary journey is: select task -> request breakdown and estimate -> review ->
save chosen steps -> focus on one step -> explicitly complete -> update existing
daily progress. Secondary journey: open AI Tools -> choose Rewrite/Tone Check/
Explain/Decide -> enter context -> review -> copy or explicitly apply. Add contextual
actions to current task screens rather than seven top-level navigation entries.

All network AI actions need a visible loading/cancel/error state, editable retained
input, timeout handling, and an offline explanation. Only selected text/context is
sent; no automatic upload of journals, profiles or entire task history. Default
AI history is off. Accepted tasks and focus sessions remain local. Provider keys
must remain on the server. Hosted paid AI requires verified access and budget
limits even when task cloud sync is off; the current dev-user seam is insufficient.

Proposed evaluation: at least 20 curated examples per AI operation, including
ambiguous inputs and prompt-injection text. Require 100% schema/bounds checks in
deterministic mocked tests; target >=80% useful outputs on the reviewed examples,
with zero critical factual mutation in rewriting fixtures. These are launch targets,
not observed model quality. During a two-week pilot measure accepted breakdowns,
edits before acceptance and whether accepted steps lead to completed focus sessions.
Keep evaluation fixtures synthetic and collect feedback without private-text logs.


Voice creation UX update: **Add by voice** is available in the main navigation and
Master Tasks, with a microphone shortcut in Day. After a single spoken creation,
Stop opens the filled task editor automatically; only **Save task** persists it.
See [the voice guide](OFFLINE_VOICE.md) for commands and platform verification.

Recording feedback: show a heartbeat-style waveform driven by microphone volume,
a listening label and elapsed recording time. Silence must not show invented
speech activity. Text recognition still happens after Stop; live captions are not
part of this change.

Voice task extraction now accepts common English/Hindi/Hinglish conversational
creation phrases, selected natural calendar dates, and common duration idioms.
Start delays and task durations remain distinct. Conflicting recognized schedule
fields require correction; interpretation notes are visible in the save form.
Offline date parsing uses chrono_dart; see OFFLINE_VOICE.md for bounded syntax.

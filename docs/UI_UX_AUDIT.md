# Momentum / Bubble Time Progress — UI/UX audit

Original review: 29 October 2026; screenshot update: 30 October 2026  
Scope: current Flutter repository; review only.

**Updated assessment: 4.2/10, provisional, combining source evidence and the available light-theme reference screenshots. Visual design: 5/10; professional appearance: 4/10.** The teal/mint palette and time bubbles provide a recognizable identity, but large summaries repeatedly push tasks, reflection and trends below the opening viewport. Saving, date selection, completion, and preserving user input remain the highest priorities.

This update changes the audit only. Application source remains unchanged; the screenshot tools and reference images were created separately.

## Evidence and limits

Reviewed the application shell, all 16 screen files, shared task/routine dialogs, theme configuration, visual components, and relevant persistence paths. Current code takes precedence over the README and historical implementation reports.

The original review ran the existing suite with **flutter test --no-pub: 40 passed, 1 skipped**. The skipped test is the opt-in native speech-model test, gated by RUN_NATIVE_VOICE_TEST. Passing tests cover the shell, selected task forms, task identity/persistence, parsing, and voice review behavior. They do not establish that every journey works. Tests were not rerun for this documentation update.

The current [screenshot gallery](../screenshots/phone/20261030-003057/index.html) contains **101 light-theme images across 31 capture groups**, including scroll continuations, dashboard tabs and forms. These render production Flutter widgets using synthetic data in temporary Hive storage. The manifest declares a 390 × 844 logical layout exported at 2× (780 × 1688 PNGs). This update visually reviews representative opening screens for all 16 screen modules, the shell, and selected schedule/editor continuations; it does not claim every image or state was inspected. Reports shares the Progress screen; Settings is not captured because it is disconnected from active navigation.

**Capture limitations affect the conclusions.** The [capture harness](../tool/capture_screenshots_test.dart) sets the test surface size and device pixel ratio, but does not explicitly set the test view's physical size. The [shell image](../screenshots/phone/20261030-003057/light/00-app-shell-01.png) shows a desktop rail despite the narrow image. Layout constraints and MediaQuery therefore cannot be assumed to represent the same phone viewport. Exact wrapping, breakpoint behavior and first-screen proportions need a corrected capture or device check. Content order and repeated sections remain useful evidence, corroborated by source.

Some chip labels render as solid bars; unusually heavy black shadow outlines and exposed black corners also appear. Treat these as capture artifacts pending verification, **not scored product defects**. The [manifest](../screenshots/phone/20261030-003057/light/manifest.json) records 17 overflow reports: four distinct screen/message combinations (Tasks: 37 px; Log & Earn: 25, 12 and 2.3 px). These establish failures in this harness, not confirmed real-phone failures. Form continuations also show overflow markers; their attribution requires a targeted rerun. Capture group labels can span a screen and its subsequently opened dialogs.

Only light-theme captures are present in the current folder. Dark appearance, keyboard-open layouts, system chrome, permissions, assistive technology, motion and performance remain unassessed visually. No interactive device session, contrast measurement, TalkBack/VoiceOver session or frame profiling was performed. Numerical ratings are expert judgments with these limits, not usability-study measurements or release certification.

- **Verified:** supported directly by current source or the test run.
- **Observed:** visible in a linked reference screenshot; subject to the capture limits above. It does not establish interaction behavior.
- **Risk:** an implementation pattern needs runtime verification; a failure has not been reproduced.
- **Proposal:** a recommendation, not an existing feature.
- Audience and preferred default navigation are inferred.

### Source reference index

| Ref | Source |
|---|---|
| S1 | [Application shell, routing and theme](C:/Users/rohan/repos/Notebook-main/Notebook-main/Bubble-Time-Progress-App-Flutter-/lib/main.dart:155) |
| S2 | [Dashboard composition and tabs](C:/Users/rohan/repos/Notebook-main/Notebook-main/Bubble-Time-Progress-App-Flutter-/lib/screens/dashboard_view.dart:102) |
| S3 | [Year view](C:/Users/rohan/repos/Notebook-main/Notebook-main/Bubble-Time-Progress-App-Flutter-/lib/screens/year_view.dart:343) |
| S4 | [Month view](C:/Users/rohan/repos/Notebook-main/Notebook-main/Bubble-Time-Progress-App-Flutter-/lib/screens/month_view.dart:312) |
| S5 | [Week view](C:/Users/rohan/repos/Notebook-main/Notebook-main/Bubble-Time-Progress-App-Flutter-/lib/screens/week_view.dart:542) |
| S6 | [Day view and schedule](C:/Users/rohan/repos/Notebook-main/Notebook-main/Bubble-Time-Progress-App-Flutter-/lib/screens/day_view.dart:640) |
| S7 | [Master Tasks](C:/Users/rohan/repos/Notebook-main/Notebook-main/Bubble-Time-Progress-App-Flutter-/lib/screens/task_screen.dart:260) |
| S8 | [Task form](C:/Users/rohan/repos/Notebook-main/Notebook-main/Bubble-Time-Progress-App-Flutter-/lib/widgets/quick_add_task_dialog.dart:45) and [quick-add persistence](C:/Users/rohan/repos/Notebook-main/Notebook-main/Bubble-Time-Progress-App-Flutter-/lib/widgets/quick_add_task_dialog.dart:1443) |
| S9 | [Routine occurrence dialog](C:/Users/rohan/repos/Notebook-main/Notebook-main/Bubble-Time-Progress-App-Flutter-/lib/widgets/routine_occurrence_dialog.dart:87) |
| S10 | [Voice capture/review screen](C:/Users/rohan/repos/Notebook-main/Notebook-main/Bubble-Time-Progress-App-Flutter-/lib/screens/voice_tasks_screen.dart:228) |
| S11 | [Streak Journey](C:/Users/rohan/repos/Notebook-main/Notebook-main/Bubble-Time-Progress-App-Flutter-/lib/screens/streak_view.dart:29) |
| S12 | [Instruction Dashboard](C:/Users/rohan/repos/Notebook-main/Notebook-main/Bubble-Time-Progress-App-Flutter-/lib/screens/instruction_dashboard_view.dart:27) |
| S13 | [Goal Dashboard](C:/Users/rohan/repos/Notebook-main/Notebook-main/Bubble-Time-Progress-App-Flutter-/lib/screens/goal_dashboard_view.dart:41) |
| S14 | [Reward Money History](C:/Users/rohan/repos/Notebook-main/Notebook-main/Bubble-Time-Progress-App-Flutter-/lib/screens/reward_money_history_view.dart:21) |
| S15 | [Motivation](C:/Users/rohan/repos/Notebook-main/Notebook-main/Bubble-Time-Progress-App-Flutter-/lib/screens/motivation_motto_dashboard_view.dart:29) |
| S16 | [Productivity Timeline](C:/Users/rohan/repos/Notebook-main/Notebook-main/Bubble-Time-Progress-App-Flutter-/lib/screens/productivity_timeline_view.dart:48) |
| S17 | [Log & Earn](C:/Users/rohan/repos/Notebook-main/Notebook-main/Bubble-Time-Progress-App-Flutter-/lib/screens/log_earn_view.dart:36) |
| S18 | [Journal & Reflection](C:/Users/rohan/repos/Notebook-main/Notebook-main/Bubble-Time-Progress-App-Flutter-/lib/screens/journal_view.dart:75) |
| S19 | [Journey Timeline and entry form](C:/Users/rohan/repos/Notebook-main/Notebook-main/Bubble-Time-Progress-App-Flutter-/lib/screens/journey_timeline_view.dart:17) |
| S20 | [Settings panel](C:/Users/rohan/repos/Notebook-main/Notebook-main/Bubble-Time-Progress-App-Flutter-/lib/screens/dashboard_view.dart:5279) |
| S21 | [Text sizing](C:/Users/rohan/repos/Notebook-main/Notebook-main/Bubble-Time-Progress-App-Flutter-/lib/widgets/app_text.dart:5), [bubble map](C:/Users/rohan/repos/Notebook-main/Notebook-main/Bubble-Time-Progress-App-Flutter-/lib/widgets/period_progress_bubble_map.dart:42), [period metrics](C:/Users/rohan/repos/Notebook-main/Notebook-main/Bubble-Time-Progress-App-Flutter-/lib/widgets/productivity_period_summary.dart:37) |
| S22 | [Task storage](C:/Users/rohan/repos/Notebook-main/Notebook-main/Bubble-Time-Progress-App-Flutter-/lib/services/hive_service.dart:1071), [date moves](C:/Users/rohan/repos/Notebook-main/Notebook-main/Bubble-Time-Progress-App-Flutter-/lib/services/hive_service.dart:1262), [reward ledger](C:/Users/rohan/repos/Notebook-main/Notebook-main/Bubble-Time-Progress-App-Flutter-/lib/services/hive_service.dart:1824) |

## PART 1 — Application understanding

### Purpose and audience

Momentum combines personal planning with visual time/progress tracking. It offers tasks, recurring routines, project steps, instructions/checklists, journaling, streaks, productivity scoring, savings-style reward goals, and offline voice commands.

**Inferred audience:** individuals managing study, work, habits, and personal goals who appreciate optional gamification. English/Hindi voice input suggests a bilingual audience. No evidence establishes a particular age group or a validated accessibility persona.

The repository includes Android, iOS, web, Windows, macOS, and Linux projects. Platform folders do not establish feature parity; native plugins, microphone access, images, and keyboard interactions need platform testing.

### Current journeys

1. **Open and orient:** the shell starts on Month. Below 700 px width, a narrow left-edge handle opens navigation. There are 15 navigation entries, including voice.
2. **Create a task:** floating action button or Master Tasks → Add Task → shared dialog → configure → save. Advanced fields complicate simple creation.
3. **Complete work:** Master Tasks has checkbox-shaped status icons but uses editing/occurrence dialogs for completion. Log & Earn has actual checkboxes. Users must learn different interaction patterns.
4. **Plan a day:** Day shows hour bubbles, metrics, a full-day schedule, tasks and journal access. Existing tasks support drag scheduling. Empty-hour creation currently discards the form result.
5. **Use voice:** record → stop → transcribe → review the filled editor → explicitly save. Typed commands remain available. This is one of the clearer journeys.
6. **Build routines:** task form → repeat settings → occurrence tracking → optional instruction review → streak/score updates.
7. **Reflect:** enter Journal through Day, task actions or dashboard/streak links → mood → reflection → save. Date changes replace the editor contents without a draft guard.
8. **Review progress:** Streak, Progress, Reports, Goals, Money and dashboard tabs provide overlapping ways to review activity.

### First-time versus returning-user experience

A first-time user may understand the time metaphor but struggle to discover planning and completion. Month bubbles are informational rather than date-selection controls. Hidden mobile navigation and a long task form make the app harder to learn.

Returning users benefit from local storage, date views, filters, voice review and history. Friction comes from inconsistent controls, long screens, duplicate destinations and interruptions.

Likely abandonment triggers include lost writing, a task appearing under the wrong date, an apparently successful save with no persistence, and Select All changing completion state. These are more urgent than decorative refinement.

## PART 2 — Overall UI/UX rating

Weights are unchanged from the original review. Visual categories now have limited screenshot evidence; behavioral categories retain source evidence. Responsiveness remains a source-only provisional rating because these captures do not validate phone breakpoints.

| Evaluation category | Rating /10 | Weight | Basis |
|---|---:|---:|---|
| Overall visual design | 5 | 10% | Recognizable teal/mint palette and bubbles; oversized summaries and competing emphasis in captures |
| Color scheme and consistency | 4 | 10% | Light theme is partly coherent, but blue/purple modules and pastel form fills vary; fixed light surfaces remain a source risk |
| Typography and readability | 5 | 10% | Clear major headings; tiny annual numbers, dense metadata and frequent bold emphasis; chip-font artifacts excluded |
| Layout and spacing | 4 | 10% | Captures corroborate summaries before actions, long forms and repeated nested cards; exact device proportions unverified |
| Navigation and user flow | 3 | 15% | Hidden mobile entry, 15 choices, duplicate routes and disconnected settings |
| Ease of use | 4 | 15% | Inconsistent creation/completion behavior and complex forms |
| Accessibility | 4 | 10% | Some labels/semantics; 32 px controls, tiny text and custom charts need improvement |
| Responsiveness | 5 | 10% | Source-only provisional score: adaptive code exists; dense rows/fixed heights need a valid viewport and device check |
| Interaction and feedback | 5 | 5% | Strong voice states; weaker save, draft, bulk action and validation behavior |
| Professional appearance | 4 | 5% | Clear headings and recognizable identity, but repeated metrics, implementation copy and inconsistent card hierarchy reduce polish; renderer artifacts excluded |

**Weighted score:**  
(5×10 + 4×10 + 5×10 + 4×10 + 3×15 + 4×15 + 4×10 + 5×10 + 5×5 + 4×5) ÷ 100 = **420 ÷ 100 = 4.2/10**.

The rounded overall result remains 4.2, but its evidence has changed: visual design and professional appearance are now scored, and layout drops from 5 to 4 because the screenshots corroborate weak action hierarchy. All categories have a provisional score; this does not mean all categories have device validation. Passing tests and static screenshots do not resolve the source-confirmed journey defects.

## PART 3 — Screen-by-screen review

These are mixed-evidence usability scores, not visual-only ratings. Source-confirmed behavior remains decisive; the linked visual review below adds evidence about composition and content hierarchy. Settings remains source-only. The Streak score decreases from 5 to 4 because its opening composition gives the profile/metrics much more prominence than habits.

| Screen / surface | What works | What does not work; end-user experience | Rating | Recommended changes / priority |
|---|---|---|---:|---|
| Main shell (S1) | Retains destinations; desktop tooltips | Hidden mobile entry, 15 choices, unexplained Month default; Progress/Reports duplicate | 3/10 | **High:** visible primary navigation, explicit Settings, consolidate duplicates |
| Dashboard — six tabs (S2) | Sections for Overview, Productivity, Tasks, Goals, Instructions, Growth | Duplicates sidebar; hero/progress/motto precede work. Implementation copy such as “No duplicate cards” and “existing engine.” Hero opens Journal; avatar opens Progress | 4/10 | **High:** next action first and explicit links; **Medium:** remove implementation copy |
| Year (S3) | Distinctive bubbles, selected year and legend | Day-of-year labels are 6.5–8 px; tooltip needed for dates. Recurrence panel fixed at 140 px. Add absent on other years | 5/10 | **Medium:** accessible monthly drill-down; dots as overview rather than tiny reading targets |
| Month (S4) | Clear period title and selector | Bubbles cannot open tasks. “Monthly Tasks” includes monthly recurrences only. Empty copy congratulates users despite restricted scope | 4/10 | **High:** selected-date agenda; **Medium:** accurate scope/empty labels |
| Week (S5) | Previous/next and breakdown | Analytics precede work; recurrence-only panel; fixed 80 px app-bar bottom needs large-text testing | 5/10 | **Medium:** agenda first, expandable analytics, Today shortcut |
| Day (S6) | Date controls, voice, drag scheduling, unscheduled tasks | Empty-hour save discarded; 1,728 px timeline; “Today Schedule” on other dates; overlap lanes capped at four | 3/10 | **Critical:** save fix; **High:** agenda and reliable overlap handling; **Medium:** selected-date wording |
| Master Tasks (S7) | Filters, add/voice, edit/delete tooltips, delete confirmation | Checkbox icons inert; dense metadata; no search; 32×32 actions; goal link inferred from text | 4/10 | **High:** real completion, larger actions, true relationships; **Medium:** search and simpler rows |
| Task editor / quick-add (S8) | Shared form, date picker, required-name check, steps/routines | Long “quick” form; changed date ignored by storage call; fixed pale fills; snackbar validation; drafts dismissible | 3/10 | **Critical:** date persistence; **High:** draft protection and inline validation; **Medium:** basic/advanced split |
| Routine occurrence dialog (S9) | Explicit status, instruction review, separate routine edit, journal explanation | Dense nested choices; locked states differ from reversible Log & Earn controls | 5/10 | **High:** consistent correction/date rules; **Medium:** simpler completion hierarchy |
| Offline Voice (S10) | Privacy explanation, typed fallback, capture states, audio-level feedback, explicit review, saved status | Long examples; cancellation shown as error; no processing cancel action; long target dropdown | 7/10 | **Medium:** collapsible examples, neutral cancellation, cancel processing, searchable target |
| Streak Journey (S11) | Connects routines, heatmap, daily/weekly history | Profile/metric hero fills the opening capture before habits; duplicate sections; distressed miss emoji; profile tap opens Journal | 4/10 | **Medium:** compact checklist/consistency, neutral misses, explicit Journal link |
| Instructions (S12) | Filters, update actions, linked rules/options | List excludes all linked items although editor creates them; long form; “points and Points”; immediate deletion | 4/10 | **High:** Linked/Standalone visibility and recovery; **Medium:** presets and clearer vocabulary |
| Goals/editor/detail (S13) | Savings progress, images, milestones, history | Long financial-goal form; invalid dates silently null, amounts zero; route-independent reminder timer | 5/10 | **High:** validation/reminder control; **Medium:** Reward Goals naming and compact cards |
| Money/withdrawal (S14) | Summaries, filtered dated ledger | Withdraw implies payout but writes local ledger. Invalid amount can show saved without write; invalid date becomes today | 4/10 | **High:** validation and truthful success; **Medium:** ledger wording, date picker |
| Motivation (S15) | Quotes, favorite/pin, reminder settings | 30-second popup option; redundant reminder actions; authored text title-cased on save; immediate delete; empty save silently returns | 5/10 | **Medium:** inline delivery, original wording, validation and undo |
| Progress/Reports → Productivity Timeline (S1, S16) | Trends, detail, points, heatmap | Two independent identical instances/timers; profile/money/photos before trends; reminders can fire while hidden | 4/10 | **High:** one route and reminder coordinator; **Medium:** period-first analytics |
| Log & Earn (S17) | Date picker, real checkbox, future-date guard, reward details | Select All completes tasks; may launch sequential instruction dialogs; coins/points overlap | 4/10 | **High:** true selection then explicit completion; consistent correction |
| Journal (S18) | Mood/text, task context, saved feedback/history | Date changes overwrite drafts; no exit guard; immediate delete; rank/mood precede writing; Dashboard may simply pop | 3/10 | **High:** drafts/recovery; **Medium:** writing-first structure and correct navigation |
| Journey Timeline/editor (S19) | Merges activity by date; helpful empty state | Photo requires URL/path; related tasks deduplicated by name; direct deletion; eager history construction | 5/10 | **Medium:** picker, ID-based links, lazy sections, undo |
| Settings (S20) | Theme/palette/font controls and preview foundation | Entry callbacks only in unused builders. Layout/chart/icon/system-theme preferences lack behavior consumers | 2/10 | **High:** reachable route and working options only; whole-app verification |


### Screenshot evidence and visual changes to the review

Links point to the currently available capture set. References V1–V18 are visual evidence, not proof that controls save, navigate or announce correctly. Fold positions describe these reference images only; validate them again with consistent view dimensions.

| Ref / Screen | Observed strengths and problems | Practical change |
|---|---|---|
| V1 — [Shell](../screenshots/phone/20261030-003057/light/00-app-shell-01.png) | Teal header and mint background establish an identity. Desktop rail appears in the narrow image, exposing a capture/viewport mismatch | Correct capture dimensions before judging mobile navigation visually; retain the source finding about the hidden mobile handle |
| V2 — [Dashboard](../screenshots/phone/20261030-003057/light/01-dashboard-01.png) | Distinct sections and readable headings. Rank, several totals, progress and motto precede tasks. “Combined dashboard summary” and “No duplicate cards” describe implementation | Lead with next task and Add Task; reduce totals to a compact summary and remove implementation copy |
| V3 — [Year](../screenshots/phone/20261030-003057/light/02-year-01.png) | The annual bubble map is distinctive, with a clear elapsed-year summary. Hundreds of tiny numbered dots demand close reading and dominate the page | Keep dots as overview; use readable month groups and a date list/drill-down |
| V4 — [Month](../screenshots/phone/20261030-003057/light/03-month-01.png) | Day numbers, legend and highlighted current day make the map easier to read than Year. Secondary metrics add competing emphasis; the selector initially shows early months despite an October title | Keep the map; put the selected-date agenda next. Verify selector positioning after capture settling before calling it a product bug |
| V5 — [Week](../screenshots/phone/20261030-003057/light/04-week-01.png) | Seven day markers, weekday labels and date range are understandable. Score, rating, points and hours occupy a large summary before work | Compact the summary and show a weekly agenda first; explain score separately from elapsed time |
| V6 — [Day opening](../screenshots/phone/20261030-003057/light/05-day-01.png), [schedule continuation](../screenshots/phone/20261030-003057/light/05-day-04.png) | Hour bubbles provide an overview, but bubbles and metrics precede the schedule. The continuation spends substantial space on empty overnight hours | Open on the relevant agenda/time; make the 24-hour overview optional |
| V7 — [Master Tasks](../screenshots/phone/20261030-003057/light/06-tasks-01.png) | Completed titles have visible strike-through. Multiple chips, urgency, importance, duration and instructions make each card expensive to scan | Prioritize completion, title and due time; move optional metadata into expansion/details. Do not treat rectangular chip glyphs as app text |
| V8 — [Task form opening](../screenshots/phone/20261030-003057/light/06-task-create-form-01.png), [continuation](../screenshots/phone/20261030-003057/light/06-task-create-form-04.png) | Field labels and persistent Cancel/Add Task footer are useful. Large urgency/importance blocks, phase explanation, instructions and metadata create a long editor; continuation shows overflow markers | Preserve the footer; basic fields first, advanced groups collapsed. Reproduce phase action-row overflow with corrected metrics before choosing the layout fix |
| V9 — [Streak](../screenshots/phone/20261030-003057/light/07-streak-01.png) | Consistent teal gradient and recognizable statistics. Profile, rank, level, streak and numerous counters fill the first image before habits. “Fragmented” and “Fogged” are prominent labels | Show today's routines and a small consistency summary first; use neutral, optional gamification wording |
| V10 — [Instructions](../screenshots/phone/20261030-003057/light/08-instructions-01.png) | Summary structure is clear, but a large zero-progress ring and several totals precede actionable instructions | Put instructions and Add first; collapse the summary when it provides little information |
| V11 — [Goals](../screenshots/phone/20261030-003057/light/09-goals-01.png) | Individual goal progress is understandable. Six summary tiles plus filters substantially delay the first goal | One available-budget summary, compact filters and goal cards with one next action |
| V12 — [Money](../screenshots/phone/20261030-003057/light/10-money-01.png) | Positive amount uses a sign and color; transaction description is useful. Five large summaries outweigh the single visible transaction | Emphasize balance and ledger; place secondary totals in an expandable summary |
| V13 — [Motivation](../screenshots/phone/20261030-003057/light/11-motivation-01.png) | Today's motto and reminder labels are readable. A large reminder configuration section separates the featured motto from the quote list, which repeats the motto | Compact the featured quote; move reminder configuration into a secondary panel |
| V14 — [Progress / Reports](../screenshots/phone/20261030-003057/light/12-progress-reports-01.png) | Clear section title and grouped counters. Profile and a long stack of metrics precede trends; two differently valued tiles both read “Lifetime Points” | Start with period and trend; define/name distinct currencies or remove duplicate labels. Move profile editing out of the main analytics hierarchy |
| V15 — [Log & Earn](../screenshots/phone/20261030-003057/light/13-log-earn-01.png) | Selected date and Select All are visible. Large reward/streak tiles and a milestone card put task logging near the bottom. Task-row overflow markers appear | Put date and tasks first, rewards second; retain H2's separate selection/complete action. Treat overflow as a reproduction target, not a verified device failure |
| V16 — [Journal](../screenshots/phone/20261030-003057/light/14-journal-01.png) | Mood choices use labels and selected outlines as well as color. Profile/rank, date card and six large mood tiles precede writing; editor only begins near the bottom | Date/save state, compact mood choices, then editor; move rank/profile elsewhere. Draft protection remains essential |
| V17 — [Journey](../screenshots/phone/20261030-003057/light/15-journey-01.png) | Add journey entry is prominent and daily activity is grouped. Long introductory hero, repeated “Today's Activity” headings and nested tinted cards compete with the actual entry | Shorten the intro, keep one date heading and flatten entries into a readable feed |
| V18 — [Voice](../screenshots/phone/20261030-003057/light/16-voice-01.png) | Most focused opening composition: purpose, privacy/review explanation, Record button and editable transcript. Hindi examples render legibly. Long examples separate transcript from Analyse | Preserve this sequence, shorten examples and expose more help on demand; native microphone behavior is not established by this capture |

The strongest visible foundation is the repeated teal header/action color, soft mint background and distinctive time maps. The main weakness is **what receives space and attention**, rather than a lack of decoration. Blue/purple profile and Journey treatments, pale blue dashboards and lavender form sections also need clearer roles within that system. Exact color contrast and text sizes have not been measured from these images.

## PART 4 — Detailed problem report

Each row includes the affected component, evidence, user impact, proposed Flutter approach and expected benefit. Risks are not presented as reproduced failures.

| ID / Component | Problem / evidence | User impact | Priority | Recommended fix and expected improvement |
|---|---|---|---|---|
| C1 — Day schedule | **Verified:** S6 line 703 opens showTaskFormDialog without persisting its returned Task | Add closes the form without storing the task through this path | Critical | Await result, persist through service, report success after write, retain draft on failure. Restores creation |
| C2 — Quick-add date | **Verified:** S8 lets dueDate change but calls addTask(date, result); S22 uses that argument for storage key | Task due tomorrow can be stored under today and absent from tomorrow’s lookup | Critical | Use returned due date; centralize creation and test both date buckets/reopen. Restores calendar reliability |
| H1 — Journal drafts | **Verified:** S18 date change reloads controller text; no dirty guard on exit | Writing lost through ordinary navigation | High | Date-specific drafts or dirty-state confirmation; PopScope for route exit plus separate date-switch guard |
| H2 — Bulk completion | **Verified:** S17 Select All calls _complete for each eligible task | Selection unexpectedly changes history/rewards | High | Selected-ID state followed by Complete selected review; show count, exclusions, result and correction |
| H3 — Mobile navigation | **Verified:** S1 28 px edge hit region, 12×72 visual handle, no visible menu label | Features hard to discover and entry hard to interpret | High | NavigationBar plus labeled More/Drawer; predictable semantic and keyboard interaction |
| H4 — Settings | **Verified:** entry callbacks occur in unused dashboard sidebar/header builders; several preferences have no behavior consumers | Personalization inaccessible; exposing current panel would include ineffective options | High | Add Settings route; wire/remove each preference; actual themeMode/brightness resolution |
| H5 — Linked instructions | **Verified:** S12 list excludes linked instructions while editor permits them | Newly saved items seem to disappear | High | Standalone/Linked sections and post-save destination link; all saved items retrievable |
| H6 — Task checkbox | **Verified:** S7 uses plain Icon for checkbox shape | Tapping expected completion control does nothing | High | Checkbox using shared occurrence command; title opens details, Edit changes metadata |
| H7 — Targets/text | **Verified:** 32×32 task actions; 6.5–8 px Year labels; small-screen font shrink helper | High precision and reading demands | High | Aim for 48 logical-pixel mobile targets, scalable text, labeled controls and date-list alternative |
| H8 — Theme mismatch | **Verified:** fixed light/pastel surfaces coexist with theme-derived text in period screens/forms | Dark appearance can mismatch and customization feels incomplete | High | ColorScheme/ThemeExtension roles throughout; measure rendered contrast. No contrast ratios measured here |
| H9 — Reminder duplication | **Verified mechanism:** IndexedStack mounts two Timeline instances and Goals; each starts an ungated 30-minute timer | Multiple goal dialogs can be requested during unrelated work | High | Single coordinator, route/lifecycle guards, shared snooze, suppression during input. Actual frequency not device-tested |
| H10 — False save outcome | **Verified:** withdrawal invalid input becomes 0; service returns without writing, caller shows saved; malformed date becomes now | User cannot trust recorded history | High | Validate before close, return explicit service outcome, retain input. Apply to goal dates/amounts too |
| H11 — Deletion | **Verified:** Journal, Motivation, Instructions and Journey have direct delete paths; Tasks already confirms | Mistaken tap removes content without recovery | High | Confirmation for substantial content or durable undo; retain existing task protection |
| M1 — Duplicate destinations | **Verified:** Progress/Reports same screen; dashboard repeats feature destinations | Unclear information ownership | Medium | One route per objective; subviews for genuine differences |
| M2 — Long task form | **Verified:** shared form exposes many optional metadata branches | Simple capture requires advanced scanning | Medium | Name/date first; Repeat and More options; full-height mobile editor for complex tasks |
| M3 — Task scope | **Verified:** Month/Week/Year panels filter corresponding recurrence frequencies; bubbles informational | “Tasks” and congratulatory empty states imply broader coverage | Medium | Accurate “Monthly routines” naming or all-period tasks, factual empty state, contextual Add |
| M4 — Score denominator | **Verified:** month/year capacity includes full period, including future days | Mid-period score can look low before remaining days occur | Medium | Label full-period progress; separate performance-to-date with explicit eligible-day policy |
| M5 — Completion metric | **Verified:** routineCompletionRate adds completed + pending + overdue; Month/Year pending already includes overdue | Double-counted denominator and unclear routine population | Medium | Exclusive status groups and routine-occurrence denominator in a shared tested metrics model |
| M6 — Goal badge | **Verified:** S7 infers linkage from “goal” in category/description | Badge claims relationship that may not exist | Medium | Explicit goal ID or truthful tag label; actual linked destination |
| M7 — Journal Dashboard action | **Verified:** optional callback then maybePop; many callers omit callback | Action returns to origin rather than Dashboard | Medium | Explicit Dashboard route or label Back |
| M8 — Authored text | **Verified:** quote save title-cases text; task storage normalizes names | Acronyms and intentional capitalization changed | Medium | Preserve authored content; casing transformations only for controlled UI labels |
| M9 — Money wording | **Verified:** withdrawal writes a local ledger, no payout call in this action | “Withdraw” suggests money transfer | Medium | “Record reward spending”; explain personal reward budget and distinguish points/coins/rupees |
| M10 — Journey media | **Verified:** URL/path entry although Goals already uses image_picker | Mobile photo entry requires technical location | Medium | Reuse picker, thumbnail/remove/error states; optional advanced URL input |
| M11 — Validation | **Verified:** silent goal parse fallbacks, empty motto save return, snackbar-only task name error | Unclear correction and silently altered input | Medium | Form/TextFormField errors, date picker, first-error focus and retained input |
| M12 — Date freshness | **Verified pattern:** shell constructs TaskScreen with DateTime.now once; period views initialize dates once | Risk: today creation default stale after midnight in retained screen | Medium | Distinguish follows-today from intentionally selected date; refresh on resume/day change |
| M13 — Layout risks | **Verified patterns:** full-day timeline, fixed routine panels/app-bar height, dense rows, four-lane cap | Risk: excess scrolling, clipped large text or obscured overlapping events | Medium | Agenda/detail variants, content-driven heights, overflow group and responsive tests |
| M14 — Hidden-screen work | **Verified patterns:** eager IndexedStack, broad box listeners, timers/pulses, year-wide calculations in build | Risk: unnecessary processing as history grows; jank not measured | Medium | Lazy creation, narrow listeners, cached summaries, TickerMode and explicit timer suspension |
| M15 — Chart accessibility | **Verified:** custom chart/bubble implementations lack structured equivalent detail for all encoded data | Risk: screen-reader users miss information | Medium | Semantic date/status/value summaries and accessible lists/tables; assistive-tech testing |
| L1 — Copy/tone | **Verified:** implementation explanations, congratulatory empty recurrence states, distressed miss emoji | Confusion or discouragement | Low | User-centered, factual labels; neutral Not logged/Missed with recovery action |
| L2 — Decoration | **Observed:** multiple gradients, tinted nested cards and bold sections compete in V2, V9, V16 and V17; heavy black shadow artifacts excluded | Main action loses emphasis among decorative sections | Low | One primary emphasis and shared surface/spacing/radius roles; verify actual device shadows separately |

### Visual findings added by this update

| ID / Priority | Screenshot evidence | User impact | Proposed change / acceptance check |
|---|---|---|---|
| V-H1 / High — Action hierarchy | V2, V6, V9, V14–V16: summaries/profile before the screen's core work | More scanning and scrolling before planning, logging or writing | Move each primary action/work area ahead of optional metrics. On a valid 390 px layout, show the first task or useful editor area without scrolling; also verify at 360 px and large text |
| V-M1 / Medium — Repeated metric labels | V14: two “Lifetime Points” cards show 61 and 6 in seeded data | User cannot tell whether values are different currencies or inconsistent totals | Name each measure and unit explicitly; reconcile against the data model. Screenshot values alone do not prove a calculation bug |
| V-M2 / Medium — Card and form density | V7, V8, V17: many chips, large option blocks and nested tinted cards | Daily scanning and simple capture require too much attention | Compact task rows, basic/advanced form groups and flatter history entries; keep persistent form actions |
| V-M3 / Medium — Visual consistency | V10–V14 use pale blue/white sections; V16 blue profile; V17 purple/blue hero alongside teal shell | Screens feel assembled from different visual systems | Define surface, accent, selected and status roles; retain purposeful color distinctions and verify light/dark contrast |
| V-M4 / Medium — Readability and tone | V3 tiny annual numbers; V9/V16 prominent “Fragmented” / “Fogged”; V2 implementation copy | Fine detail is difficult to read and labels do not clearly help the user act | Readable drill-down; neutral status wording; remove developer-facing explanations from the product |

These findings strengthen existing layout/copy recommendations; they do not replace C1/C2 or H1/H2. Rectangular glyphs, black shadow outlines, selector settling and recorded overflows require capture/device validation before being classified as product defects.

## PART 5 — UI enhancement recommendations

These 16 proposals follow from the evidence and require no new packages.

1. **Propose Today as default:** date, next task, remaining work and Add Task first. Let returning users choose their starting view.
2. **Four primary destinations:** Today, Plan, Progress, More. Calendar scales belong inside Plan.
3. **Keep the bubble identity:** pair overview bubbles with an agenda/date list; tiny annual dots should not carry the entire interaction.
4. **Make capture quick:** name and date before optional Repeat, steps and advanced metadata.
5. **Unify completion:** real checkboxes backed by the same occurrence rules on Tasks, Today and Log & Earn.
6. **Separate selection from mutation:** bulk selection highlights items; a separate explicit command completes them.
7. **Protect reflection:** date-specific drafts, visible saved state and deletion recovery.
8. **Make saves verifiable:** success after persistence, input retained on error, link to saved task/date.
9. **Use one token system:** theme roles for surfaces, text, borders and statuses.
10. **Readable type hierarchy:** approximately 16 px body, 14 px supporting text, concise headings; respect user scaling.
11. **Simplify task rows:** title, due label, status and completion; secondary metadata in details.
12. **Explain metrics:** distinguish time elapsed, task completion, reward points and full-period capacity.
13. **Give Settings a real home:** start with verified appearance, text, start-screen and reminder controls.
14. **Reduce interruption:** inline motivation, shared snooze and reminders paused during input.
15. **Reuse familiar input:** image/date pickers and searchable long task selections.
16. **Restrain feedback:** brief meaningful transitions and optional completion haptics; honor reduced motion and avoid perpetual glow as the main status signal.

## PART 6 — Proposed design improvements

### Shared design language

Build on the teal/mint identity visible in the current captures and retain optional accent personalization. Give blue/purple treatments a defined purpose instead of a separate style for each module. Use neutral surfaces; green completion, amber attention, red errors/destructive actions, always paired with words or icons. Measure exact contrast after rendering with verified fonts and view dimensions.

Suggested type roles: 24–28 px page titles, 18–20 section headings, 16 body, 14 supporting text. Use regular/medium body weights and semibold headings instead of widespread w900. Start with an 8-point spacing rhythm, 16 px page insets, 12–16 px card padding/radii, and 48 px mobile targets. Allow growth/wrapping at large text sizes.

Selection/expansion transitions around 150–250 ms can clarify change. Respect platform motion preferences. These are proposed design values to validate, not observed outcomes.

### Shell and Dashboard

**Current:** hidden mobile navigation, 15 entries, six dashboard tabs, summary/motto content ahead of work.

**Proposed:** Today / Plan / Progress / More bottom navigation; NavigationRail on larger layouts. Settings in More and a desktop footer. Today shows date, next scheduled item, pending tasks and Add Task. Place compact progress and optional motto below daily actions. Give Journal and Progress explicit labeled buttons rather than surprising whole-card taps.

### Year, Month and Week

**Current:** elapsed-time maps followed by analytics and recurrence-only panels.

**Proposed:** Plan with Day / Week / Month / Year selection. Month uses weekday labels, selectable dates and an agenda below. Week prioritizes scheduled work. Year shows monthly groups and readable summary, with month drill-down. Label Time elapsed separately from Tasks completed. Add Task always names the selected date.

Keep annual dots as overview; do not depend on 6.5 px day numbers for reading. Offer an accessible date list. Keep period selectors and Today in a consistent header position.

### Day

**Current:** bubbles and metrics precede a 1,728 px timeline.

**Proposed:** date header and Today shortcut, agenda, unscheduled tasks and Add Task. A Timeline switch serves scheduling-heavy use. Open near the relevant time; offer Edit time as a non-drag alternative. For many overlaps, show a labeled grouped event opening a list instead of additional unreadable columns.

### Master Tasks, editor and routine completion

**Current:** dense cards, inert checkbox icons, lengthy dialog.

**Proposed:** search, active/completed filters and compact rows. Checkbox, two-line title, due label and overflow action. Name/date first in Add Task; optional time and Repeat; More options for priority, steps, category, instructions and delegation.

Use full-screen mobile editing for long forms with persistent Save; retain width-constrained desktop dialogs. Routine completion names the exact occurrence date, reviews instructions only when necessary, and exposes consistent correction behavior.

### Streaks and Instructions

**Current:** overlapping activity sections, negative miss emoji, long instruction setup.

**Proposed:** Streaks as a Progress subview: today’s routines, seven-day consistency and expandable long-term history. Use neutral missed states and a next action.

Instructions separates Standalone and Linked. Create from a simple checklist or advanced scored options. Show linked task as a real link and keep newly saved content visible. Use one clearly defined points vocabulary.

### Journal and Journey

**Current:** rank/mood compete with reflection, dates replace drafts, Journey photos need a path/URL.

**Proposed:** date and save state, compact mood choices, reflection editor, persistent Save. History/analytics below or in another tab. Keep per-date drafts and deletion recovery. Journey uses lazy dated sections, type filters and existing image_picker. Select related tasks by stable ID so same-name tasks remain distinct.

### Goals and Money

**Current:** generic Goals label presents a financial model; large cards, free-text dates, withdrawal language.

**Proposed:** label current feature Reward Goals. Compact cards show target, saved amount, progress and one next action. Detail houses photos/milestones/history. Group editor into Goal / Budget / Optional details.

Money shows available reward budget, earned and recorded spending, with Record spending. Explain local personal tracking. Validate amount/date before closing and preserve input on failure. No payment integration is needed to correct this wording.

### Progress and Reports

**Current:** two identical destinations; profile, money and photos above analytics.

**Proposed:** one Progress page with Overview / Trends / History. A single period selector drives relevant metrics consistently. Completion/activity first, points explanation second. Profile/media belong in Profile/Journey. Every chart has an accessible textual equivalent.

### Voice and Motivation

**Current:** sound review model with extensive examples; potentially frequent motivation dialogs.

**Proposed:** preserve Record → Review → Save. Show two short examples and expandable help, neutral cancellation, cancel processing, and Saved to [date] with Open task.

Motivation defaults to an inline card; edit/favorite in a small menu. Reminders are explicit, optional and snoozable. Preserve original quote wording and capitalization.

### Settings

**Current:** disconnected panel and persisted-but-unused options.

**Proposed:** ordinary Settings route with Appearance, Text size, Start screen and Reminders. Preview plus actual applied behavior. Hide layout/chart/icon choices until their supported behavior exists throughout the product. Keep readable defaults and verify every retained palette/font option.

## PART 7 — Flutter implementation guidance

### Retain the useful foundation

The project already has ThemeData, ColorScheme.fromSeed, a ThemeExtension, shared forms, reactive Hive listeners, explicit voice review, typed steps, stable task identities and tests. Keep these.

Extract commands, view models and reusable sections incrementally. Large files alone do not justify rewriting the architecture. No new state-management or chart dependency is required for priority fixes.

### Fix persistence at the boundary

Illustrative empty-hour creation:

~~~dart
Future<void> addAtHour(int hour) async {
  final draft = await showTaskFormDialog(
    context,
    date: _currentDay,
    initialHourSlot: hour,
  );
  if (draft == null) return;

  try {
    await widget.hiveService.addTask(draft.dueDate, draft);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Task saved')),
    );
  } catch (_) {
    if (!mounted) return;
    // Production flow should retain/reopen the draft for retry.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not save. Please try again.')),
    );
  }
}
~~~

Also use the returned due date in quick-add. Centralize creation so all entry points behave consistently.

Verify time placement separately: Day currently reads schedule metadata from description, while the form also has hourSlot. Persisting a task alone does not establish correct placement in the visual schedule.

Retain the existing recovery-aware date-move path for edits. Test creation and movement separately.

### Use meaningful completion controls

~~~dart
Checkbox(
  value: completed,
  semanticLabel: 'Complete ' + task.task,
  onChanged: saving
      ? null
      : (value) => setOccurrenceCompleted(
          task, selectedDate, value ?? false),
)
~~~

This is schematic: preserve journal-specific and instruction-review rules. A shared command should resolve occurrence date, save state, recalculate rewards and expose errors. Use IDs for bulk selection, not names or positions.

### Connect system appearance

~~~dart
MaterialApp(
  theme: buildAppTheme(Brightness.light),
  darkTheme: buildAppTheme(Brightness.dark),
  themeMode: followSystem
      ? ThemeMode.system
      : (darkSelected ? ThemeMode.dark : ThemeMode.light),
  home: const AppShell(),
)
~~~

This is a proposed structure, not a drop-in patch. Keep palette/font configuration inside buildAppTheme. Replace fixed light fills with ColorScheme roles; retain semantic custom colors through the existing extension. Flutter resolves system preference through themeMode and supplied light/dark themes. [Flutter themeMode documentation](https://api.flutter.dev/flutter/material/MaterialApp/themeMode.html)

Do not interpret the absence of an explicit useMaterial3 flag as proof of Material 2; framework defaults depend on the SDK. The observed issue is inconsistent theme/component usage.

### Use content-driven responsive layouts

~~~dart
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth < 840) {
      return ListView(children: [summary, taskList, details]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: taskList),
        const SizedBox(width: 24),
        Expanded(child: details),
      ],
    );
  },
)
~~~

The breakpoint is a proposal. Give each variant appropriate scroll constraints and account for navigation-rail width. Prefer local constraints over full-screen width. Let text wrap instead of shrinking it.

Use SafeArea around persistent controls and account for viewInsets in custom editor surfaces. Existing scrollable AlertDialogs are a useful starting point, not proof that keyboard and large-text states work everywhere.

### Accessibility and equivalent information

Prefer labeled native controls, adequately sized IconButtons and selected-state semantics for custom choices. Charts should offer values in text/list form. An annual map can summarize a month and open a date list rather than relying on hundreds of ambiguous dots.

Proposed focused tests after implementation:

~~~dart
final semantics = tester.ensureSemantics();
try {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
} finally {
  semantics.dispose();
}
~~~

Use platform-appropriate target checks and actual TalkBack/VoiceOver sessions. Automated checks do not replace assistive-technology testing. [Flutter accessibility testing](https://docs.flutter.dev/ui/accessibility/accessibility-testing)

### Stop unnecessary work and interruptions

Use lazy screen creation and TickerMode for inactive retained screen subtrees. TickerMode controls animation tickers, **not Timer.periodic**. Suspend timers explicitly and centralize reminders. [Flutter TickerMode documentation](https://api.flutter.dev/flutter/widgets/TickerMode-class.html)

Use narrow listenables so unrelated data does not rebuild themes and year-wide summaries. Move expensive derivations outside build where practical and invalidate cached results on relevant changes. Profile representative history before claiming a speed improvement.

Honor custom animation preferences. Current Flutter documentation distinguishes disableAnimations from iOS reduceMotion; use the APIs available in the installed SDK rather than assuming one flag covers both. [Flutter animation-preference documentation](https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html)

### Explicit editor state and reusable components

Represent draft, dirty, saving and error states explicitly. Use Form validators near fields, meaningful service results, duplicate-submission prevention and retained input on failure.

Useful extractions include TaskRow, EmptyState, ErrorMessage, PeriodSelector and MetricCard. A shared metrics model and reminder coordinator address real duplication. Preserve dependency injection; the shared form’s direct HiveService.instance access currently complicates isolation.

### Verification required before release

These are proposed checks, not tests completed during this audit:

- Create from every entry point; change date; save/reopen; inspect both date buckets.
- Save from an empty hour; verify persistence and visual time placement.
- Type a journal draft; switch dates, navigate Back, restart; verify intentional draft behavior.
- Select multiple tasks; verify selection alone does not mutate completion; test explicit completion, cancellation and partial failure.
- Save a linked instruction, then find/edit it.
- Reject zero/invalid withdrawal amounts and malformed goal dates without false success.
- Reach Settings and verify each visible preference changes actual behavior.
- Correct the screenshot harness so test-view physical size, pixel ratio, MediaQuery and layout constraints agree; assert logical dimensions before capture. Resolve chip font loading and check normal shadow rendering. Reproduce the phase-row and Log & Earn overflow cases before attributing them to phone layouts.
- Render at 320/360/390 px, landscape and desktop widths, with large text, keyboard open, light/dark and reduced motion.
- Exercise midnight/resume, five overlapping events, long titles, empty data and substantial history.
- Verify no duplicate reminders during editing, recording or another tab.
- Profile scrolling/background work; test native voice and microphone permissions on supported devices.

## PART 8 — Prioritized improvement roadmap

Rough effort for one developer familiar with this project, including focused validation. Items overlap; these are not additive commitments.

| Group / Priority | Improvement | Expected UX benefit | Effort | Affected screens |
|---|---|---|---|---|
| Quick win / P0 | Persist empty-hour tasks and use selected due date | Reliable capture/calendar location | 0.5–1 day | Day, all quick-add entries |
| Quick win / P0 | Remove/rename unsafe Select All until selection is implemented | Avoid unexpected completion | Under 0.5 day | Log & Earn |
| Quick win / P1 | Visible menu, reachable Settings, remove duplicate Reports entry | Discoverability | 0.5–1 day | Shell, Dashboard |
| Quick win / P1 | Validate money/goal inputs before close | Truthful success and correct data | 0.5–1.5 days | Money, Goals |
| Quick win / P1 | Larger task actions and actual completion checkbox | Easier daily interaction | 0.5–1 day | Tasks |
| Quick win / P2 | Correct scope, empty, implementation and date wording | Accurate expectations | 0.5–1 day | Period views, Dashboard, Day |
| Quick win / P2 | Distinguish duplicate points labels and remove implementation copy | Understandable summaries | 0.5–1 day | Progress, Dashboard |
| Medium / P1 | Journal drafts and consistent deletion recovery | Protect user effort | 1–3 days | Journal, Journey, Motivation, Instructions |
| Medium / P1 | Shared occurrence rules and linked-instruction visibility | Consistent completion/retrieval | 2–4 days | Tasks, routines, Log & Earn, Instructions |
| Medium / P1 | Central reminders and inactive-screen guards | Fewer interruptions | 1–2 days | Goals, Progress, Motivation |
| Medium / P1 | Theme roles and working preferences | Consistent appearance | 2–4 days | All screens |
| Medium / P2 | Basic/advanced editor with inline errors | Faster capture | 2–4 days | Task form, voice review |
| Medium / P1 | Put work before summaries; compact profile/mood/metric sections | Faster access to tasks, logging, writing and trends (V-H1) | 2–4 days | Dashboard, Day, Streak, Progress, Log & Earn, Journal |
| Medium / P2 | Correct/label metric denominators | Trustworthy progress | 1–3 days | Month, Year, summaries |
| Medium / P2 | Journey picker and ID-based relationships | Easier media and accurate links | 1–2 days | Journey, Goals, Tasks |
| Major / P1 | Today / Plan / Progress / More structure | Lower navigation burden | 3–6 days | Shell, main screens |
| Major / P2 | Unified calendar/agenda and overlap UI | Better planning, less scrolling | 4–7 days | Year, Month, Week, Day |
| Major / P2 | Consolidated progress/streak/history hierarchy | Clearer review | 3–5 days | Dashboard, Streak, Progress, Journey |
| Release gate / P1 | Responsive/accessibility/device verification | Evidence of release quality | 2–4 days initially | Whole app |

Order: fix data/action defects, protect drafts, clarify navigation and outcomes, unify components/themes, then restructure larger screens. A new layout alone will preserve underlying failures.

## PART 9 — Final assessment

### Current rating

**4.2/10 overall, provisional; visual design 5/10 and professional appearance 4/10.** The unchanged rounded overall score now includes screenshot evidence and a lower layout score. The light-theme reference images show a recognizable visual identity but weak action hierarchy and inconsistent composition. Dark-mode rendering and real-device responsiveness remain unverified. Core-flow issues should be addressed before public release.

### Three strongest aspects

1. Distinctive time-bubble identity and a recognizable teal/mint light-theme foundation in the captures.
2. Useful local task/routine infrastructure, stable identities, shared forms and a passing existing test suite.
3. Voice capture with typed fallback, visible states and explicit review before saving.

### Five most important problems

1. Unreliable task creation in empty-hour and changed-date quick-add paths.
2. Unsaved journal writing lost through ordinary navigation.
3. Select All conceals bulk completion.
4. Hidden/overlapping navigation and disconnected Settings.
5. Summaries/profile cards bury core work; tiny annual labels, dense task metadata and inconsistent surface roles reduce clarity.

### Top five recommended improvements

1. Centralize and verify creation, date placement and completion.
2. Protect drafts and provide deletion recovery.
3. Make navigation visible and task-oriented.
4. Put tasks/writing/trends before optional summaries; simplify capture and daily task rows while retaining advanced controls.
5. Apply one accessible component/theme/type system and verify on devices.

### Realistic target quality

**7.5–8/10 is a reasonable target**, conditional on resolving behavior defects, simplifying the daily journey, consistent rendering and validation with users/assistive technology. This is a target, not a promised result.

A 9/10 claim would require evidence of successful first-use journeys, reliable long-session behavior, polished device layouts, accessibility and measured performance.

### Implement first

Fix both task-save paths, journal drafts and misleading bulk completion first. These determine whether people can trust the app with everyday work. Then address discoverability, false success/validation, linked instruction visibility and consistent completion. Visual polish will deliver more value once controls reliably do what they promise.

No product fixes have been implemented by this audit update. Application source remains unchanged. The next visual verification should use corrected capture dimensions/fonts and an interactive phone session; the existing gallery is useful reference evidence, not a device acceptance test.


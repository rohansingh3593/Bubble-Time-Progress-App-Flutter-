# Navigation and screen organization

Updated 4 November 2026. This records the navigation implementation, separate from the historical whole-app audit.

| Destination | Purpose | Organization |
| --- | --- | --- |
| Today | Act on today's tasks | Add task, next tasks, completion summary and reflection |
| Plan | Browse dates and schedules | Day, Week, Month and Year share the selected date; date picker and Today shortcut stay visible |
| Progress | Understand trends | One destination for trends, history and reports |
| More | Find supporting features | Searchable groups: Plan and act, Reflect, Rewards, Preferences |

More contains Tasks, Routines and streaks, Instructions, Add by voice, Journal, Journey, Motivation, Log & Earn, Reward goals, Reward budget and Settings. Descriptions explain each feature. Settings also has a shortcut in More's app bar. The redundant dashboard overview link has been removed; its legacy widget remains in the repository.

## Navigation behavior

- Four labeled destinations remain visible on detail pages. Wider layouts use a navigation rail.
- Each destination retains its route history and screen state for the current app session. Switching destinations preserves a journal editor, Plan's date/scale, and More's search/scroll position.
- Back returns through the active destination's history, respecting save/draft guards. Back at another destination's root returns to Today; Back at Today's root follows platform exit behavior.
- Reselecting the active destination keeps your place. Task dialogs block underlying navigation until saved or dismissed, with discard protection.
- Changing phone/window width preserves the current route. Inactive destinations pause animations; destinations are created on first visit.
- The start-screen preference applies on the next app launch. Route history itself is not persisted across process restarts.
- Plan keeps period summaries collapsed below calendar and routine content, keeping trends secondary to planning.
- Plan routine panels use theme surfaces for readable labels in both light and dark appearance.
- Calendar navigation has labeled controls and a shared date picker. Large-text fixes allow calendar legends and week controls to wrap without shrinking text.

## Evidence

Eight navigation regression tests cover independent histories, back behavior, search and empty results, calendar/date continuity across a month boundary, resizing, saved start destination, journal draft retention, guarded task dialogs and 320 px calendars at 2x text. On 4 November, all **21 navigation and workflow tests passed**, including the eight navigation tests. The earlier full-suite run on 31 October passed 61 tests with 1 opt-in native voice test skipped. Focused analysis at that checkpoint reported no errors or warnings, with 10 style/deprecation information messages.

Phone reference gallery: [light and dark navigation screenshots](../screenshots/phone/navigation-review-20261104/index.html). These use actual widgets, synthetic data and a 390 x 844 viewport. The 18 light/dark images recorded no rendering issues. Generated files are ignored by Git.

Regenerate with:

```powershell
.\capture_screenshots.ps1 -Theme both -Screen 00-app-shell
```

A perfect usability score is not established by these checks. Android/iOS back gestures, screen-reader traversal, and feature-finding with users remain device/usability review items. This pass does not re-rate unrelated visual, persistence or reward behavior.

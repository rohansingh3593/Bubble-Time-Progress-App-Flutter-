# Production Architecture Roadmap

This roadmap extends the current local-first Flutter app into a production-ready, cross-platform productivity system with Flutter desktop/mobile clients, a FastAPI backend, MongoDB persistence, and real-time synchronization.

## Target System Overview

```text
                    ┌─────────────────────────┐
                    │ Flutter Windows App     │
                    │ Desktop Productivity    │
                    └──────────┬──────────────┘
                               │
                     WebSocket + REST API
                               │
                               ▼
                  ┌──────────────────────────┐
                  │      FastAPI Backend      │
                  │--------------------------│
                  │ Authentication           │
                  │ Task Service             │
                  │ Routine Service          │
                  │ Instruction Service      │
                  │ Goal Service             │
                  │ Journal Service          │
                  │ Notification Service     │
                  │ WebSocket Manager        │
                  │ Scheduler                │
                  │ Analytics Service        │
                  └──────────┬───────────────┘
                             │
                 Async Motor │
                             ▼
                  ┌──────────────────────────┐
                  │        MongoDB           │
                  │ Tasks                    │
                  │ Routines                 │
                  │ Instructions             │
                  │ Goals                    │
                  │ Journals                 │
                  │ Rewards                  │
                  │ User Settings            │
                  │ Notifications            │
                  │ Statistics               │
                  └──────────┬───────────────┘
                             ▲
                             │
                     WebSocket + REST API
                             │
                    ┌────────┴─────────────┐
                    │ Flutter Mobile App   │
                    │ Daily Companion      │
                    └──────────────────────┘
```


## Working Starter Implementation

The repository includes a runnable starter backend in `backend/` and a Flutter WebSocket helper in `lib/services/sync_service.dart`. This makes the architecture executable instead of documentation-only.

```text
Flutter Windows App
        ↕ WebSocket + REST API
FastAPI Backend
        ↕ MongoDB
Flutter Mobile App
```

Backend files:

```text
backend/
├── main.py
├── database.py
├── websocket_manager.py
├── models.py
└── requirements.txt
```

Install and run the backend from the `backend/` directory:

```bash
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Use `http://localhost:8000` for the health check. Mobile devices should connect to the host machine IP, for example `ws://192.168.1.10:8000/ws`.

The working synchronization rule is:

- Windows task time update: Windows Flutter → WebSocket → FastAPI → MongoDB → broadcast → Mobile Flutter.
- Mobile task completion: Mobile Flutter → WebSocket → FastAPI → MongoDB → broadcast → Windows Flutter.

## Recommended Repository Structure

The existing Flutter application can remain the shared app shell while the backend and any split desktop/mobile clients are introduced incrementally.

```text
task_app/
├── flutter_windows_app/
├── flutter_mobile_app/
└── backend/
    ├── app/
    ├── main.py
    ├── config/
    │   ├── settings.py
    │   └── constants.py
    ├── database/
    │   └── mongodb.py
    ├── websocket/
    │   ├── manager.py
    │   └── broadcaster.py
    ├── models/
    │   ├── task.py
    │   ├── instruction.py
    │   ├── routine.py
    │   ├── goal.py
    │   ├── journal.py
    │   ├── notification.py
    │   └── user.py
    ├── routes/
    │   ├── auth.py
    │   ├── task.py
    │   ├── routine.py
    │   ├── instruction.py
    │   ├── goal.py
    │   ├── journal.py
    │   └── websocket.py
    ├── services/
    │   ├── task_service.py
    │   ├── schedule_service.py
    │   ├── analytics_service.py
    │   ├── notification_service.py
    │   ├── instruction_service.py
    │   └── reward_service.py
    ├── scheduler/
    │   └── apscheduler.py
    ├── utils/
    └── requirements.txt
```

## API Boundaries

Use REST for durable CRUD operations and WebSockets for real-time synchronization.

### REST Endpoints

| Capability | Endpoint examples |
| --- | --- |
| Tasks | `GET /tasks`, `POST /tasks`, `PUT /tasks/{id}`, `DELETE /tasks/{id}` |
| Goals | `GET /goals`, `POST /goals`, `PUT /goals/{id}` |
| Journals | `GET /journals`, `POST /journal` |
| Analytics | `GET /statistics`, `GET /dashboard` |
| Settings | `GET /settings`, `PUT /settings` |

### WebSocket Endpoint

Prefer a single event-routed endpoint:

```text
/ws
```

Topic-specific endpoints such as `/ws/tasks`, `/ws/goals`, `/ws/notifications`, `/ws/dashboard`, and `/ws/journal` can be added later if traffic isolation becomes necessary.

## Event-Based WebSocket Protocol

Send typed events rather than raw records so clients can route changes consistently.

```json
{
  "event": "task_updated",
  "data": {
    "task_id": "123",
    "title": "Workout",
    "start_time": "08:00",
    "end_time": "09:00"
  }
}
```

Recommended events:

- `task_created`
- `task_updated`
- `task_deleted`
- `task_completed`
- `routine_completed`
- `instruction_updated`
- `goal_updated`
- `journal_saved`
- `notification_created`
- `reward_updated`
- `schedule_changed`
- `settings_changed`

## Real-Time Flows

### Task Updated

1. Windows app edits a task.
2. Client sends a WebSocket event or REST update.
3. FastAPI validates the user and payload.
4. Backend persists the change to MongoDB.
5. WebSocket broadcaster sends `task_updated` to subscribed devices.
6. Mobile app refreshes the affected task/timeline state.

### Task Completed

1. Mobile app marks a task complete.
2. Backend updates the task status.
3. Reward service calculates bonus coins or points.
4. Streak/statistics services update progress.
5. Backend broadcasts `task_completed`, `reward_updated`, and any statistics changes.
6. Windows dashboard updates immediately.

### Drag-and-Drop Schedule

1. Windows app drags a task to a new timeline slot.
2. Client sends the new `start_time` and `end_time`.
3. Schedule service validates overlaps and recalculates the day timeline.
4. Backend saves the updated schedule.
5. Backend broadcasts `schedule_changed`.
6. Mobile timeline refreshes with the new schedule.

## MongoDB Collections

Start with clear domain collections and add history/audit collections as features mature.

- `users`
- `tasks`
- `task_history`
- `routines`
- `routine_history`
- `instructions`
- `instruction_history`
- `goals`
- `goal_progress`
- `journals`
- `notifications`
- `motivations`
- `analytics`
- `rewards`
- `settings`
- `activity_logs`
- `websocket_sessions`

## Suggested Backend Libraries

- FastAPI
- Motor
- Uvicorn
- Pydantic
- APScheduler
- python-jose
- passlib
- bcrypt
- python-dotenv
- websockets
- orjson

## Suggested Flutter Packages

- `web_socket_channel`
- `dio`
- `provider`, `riverpod`, or `bloc`
- `flutter_local_notifications`
- `timezone`
- `go_router`
- `flutter_secure_storage`
- `shared_preferences`
- `connectivity_plus`
- `uuid`

## Implementation Phases

1. **Local-first hardening**: keep Hive storage stable, normalize models, and add repository interfaces around local data access.
2. **Backend foundation**: add FastAPI, MongoDB connection management, authentication, and task CRUD.
3. **Sync layer**: introduce REST repositories in Flutter plus event-routed WebSocket updates.
4. **Productivity domains**: add routines, instructions, goals, journals, rewards, and analytics services.
5. **Scheduling and notifications**: add drag-and-drop schedule persistence, conflict handling, APScheduler jobs, and local/push notification flows.
6. **Offline support**: cache API responses locally, queue mutations while offline, and reconcile changes when connectivity returns.
7. **Scale and operations**: add structured logging, activity logs, monitoring, backups, rate limiting, and deployment automation.

## Feature Coverage

This architecture supports:

- Real-time Windows-to-mobile task synchronization
- Drag-and-drop scheduling
- Live dashboard updates
- Notifications and reminders
- Streak synchronization
- Goal progress updates
- Instruction completion updates
- Journal synchronization
- Reward/coin updates
- Offline caching with later synchronization
- Multi-device login
- Future web app support

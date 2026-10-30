import json
import os
import re
from datetime import datetime
from typing import Annotated

from fastapi import FastAPI, Header, HTTPException, WebSocket, WebSocketDisconnect, status
from fastapi.middleware.cors import CORSMiddleware

from database import tasks_collection
from models import BroadcastEvent, TaskPayload, TaskUpdatePayload, WebSocketEvent
from websocket_manager import WebSocketManager

app = FastAPI(title="Momentum Task Sync Backend")
manager = WebSocketManager()

allowed_origins = [
    origin.strip()
    for origin in os.getenv("CORS_ALLOWED_ORIGINS", "*").split(",")
    if origin.strip()
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

TIME_PATTERN = re.compile(r"^([01]\d|2[0-3]):[0-5]\d$")


@app.on_event("startup")
async def configure_database_indexes():
    await tasks_collection.create_index(
        [("user_id", 1), ("task_id", 1)],
        unique=True,
    )


def utc_now_iso() -> str:
    return datetime.utcnow().isoformat()


def resolve_user_id(x_user_id: str | None = None) -> str:
    # Development auth seam: replace this with token verification before production.
    user_id = (x_user_id or os.getenv("DEV_USER_ID", "dev-user")).strip()
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="A user identity is required.",
        )
    return user_id


def public_task(task: dict) -> dict:
    task = dict(task)
    task["_id"] = str(task["_id"])
    return task


def validate_schedule(task_data: dict) -> None:
    for field_name in ("start_time", "end_time"):
        value = task_data.get(field_name)
        if value is not None and not TIME_PATTERN.match(str(value)):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"{field_name} must use HH:MM 24-hour format.",
            )


def task_event_name(task_data: dict, default: str) -> str:
    if task_data.get("done") is True or str(task_data.get("status", "")).lower() == "completed":
        return "task_completed"
    if "start_time" in task_data or "end_time" in task_data:
        return "schedule_changed"
    return default


async def broadcast_task_event(user_id: str, event: str, task_data: dict) -> None:
    message = BroadcastEvent(event=event, user_id=user_id, data=task_data).model_dump()
    await manager.broadcast(user_id, message)


@app.get("/")
async def health_check():
    return {"status": "Backend running"}


@app.get("/tasks")
async def get_tasks(x_user_id: Annotated[str | None, Header(alias="X-User-Id")] = None):
    tasks = []
    user_id = resolve_user_id(x_user_id)
    async for task in tasks_collection.find({"user_id": user_id}):
        tasks.append(public_task(task))
    return tasks


@app.post("/tasks")
async def create_task(
    task: TaskPayload,
    x_user_id: Annotated[str | None, Header(alias="X-User-Id")] = None,
):
    user_id = resolve_user_id(x_user_id)
    task_data = task.model_dump(exclude_none=True)
    task_data.pop("user_id", None)
    validate_schedule(task_data)
    task_data["user_id"] = user_id
    task_data["updated_at"] = utc_now_iso()

    result = await tasks_collection.update_one(
        {"task_id": task_data["task_id"], "user_id": user_id},
        {"$set": task_data},
        upsert=True,
    )

    event = "task_created" if result.upserted_id is not None else task_event_name(task_data, "task_updated")
    await broadcast_task_event(user_id, event, task_data)

    return {"message": "Task saved", "task": task_data}


@app.put("/tasks/{task_id}")
async def update_task(
    task_id: str,
    task: TaskUpdatePayload,
    x_user_id: Annotated[str | None, Header(alias="X-User-Id")] = None,
):
    user_id = resolve_user_id(x_user_id)
    task_data = task.model_dump(exclude_none=True)
    task_data.pop("user_id", None)
    validate_schedule(task_data)
    task_data["task_id"] = task_id
    task_data["user_id"] = user_id
    task_data["updated_at"] = utc_now_iso()

    result = await tasks_collection.update_one(
        {"task_id": task_id, "user_id": user_id},
        {"$set": task_data},
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Task not found.")

    event = task_event_name(task_data, "task_updated")
    await broadcast_task_event(user_id, event, task_data)
    return {"message": "Task updated", "task": task_data}


@app.delete("/tasks/{task_id}")
async def delete_task(
    task_id: str,
    x_user_id: Annotated[str | None, Header(alias="X-User-Id")] = None,
):
    user_id = resolve_user_id(x_user_id)
    result = await tasks_collection.delete_one({"task_id": task_id, "user_id": user_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Task not found.")

    data = {"task_id": task_id, "user_id": user_id, "updated_at": utc_now_iso()}
    await broadcast_task_event(user_id, "task_deleted", data)
    return {"message": "Task deleted", "task_id": task_id}


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    user_id = websocket.query_params.get("user_id") or os.getenv("DEV_USER_ID", "dev-user")
    await manager.connect(user_id, websocket)

    try:
        while True:
            raw_data = await websocket.receive_text()
            message = WebSocketEvent.model_validate(json.loads(raw_data))
            if message.event == "ping":
                await websocket.send_text(json.dumps({"event": "pong", "data": {}}))

    except WebSocketDisconnect:
        manager.disconnect(user_id, websocket)
    except Exception:
        manager.disconnect(user_id, websocket)

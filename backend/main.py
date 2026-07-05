import json
from datetime import datetime

from fastapi import FastAPI, WebSocket
from fastapi.middleware.cors import CORSMiddleware

from database import tasks_collection
from models import TaskPayload, WebSocketEvent
from websocket_manager import WebSocketManager

app = FastAPI(title="Momentum Task Sync Backend")
manager = WebSocketManager()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def utc_now_iso() -> str:
    return datetime.utcnow().isoformat()


@app.get("/")
async def health_check():
    return {"status": "Backend running"}


@app.get("/tasks")
async def get_tasks():
    tasks = []
    async for task in tasks_collection.find({}):
        task["_id"] = str(task["_id"])
        tasks.append(task)
    return tasks


@app.post("/tasks")
async def create_task(task: TaskPayload):
    task_data = task.model_dump(exclude_none=True)
    task_data["updated_at"] = utc_now_iso()

    await tasks_collection.update_one(
        {"task_id": task_data["task_id"]},
        {"$set": task_data},
        upsert=True,
    )

    await manager.broadcast({"event": "task_created_or_updated", "data": task_data})

    return {"message": "Task saved", "task": task_data}


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)

    try:
        while True:
            raw_data = await websocket.receive_text()
            message = WebSocketEvent.model_validate(json.loads(raw_data))
            event = message.event
            data = message.data

            if event in ["task_created", "task_updated", "task_completed"]:
                data["updated_at"] = utc_now_iso()

                await tasks_collection.update_one(
                    {"task_id": data["task_id"]},
                    {"$set": data},
                    upsert=True,
                )

                await manager.broadcast({"event": event, "data": data})

            if event == "task_deleted":
                await tasks_collection.delete_one({"task_id": data["task_id"]})
                data["updated_at"] = utc_now_iso()
                await manager.broadcast({"event": event, "data": data})

    except Exception:
        manager.disconnect(websocket)
